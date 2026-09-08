"""Bot-id → adapter dispatch.

The bridge looks up a handler by canonical bot id and forwards the Stitch
invoke (context window including trigger as the last node, optional column
cwd). Adapters own runtime projection, session affinity, and any durable
handles — none of that belongs on the wire or in Stitch's core model.
"""

from __future__ import annotations

from collections.abc import Awaitable, Callable, Mapping, Sequence
from typing import Any

from cursor_adapter import handle as cursor_handle
from openai_compatible import stream_reply as openai_stream_reply

SendFn = Callable[[dict[str, Any]], Awaitable[None]]

AdapterFn = Callable[..., Awaitable[None]]

# Canonical bot id → adapter. Keys must match protocol.KNOWN_BOT_IDS.
ADAPTERS: dict[str, AdapterFn] = {
    "chatgpt": openai_stream_reply,
    "cursor": cursor_handle,
}


async def dispatch(
    *,
    bot_id: str,
    parent_message_id: str | None,
    context: Sequence[Mapping[str, Any]],
    send: SendFn,
    cwd: str | None = None,
) -> None:
    """Invoke the adapter registered for [bot_id]."""
    handler = ADAPTERS[bot_id]
    await handler(
        parent_message_id=parent_message_id,
        bot_id=bot_id,
        context=context,
        send=send,
        cwd=cwd,
    )
