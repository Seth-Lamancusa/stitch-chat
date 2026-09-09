"""Adapter registry / Cursor shim tests (no live Cursor API)."""

from __future__ import annotations

import asyncio
from pathlib import Path
from unittest.mock import AsyncMock, patch

import adapters
import protocol
from cursor_adapter import handle as cursor_handle


def test_registry_covers_every_known_bot():
    assert set(adapters.ADAPTERS) == protocol.KNOWN_BOT_IDS


def test_cursor_does_not_require_cwd():
    by_id = {entry["id"]: entry for entry in protocol.bot_registry_payload()}
    assert by_id["chatgpt"]["requires_cwd"] is False
    assert by_id["cursor"]["requires_cwd"] is False
    assert protocol.bot_requires_cwd("cursor") is False
    assert protocol.BOTS_REQUIRING_CWD == frozenset()


def test_cursor_shim_emits_start_end_with_usage():
    sent: list[dict] = []

    async def send(envelope: dict) -> None:
        sent.append(envelope)

    fake_result = {
        "ok": True,
        "status": "finished",
        "text": "hello from cursor",
        "mode": "miss",
        "agent_id": "agent-test",
        "usage": {
            "prompt_tokens": 10,
            "completion_tokens": 4,
            "total_tokens": 14,
            "input_tokens": 10,
            "output_tokens": 4,
            "cache_read_tokens": 0,
            "cache_write_tokens": 0,
        },
    }

    with patch(
        "cursor_adapter._SESSION.invoke",
        new=AsyncMock(return_value=fake_result),
    ) as invoke:
        asyncio.run(
            cursor_handle(
                parent_message_id="trig-1",
                bot_id="cursor",
                context=[
                    {
                        "id": "trig-1",
                        "role": "user",
                        "author_id": "",
                        "content": "@cursor hi",
                    }
                ],
                send=send,
                cwd="/tmp/proj",
            )
        )

    assert invoke.await_count == 1
    req = invoke.await_args.args[0]
    assert req["cwd"] == "/tmp/proj"
    assert req["assistant_message_id"].startswith("srv-")
    assert len(sent) == 2
    assert sent[0]["type"] == protocol.MESSAGE_START
    assert sent[0]["role"] == "localBot"
    assert sent[0]["parent_message_id"] == "trig-1"
    assert sent[1]["type"] == protocol.MESSAGE_END
    assert sent[1]["content"] == "hello from cursor"
    assert sent[1]["usage"]["input_tokens"] == 10
    assert sent[0]["message_id"] == sent[1]["message_id"] == req["assistant_message_id"]


def test_cursor_shim_maps_runner_failure_to_error():
    sent: list[dict] = []

    async def send(envelope: dict) -> None:
        sent.append(envelope)

    with patch(
        "cursor_adapter._SESSION.invoke",
        new=AsyncMock(
            return_value={
                "ok": False,
                "error": "run status=error",
                "error_kind": "run",
            }
        ),
    ):
        asyncio.run(
            cursor_handle(
                parent_message_id="trig-2",
                bot_id="cursor",
                context=[{"id": "trig-2", "role": "user", "content": "@cursor x"}],
                send=send,
                cwd="/tmp/proj",
            )
        )

    assert len(sent) == 1
    assert sent[0]["type"] == protocol.ERROR
    assert "run status=error" in sent[0]["error"]


def test_cursor_shim_expands_tilde_cwd():
    sent: list[dict] = []

    async def send(envelope: dict) -> None:
        sent.append(envelope)

    with patch(
        "cursor_adapter._SESSION.invoke",
        new=AsyncMock(
            return_value={
                "ok": True,
                "status": "finished",
                "text": "tilde-ok",
                "mode": "miss",
            }
        ),
    ) as invoke:
        asyncio.run(
            cursor_handle(
                parent_message_id="trig-4",
                bot_id="cursor",
                context=[{"id": "trig-4", "role": "user", "content": "@cursor x"}],
                send=send,
                cwd="~/stitch/stitch-chat",
            )
        )

    expected = str((Path.home() / "stitch" / "stitch-chat").resolve())
    assert invoke.await_args.args[0]["cwd"] == expected
    sent: list[dict] = []

    async def send(envelope: dict) -> None:
        sent.append(envelope)

    fake_result = {
        "ok": True,
        "status": "finished",
        "text": "home-ok",
        "mode": "miss",
        "usage": None,
    }

    with patch(
        "cursor_adapter._SESSION.invoke",
        new=AsyncMock(return_value=fake_result),
    ) as invoke:
        asyncio.run(
            cursor_handle(
                parent_message_id="trig-3",
                bot_id="cursor",
                context=[{"id": "trig-3", "role": "user", "content": "@cursor x"}],
                send=send,
                cwd=None,
            )
        )

    invoke.assert_awaited_once()
    assert invoke.await_args.args[0]["cwd"] == str(Path.home().resolve())
    assert [e["type"] for e in sent] == [
        protocol.MESSAGE_START,
        protocol.MESSAGE_END,
    ]
