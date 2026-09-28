"""Cursor adapter shim: Stitch bridge → bundled Cursor CLI.

Same `handle(...)` shape as Completions. Spawns `cursor-agent` per invoke
(parallel-safe across workspaces via a per-cwd lock; one workspace is
serialized). The bridge process never imports `cursor-sdk`.

Maps streamed progress into two reply chains under the trigger:
  - side fork: thinking / functionCall / functionResult
  - reply branch: localBot assistant text (last message_end buffered until
    the terminal result, then flushed with is_final + usage)
"""

from __future__ import annotations

import uuid
from collections.abc import Awaitable, Callable, Mapping, Sequence
from pathlib import Path
from typing import Any

import cursor_cli
import protocol
from logging_setup import hop
from typing_cue import TypingCue

SendFn = Callable[[dict[str, Any]], Awaitable[None]]

_SIDE_KINDS = frozenset({"thinking", "functionCall", "functionResult"})


async def _invoke_runner_once(
    payload: dict[str, Any],
    on_progress: Callable[[Mapping[str, Any]], Awaitable[None]],
) -> dict[str, Any]:
    """Run one invoke against the bundled Cursor CLI."""
    return await cursor_cli.invoke(payload, on_progress)


def _role_for_kind(kind: str) -> str:
    if kind in ("thinking", "functionCall", "functionResult", "localBot"):
        return kind
    return "localBot"


async def handle(
    *,
    parent_message_id: str | None,
    bot_id: str,
    context: Sequence[Mapping[str, Any]],
    send: SendFn,
    cwd: str | None = None,
    model: str | None = None,
) -> None:
    """Forward a Cursor invoke to the runtime runner and emit wire envelopes."""
    fallback_message_id = f"srv-{uuid.uuid4()}"
    invoke_root_id = parent_message_id
    # Column cwd is optional; fall back to home. Expand ~ so Dart tags like
    # `~/stitch/stitch-chat` become real paths before the runner/SDK see them.
    raw = (cwd or "").strip() or str(Path.home())
    resolved_cwd = str(Path(raw).expanduser().resolve())

    hop(
        "py.adapter",
        "cursor start bot_id={} parent={} cwd={} context_len={} model={}",
        bot_id,
        parent_message_id,
        resolved_cwd,
        len(context),
        model or "-",
    )

    side_parent = parent_message_id
    reply_parent = parent_message_id
    buffered_reply_end: dict[str, Any] | None = None
    saw_reply_part = False
    typing = TypingCue(
        send,
        author_id=bot_id,
        target_message_id=parent_message_id,
    )

    async def _reject_unauthenticated() -> None:
        """Login lapsed mid-run. Skip (not an error toast) so Dart can replay."""
        cursor_cli.invalidate_auth_cache()
        await send(
            protocol.auth_state_envelope(
                bot_id=bot_id,
                state="unauthenticated",
                detail="Not authenticated",
            )
        )
        await send(
            {
                "type": protocol.INVOKE_SKIPPED,
                "message_id": None,
                "parent_message_id": parent_message_id,
                "invoke_root_id": invoke_root_id,
                "bot_id": bot_id,
                "reason": "requires_auth",
            }
        )

    async def _send_start(
        *,
        message_id: str,
        parent: str | None,
        role: str,
        tool_name: str | None = None,
        tool_call_id: str | None = None,
    ) -> None:
        env: dict[str, Any] = {
            "type": protocol.MESSAGE_START,
            "message_id": message_id,
            "parent_message_id": parent,
            "invoke_root_id": invoke_root_id,
            "bot_id": bot_id,
            "role": role,
        }
        if tool_name:
            env["tool_name"] = tool_name
        if tool_call_id:
            env["tool_call_id"] = tool_call_id
        await send(env)

    async def _send_end(
        *,
        message_id: str,
        parent: str | None,
        role: str,
        content: str,
        is_final: bool = False,
        hidden: bool = False,
        usage: Mapping[str, Any] | None = None,
        tool_name: str | None = None,
        tool_call_id: str | None = None,
        is_error: bool | None = None,
    ) -> None:
        env: dict[str, Any] = {
            "type": protocol.MESSAGE_END,
            "message_id": message_id,
            "parent_message_id": parent,
            "invoke_root_id": invoke_root_id,
            "bot_id": bot_id,
            "role": role,
            "content": content,
            "is_final": is_final,
        }
        if hidden:
            env["hidden"] = True
        if usage is not None:
            env["usage"] = dict(usage)
        if tool_name:
            env["tool_name"] = tool_name
        if tool_call_id:
            env["tool_call_id"] = tool_call_id
        if is_error is not None:
            env["is_error"] = is_error
        await send(env)

    async def on_progress(part: Mapping[str, Any]) -> None:
        nonlocal side_parent, reply_parent, buffered_reply_end, saw_reply_part
        await typing.refresh()
        kind = str(part.get("kind") or "")
        message_id = str(part.get("message_id") or f"srv-{uuid.uuid4()}")
        content = str(part.get("content") or "")
        role = _role_for_kind(kind)
        tool_name = part.get("tool_name")
        tool_call_id = part.get("tool_call_id")
        is_error = part.get("is_error")
        branch = str(part.get("branch") or "")
        if not branch:
            branch = "side" if kind in _SIDE_KINDS else "reply"

        if branch == "side" or kind in _SIDE_KINDS:
            parent = side_parent
            edge_hidden = parent is not None and parent == invoke_root_id
            await _send_start(
                message_id=message_id,
                parent=parent,
                role=role,
                tool_name=str(tool_name) if tool_name else None,
                tool_call_id=str(tool_call_id) if tool_call_id else None,
            )
            await _send_end(
                message_id=message_id,
                parent=parent,
                role=role,
                content=content,
                hidden=edge_hidden,
                tool_name=str(tool_name) if tool_name else None,
                tool_call_id=str(tool_call_id) if tool_call_id else None,
                is_error=bool(is_error) if is_error is not None else None,
            )
            side_parent = message_id
            return

        parent = reply_parent
        if buffered_reply_end is not None:
            await _send_end(**buffered_reply_end)
            buffered_reply_end = None

        await _send_start(
            message_id=message_id,
            parent=parent,
            role=role,
        )
        buffered_reply_end = {
            "message_id": message_id,
            "parent": parent,
            "role": role,
            "content": content,
        }
        reply_parent = message_id
        saw_reply_part = True

    async with typing:
        try:
            result = await _invoke_runner_once(
                {
                    "cwd": resolved_cwd,
                    "context": list(context),
                    "model": model,
                    "assistant_message_id": fallback_message_id,
                },
                on_progress,
            )
        except Exception as exc:  # noqa: BLE001
            hop(
                "py.adapter",
                "cursor runner error parent={} err={}",
                parent_message_id,
                exc,
            )
            if cursor_cli.looks_like_auth_failure(str(exc)):
                await _reject_unauthenticated()
                return
            await send(
                {
                    "type": protocol.ERROR,
                    "message_id": fallback_message_id,
                    "parent_message_id": parent_message_id,
                    "invoke_root_id": invoke_root_id,
                    "error": f"cursor runner failed: {exc}",
                }
            )
            return

        if not result.get("ok"):
            err = str(result.get("error") or "cursor run failed")
            hop(
                "py.adapter",
                "cursor fail parent={} kind={} mode={} agent={} err={}",
                parent_message_id,
                result.get("error_kind"),
                result.get("mode"),
                result.get("agent_id") or "-",
                err,
            )
            if result.get("error_kind") == "auth" or cursor_cli.looks_like_auth_failure(err):
                await _reject_unauthenticated()
                return
            await send(
                {
                    "type": protocol.ERROR,
                    "message_id": fallback_message_id,
                    "parent_message_id": parent_message_id,
                    "invoke_root_id": invoke_root_id,
                    "error": err,
                }
            )
            return

        usage = result.get("usage") if isinstance(result.get("usage"), dict) else None
        text = str(result.get("text") or "")

        hop(
            "py.adapter",
            "cursor ok parent={} mode={} agent={} run={} chars={} usage={} reply_parts={}",
            parent_message_id,
            result.get("mode"),
            result.get("agent_id") or "-",
            result.get("run_id") or "-",
            len(text),
            usage,
            saw_reply_part,
        )

        # Runner finished but final reply may still be buffered — keep typing until
        # the terminal message_end is on the wire.
        await typing.refresh()

        if buffered_reply_end is not None:
            await _send_end(
                **buffered_reply_end,
                is_final=True,
                usage=usage,
            )
            return

        if text:
            message_id = str(
                result.get("assistant_message_id") or fallback_message_id
            )
            await _send_start(
                message_id=message_id,
                parent=parent_message_id,
                role="localBot",
            )
            await _send_end(
                message_id=message_id,
                parent=parent_message_id,
                role="localBot",
                content=text,
                is_final=True,
                usage=usage,
            )
            return

        await send(
            {
                "type": protocol.ERROR,
                "message_id": fallback_message_id,
                "parent_message_id": parent_message_id,
                "invoke_root_id": invoke_root_id,
                "error": "cursor run finished with no assistant text",
            }
        )
