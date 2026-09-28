"""OpenAI-compatible Chat Completions handler (first Stitch bot path).

Projects a Stitch context window (trigger included as the last node) into
`messages[]` and calls chat.completions. No strict role alternation, no
name-prefixing, no session affinity — those belong in later adapter-local
projectors if a runtime requires them.
"""

from __future__ import annotations

import os
import uuid
from collections.abc import Awaitable, Callable, Mapping, Sequence
from typing import Any

from loguru import logger
from openai import AsyncOpenAI

import protocol
from logging_setup import hop

SendFn = Callable[[dict[str, Any]], Awaitable[None]]

# Stitch MessageRole wire values → Completions roles.
_ROLE_TO_COMPLETIONS = {
    "user": "user",
    "localBot": "assistant",
    "functionCall": "assistant",
    "functionResult": "user",
    "thinking": "assistant",
}


def project_context(
    context: Sequence[Mapping[str, Any]],
) -> list[dict[str, str]]:
    """Stitch context window (trigger last) → Chat Completions messages[]."""
    messages: list[dict[str, str]] = []
    for node in context:
        role = _ROLE_TO_COMPLETIONS.get(str(node.get("role", "")), "user")
        content = str(node.get("content", ""))
        if not content:
            continue
        messages.append({"role": role, "content": content})
    return messages


async def stream_reply(
    *,
    parent_message_id: str | None,
    bot_id: str,
    context: Sequence[Mapping[str, Any]],
    send: SendFn,
    cwd: str | None = None,
    model: str | None = None,
) -> None:
    """Call Chat Completions and emit message_start / message_end / error.

    [cwd] is accepted for a uniform adapter invoke shape; Completions does
    not bind a working directory. [context] already includes the trigger as
    its final node.
    """
    api_key = os.environ.get("OPENAI_API_KEY")
    base_url = os.environ.get("OPENAI_BASE_URL")  # OpenRouter / Ollama / etc.
    resolved_model = model or os.environ.get("OPENAI_MODEL") or protocol.DEFAULT_MODEL
    message_id = f"srv-{uuid.uuid4()}"

    hop(
        "py.adapter",
        "start bot_id={} parent={} model={} cwd={} context_len={} base_url={}",
        bot_id,
        parent_message_id,
        resolved_model,
        cwd or "-",
        len(context),
        base_url or "default",
    )

    if not api_key and not base_url:
        # Local servers (Ollama) often need no key; cloud OpenAI does.
        logger.error("OPENAI_API_KEY not set and no OPENAI_BASE_URL")
        await send(
            {
                "type": protocol.ERROR,
                "message_id": message_id,
                "parent_message_id": parent_message_id,
                "error": "OPENAI_API_KEY not set",
            }
        )
        return

    typing_target = parent_message_id
    if typing_target:
        await send(
            protocol.cue_envelope(
                author_id=bot_id,
                target_message_id=typing_target,
                typing=True,
            )
        )

    async def _clear_typing() -> None:
        nonlocal typing_target
        if not typing_target:
            return
        await send(
            protocol.cue_envelope(
                author_id=bot_id,
                target_message_id=typing_target,
                typing=False,
            )
        )
        typing_target = None

    client_kwargs: dict[str, Any] = {}
    if api_key:
        client_kwargs["api_key"] = api_key
    else:
        client_kwargs["api_key"] = "not-needed"
    if base_url:
        client_kwargs["base_url"] = base_url

    client = AsyncOpenAI(**client_kwargs)
    messages = project_context(context)
    hop(
        "py.adapter",
        "projected messages={} roles={}",
        len(messages),
        ",".join(m["role"] for m in messages) or "-",
    )

    await send(
        {
            "type": protocol.MESSAGE_START,
            "message_id": message_id,
            "parent_message_id": parent_message_id,
            "bot_id": bot_id,
            "role": "localBot",
        }
    )

    full_content = ""
    usage: dict[str, int] | None = None
    chunk_count = 0
    try:
        hop(
            "py.adapter",
            "→runtime completions.create model={} stream=true",
            resolved_model,
        )
        # Prefer usage on the final streamed chunk when the server supports it;
        # fall back to a plain stream for strict OpenAI-compatible servers
        # (Ollama, some proxies) that reject stream_options.
        try:
            stream = await client.chat.completions.create(
                model=resolved_model,
                messages=messages,
                stream=True,
                stream_options={"include_usage": True},
            )
        except Exception as exc:
            hop(
                "py.runtime",
                "stream_options rejected; retry plain stream err={}",
                exc,
            )
            stream = await client.chat.completions.create(
                model=resolved_model,
                messages=messages,
                stream=True,
            )
        hop("py.runtime", "stream open model={}", resolved_model)
        async for event in stream:
            if getattr(event, "usage", None) is not None:
                usage = {
                    "prompt_tokens": event.usage.prompt_tokens or 0,
                    "completion_tokens": event.usage.completion_tokens or 0,
                    "total_tokens": event.usage.total_tokens or 0,
                }
                hop("py.runtime", "usage {}", usage)
            if not event.choices:
                continue
            delta = event.choices[0].delta
            if delta and delta.content:
                chunk_count += 1
                full_content += delta.content
        hop(
            "py.runtime",
            "stream closed chunks={} chars={}",
            chunk_count,
            len(full_content),
        )
    except Exception as exc:  # noqa: BLE001 - surface any OpenAI/network error
        logger.exception(
            "completions failed bot_id={} parent={} model={}",
            bot_id,
            parent_message_id,
            resolved_model,
        )
        hop(
            "py.adapter",
            "←runtime error bot_id={} parent={} err={}",
            bot_id,
            parent_message_id,
            exc,
        )
        await send(
            {
                "type": protocol.ERROR,
                "message_id": message_id,
                "parent_message_id": parent_message_id,
                "error": str(exc),
            }
        )
        await _clear_typing()
        return

    end: dict[str, Any] = {
        "type": protocol.MESSAGE_END,
        "message_id": message_id,
        "parent_message_id": parent_message_id,
        "bot_id": bot_id,
        "role": "localBot",
        "content": full_content,
        "is_final": True,
    }
    if usage is not None:
        end["usage"] = usage
    hop(
        "py.adapter",
        "←runtime done bot_id={} parent={} chars={} usage={}",
        bot_id,
        parent_message_id,
        len(full_content),
        usage,
    )
    await send(end)
    await _clear_typing()
