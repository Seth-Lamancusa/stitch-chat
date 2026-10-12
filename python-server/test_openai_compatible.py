"""Unit tests for Completions context projection (no network)."""

from __future__ import annotations

import asyncio
import os
from types import SimpleNamespace
from unittest.mock import patch

import protocol
from openai_compatible import project_context, stream_reply


def test_project_context_maps_roles_including_trailing_trigger():
    messages = project_context(
        [
            {"id": "1", "role": "user", "author_id": "alice", "content": "hi"},
            {"id": "2", "role": "localBot", "author_id": "chatgpt", "content": "hello"},
            {"id": "3", "role": "user", "author_id": "bob", "content": "follow up"},
            {
                "id": "4",
                "role": "user",
                "author_id": "alice",
                "content": "@chatgpt what next?",
            },
        ],
    )
    assert messages == [
        {"role": "user", "content": "hi"},
        {"role": "assistant", "content": "hello"},
        {"role": "user", "content": "follow up"},
        {"role": "user", "content": "@chatgpt what next?"},
    ]


def test_project_context_skips_empty_and_allows_trigger_only():
    assert project_context(
        [{"id": "t", "role": "user", "content": "just the trigger"}]
    ) == [{"role": "user", "content": "just the trigger"}]
    assert project_context(
        [
            {"role": "user", "content": ""},
            {"role": "user", "content": "x"},
        ]
    ) == [{"role": "user", "content": "x"}]


def test_stream_reply_typing_heartbeat_during_silence():
    """A quiet completion still refreshes typing before Dart's 8s TTL."""
    sent: list[dict] = []

    async def send(envelope: dict) -> None:
        sent.append(envelope)

    class _Stream:
        def __init__(self) -> None:
            self._done = False

        def __aiter__(self) -> _Stream:
            return self

        async def __anext__(self) -> SimpleNamespace:
            if self._done:
                raise StopAsyncIteration
            await asyncio.sleep(0.08)
            self._done = True
            return SimpleNamespace(
                choices=[SimpleNamespace(delta=SimpleNamespace(content="hello"))],
                usage=None,
            )

    class _Completions:
        async def create(self, **kwargs: object) -> _Stream:
            return _Stream()

    class _Client:
        def __init__(self, **kwargs: object) -> None:
            self.chat = SimpleNamespace(completions=_Completions())

    with (
        patch.dict(os.environ, {"OPENAI_API_KEY": "test-key"}, clear=False),
        patch("openai_compatible.AsyncOpenAI", _Client),
        patch("typing_cue.TYPING_HEARTBEAT_S", 0.02),
    ):
        asyncio.run(
            stream_reply(
                parent_message_id="trig-oai",
                bot_id="chatgpt",
                context=[{"id": "trig-oai", "role": "user", "content": "@chatgpt hi"}],
                send=send,
            )
        )

    cues = [e for e in sent if e.get("type") == protocol.CUE]
    assert all(c["target_message_id"] == "trig-oai" for c in cues)
    assert all(c["author_id"] == "chatgpt" for c in cues)
    assert cues[0]["typing"] is True
    assert cues[-1]["typing"] is False
    assert sum(1 for c in cues if c["typing"] is True) >= 2
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
    assert sent[final_end_idx]["content"] == "hello"
