"""WS connection handling: parses envelopes, dispatches to the bot handler."""

import asyncio
import json
import logging

import websockets

import protocol
from openai_handler import stream_reply

logger = logging.getLogger("stitch.server")


async def handle_connection(websocket):
    async def send(envelope: dict):
        await websocket.send(json.dumps(envelope))

    await send({"type": protocol.READY})

    async for raw in websocket:
        try:
            envelope = json.loads(raw)
        except json.JSONDecodeError:
            await send({"type": protocol.ERROR, "message_id": None, "error": "invalid JSON"})
            continue

        if envelope.get("type") == protocol.USER_MESSAGE:
            await stream_reply(
                content=envelope.get("content", ""),
                parent_message_id=envelope.get("message_id"),
                send=send,
            )
        else:
            await send({
                "type": protocol.ERROR,
                "message_id": envelope.get("message_id"),
                "error": f"unknown envelope type: {envelope.get('type')}",
            })


async def serve():
    logging.basicConfig(level=logging.INFO)
    async with websockets.serve(handle_connection, protocol.HOST, protocol.PORT):
        logger.info("stitch python server listening on ws://%s:%d", protocol.HOST, protocol.PORT)
        await asyncio.Future()  # run forever


if __name__ == "__main__":
    asyncio.run(serve())
