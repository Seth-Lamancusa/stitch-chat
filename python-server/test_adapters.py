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
    assert by_id["cursor"]["requires_auth"] is True
    assert protocol.bot_requires_cwd("cursor") is False
    assert protocol.bot_requires_auth("cursor") is True
    assert protocol.BOTS_REQUIRING_CWD == frozenset()


def test_cursor_shim_fallback_reply_when_no_progress():
    sent: list[dict] = []

    async def send(envelope: dict) -> None:
        sent.append(envelope)

    fake_result = {
        "ok": True,
        "status": "finished",
        "event": "done",
        "text": "hello from cursor",
        "mode": "miss",
        "agent_id": "agent-test",
        "assistant_message_id": "srv-fallback",
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

    async def fake_invoke_stream(payload, on_progress):
        return fake_result

    with patch(
        "cursor_adapter._invoke_runner_once",
        new=AsyncMock(side_effect=fake_invoke_stream),
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
    cues = [e for e in sent if e["type"] == protocol.CUE]
    assert cues[0] == protocol.cue_envelope(
        author_id="cursor", target_message_id="trig-1", typing=True
    )
    assert cues[-1] == protocol.cue_envelope(
        author_id="cursor", target_message_id="trig-1", typing=False
    )
    assert all(c["typing"] is True for c in cues[:-1])
    messages = [e for e in sent if e["type"] != protocol.CUE]
    assert len(messages) == 2
    assert messages[0]["type"] == protocol.MESSAGE_START
    assert messages[0]["role"] == "localBot"
    assert messages[0]["parent_message_id"] == "trig-1"
    assert messages[0]["invoke_root_id"] == "trig-1"
    assert messages[1]["type"] == protocol.MESSAGE_END
    assert messages[1]["content"] == "hello from cursor"
    assert messages[1]["is_final"] is True
    assert messages[1]["usage"]["input_tokens"] == 10


def test_cursor_shim_dual_chain_buffers_last_reply():
    sent: list[dict] = []

    async def send(envelope: dict) -> None:
        sent.append(envelope)

    async def fake_invoke_stream(payload, on_progress):
        await on_progress(
            {
                "kind": "thinking",
                "branch": "side",
                "message_id": "srv-think",
                "content": "hmm",
            }
        )
        await on_progress(
            {
                "kind": "functionCall",
                "branch": "side",
                "message_id": "srv-call",
                "content": "**read**\n\n```json\n{}\n```",
                "tool_name": "read",
                "tool_call_id": "c1",
            }
        )
        await on_progress(
            {
                "kind": "functionResult",
                "branch": "side",
                "message_id": "srv-result",
                "content": "```\nfile contents\n```",
                "tool_name": "read",
                "tool_call_id": "c1",
            }
        )
        await on_progress(
            {
                "kind": "localBot",
                "branch": "reply",
                "message_id": "srv-a1",
                "content": "first",
            }
        )
        await on_progress(
            {
                "kind": "localBot",
                "branch": "reply",
                "message_id": "srv-a2",
                "content": "second",
            }
        )
        return {
            "ok": True,
            "status": "finished",
            "event": "done",
            "text": "second",
            "mode": "miss",
            "usage": {"input_tokens": 1, "output_tokens": 2, "total_tokens": 3},
            "reply_message_ids": ["srv-a1", "srv-a2"],
        }

    with patch(
        "cursor_adapter._invoke_runner_once",
        new=AsyncMock(side_effect=fake_invoke_stream),
    ):
        asyncio.run(
            cursor_handle(
                parent_message_id="trig-1",
                bot_id="cursor",
                context=[{"id": "trig-1", "role": "user", "content": "@cursor x"}],
                send=send,
                cwd="/tmp/proj",
            )
        )

    # Side: think, call, result — each start+end immediately (6).
    # Reply: a1 start, a1 end (flushed when a2 starts), a2 start, a2 end final (4).
    messages = [e for e in sent if e["type"] != protocol.CUE]
    types = [e["type"] for e in messages]
    assert types.count(protocol.MESSAGE_START) == 5
    assert types.count(protocol.MESSAGE_END) == 5

    by_id = {
        e["message_id"]: e
        for e in messages
        if e["type"] == protocol.MESSAGE_END
    }
    assert by_id["srv-think"]["parent_message_id"] == "trig-1"
    assert by_id["srv-think"]["role"] == "thinking"
    assert by_id["srv-think"].get("is_final") is False
    assert by_id["srv-think"].get("hidden") is True
    assert by_id["srv-call"]["parent_message_id"] == "srv-think"
    assert by_id["srv-call"].get("hidden") is not True
    assert by_id["srv-result"]["parent_message_id"] == "srv-call"
    assert by_id["srv-result"].get("hidden") is not True
    assert by_id["srv-a1"]["parent_message_id"] == "trig-1"
    assert by_id["srv-a1"]["role"] == "localBot"
    assert by_id["srv-a1"].get("is_final") is False
    assert by_id["srv-a1"].get("hidden") is not True
    assert by_id["srv-a2"]["parent_message_id"] == "srv-a1"
    assert by_id["srv-a2"]["is_final"] is True
    assert by_id["srv-a2"]["usage"]["total_tokens"] == 3
    assert all(e.get("invoke_root_id") == "trig-1" for e in messages)

    # Typing stays on the trigger for the whole invoke; progress refreshes
    # the cue (Dart TTL); clears only after the final assistant message_end.
    cues = [e for e in sent if e["type"] == protocol.CUE]
    assert all(c["target_message_id"] == "trig-1" for c in cues)
    assert cues[0]["typing"] is True
    assert cues[-1]["typing"] is False
    assert all(c["typing"] is True for c in cues[:-1])
    # Initial + refresh per progress part + refresh after runner before final flush.
    assert len(cues) == 8


def test_cursor_shim_maps_runner_failure_to_error():
    sent: list[dict] = []

    async def send(envelope: dict) -> None:
        sent.append(envelope)

    async def fake_invoke_stream(payload, on_progress):
        return {
            "ok": False,
            "error": "run status=error",
            "error_kind": "run",
        }

    with patch(
        "cursor_adapter._invoke_runner_once",
        new=AsyncMock(side_effect=fake_invoke_stream),
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

    assert [e["type"] for e in sent] == [
        protocol.CUE,
        protocol.ERROR,
        protocol.CUE,
    ]
    assert sent[0]["typing"] is True
    assert "run status=error" in sent[1]["error"]
    assert sent[1]["invoke_root_id"] == "trig-2"
    assert sent[2]["typing"] is False
    assert sent[2]["target_message_id"] == "trig-2"


def test_cursor_shim_expands_tilde_cwd():
    sent: list[dict] = []

    async def send(envelope: dict) -> None:
        sent.append(envelope)

    async def fake_invoke_stream(payload, on_progress):
        return {
            "ok": True,
            "status": "finished",
            "text": "tilde-ok",
            "mode": "miss",
            "assistant_message_id": "srv-tilde",
        }

    with patch(
        "cursor_adapter._invoke_runner_once",
        new=AsyncMock(side_effect=fake_invoke_stream),
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


def test_cursor_shim_parallel_invokes_do_not_block_each_other():
    """Each invoke uses its own subprocess; mocks may overlap."""
    order: list[str] = []

    async def send_a(envelope: dict) -> None:
        order.append(f"a:{envelope['type']}")

    async def send_b(envelope: dict) -> None:
        order.append(f"b:{envelope['type']}")

    async def slow_invoke(payload, on_progress):
        await asyncio.sleep(0.05)
        return {
            "ok": True,
            "status": "finished",
            "text": "a-ok",
            "mode": "miss",
            "assistant_message_id": "srv-a",
        }

    async def fast_invoke(payload, on_progress):
        return {
            "ok": True,
            "status": "finished",
            "text": "b-ok",
            "mode": "miss",
            "assistant_message_id": "srv-b",
        }

    calls = 0

    async def invoke_router(payload, on_progress):
        nonlocal calls
        calls += 1
        if calls == 1:
            return await slow_invoke(payload, on_progress)
        return await fast_invoke(payload, on_progress)

    with patch(
        "cursor_adapter._invoke_runner_once",
        new=AsyncMock(side_effect=invoke_router),
    ):
        async def run_both() -> None:
            await asyncio.gather(
                cursor_handle(
                    parent_message_id="trig-a",
                    bot_id="cursor",
                    context=[{"id": "trig-a", "role": "user", "content": "@cursor a"}],
                    send=send_a,
                    cwd="/tmp/proj",
                ),
                cursor_handle(
                    parent_message_id="trig-b",
                    bot_id="cursor",
                    context=[{"id": "trig-b", "role": "user", "content": "@cursor b"}],
                    send=send_b,
                    cwd="/tmp/proj",
                ),
            )

        asyncio.run(run_both())

    assert calls == 2
    # Fast invoke (b) should finish before slow (a) despite starting second.
    b_final_idx = next(
        i for i, e in enumerate(order) if e == "b:message_end"
    )
    a_final_idx = next(
        i for i, e in enumerate(order) if e == "a:message_end"
    )
    assert b_final_idx < a_final_idx


def test_cursor_shim_typing_clears_after_final_message_end():
    sent: list[dict] = []

    async def send(envelope: dict) -> None:
        sent.append(envelope)

    async def fake_invoke(payload, on_progress):
        await on_progress(
            {
                "kind": "localBot",
                "branch": "reply",
                "message_id": "srv-a1",
                "content": "done",
            }
        )
        return {
            "ok": True,
            "status": "finished",
            "text": "done",
            "mode": "miss",
            "usage": {"total_tokens": 1},
        }

    with patch(
        "cursor_adapter._invoke_runner_once",
        new=AsyncMock(side_effect=fake_invoke),
    ):
        asyncio.run(
            cursor_handle(
                parent_message_id="trig-5",
                bot_id="cursor",
                context=[{"id": "trig-5", "role": "user", "content": "@cursor x"}],
                send=send,
                cwd="/tmp/proj",
            )
        )

    final_end_idx = next(
        i
        for i, e in enumerate(sent)
        if e.get("type") == protocol.MESSAGE_END and e.get("is_final") is True
    )
    clear_idx = next(
        i
        for i, e in enumerate(sent)
        if e.get("type") == protocol.CUE and e.get("typing") is False
    )
    assert final_end_idx < clear_idx


def test_cursor_shim_typing_heartbeat_during_silence():
    """A quiet SDK step still refreshes typing before Dart's 8s TTL."""
    sent: list[dict] = []

    async def send(envelope: dict) -> None:
        sent.append(envelope)

    async def fake_invoke(payload, on_progress):
        await asyncio.sleep(0.08)
        return {
            "ok": True,
            "status": "finished",
            "text": "after silence",
            "mode": "miss",
            "assistant_message_id": "srv-hb",
        }

    with (
        patch("cursor_adapter._invoke_runner_once", new=AsyncMock(side_effect=fake_invoke)),
        patch("typing_cue.TYPING_HEARTBEAT_S", 0.02),
    ):
        asyncio.run(
            cursor_handle(
                parent_message_id="trig-hb",
                bot_id="cursor",
                context=[{"id": "trig-hb", "role": "user", "content": "@cursor x"}],
                send=send,
                cwd="/tmp/proj",
            )
        )

    cues = [e for e in sent if e["type"] == protocol.CUE]
    assert all(c["target_message_id"] == "trig-hb" for c in cues)
    assert cues[0]["typing"] is True
    assert cues[-1]["typing"] is False
    # Initial cue plus at least one clock refresh while the runner was silent.
    assert sum(1 for c in cues if c["typing"] is True) >= 2
    clear_idx = next(
        i for i, e in enumerate(sent) if e.get("type") == protocol.CUE and e.get("typing") is False
    )
    final_end_idx = next(
        i
        for i, e in enumerate(sent)
        if e.get("type") == protocol.MESSAGE_END and e.get("is_final") is True
    )
    assert final_end_idx < clear_idx
    assert not any(
        e.get("type") == protocol.CUE and e.get("typing") is True
        for e in sent[clear_idx + 1 :]
    )


def test_cursor_shim_defaults_cwd_to_home():
    sent: list[dict] = []

    async def send(envelope: dict) -> None:
        sent.append(envelope)

    async def fake_invoke_stream(payload, on_progress):
        return {
            "ok": True,
            "status": "finished",
            "text": "home-ok",
            "mode": "miss",
            "usage": None,
            "assistant_message_id": "srv-home",
        }

    with patch(
        "cursor_adapter._invoke_runner_once",
        new=AsyncMock(side_effect=fake_invoke_stream),
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
    types = [e["type"] for e in sent]
    assert types[0] == protocol.CUE
    assert types[-1] == protocol.CUE
    assert protocol.MESSAGE_START in types
    final_end = next(e for e in sent if e.get("type") == protocol.MESSAGE_END)
    assert final_end["is_final"] is True
    assert sent[0]["typing"] is True
    assert sent[-1]["typing"] is False
    final_end_idx = sent.index(final_end)
    clear_idx = len(sent) - 1
    assert final_end_idx < clear_idx
