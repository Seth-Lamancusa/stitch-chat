"""Bot-id → adapter dispatch.

The bridge looks up a handler by canonical bot id and forwards the Stitch
invoke (context window including trigger as the last node, optional column
cwd). Adapters own runtime projection, session affinity, and any durable
handles — none of that belongs on the wire or in Stitch's core model.
"""

from __future__ import annotations

from collections.abc import Awaitable, Callable, Mapping, Sequence
from typing import Any

import protocol
import cursor_cli
from cursor_adapter import handle as cursor_handle
from openai_compatible import stream_reply as openai_stream_reply

SendFn = Callable[[dict[str, Any]], Awaitable[None]]

AdapterFn = Callable[..., Awaitable[None]]

# Canonical bot id → adapter. Keys must match protocol.KNOWN_BOT_IDS.
ADAPTERS: dict[str, AdapterFn] = {
    "chatgpt": openai_stream_reply,
    "cursor": cursor_handle,
}

# Bots whose login the bridge can run. Dart never sees the command.
AUTH_STATUS: dict[str, Callable[..., Awaitable[dict[str, Any]]]] = {
    "cursor": cursor_cli.status,
}
AUTH_BEGIN: dict[str, Callable[..., Awaitable[dict[str, Any]]]] = {
    "cursor": cursor_cli.begin_login,
}


async def auth_snapshot(bot_id: str, *, refresh: bool = False) -> dict[str, Any]:
    """Current auth state for [bot_id]. Bots without a handler are authenticated."""
    handler = AUTH_STATUS.get(bot_id)
    if handler is None:
        return {"bot_id": bot_id, "state": "authenticated"}
    snap = await handler(refresh=refresh)
    return {**snap, "bot_id": bot_id}


async def auth_skip_reason(bot_id: str) -> str | None:
    """`requires_auth` when the bot must sign in before dispatch, else None."""
    if not protocol.bot_requires_auth(bot_id):
        return None
    snap = await auth_snapshot(bot_id)
    if snap.get("state") == "authenticated":
        return None
    return "requires_auth"


async def publish_auth_states(send: SendFn) -> None:
    """Push one `auth_state` per bot that advertises `requires_auth`."""
    for bot_id in sorted(protocol.BOTS_REQUIRING_AUTH):
        snap = await auth_snapshot(bot_id, refresh=True)
        await send(
            protocol.auth_state_envelope(
                bot_id=bot_id,
                state=str(snap.get("state") or "unauthenticated"),
                url=snap.get("url"),
                detail=snap.get("detail"),
            )
        )


async def begin_auth(bot_id: str, send: SendFn) -> None:
    """Run [bot_id]'s auth handler. The handler owns the login command."""
    if bot_id not in AUTH_BEGIN:
        await send(
            {
                "type": protocol.ERROR,
                "message_id": None,
                "parent_message_id": None,
                "error": f"no auth handler for bot_id: {bot_id}",
            }
        )
        return

    await send(protocol.auth_state_envelope(bot_id=bot_id, state="pending"))
    snap = await AUTH_BEGIN[bot_id]()
    await send(
        protocol.auth_state_envelope(
            bot_id=bot_id,
            state=str(snap.get("state") or "unauthenticated"),
            detail=snap.get("detail"),
        )
    )


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
