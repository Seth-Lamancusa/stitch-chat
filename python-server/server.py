"""WS connection handling: parses envelopes, dispatches to bot adapters."""

from __future__ import annotations

import asyncio
import json
from typing import Any

import websockets
from loguru import logger

import adapters
import protocol
from logging_setup import configure_logging, hop


def _normalize_bot_id(raw: Any) -> str:
    bot_id = str(raw or protocol.DEFAULT_BOT_ID).strip().lstrip("@").lower()
    return protocol.BOT_ALIASES.get(bot_id, bot_id)


def _normalize_cwd(raw: Any) -> str | None:
    if raw is None:
        return None
    cwd = str(raw).strip()
    return cwd or None


async def handle_connection(websocket):
    async def send(envelope: dict):
        hop(
            "py.ws",
            "→dart type={} message_id={} parent={}",
            envelope.get("type"),
            envelope.get("message_id"),
            envelope.get("parent_message_id"),
        )
        await websocket.send(json.dumps(envelope))

    peer = getattr(websocket, "remote_address", None)
    logger.info("client connected peer={}", peer)
    await send({"type": protocol.READY, "bots": protocol.bot_registry_payload()})

    async for raw in websocket:
        try:
            envelope = json.loads(raw)
        except json.JSONDecodeError:
            logger.warning("invalid JSON from peer={}", peer)
            await send(
                {
                    "type": protocol.ERROR,
                    "message_id": None,
                    "parent_message_id": None,
                    "error": "invalid JSON",
                }
            )
            continue

        hop(
            "py.ws",
            "←dart type={} message_id={} bot_id={} cwd={} context_len={}",
            envelope.get("type"),
            envelope.get("message_id"),
            envelope.get("bot_id"),
            envelope.get("cwd") or "-",
            len(envelope.get("context") or [])
            if isinstance(envelope.get("context"), list)
            else "?",
        )

        if envelope.get("type") != protocol.USER_MESSAGE:
            logger.warning("unknown envelope type={}", envelope.get("type"))
            await send(
                {
                    "type": protocol.ERROR,
                    "message_id": envelope.get("message_id"),
                    "parent_message_id": envelope.get("message_id"),
                    "error": f"unknown envelope type: {envelope.get('type')}",
                }
            )
            continue

        bot_id = _normalize_bot_id(envelope.get("bot_id"))
        parent_message_id = envelope.get("message_id")
        context = envelope.get("context") or []
        if not isinstance(context, list):
            context = []
        cwd = _normalize_cwd(envelope.get("cwd"))

        if bot_id not in protocol.KNOWN_BOT_IDS:
            logger.warning("unknown bot_id={} parent={}", bot_id, parent_message_id)
            await send(
                {
                    "type": protocol.ERROR,
                    "message_id": None,
                    "parent_message_id": parent_message_id,
                    "error": f"unknown bot_id: {bot_id}",
                }
            )
            continue

        if bot_id not in adapters.ADAPTERS:
            logger.error("no adapter registered for bot_id={}", bot_id)
            await send(
                {
                    "type": protocol.ERROR,
                    "message_id": None,
                    "parent_message_id": parent_message_id,
                    "error": f"no adapter for bot_id: {bot_id}",
                }
            )
            continue

        if protocol.bot_requires_cwd(bot_id) and not cwd:
            logger.warning(
                "cwd required bot_id={} parent={} — skip dispatch",
                bot_id,
                parent_message_id,
            )
            hop(
                "py.server",
                "skip dispatch bot_id={} parent={} reason=requires_cwd",
                bot_id,
                parent_message_id,
            )
            await send(
                {
                    "type": protocol.INVOKE_SKIPPED,
                    "message_id": None,
                    "parent_message_id": parent_message_id,
                    "bot_id": bot_id,
                    "reason": "requires_cwd",
                }
            )
            continue

        hop(
            "py.server",
            "→adapter dispatch bot_id={} parent={} cwd={} context_len={}",
            bot_id,
            parent_message_id,
            cwd or "-",
            len(context),
        )

        # Fire-and-forget so one slow adapter call doesn't block the socket.
        asyncio.create_task(
            adapters.dispatch(
                bot_id=bot_id,
                parent_message_id=parent_message_id,
                context=context,
                send=send,
                cwd=cwd,
            )
        )


async def serve():
    configure_logging()
    async with websockets.serve(handle_connection, protocol.HOST, protocol.PORT):
        logger.info(
            "stitch python server listening on ws://{}:{}",
            protocol.HOST,
            protocol.PORT,
        )
        await asyncio.Future()  # run forever


if __name__ == "__main__":
    asyncio.run(serve())
