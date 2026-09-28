"""Cursor CLI parser, session affinity, and auth-gate tests (no live CLI)."""

from __future__ import annotations

import asyncio
import json
from pathlib import Path

import adapters
import cursor_cli
import protocol


def test_fingerprint_stable(tmp_path: Path):
    nodes = [
        {"id": "a", "role": "user", "author_id": "", "content": "hi"},
        {"id": "b", "role": "localBot", "author_id": "cursor", "content": "yo"},
    ]
    fp1 = cursor_cli.fingerprint_for(nodes, "/tmp/proj")
    fp2 = cursor_cli.fingerprint_for(nodes, "/tmp/proj")
    assert fp1 == fp2
    assert fp1 != cursor_cli.fingerprint_for(nodes, "/tmp/other")


def test_fingerprint_changes_when_prefix_mutates():
    a = [{"id": "a", "role": "user", "author_id": "", "content": "hi"}]
    b = [{"id": "a", "role": "user", "author_id": "", "content": "hi!"}]
    assert cursor_cli.fingerprint_for(a, "/tmp/p") != cursor_cli.fingerprint_for(b, "/tmp/p")


def test_hit_delta_is_last_node_only():
    ctx = [
        {"id": "a", "role": "user", "content": "one"},
        {"id": "b", "role": "localBot", "author_id": "cursor", "content": "two"},
        {"id": "c", "role": "user", "content": "three"},
    ]
    assert cursor_cli.project_hit_delta(ctx) == "three"


def test_miss_seed_concatenates():
    ctx = [
        {"id": "a", "role": "user", "author_id": "", "content": "one"},
        {"id": "b", "role": "localBot", "author_id": "cursor", "content": "two"},
    ]
    seed = cursor_cli.project_miss_seed(ctx)
    assert "[user]" in seed and "one" in seed
    assert "[localBot/cursor]" in seed and "two" in seed


def test_advance_only_current_prefix_hits(tmp_path: Path):
    store = cursor_cli.SessionStore(tmp_path / "sessions.json")
    cwd = "/tmp/proj"
    nodes = [{"id": "u1", "role": "user", "author_id": "", "content": "hi"}]
    fp = store.advance(
        session_id="chat-1",
        cwd=cwd,
        request_nodes=nodes,
        assistant_message_id="bot-1",
        assistant_text="hello",
    )
    last = store.by_fingerprint[fp].last_known_prefix
    assert cursor_cli.fingerprint_for(last, cwd) == fp
    assert cursor_cli.fingerprint_for(nodes, cwd) not in store.by_fingerprint

    nodes2 = [
        *last,
        {"id": "u2", "role": "user", "author_id": "", "content": "again"},
    ]
    fp2 = store.advance(
        session_id="chat-1",
        cwd=cwd,
        request_nodes=nodes2,
        assistant_message_id="bot-2",
        assistant_text="ok",
    )
    assert fp not in store.by_fingerprint
    assert fp2 in store.by_fingerprint

    reloaded = cursor_cli.SessionStore(tmp_path / "sessions.json")
    assert fp2 in reloaded.by_fingerprint
    assert reloaded.by_fingerprint[fp2].session_id == "chat-1"


def test_advance_with_reply_nodes(tmp_path: Path):
    store = cursor_cli.SessionStore(tmp_path / "sessions.json")
    nodes = [{"id": "u1", "role": "user", "author_id": "", "content": "hi"}]
    reply = [
        {"id": "a1", "role": "localBot", "author_id": "cursor", "content": "first"},
        {"id": "a2", "role": "localBot", "author_id": "cursor", "content": "second"},
    ]
    fp = store.advance(
        session_id="chat-1",
        cwd="/tmp/proj",
        request_nodes=nodes,
        reply_nodes=reply,
    )
    last = store.by_fingerprint[fp].last_known_prefix
    assert [n["id"] for n in last] == ["u1", "a1", "a2"]


def test_stream_json_skips_buffered_flush_and_emits_tools():
    raw = """
{"type":"system","subtype":"init","model":"composer-2.5","session_id":"chat-1"}
{"type":"assistant","timestamp_ms":1,"message":{"content":[{"text":"Hel"}]}}
{"type":"assistant","timestamp_ms":2,"message":{"content":[{"text":"lo"}]}}
{"type":"assistant","model_call_id":"mc1","message":{"content":[{"text":"Hello"}]}}
{"type":"tool_call","subtype":"started","tool_call":{"readToolCall":{"args":{"path":"a.txt"}}}}
{"type":"tool_call","subtype":"completed","tool_call":{"readToolCall":{"args":{"path":"a.txt"},"result":{"content":"x"}}}}
{"type":"assistant","timestamp_ms":3,"message":{"content":[{"text":"Done"}]}}
{"type":"assistant","message":{"content":[{"text":"Done"}]}}
{"type":"result","duration_ms":10,"session_id":"chat-1","usage":{"input_tokens":3,"output_tokens":1},"result":"HelloDone"}
""".strip()
    assembler = cursor_cli.StreamAssembler()
    parts: list[dict] = []
    for line in raw.splitlines():
        parts.extend(assembler.feed(json.loads(line)))
    parts.extend(assembler.flush_text())

    kinds = [part["kind"] for part in parts]
    assert kinds == ["localBot", "functionCall", "functionResult", "localBot"]
    assert parts[0]["content"] == "Hello"
    assert parts[1]["tool_name"] == "read"
    assert parts[1]["tool_call_id"] == parts[2]["tool_call_id"]
    assert "a.txt" in parts[1]["content"]
    assert parts[3]["content"] == "Done"
    assert parts[3]["content"].count("Done") == 1
    assert assembler.session_id == "chat-1"
    assert assembler.usage is not None
    assert assembler.usage["input_tokens"] == 3
    assert assembler.usage["total_tokens"] == 4
    # Buffered flush with model_call_id must not duplicate the deltas.
    assert parts[0]["content"].count("Hello") == 1


def test_end_flush_without_deltas_is_kept():
    assembler = cursor_cli.StreamAssembler()
    assembler.feed(
        {"type": "assistant", "message": {"content": [{"text": "Only once"}]}}
    )
    parts = assembler.flush_text()
    assert parts[0]["content"] == "Only once"


def test_unknown_tool_is_opaque():
    assembler = cursor_cli.StreamAssembler()
    parts = assembler.feed(
        {
            "type": "tool_call",
            "subtype": "started",
            "tool_call": {"weird": {"args": {"x": 1}}},
        }
    )
    assert parts[0]["kind"] == "functionCall"
    assert parts[0]["tool_name"] == "weird"
    assert "x" in parts[0]["content"]


def test_interpret_status():
    assert cursor_cli.interpret_status(0, "Logged in as ada@example.com") == "authenticated"
    assert cursor_cli.interpret_status(1, "Not authenticated") == "unauthenticated"
    assert cursor_cli.looks_like_auth_failure("Error: Not logged in")


def test_resolve_override_missing_does_not_fall_through(monkeypatch, tmp_path: Path):
    monkeypatch.setenv("STITCH_CURSOR_AGENT", str(tmp_path / "missing-agent"))
    assert cursor_cli.resolve_agent_binary() is None


def test_cursor_requires_auth_in_registry():
    by_id = {entry["id"]: entry for entry in protocol.bot_registry_payload()}
    assert by_id["cursor"]["requires_auth"] is True
    assert by_id["chatgpt"]["requires_auth"] is False
    assert protocol.bot_requires_auth("cursor") is True
    assert protocol.bot_requires_auth("chatgpt") is False


def test_auth_skip_reason(monkeypatch):
    async def unauthenticated(bot_id: str, *, refresh: bool = False) -> dict:
        return {"bot_id": bot_id, "state": "unauthenticated"}

    async def authenticated(bot_id: str, *, refresh: bool = False) -> dict:
        return {"bot_id": bot_id, "state": "authenticated"}

    monkeypatch.setattr(adapters, "auth_snapshot", unauthenticated)
    assert asyncio.run(adapters.auth_skip_reason("cursor")) == "requires_auth"
    assert asyncio.run(adapters.auth_skip_reason("chatgpt")) is None

    monkeypatch.setattr(adapters, "auth_snapshot", authenticated)
    assert asyncio.run(adapters.auth_skip_reason("cursor")) is None


def test_begin_auth_runs_the_bot_handler(monkeypatch):
    sent: list[dict] = []
    called = {"n": 0}

    async def send(envelope: dict) -> None:
        sent.append(envelope)

    async def fake_login():
        called["n"] += 1
        return {"state": "authenticated"}

    monkeypatch.setitem(adapters.AUTH_BEGIN, "cursor", fake_login)
    asyncio.run(adapters.begin_auth("cursor", send))

    states = [envelope for envelope in sent if envelope["type"] == protocol.AUTH_STATE]
    assert called["n"] == 1
    assert [envelope["state"] for envelope in states] == ["pending", "authenticated"]
    assert "url" not in states[0] and "url" not in states[1]
