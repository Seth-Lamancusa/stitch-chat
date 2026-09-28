"""Per-invoke typing cue.

Dart's TypingCueStore drops a cue 8s after the last ``typing=true``. A run
can sit quiet longer than that — tool execution, reasoning, a buffered
stream — so each invoke keeps its own clock that re-sends ``typing=true``
until the adapter ends the cue.

The wire envelope lives in [protocol.cue_envelope]. Adapters choose the
target message and may call [TypingCue.refresh] early (for example when a
progress part arrives). Parallel invokes each hold their own cue; Dart keys
them by author and target.
"""

from __future__ import annotations

import asyncio
from collections.abc import Awaitable, Callable
from typing import Any

import protocol

SendFn = Callable[[dict[str, Any]], Awaitable[None]]

# One second inside the Dart TTL so a tick lands before the cue expires.
TYPING_HEARTBEAT_S = 7.0


class TypingCue:
    """Typing indicator for one bot invoke, held until [end]."""

    def __init__(
        self,
        send: SendFn,
        *,
        author_id: str,
        target_message_id: str | None,
    ) -> None:
        self._send = send
        self._author_id = author_id
        self._target = target_message_id
        self._on = False
        self._task: asyncio.Task[None] | None = None

    async def __aenter__(self) -> TypingCue:
        await self.begin()
        return self

    async def __aexit__(self, exc_type: object, exc: object, tb: object) -> None:
        await self.end()

    async def begin(self) -> None:
        """Send ``typing=true`` and start the refresh clock. No-op without a target."""
        if not self._target or self._on:
            return
        self._on = True
        await self._emit(True)
        self._task = asyncio.create_task(self._heartbeat())

    async def refresh(self) -> None:
        """Re-send ``typing=true`` if this cue is still active."""
        if self._on:
            await self._emit(True)

    async def end(self) -> None:
        """Stop the clock, then send ``typing=false``. Idempotent."""
        await self._stop()
        if not self._on:
            return
        # Drop the flag before the clear so an in-flight refresh cannot
        # turn the cue back on after typing=false.
        self._on = False
        await self._emit(False)

    async def _heartbeat(self) -> None:
        while True:
            await asyncio.sleep(TYPING_HEARTBEAT_S)
            await self.refresh()

    async def _stop(self) -> None:
        task = self._task
        self._task = None
        if task is None:
            return
        if not task.done():
            task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass

    async def _emit(self, typing: bool) -> None:
        if not self._target:
            return
        await self._send(
            protocol.cue_envelope(
                author_id=self._author_id,
                target_message_id=self._target,
                typing=typing,
            )
        )
