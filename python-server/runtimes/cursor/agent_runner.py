"""Cursor local SDK agent runner (isolated venv; no bridge imports).

Owns create/resume/send/wait, adapter-private fingerprint → agent_id cache,
and projection of Stitch context nodes into prompt strings.

IPC: NDJSON on stdin/stdout. One request object per line; one response
object per line (same `id` when provided). Also supports `--once` for a
single JSON document on stdin (smoke / debugging).

Affinity (in-memory only — not durable across runner process death):
  - Key = hash(last_known_prefix nodes + cwd). Historical keys are dropped
    when a turn advances, so forks (different prefix) miss.
  - Miss: create + seed with full projected window; on success store
    last_known = request_context + assistant node (shim-provided id).
  - Hit: when fingerprint(context[:-1], cwd) matches; resume + send only
    the trigger text; advance last_known to the new full window + assistant.
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
from collections.abc import Mapping, Sequence
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from cursor_sdk import AsyncClient, CursorAgentError, LocalAgentOptions
from dotenv import find_dotenv, load_dotenv

load_dotenv(find_dotenv())

DEFAULT_MODEL = "composer-2.5"
CURSOR_AUTHOR = "cursor"


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
        assistant_message_id: str,
        assistant_text: str,
    ) -> str:
        """Store last-known = request window + assistant node; return new fp."""
        last_known = [
            *request_nodes,
            {
                "id": assistant_message_id,
                "role": "localBot",
                "author_id": CURSOR_AUTHOR,
                "content": assistant_text,
            },
        ]
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


async def _run_create_send(
    *,
    client: AsyncClient,
    cwd: str,
    prompt: str,
    model: str,
    api_key: str | None,
) -> tuple[str, Any]:
    agent = await client.create_agent(
        model=model,
        api_key=api_key,
        local=LocalAgentOptions(cwd=cwd),
    )
    agent_id = str(getattr(agent, "agent_id", "") or "")
    try:
        run = await agent.send(prompt)
        result = await run.wait()
        return agent_id, result
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
) -> Any:
    # Local agents require an explicit model on resume/send (create stored it;
    # resume clears agent.model unless passed again).
    agent = await client.resume_agent(agent_id, {"model": model})
    try:
        run = await agent.send(prompt, {"model": model})
        return await run.wait()
    finally:
        try:
            await agent.close()
        except Exception:  # noqa: BLE001
            pass


async def handle_invoke(request: Mapping[str, Any]) -> dict[str, Any]:
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
    assistant_message_id = str(
        request.get("assistant_message_id") or f"srv-cursor-{os.getpid()}"
    )

    request_nodes = prefix_nodes(context)
    # Hit when the window *before* the trigger matches an agent's last-known
    # (which already includes the prior assistant node after a success).
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

    try:
        if mode == "hit" and entry is not None:
            prompt = project_hit_delta(context)
            agent_id = entry.agent_id
            async with _STATE.lock_for(agent_id):
                try:
                    result = await _run_resume_send(
                        client=client,
                        agent_id=agent_id,
                        prompt=prompt,
                        model=model,
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
                agent_id, result = await _run_create_send(
                    client=client,
                    cwd=cwd,
                    prompt=prompt,
                    model=model,
                    api_key=api_key,
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

    new_fp = _STATE.advance(
        agent_id=agent_id,
        cwd=cwd,
        request_nodes=request_nodes,
        assistant_message_id=assistant_message_id,
        assistant_text=text,
    )

    return {
        "ok": True,
        "status": "finished",
        "text": text,
        "usage": usage,
        "mode": mode,
        "agent_id": agent_id,
        "run_id": run_id,
        "fingerprint": new_fp,
        "assistant_message_id": assistant_message_id,
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
            result = await handle_invoke(request)
            if req_id is not None:
                result = {**result, "id": req_id}
            _emit(result)
        except Exception as exc:  # noqa: BLE001
            _emit(
                {
                    "id": req_id,
                    "ok": False,
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
    result = await handle_invoke(request)
    _emit(result)
    return 0 if result.get("ok") else 1


async def _shutdown() -> None:
    await _STATE.aclose()


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--once",
        action="store_true",
        help="Read one JSON invoke from stdin, print one JSON result, exit",
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
