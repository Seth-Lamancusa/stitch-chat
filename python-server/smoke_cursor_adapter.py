"""End-to-end smoke: cursor_adapter.handle → real runner/API.

Run from python-server with the *bridge* venv (stdlib + project modules):
    ./venv/bin/python smoke_cursor_adapter.py
"""

from __future__ import annotations

import asyncio
from pathlib import Path

from cursor_adapter import handle


async def main() -> None:
    cwd = str(Path(__file__).resolve().parents[1])
    sent: list[dict] = []

    async def send(envelope: dict) -> None:
        sent.append(envelope)
        print("ENVELOPE", envelope.get("type"), flush=True)

    await handle(
        parent_message_id="trig-smoke",
        bot_id="cursor",
        context=[
            {
                "id": "trig-smoke",
                "role": "user",
                "author_id": "",
                "content": "Reply with exactly: shim-ok",
            }
        ],
        send=send,
        cwd=cwd,
    )

    types = [e.get("type") for e in sent]
    print("TYPES", types)
    assert types == ["message_start", "message_end"], sent
    assert sent[1]["content"], sent[1]
    print("CONTENT", repr(sent[1]["content"]))
    print("USAGE", sent[1].get("usage"))
    print("SHIM_OK")


if __name__ == "__main__":
    asyncio.run(main())
