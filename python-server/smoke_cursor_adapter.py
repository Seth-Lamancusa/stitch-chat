"""End-to-end smoke: cursor_adapter.handle → real runner/API.

Run from python-server with the *bridge* venv (stdlib + project modules):
    ./venv/bin/python smoke_cursor_adapter.py
"""

from __future__ import annotations

import asyncio
from pathlib import Path

from cursor_adapter import handle
import protocol


async def main() -> None:
    cwd = str(Path(__file__).resolve().parents[1])
    sent: list[dict] = []

    async def send(envelope: dict) -> None:
        sent.append(envelope)
        print(
            "ENVELOPE",
            envelope.get("type"),
            envelope.get("role"),
            envelope.get("is_final"),
            flush=True,
        )

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
    assert protocol.ERROR not in types, sent
    assert protocol.MESSAGE_START in types
    assert protocol.MESSAGE_END in types
    finals = [e for e in sent if e.get("type") == protocol.MESSAGE_END and e.get("is_final")]
    assert len(finals) == 1, sent
    assert finals[0].get("content"), finals[0]
    assert all(e.get("invoke_root_id") == "trig-smoke" for e in sent if e.get("type") != protocol.ERROR)
    print("CONTENT", repr(finals[0]["content"]))
    print("USAGE", finals[0].get("usage"))
    print("SHIM_OK")


if __name__ == "__main__":
    asyncio.run(main())
