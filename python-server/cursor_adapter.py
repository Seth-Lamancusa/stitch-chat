"""Cursor adapter shim: Stitch bridge → runtimes/cursor/agent_runner.py.

Same `handle(...)` shape as Completions. Spawns a long-lived NDJSON runner
in the Cursor runtime venv (bridge process never imports `cursor-sdk`).
Maps runner results to `message_start` / `message_end` / `error`.

Affinity and SDK handles live entirely inside the runner.
"""

from __future__ import annotations

import asyncio
import json
import os
import uuid
from collections.abc import Awaitable, Callable, Mapping, Sequence
from pathlib import Path
from typing import Any

import protocol
from logging_setup import hop

SendFn = Callable[[dict[str, Any]], Awaitable[None]]

_RUNTIME_DIR = Path(__file__).resolve().parent / "runtimes" / "cursor"
_RUNNER = _RUNTIME_DIR / "agent_runner.py"
# absolute() — do not resolve() the venv python symlink (breaks site-packages).
_PYTHON = _RUNTIME_DIR / "venv" / "bin" / "python"


class _RunnerSession:
    """One long-lived agent_runner subprocess shared across Cursor invokes."""

    def __init__(self) -> None:
        self._proc: asyncio.subprocess.Process | None = None
        self._lock = asyncio.Lock()
        self._next_id = 1

    async def ensure_started(self) -> None:
        if self._proc is not None and self._proc.returncode is None:
            return
        if not _PYTHON.is_file():
            raise FileNotFoundError(
                f"Cursor runtime python missing: {_PYTHON} "
                "(create runtimes/cursor/venv and install requirements)"
            )
        if not _RUNNER.is_file():
            raise FileNotFoundError(f"Cursor agent_runner missing: {_RUNNER}")

        hop("py.cursor", "start runner bin={} script={}", _PYTHON, _RUNNER)
        # Do not pin the runner to runtimes/cursor: the SDK bridge inherits
        # process cwd as the agent executor root. agent_runner chdirs per
        # invoke cwd before launch_bridge; starting in $HOME is a safe default.
        self._proc = await asyncio.create_subprocess_exec(
            str(_PYTHON.absolute()),
            str(_RUNNER.absolute()),
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            env=os.environ.copy(),
            cwd=str(Path.home()),
            limit=8 * 1024 * 1024,
        )

    async def invoke(self, payload: dict[str, Any]) -> dict[str, Any]:
        async with self._lock:
            await self.ensure_started()
            assert self._proc is not None
            assert self._proc.stdin is not None
            assert self._proc.stdout is not None

            req_id = self._next_id
            self._next_id += 1
            body = {**payload, "id": req_id}
            line = json.dumps(body, ensure_ascii=False) + "\n"
            self._proc.stdin.write(line.encode("utf-8"))
            await self._proc.stdin.drain()

            raw = await self._proc.stdout.readline()
            if not raw:
                stderr = b""
                if self._proc.stderr is not None:
                    try:
                        stderr = await asyncio.wait_for(
                            self._proc.stderr.read(8000), timeout=0.5
                        )
                    except asyncio.TimeoutError:
                        pass
                raise RuntimeError(
                    "cursor runner exited without response "
                    f"rc={self._proc.returncode} stderr={stderr.decode('utf-8', 'replace')}"
                )
            return json.loads(raw.decode("utf-8"))


_SESSION = _RunnerSession()


async def handle(
    *,
    parent_message_id: str | None,
    bot_id: str,
    context: Sequence[Mapping[str, Any]],
    send: SendFn,
    cwd: str | None = None,
    model: str | None = None,
) -> None:
    """Forward a Cursor invoke to the runtime runner and emit wire envelopes."""
    message_id = f"srv-{uuid.uuid4()}"
    # Column cwd is optional; fall back to home. Expand ~ so Dart tags like
    # `~/stitch/stitch-chat` become real paths before the runner/SDK see them.
    raw = (cwd or "").strip() or str(Path.home())
    resolved_cwd = str(Path(raw).expanduser().resolve())

    hop(
        "py.adapter",
        "cursor start bot_id={} parent={} cwd={} context_len={} model={}",
        bot_id,
        parent_message_id,
        resolved_cwd,
        len(context),
        model or "-",
    )

    try:
        result = await _SESSION.invoke(
            {
                "cwd": resolved_cwd,
                "context": list(context),
                "model": model,
                "assistant_message_id": message_id,
            }
        )
    except Exception as exc:  # noqa: BLE001
        hop(
            "py.adapter",
            "cursor runner error parent={} err={}",
            parent_message_id,
            exc,
        )
        await send(
            {
                "type": protocol.ERROR,
                "message_id": message_id,
                "parent_message_id": parent_message_id,
                "error": f"cursor runner failed: {exc}",
            }
        )
        return

    if not result.get("ok"):
        hop(
            "py.adapter",
            "cursor fail parent={} kind={} mode={} agent={} err={}",
            parent_message_id,
            result.get("error_kind"),
            result.get("mode"),
            result.get("agent_id") or "-",
            result.get("error"),
        )
        await send(
            {
                "type": protocol.ERROR,
                "message_id": message_id,
                "parent_message_id": parent_message_id,
                "error": str(result.get("error") or "cursor run failed"),
            }
        )
        return

    hop(
        "py.adapter",
        "cursor ok parent={} mode={} agent={} run={} chars={} usage={}",
        parent_message_id,
        result.get("mode"),
        result.get("agent_id") or "-",
        result.get("run_id") or "-",
        len(str(result.get("text") or "")),
        result.get("usage"),
    )

    await send(
        {
            "type": protocol.MESSAGE_START,
            "message_id": message_id,
            "parent_message_id": parent_message_id,
            "bot_id": bot_id,
            "role": "localBot",
        }
    )
    end: dict[str, Any] = {
        "type": protocol.MESSAGE_END,
        "message_id": message_id,
        "parent_message_id": parent_message_id,
        "bot_id": bot_id,
        "role": "localBot",
        "content": str(result.get("text") or ""),
    }
    usage = result.get("usage")
    if isinstance(usage, dict):
        end["usage"] = usage
    await send(end)
