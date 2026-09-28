"""TypingCue keeps one invoke's indicator alive until end()."""

from __future__ import annotations

import asyncio
from unittest.mock import patch

import protocol
from typing_cue import TypingCue


def _cues(sent: list[dict]) -> list[dict]:
    return [e for e in sent if e.get("type") == protocol.CUE]


def test_typing_cue_noop_without_target():
    sent: list[dict] = []

    async def send(envelope: dict) -> None:
        sent.append(envelope)

    async def run() -> None:
        async with TypingCue(send, author_id="chatgpt", target_message_id=None) as cue:
            await cue.refresh()

    asyncio.run(run())
    assert sent == []


def test_typing_cue_heartbeat_then_clear():
    sent: list[dict] = []

    async def send(envelope: dict) -> None:
        sent.append(envelope)

    async def run() -> None:
        async with TypingCue(send, author_id="chatgpt", target_message_id="trig") as cue:
            await asyncio.sleep(0.08)
            await cue.refresh()

    with patch("typing_cue.TYPING_HEARTBEAT_S", 0.02):
        asyncio.run(run())

    cues = _cues(sent)
    assert all(c["author_id"] == "chatgpt" for c in cues)
    assert all(c["target_message_id"] == "trig" for c in cues)
    assert cues[0]["typing"] is True
    assert cues[-1]["typing"] is False
    assert sum(1 for c in cues if c["typing"] is True) >= 2
    assert sum(1 for c in cues if c["typing"] is False) == 1


def test_typing_cue_end_is_idempotent():
    sent: list[dict] = []

    async def send(envelope: dict) -> None:
        sent.append(envelope)

    async def run() -> None:
        cue = TypingCue(send, author_id="cursor", target_message_id="trig")
        await cue.begin()
        await cue.end()
        await cue.end()

    asyncio.run(run())
    cues = _cues(sent)
    assert [c["typing"] for c in cues] == [True, False]
