"""Cursor local SDK agent runner (isolated venv; no bridge imports).

Owns create/resume/send/wait, adapter-private fingerprint → agent_id cache,
and projection of Stitch context nodes into prompt strings.

IPC: NDJSON on stdin/stdout. One request object per line; zero or more
`event=progress` lines (same `id`), then one terminal response line
(`ok` present). Also supports `--once` for a single JSON document on
stdin (smoke / debugging).

Progress parts come from SendOptions.on_step (completed conversation
steps: thinking, assistant text, tool batch) — not from run.messages(),
which can fragment thinking/assistant below step granularity.

Affinity (in-memory only — not durable across runner process death):
  - Key = hash(last_known_prefix nodes + cwd). Historical keys are dropped
    when a turn advances, so forks (different prefix) miss.
  - Miss: create + seed with full projected window; on success store
    last_known = request_context + reply-branch localBot nodes.
  - Hit: when fingerprint(context[:-1], cwd) matches; resume + send only
    the trigger text; advance last_known to the new full window + reply
    branch.
  - Do not advance on CursorAgentError or result.status != "finished".

Local SDK agents may still exist on disk under the workspace after a
runner restart; affinity cold-starts until persistence lands.
"""

from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
import os
import sys
import traceback
import uuid
from collections.abc import Awaitable, Callable, Mapping, Sequence
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from cursor_sdk import AsyncClient, CursorAgentError, LocalAgentOptions, SendOptions
from dotenv import find_dotenv, load_dotenv

load_dotenv(find_dotenv())

DEFAULT_MODEL = "composer-2.5"
CURSOR_AUTHOR = "cursor"

ProgressFn = Callable[[Mapping[str, Any]], Awaitable[None] | None]


def _normalize_cwd(cwd: str) -> str:
    return str(Path(cwd).expanduser().resolve())


def project_miss_seed(context: Sequence[Mapping[str, Any]]) -> str:
    """Concatenate the full Stitch window into one user prompt (trigger last)."""
    parts: list[str] = []
    for node in context:
        role = str(node.get("role") or "user")
        author = str(node.get("author_id") or node.get("bot_id") or "")
        content = str(node.get("content") or "")
        if not content:
            continue
        label = role if not author else f"{role}/{author}"
        parts.append(f"[{label}]\n{content}")
    return "\n\n".join(parts)


def project_hit_delta(context: Sequence[Mapping[str, Any]]) -> str:
    """Hit path: only the trigger (last node) content."""
    if not context:
        return ""
    return str(context[-1].get("content") or "")


def prefix_nodes(context: Sequence[Mapping[str, Any]]) -> list[dict[str, str]]:
    """Canonical prefix nodes used for fingerprinting (adapter-private)."""
    out: list[dict[str, str]] = []
    for node in context:
        out.append(
            {
                "id": str(node.get("id") or ""),
                "role": str(node.get("role") or ""),
                "author_id": str(
                    node.get("author_id") or node.get("bot_id") or ""
                ),
                "content": str(node.get("content") or ""),
            }
        )
    return out


def fingerprint_for(prefix: Sequence[Mapping[str, str]], cwd: str) -> str:
    payload = json.dumps(
        {"cwd": _normalize_cwd(cwd), "prefix": list(prefix)},
        separators=(",", ":"),
        ensure_ascii=False,
    )
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def usage_to_dict(usage: Any) -> dict[str, int] | None:
    if usage is None:
        return None
    input_tokens = int(getattr(usage, "input_tokens", 0) or 0)
    output_tokens = int(getattr(usage, "output_tokens", 0) or 0)
    cache_read = int(getattr(usage, "cache_read_tokens", 0) or 0)
    cache_write = int(getattr(usage, "cache_write_tokens", 0) or 0)
    total = int(
        getattr(usage, "total_tokens", 0)
        or (input_tokens + output_tokens + cache_read + cache_write)
    )
    out: dict[str, int] = {
        "prompt_tokens": input_tokens,
        "completion_tokens": output_tokens,
        "total_tokens": total,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "cache_read_tokens": cache_read,
        "cache_write_tokens": cache_write,
    }
    reasoning = getattr(usage, "reasoning_tokens", None)
    if reasoning is not None:
        out["reasoning_tokens"] = int(reasoning)
    return out


def _new_message_id() -> str:
    return f"srv-{uuid.uuid4()}"


def _jsonish(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, str):
        return value
    try:
        return json.dumps(value, ensure_ascii=False, indent=2)
    except TypeError:
        return str(value)


def _fence(body: str, lang: str = "") -> str:
    """Wrap body in a markdown fence; lengthen ticks if body contains ```."""
    tick = "```"
    while tick in body:
        tick += "`"
    lang_part = lang if lang else ""
    return f"{tick}{lang_part}\n{body}\n{tick}"


def _format_function_call(name: str, args: Any) -> str:
    body = _jsonish(args)
    if body:
        return f"**{name}**\n\n{_fence(body, 'json')}"
    return f"**{name}**"


def _format_function_result(result: Any, *, is_error: bool = False) -> str:
    if isinstance(result, str):
        text = result
        lang = ""
    else:
        text = _jsonish(result)
        lang = "json" if text else ""
    prefix = "**error**\n\n" if is_error else ""
    if not text:
        return f"{prefix}_(empty)_"
    return f"{prefix}{_fence(text, lang)}"


def _tool_fields(message: Mapping[str, Any]) -> tuple[str, str, Any, Any, bool]:
    """Best-effort extract (name, call_id, args, result, is_error) from a tool step."""
    # Completed ToolCall union often looks like {type: "read", args, result}.
    name = str(
        message.get("name")
        or message.get("toolName")
        or message.get("tool_name")
        or message.get("type")
        or "tool"
    )
    if name in ("toolCall", "tool_call"):
        name = str(message.get("toolName") or message.get("name") or "tool")
    call_id = str(
        message.get("call_id")
        or message.get("callId")
        or message.get("toolCallId")
        or message.get("tool_call_id")
        or ""
    )
    args = message.get("args")
    result = message.get("result")
    status = str(message.get("status") or "").lower()
    is_error = status == "error" or bool(message.get("is_error") or message.get("isError"))
    return name, call_id, args, result, is_error


def conversation_step_to_parts(step: Any) -> list[dict[str, Any]]:
    """Map one completed ConversationStep into Stitch progress part(s).

    Prefer this over run.messages(): SDK message stream can emit thinking /
    assistant text in sub-step chunks; on_step fires once per completed
    thinking, assistant, or tool batch (see Cursor SDK SendOptions.on_step).
    """
    step_type = getattr(step, "type", None)
    if isinstance(step, Mapping):
        step_type = step.get("type")
        message = step.get("message")
    else:
        message = getattr(step, "message", None)

    if step_type == "thinkingMessage":
        text = ""
        if message is not None:
            text = str(getattr(message, "text", None) or "")
            if not text and isinstance(message, Mapping):
                text = str(message.get("text") or "")
        if not text.strip():
            return []
        return [
            {
                "kind": "thinking",
                "branch": "side",
                "message_id": _new_message_id(),
                "content": text,
            }
        ]

    if step_type == "assistantMessage":
        text = ""
        if message is not None:
            text = str(getattr(message, "text", None) or "")
            if not text and isinstance(message, Mapping):
                text = str(message.get("text") or "")
        if not text.strip():
            return []
        return [
            {
                "kind": "localBot",
                "branch": "reply",
                "message_id": _new_message_id(),
                "content": text,
            }
        ]

    if step_type == "toolCall":
        if not isinstance(message, Mapping):
            return []
        name, call_id, args, result, is_error = _tool_fields(message)
        parts: list[dict[str, Any]] = [
            {
                "kind": "functionCall",
                "branch": "side",
                "message_id": _new_message_id(),
                "content": _format_function_call(name, args),
                "tool_name": name,
                "tool_call_id": call_id,
            }
        ]
        # Completed tool batch — also emit the result node.
        parts.append(
            {
                "kind": "functionResult",
                "branch": "side",
                "message_id": _new_message_id(),
                "content": _format_function_result(result, is_error=is_error),
                "tool_name": name,
                "tool_call_id": call_id,
                "is_error": is_error,
            }
        )
        return parts

    return []


def sdk_message_to_parts(message: Any) -> list[dict[str, Any]]:
    """Legacy mapper for run.messages() chunks (tests / fallback only).

    Prefer conversation_step_to_parts — message stream fragments thinking and
    assistant text below completed-step granularity.
    """
    msg_type = getattr(message, "type", None)
    if msg_type == "thinking":
        text = str(getattr(message, "text", "") or "")
        if not text.strip():
            return []
        return [
            {
                "kind": "thinking",
                "branch": "side",
                "message_id": _new_message_id(),
                "content": text,
            }
        ]

    if msg_type == "tool_call":
        status = str(getattr(message, "status", "") or "")
        name = str(getattr(message, "name", "") or "")
        call_id = str(getattr(message, "call_id", "") or "")
        if status == "running":
            return [
                {
                    "kind": "functionCall",
                    "branch": "side",
                    "message_id": _new_message_id(),
                    "content": _format_function_call(
                        name, getattr(message, "args", None)
                    ),
                    "tool_name": name,
                    "tool_call_id": call_id,
                }
            ]
        if status in ("completed", "error"):
            return [
                {
                    "kind": "functionResult",
                    "branch": "side",
                    "message_id": _new_message_id(),
                    "content": _format_function_result(
                        getattr(message, "result", None),
                        is_error=status == "error",
                    ),
                    "tool_name": name,
                    "tool_call_id": call_id,
                    "is_error": status == "error",
                }
            ]
        return []

    if msg_type == "assistant":
        content = getattr(getattr(message, "message", None), "content", None)
        if not content:
            return []
        parts: list[dict[str, Any]] = []
        for block in content:
            if getattr(block, "type", None) != "text":
                continue
            text = str(getattr(block, "text", "") or "")
            if not text.strip():
                continue
            parts.append(
                {
                    "kind": "localBot",
                    "branch": "reply",
                    "message_id": _new_message_id(),
                    "content": text,
                }
            )
        return parts

    return []


@dataclass
class CacheEntry:
    fingerprint: str
    agent_id: str
    last_known_prefix: list[dict[str, str]]
    cwd: str


@dataclass
class RunnerState:
    """Process-local SDK clients + affinity. Not durable across restarts."""

    clients: dict[str, AsyncClient] = field(default_factory=dict)
    # fingerprint(last_known_prefix, cwd) → entry (current prefix only).
    by_fingerprint: dict[str, CacheEntry] = field(default_factory=dict)
    agent_locks: dict[str, asyncio.Lock] = field(default_factory=dict)

    def lock_for(self, agent_id: str) -> asyncio.Lock:
        lock = self.agent_locks.get(agent_id)
        if lock is None:
            lock = asyncio.Lock()
            self.agent_locks[agent_id] = lock
        return lock

    async def client_for(self, cwd: str) -> AsyncClient:
        key = _normalize_cwd(cwd)
        existing = self.clients.get(key)
        if existing is not None:
            return existing
        # The SDK bridge subprocess inherits this process's cwd, and (as of
        # cursor-sdk 1.0.31) LocalAgentOptions.cwd / --workspace alone do not
        # relocate the local executor — smoke: pwd stayed at the runner's
        # launch directory. Chdir before spawn so the bridge lands in `key`.
        os.chdir(key)
        client = await AsyncClient.launch_bridge(
            workspace=key,
            local=LocalAgentOptions(cwd=key),
        )
        self.clients[key] = client
        return client

    def drop_agent_entries(self, agent_id: str) -> None:
        for fp, cached in list(self.by_fingerprint.items()):
            if cached.agent_id == agent_id:
                del self.by_fingerprint[fp]

    def advance(
        self,
        *,
        agent_id: str,
        cwd: str,
        request_nodes: list[dict[str, str]],
        reply_nodes: Sequence[Mapping[str, str]] | None = None,
        assistant_message_id: str | None = None,
        assistant_text: str | None = None,
    ) -> str:
        """Store last-known = request window + reply-branch nodes; return fp.

        Prefer [reply_nodes] (streamed assistant parts). Legacy single-node
        kwargs remain for unit tests.
        """
        if reply_nodes is not None:
            reply = [
                {
                    "id": str(n.get("id") or ""),
                    "role": str(n.get("role") or "localBot"),
                    "author_id": str(
                        n.get("author_id") or CURSOR_AUTHOR
                    ),
                    "content": str(n.get("content") or ""),
                }
                for n in reply_nodes
            ]
        else:
            reply = [
                {
                    "id": str(assistant_message_id or ""),
                    "role": "localBot",
                    "author_id": CURSOR_AUTHOR,
                    "content": str(assistant_text or ""),
                }
            ]
        last_known = [*request_nodes, *reply]
        new_fp = fingerprint_for(last_known, cwd)
        self.drop_agent_entries(agent_id)
        self.by_fingerprint[new_fp] = CacheEntry(
            fingerprint=new_fp,
            agent_id=agent_id,
            last_known_prefix=last_known,
            cwd=cwd,
        )
        return new_fp

    async def aclose(self) -> None:
        for client in list(self.clients.values()):
            try:
                await client.aclose()
            except Exception:  # noqa: BLE001
                pass
        self.clients.clear()


_STATE = RunnerState()


async def _emit_progress(
    on_progress: ProgressFn | None, part: Mapping[str, Any]
) -> None:
    if on_progress is None:
        return
    maybe = on_progress(part)
    if asyncio.iscoroutine(maybe) or isinstance(maybe, Awaitable):
        await maybe  # type: ignore[arg-type]


async def _consume_run(
    run: Any,
    on_progress: ProgressFn | None,
    reply_nodes: list[dict[str, str]],
) -> Any:
    """Drain the run via wait(); progress parts already emitted from on_step."""
    # wait() drains the underlying stream, which invokes SendOptions.on_step
    # as each completed conversation step arrives.
    return await run.wait()


def _make_on_step(
    on_progress: ProgressFn | None,
    reply_nodes: list[dict[str, str]],
) -> Any:
    async def on_step(step: Any) -> None:
        for part in conversation_step_to_parts(step):
            await _emit_progress(on_progress, part)
            if part.get("branch") == "reply":
                reply_nodes.append(
                    {
                        "id": str(part["message_id"]),
                        "role": "localBot",
                        "author_id": CURSOR_AUTHOR,
                        "content": str(part.get("content") or ""),
                    }
                )

    return on_step


async def _run_create_send(
    *,
    client: AsyncClient,
    cwd: str,
    prompt: str,
    model: str,
    api_key: str | None,
    on_progress: ProgressFn | None,
) -> tuple[str, list[dict[str, str]], Any]:
    agent = await client.create_agent(
        model=model,
        api_key=api_key,
        local=LocalAgentOptions(cwd=cwd),
    )
    agent_id = str(getattr(agent, "agent_id", "") or "")
    try:
        reply_nodes: list[dict[str, str]] = []
        run = await agent.send(
            prompt,
            SendOptions(model=model, on_step=_make_on_step(on_progress, reply_nodes)),
        )
        result = await _consume_run(run, on_progress, reply_nodes)
        return agent_id, reply_nodes, result
    finally:
        try:
            await agent.close()
        except Exception:  # noqa: BLE001
            pass


async def _run_resume_send(
    *,
    client: AsyncClient,
    agent_id: str,
    prompt: str,
    model: str,
    on_progress: ProgressFn | None,
) -> tuple[list[dict[str, str]], Any]:
    # Local agents require an explicit model on resume/send (create stored it;
    # resume clears agent.model unless passed again).
    agent = await client.resume_agent(agent_id, {"model": model})
    try:
        reply_nodes: list[dict[str, str]] = []
        run = await agent.send(
            prompt,
            SendOptions(model=model, on_step=_make_on_step(on_progress, reply_nodes)),
        )
        result = await _consume_run(run, on_progress, reply_nodes)
        return reply_nodes, result
    finally:
        try:
            await agent.close()
        except Exception:  # noqa: BLE001
            pass


async def handle_invoke(
    request: Mapping[str, Any],
    on_progress: ProgressFn | None = None,
) -> dict[str, Any]:
    """Execute one invoke. Never advances affinity on non-finished results."""
    cwd_raw = request.get("cwd")
    # Shim normally supplies cwd (column tag or home). Home is the last-resort
    # default so a bare invoke still has a workspace for local agents.
    if not cwd_raw or not str(cwd_raw).strip():
        cwd_raw = str(Path.home())
    cwd = _normalize_cwd(str(cwd_raw))
    context = request.get("context") or []
    if not isinstance(context, list):
        context = []
    model = str(request.get("model") or DEFAULT_MODEL)
    api_key = os.environ.get("CURSOR_API_KEY") or None
    fallback_message_id = str(
        request.get("assistant_message_id") or f"srv-cursor-{os.getpid()}"
    )

    request_nodes = prefix_nodes(context)
    # Hit when the window *before* the trigger matches an agent's last-known
    # (which already includes the prior reply-branch nodes after a success).
    parent_nodes = request_nodes[:-1]
    parent_fp = fingerprint_for(parent_nodes, cwd)
    entry = _STATE.by_fingerprint.get(parent_fp)
    mode = "hit" if entry is not None else "miss"

    try:
        client = await _STATE.client_for(cwd)
    except Exception as exc:  # noqa: BLE001
        return {
            "ok": False,
            "error": f"bridge launch failed: {exc}",
            "error_kind": "startup",
            "mode": mode,
        }

    agent_id: str
    result: Any
    reply_nodes: list[dict[str, str]]

    try:
        if mode == "hit" and entry is not None:
            prompt = project_hit_delta(context)
            agent_id = entry.agent_id
            async with _STATE.lock_for(agent_id):
                try:
                    reply_nodes, result = await _run_resume_send(
                        client=client,
                        agent_id=agent_id,
                        prompt=prompt,
                        model=model,
                        on_progress=on_progress,
                    )
                except CursorAgentError as err:
                    return {
                        "ok": False,
                        "error": err.message,
                        "error_kind": "startup",
                        "retryable": bool(getattr(err, "is_retryable", False)),
                        "mode": mode,
                        "agent_id": agent_id,
                    }
        else:
            prompt = project_miss_seed(context)
            try:
                agent_id, reply_nodes, result = await _run_create_send(
                    client=client,
                    cwd=cwd,
                    prompt=prompt,
                    model=model,
                    api_key=api_key,
                    on_progress=on_progress,
                )
            except CursorAgentError as err:
                return {
                    "ok": False,
                    "error": err.message,
                    "error_kind": "startup",
                    "retryable": bool(getattr(err, "is_retryable", False)),
                    "mode": "miss",
                }
            # Register lock for subsequent hits on this agent_id.
            _STATE.lock_for(agent_id)
    except Exception as exc:  # noqa: BLE001
        return {
            "ok": False,
            "error": str(exc),
            "error_kind": "startup",
            "mode": mode,
            "traceback": traceback.format_exc(),
        }

    status = getattr(result, "status", None)
    text = str(getattr(result, "result", None) or "")
    usage = usage_to_dict(getattr(result, "usage", None))
    run_id = getattr(result, "id", None)

    if status != "finished":
        return {
            "ok": False,
            "error": f"run status={status}",
            "error_kind": "run",
            "status": status,
            "text": text,
            "usage": usage,
            "mode": mode,
            "agent_id": agent_id,
            "run_id": run_id,
        }

    # Affinity tracks the visible reply path only (not the side fork).
    affinity_reply = list(reply_nodes)
    if not affinity_reply and text:
        affinity_reply = [
            {
                "id": fallback_message_id,
                "role": "localBot",
                "author_id": CURSOR_AUTHOR,
                "content": text,
            }
        ]

    new_fp = _STATE.advance(
        agent_id=agent_id,
        cwd=cwd,
        request_nodes=request_nodes,
        reply_nodes=affinity_reply,
    )

    return {
        "ok": True,
        "status": "finished",
        "event": "done",
        "text": text,
        "usage": usage,
        "mode": mode,
        "agent_id": agent_id,
        "run_id": run_id,
        "fingerprint": new_fp,
        "assistant_message_id": (
            affinity_reply[-1]["id"] if affinity_reply else fallback_message_id
        ),
        "reply_message_ids": [n["id"] for n in reply_nodes],
    }


def _emit(obj: Mapping[str, Any]) -> None:
    sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def _claim_stdin_for_ipc() -> Any:
    """Keep NDJSON IPC on a private fd; give children /dev/null as stdin.

    `AsyncClient.launch_bridge` spawns `cursor-sdk-bridge`, which would otherwise
    inherit this process's stdin and steal (or close) the next request line.
    """
    ipc_fd = os.dup(0)
    devnull = os.open(os.devnull, os.O_RDONLY)
    try:
        os.dup2(devnull, 0)
    finally:
        os.close(devnull)
    return os.fdopen(ipc_fd, "r", encoding="utf-8", closefd=True)


async def _handle_and_emit(request: Mapping[str, Any], req_id: Any) -> None:
    async def on_progress(part: Mapping[str, Any]) -> None:
        line: dict[str, Any] = {"event": "progress", "part": dict(part)}
        if req_id is not None:
            line["id"] = req_id
        _emit(line)

    result = await handle_invoke(request, on_progress=on_progress)
    if req_id is not None:
        result = {**result, "id": req_id}
    if "event" not in result:
        result = {**result, "event": "done" if result.get("ok") else "error"}
    _emit(result)


async def _loop() -> None:
    ipc = _claim_stdin_for_ipc()
    loop = asyncio.get_event_loop()
    while True:
        line = await loop.run_in_executor(None, ipc.readline)
        if not line:
            break
        line = line.strip()
        if not line:
            continue
        req_id = None
        try:
            request = json.loads(line)
            req_id = request.get("id")
            await _handle_and_emit(request, req_id)
        except Exception as exc:  # noqa: BLE001
            _emit(
                {
                    "id": req_id,
                    "ok": False,
                    "event": "error",
                    "error": str(exc),
                    "error_kind": "internal",
                    "traceback": traceback.format_exc(),
                }
            )


async def _once() -> int:
    # --once reads the whole stdin payload before any SDK child is spawned,
    # so stdin hijacking is not an issue for this mode.
    raw = sys.stdin.read()
    request = json.loads(raw)
    req_id = request.get("id")
    try:
        await _handle_and_emit(request, req_id)
        # Exit code: scan is awkward after emit; re-run invoke is wrong.
        # Treat success if we got here without exception — smoke checks stdout.
        return 0
    except Exception:  # noqa: BLE001
        return 1


async def _shutdown() -> None:
    await _STATE.aclose()


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--once",
        action="store_true",
        help="Read one JSON invoke from stdin, print stream + result, exit",
    )
    args = parser.parse_args(argv)
    try:
        if args.once:
            code = asyncio.run(_once())
            raise SystemExit(code)
        asyncio.run(_loop())
    finally:
        try:
            asyncio.run(_shutdown())
        except Exception:  # noqa: BLE001
            pass


if __name__ == "__main__":
    main()
