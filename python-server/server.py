"""WS connection handling: parses envelopes, dispatches to bot handlers."""

from __future__ import annotations

import asyncio
import json
from typing import Any

import websockets
from loguru import logger

import protocol
from logging_setup import configure_logging, hop
from openai_compatible import stream_reply


def _normalize_bot_id(raw: Any) -> str:
    bot_id = str(raw or protocol.DEFAULT_BOT_ID).strip().lstrip("@")
    if bot_id == "openai":
        return protocol.DEFAULT_BOT_ID
    return bot_id


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
    await send({"type": protocol.READY})

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
            "←dart type={} message_id={} bot_id={} context_len={}",
            envelope.get("type"),
            envelope.get("message_id"),
            envelope.get("bot_id"),
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

        hop(
            "py.server",
            "→adapter dispatch bot_id={} parent={} context_len={} content_len={}",
            bot_id,
            parent_message_id,
            len(context),
            len(str(envelope.get("content", ""))),
        )

        # Fire-and-forget so one slow Completions call doesn't block the socket.
        asyncio.create_task(
            stream_reply(
                content=envelope.get("content", ""),
                parent_message_id=parent_message_id,
                bot_id=bot_id,
                context=context,
                send=send,
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
