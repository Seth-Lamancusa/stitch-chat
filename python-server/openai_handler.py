"""Hardcoded OpenAI Responses API call for the hello-world bot.

This stands in for the eventual RuntimeRegistry/OpenAICompatibleHandler
(see project README) — one bot, one handler, no dynamic dispatch yet.

Uses the Responses API rather than Chat Completions so this handler already
speaks in the same per-part-completion terms (`response.output_item.done`)
that the multi-part WS protocol will need once it lands — no token-delta
reveal, since the UI shows a typing indicator instead. Today's hello-world
only ever produces a single text output item, so this still emits one
message_start/message_end pair; a future tool-calling turn would emit one
pair per output item without changing this loop's shape.
"""

import os
import uuid

from openai import AsyncOpenAI

import protocol


async def stream_reply(content: str, parent_message_id: str, send):
    """Call OpenAI and forward message_end/error envelopes via `send`."""
    api_key = os.environ.get("OPENAI_API_KEY")
    message_id = f"srv-{uuid.uuid4()}"

    if not api_key:
        await send({
            "type": protocol.ERROR,
            "message_id": message_id,
            "error": "OPENAI_API_KEY not set",
        })
        return

    client = AsyncOpenAI(api_key=api_key)

    await send({
        "type": protocol.MESSAGE_START,
        "message_id": message_id,
        "parent_message_id": parent_message_id,
        "bot_id": protocol.DEFAULT_BOT_ID,
    })

    full_content = ""
    try:
        stream = await client.responses.create(
            model=protocol.DEFAULT_MODEL,
            input=[{"role": "user", "content": content}],
            stream=True,
        )
        async for event in stream:
            if event.type != "response.output_item.done":
                continue
            item = event.item
            if item.type == "message":
                full_content += "".join(
                    part.text for part in item.content if part.type == "output_text"
                )
    except Exception as exc:  # noqa: BLE001 - surface any OpenAI/network error to the client
        await send({
            "type": protocol.ERROR,
            "message_id": message_id,
            "error": str(exc),
        })
        return

    await send({
        "type": protocol.MESSAGE_END,
        "message_id": message_id,
        "content": full_content,
    })
