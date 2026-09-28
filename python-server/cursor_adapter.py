"""Cursor adapter shim: Stitch bridge → runtimes/cursor/agent_runner.py.

Same `handle(...)` shape as Completions. Spawns one `agent_runner --once`
subprocess per invoke (parallel-safe; bridge process never imports
`cursor-sdk`).

Maps streamed runner progress into two reply chains under the trigger:
  - side fork: thinking / functionCall / functionResult
  - reply branch: localBot assistant text (last message_end buffered until
    the terminal runner line, then flushed with is_final + usage)

Each subprocess owns its own SDK session; in-process affinity is not shared
across concurrent invokes.
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

_SIDE_KINDS = frozenset({"thinking", "functionCall", "functionResult"})


def _ensure_runner_binaries() -> None:
    if not _PYTHON.is_file():
        raise FileNotFoundError(
            f"Cursor runtime python missing: {_PYTHON} "
            "(create runtimes/cursor/venv and install requirements)"
        )
    if not _RUNNER.is_file():
        raise FileNotFoundError(f"Cursor agent_runner missing: {_RUNNER}")


async def _invoke_runner_once(
    payload: dict[str, Any],
    on_progress: Callable[[Mapping[str, Any]], Awaitable[None]],
) -> dict[str, Any]:
    """Run one invoke in a fresh agent_runner subprocess (`--once`)."""
    _ensure_runner_binaries()
    hop("py.cursor", "spawn runner --once bin={} script={}", _PYTHON, _RUNNER)
    proc = await asyncio.create_subprocess_exec(
        str(_PYTHON.absolute()),
        str(_RUNNER.absolute()),
        "--once",
        stdin=asyncio.subprocess.PIPE,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        env=os.environ.copy(),
        cwd=str(Path.home()),
        limit=8 * 1024 * 1024,
    )
    assert proc.stdin is not None
    assert proc.stdout is not None

    body = json.dumps(payload, ensure_ascii=False)
    proc.stdin.write(body.encode("utf-8"))
    await proc.stdin.drain()
    proc.stdin.close()

    try:
        while True:
            raw = await proc.stdout.readline()
            if not raw:
                stderr = b""
                if proc.stderr is not None:
                    try:
                        stderr = await asyncio.wait_for(
                            proc.stderr.read(8000), timeout=0.5
                        )
                    except asyncio.TimeoutError:
                        pass
                raise RuntimeError(
                    "cursor runner exited without terminal response "
                    f"rc={proc.returncode} "
                    f"stderr={stderr.decode('utf-8', 'replace')}"
                )
            record = json.loads(raw.decode("utf-8"))
            if record.get("event") == "progress":
                part = record.get("part") or {}
                if isinstance(part, dict):
                    await on_progress(part)
                continue
            return record
    finally:
        if proc.returncode is None:
            proc.kill()
            await proc.wait()


def _role_for_kind(kind: str) -> str:
    if kind in ("thinking", "functionCall", "functionResult", "localBot"):
        return kind
    return "localBot"


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
    fallback_message_id = f"srv-{uuid.uuid4()}"
    invoke_root_id = parent_message_id
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

    side_parent = parent_message_id
    reply_parent = parent_message_id
    buffered_reply_end: dict[str, Any] | None = None
    saw_reply_part = False
    typing_target: str | None = None

    async def _set_typing(on: bool) -> None:
        """Turn typing on/off for this invoke's [typing_target] only."""
        if typing_target is None:
            return
        await send(
            protocol.cue_envelope(
                author_id=bot_id,
                target_message_id=typing_target,
                typing=on,
            )
        )

    async def _refresh_typing() -> None:
        """Re-emit typing=True so Dart TTL stays fresh for long gaps."""
        if typing_target is not None:
            await _set_typing(True)

    async def _begin_typing(target: str) -> None:
        nonlocal typing_target
        typing_target = target
        await _set_typing(True)

    async def _end_typing() -> None:
        nonlocal typing_target
        if typing_target is None:
            return
        await _set_typing(False)
        typing_target = None

    async def _send_start(
        *,
        message_id: str,
        parent: str | None,
        role: str,
        tool_name: str | None = None,
        tool_call_id: str | None = None,
    ) -> None:
        env: dict[str, Any] = {
            "type": protocol.MESSAGE_START,
            "message_id": message_id,
            "parent_message_id": parent,
            "invoke_root_id": invoke_root_id,
            "bot_id": bot_id,
            "role": role,
        }
        if tool_name:
            env["tool_name"] = tool_name
        if tool_call_id:
            env["tool_call_id"] = tool_call_id
        await send(env)

    async def _send_end(
        *,
        message_id: str,
        parent: str | None,
        role: str,
        content: str,
        is_final: bool = False,
        hidden: bool = False,
        usage: Mapping[str, Any] | None = None,
        tool_name: str | None = None,
        tool_call_id: str | None = None,
        is_error: bool | None = None,
    ) -> None:
        env: dict[str, Any] = {
            "type": protocol.MESSAGE_END,
            "message_id": message_id,
            "parent_message_id": parent,
            "invoke_root_id": invoke_root_id,
            "bot_id": bot_id,
            "role": role,
            "content": content,
            "is_final": is_final,
        }
        if hidden:
            env["hidden"] = True
        if usage is not None:
            env["usage"] = dict(usage)
        if tool_name:
            env["tool_name"] = tool_name
        if tool_call_id:
            env["tool_call_id"] = tool_call_id
        if is_error is not None:
            env["is_error"] = is_error
        await send(env)

    async def on_progress(part: Mapping[str, Any]) -> None:
        nonlocal side_parent, reply_parent, buffered_reply_end, saw_reply_part
        await _refresh_typing()
        kind = str(part.get("kind") or "")
        message_id = str(part.get("message_id") or f"srv-{uuid.uuid4()}")
        content = str(part.get("content") or "")
        role = _role_for_kind(kind)
        tool_name = part.get("tool_name")
        tool_call_id = part.get("tool_call_id")
        is_error = part.get("is_error")
        branch = str(part.get("branch") or "")
        if not branch:
            branch = "side" if kind in _SIDE_KINDS else "reply"

        if branch == "side" or kind in _SIDE_KINDS:
            parent = side_parent
            edge_hidden = parent is not None and parent == invoke_root_id
            await _send_start(
                message_id=message_id,
                parent=parent,
                role=role,
                tool_name=str(tool_name) if tool_name else None,
                tool_call_id=str(tool_call_id) if tool_call_id else None,
            )
            await _send_end(
                message_id=message_id,
                parent=parent,
                role=role,
                content=content,
                hidden=edge_hidden,
                tool_name=str(tool_name) if tool_name else None,
                tool_call_id=str(tool_call_id) if tool_call_id else None,
                is_error=bool(is_error) if is_error is not None else None,
            )
            side_parent = message_id
            return

        parent = reply_parent
        if buffered_reply_end is not None:
            await _send_end(**buffered_reply_end)
            buffered_reply_end = None

        await _send_start(
            message_id=message_id,
            parent=parent,
            role=role,
        )
        buffered_reply_end = {
            "message_id": message_id,
            "parent": parent,
            "role": role,
            "content": content,
        }
        reply_parent = message_id
        saw_reply_part = True

    if parent_message_id:
        await _begin_typing(parent_message_id)

    try:
        result = await _invoke_runner_once(
            {
                "cwd": resolved_cwd,
                "context": list(context),
                "model": model,
                "assistant_message_id": fallback_message_id,
            },
            on_progress,
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
                "message_id": fallback_message_id,
                "parent_message_id": parent_message_id,
                "invoke_root_id": invoke_root_id,
                "error": f"cursor runner failed: {exc}",
            }
        )
        await _end_typing()
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
                "message_id": fallback_message_id,
                "parent_message_id": parent_message_id,
                "invoke_root_id": invoke_root_id,
                "error": str(result.get("error") or "cursor run failed"),
            }
        )
        await _end_typing()
        return

    usage = result.get("usage") if isinstance(result.get("usage"), dict) else None
    text = str(result.get("text") or "")

    hop(
        "py.adapter",
        "cursor ok parent={} mode={} agent={} run={} chars={} usage={} reply_parts={}",
        parent_message_id,
        result.get("mode"),
        result.get("agent_id") or "-",
        result.get("run_id") or "-",
        len(text),
        usage,
        saw_reply_part,
    )

    # Runner finished but final reply may still be buffered — keep typing until
    # the terminal message_end is on the wire.
    await _refresh_typing()

    if buffered_reply_end is not None:
        await _send_end(
            **buffered_reply_end,
            is_final=True,
            usage=usage,
        )
        await _end_typing()
        return

    if text:
        message_id = str(
            result.get("assistant_message_id") or fallback_message_id
        )
        await _send_start(
            message_id=message_id,
            parent=parent_message_id,
            role="localBot",
        )
        await _send_end(
            message_id=message_id,
            parent=parent_message_id,
            role="localBot",
            content=text,
            is_final=True,
            usage=usage,
        )
        await _end_typing()
        return

    await send(
        {
            "type": protocol.ERROR,
            "message_id": fallback_message_id,
            "parent_message_id": parent_message_id,
            "invoke_root_id": invoke_root_id,
            "error": "cursor run finished with no assistant text",
        }
    )
    await _end_typing()
