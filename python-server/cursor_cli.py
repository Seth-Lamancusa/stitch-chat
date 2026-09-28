"""Cursor CLI subprocess: resolve the bundled binary, stream-json, sessions.

The bridge never imports cursor-sdk. Invokes spawn `cursor-agent` (the
package executable) and map newline-delimited JSON into the progress parts
`cursor_adapter` already emits.

Session affinity matches the old runner: a hit is
fingerprint(context[:-1], cwd) of a prior successful turn; the CLI then
gets `--resume <session_id>` and only the new trigger text. The map is
persisted under the app data dir so a bridge restart can resume.
"""

from __future__ import annotations

import asyncio
import hashlib
import json
import os
import shutil
import uuid
from collections.abc import Awaitable, Callable, Mapping, Sequence
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from logging_setup import hop

ProgressFn = Callable[[Mapping[str, Any]], Awaitable[None]]

DEFAULT_OVERALL_TIMEOUT_S = 30 * 60
DEFAULT_IDLE_TIMEOUT_S = 120
LOGIN_TIMEOUT_S = 5 * 60
STATUS_TIMEOUT_S = 30

_AUTH_MARKERS = (
    "not authenticated",
    "not logged in",
    "please log in",
    "authentication required",
)

_BRIDGE_DIR = Path(__file__).resolve().parent


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
                "author_id": str(node.get("author_id") or node.get("bot_id") or ""),
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


def looks_like_auth_failure(text: str) -> bool:
    lowered = text.lower()
    return any(marker in lowered for marker in _AUTH_MARKERS)


def interpret_status(returncode: int, text: str) -> str:
    """Map `agent status` output to an auth state name."""
    if looks_like_auth_failure(text):
        return "unauthenticated"
    lowered = text.lower()
    if returncode == 0 and (
        "logged in" in lowered or "authenticated" in lowered or "@" in lowered
    ):
        return "authenticated"
    if returncode == 0 and text.strip():
        return "authenticated"
    return "unauthenticated"


def _packaged_layout() -> bool:
    """CMake installs the bridge at <bundle>/data/python-server."""
    return _BRIDGE_DIR.parent.name == "data"


def resolve_agent_binary() -> Path | None:
    """First existing binary: override, packaged sibling, dev tree, then PATH.

    `STITCH_CURSOR_AGENT` is absolute: a missing path does not fall through.
    Packaged builds do not consult PATH, so a user-installed CLI cannot
    shadow the one we ship.
    """
    override = os.environ.get("STITCH_CURSOR_AGENT")
    if override is not None and override.strip():
        path = Path(override).expanduser()
        return path if path.is_file() else None

    packaged = _BRIDGE_DIR.parent / "cursor-agent" / "cursor-agent"
    if packaged.is_file():
        return packaged

    dev = _BRIDGE_DIR.parent / "third_party" / "cursor-agent" / "cursor-agent"
    if dev.is_file():
        return dev

    if _packaged_layout():
        return None
    found = shutil.which("agent") or shutil.which("cursor-agent")
    return Path(found) if found else None


def app_data_dir() -> Path:
    override = os.environ.get("STITCH_CURSOR_DATA_DIR")
    if override and override.strip():
        return Path(override).expanduser()
    xdg = os.environ.get("XDG_DATA_HOME")
    root = Path(xdg) if xdg else Path.home() / ".local" / "share"
    return root / "stitch-chat"


def subprocess_env() -> dict[str, str]:
    """Minimal env for a GUI-launched app. File credential store avoids keychain.

    Display and session variables are passed through so `agent login` can
    open the system default browser.
    """
    env: dict[str, str] = {
        "HOME": os.environ.get("HOME", str(Path.home())),
        "PATH": os.environ.get("PATH", ""),
        "TERM": os.environ.get("TERM", "dumb"),
        "AGENT_CLI_CREDENTIAL_STORE": "file",
    }
    for key in (
        "LANG",
        "LC_ALL",
        "USER",
        "LOGNAME",
        "XDG_RUNTIME_DIR",
        "XDG_DATA_HOME",
        "XDG_CONFIG_HOME",
        "XDG_CURRENT_DESKTOP",
        "XDG_SESSION_TYPE",
        "DISPLAY",
        "WAYLAND_DISPLAY",
        "DBUS_SESSION_BUS_ADDRESS",
        "BROWSER",
    ):
        value = os.environ.get(key)
        if value:
            env[key] = value
    api_key = os.environ.get("CURSOR_API_KEY", "").strip()
    if api_key:
        env["CURSOR_API_KEY"] = api_key
    return env


def prepare_binary(binary: Path) -> Path:
    """Copy a read-only (AppImage) tree into the app data dir and run that.

    A writable tree (dev checkout) is launched in place. The package bytes
    stay the source of truth: a different VERSION replaces the copy.
    """
    if os.access(binary.parent, os.W_OK):
        return binary
    version = ""
    version_file = binary.parent / "VERSION"
    if version_file.is_file():
        version = version_file.read_text(encoding="utf-8").strip()
    dest = app_data_dir() / "cursor-agent"
    dest_bin = dest / binary.name
    dest_version = dest / "VERSION"
    if (
        dest_bin.is_file()
        and dest_version.is_file()
        and dest_version.read_text(encoding="utf-8").strip() == version
        and version
    ):
        return dest_bin
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        shutil.rmtree(dest)
    shutil.copytree(binary.parent, dest, symlinks=True)
    if version and not dest_version.is_file():
        dest_version.write_text(version + "\n", encoding="utf-8")
    hop("py.runtime", "materialized cursor-agent dest={} version={}", dest, version or "-")
    return dest_bin


@dataclass
class CacheEntry:
    fingerprint: str
    session_id: str
    last_known_prefix: list[dict[str, str]]
    cwd: str


class SessionStore:
    """fingerprint(last_known_prefix, cwd) → CLI session id."""

    def __init__(self, path: Path | None) -> None:
        self.path = path
        self.by_fingerprint: dict[str, CacheEntry] = {}
        self._load()

    def _load(self) -> None:
        if self.path is None or not self.path.is_file():
            return
        try:
            raw = json.loads(self.path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return
        entries = raw.get("entries") if isinstance(raw, dict) else None
        if not isinstance(entries, list):
            return
        for item in entries:
            if not isinstance(item, dict):
                continue
            fp = str(item.get("fingerprint") or "")
            session_id = str(item.get("session_id") or "")
            cwd = str(item.get("cwd") or "")
            prefix = item.get("last_known_prefix") or []
            if not fp or not session_id or not isinstance(prefix, list):
                continue
            nodes = [n for n in prefix if isinstance(n, dict)]
            self.by_fingerprint[fp] = CacheEntry(
                fingerprint=fp,
                session_id=session_id,
                last_known_prefix=[
                    {
                        "id": str(n.get("id") or ""),
                        "role": str(n.get("role") or ""),
                        "author_id": str(n.get("author_id") or ""),
                        "content": str(n.get("content") or ""),
                    }
                    for n in nodes
                ],
                cwd=cwd,
            )

    def save(self) -> None:
        if self.path is None:
            return
        self.path.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "entries": [
                {
                    "fingerprint": entry.fingerprint,
                    "session_id": entry.session_id,
                    "cwd": entry.cwd,
                    "last_known_prefix": entry.last_known_prefix,
                }
                for entry in self.by_fingerprint.values()
            ]
        }
        self.path.write_text(json.dumps(payload), encoding="utf-8")

    def drop_session(self, session_id: str) -> None:
        for fp, cached in list(self.by_fingerprint.items()):
            if cached.session_id == session_id:
                del self.by_fingerprint[fp]
        self.save()

    def advance(
        self,
        *,
        session_id: str,
        cwd: str,
        request_nodes: list[dict[str, str]],
        reply_nodes: Sequence[Mapping[str, str]] | None = None,
        assistant_message_id: str | None = None,
        assistant_text: str | None = None,
    ) -> str:
        """Store last-known = request window + reply-branch nodes; return fp."""
        if reply_nodes is not None:
            reply = [
                {
                    "id": str(n.get("id") or ""),
                    "role": str(n.get("role") or "localBot"),
                    "author_id": str(n.get("author_id") or "cursor"),
                    "content": str(n.get("content") or ""),
                }
                for n in reply_nodes
            ]
        else:
            reply = [
                {
                    "id": str(assistant_message_id or ""),
                    "role": "localBot",
                    "author_id": "cursor",
                    "content": str(assistant_text or ""),
                }
            ]
        last_known = [*request_nodes, *reply]
        new_fp = fingerprint_for(last_known, cwd)
        self.drop_session(session_id)
        self.by_fingerprint[new_fp] = CacheEntry(
            fingerprint=new_fp,
            session_id=session_id,
            last_known_prefix=last_known,
            cwd=_normalize_cwd(cwd),
        )
        self.save()
        return new_fp


def default_session_path() -> Path:
    override = os.environ.get("STITCH_CURSOR_SESSION_PATH")
    if override and override.strip():
        return Path(override).expanduser()
    return app_data_dir() / "cursor-sessions.json"


_STORE: SessionStore | None = None
_WORKSPACE_LOCKS: dict[str, asyncio.Lock] = {}


def get_session_store() -> SessionStore:
    global _STORE
    if _STORE is None:
        _STORE = SessionStore(default_session_path())
    return _STORE


def reset_session_store(path: Path | None = None) -> SessionStore:
    """Tests replace the process-wide store."""
    global _STORE
    _STORE = SessionStore(path)
    return _STORE


def workspace_lock(cwd: str) -> asyncio.Lock:
    key = _normalize_cwd(cwd)
    lock = _WORKSPACE_LOCKS.get(key)
    if lock is None:
        lock = asyncio.Lock()
        _WORKSPACE_LOCKS[key] = lock
    return lock


def _new_id() -> str:
    return f"srv-{uuid.uuid4()}"


def _jsonish(value: Any) -> str:
    if value is None or value == "":
        return ""
    if isinstance(value, str):
        return value
    try:
        return json.dumps(value, ensure_ascii=False, indent=2)
    except TypeError:
        return str(value)


def _format_tool(name: str, payload: Any) -> str:
    body = _jsonish(payload)
    if body and body not in ("{}", "[]", "null"):
        return f"**{name}**\n\n```json\n{body}\n```"
    return f"**{name}**"


def _session_id_from(event: Mapping[str, Any]) -> str | None:
    for key in ("session_id", "sessionId", "chat_id", "chatId"):
        value = event.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return None


def _assistant_text(event: Mapping[str, Any]) -> str:
    message = event.get("message")
    content: Any = None
    if isinstance(message, dict):
        content = message.get("content")
    elif isinstance(message, str):
        return message
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        chunks: list[str] = []
        for block in content:
            if isinstance(block, str):
                chunks.append(block)
            elif isinstance(block, dict) and isinstance(block.get("text"), str):
                chunks.append(block["text"])
        return "".join(chunks)
    text = event.get("text")
    return text if isinstance(text, str) else ""


def _tool_name_and_body(tool_call: Mapping[str, Any]) -> tuple[str, Any, Any]:
    """Return (name, args, result) from a tool_call object. Unknown shapes stay opaque."""
    for key, value in tool_call.items():
        if not isinstance(value, dict):
            continue
        name = key[: -len("ToolCall")] if key.endswith("ToolCall") else key
        name = name[:1].lower() + name[1:] if name else "tool"
        return name or "tool", value.get("args"), value.get("result")
    return "tool", dict(tool_call), None


def _is_tool_error(result: Any) -> bool:
    if not isinstance(result, dict):
        return False
    if result.get("isError") is True or result.get("is_error") is True:
        return True
    error = result.get("error")
    return bool(error)


def normalize_usage(raw: Any) -> dict[str, int] | None:
    if not isinstance(raw, dict):
        return None
    def _num(*keys: str) -> int:
        for key in keys:
            value = raw.get(key)
            if isinstance(value, bool):
                continue
            if isinstance(value, (int, float)):
                return int(value)
        return 0

    input_tokens = _num("input_tokens", "prompt_tokens")
    output_tokens = _num("output_tokens", "completion_tokens")
    cache_read = _num("cache_read_tokens", "cache_read")
    cache_write = _num("cache_write_tokens", "cache_write")
    total = _num("total_tokens") or (input_tokens + output_tokens + cache_read + cache_write)
    if total == 0 and input_tokens == 0 and output_tokens == 0:
        return None
    out: dict[str, int] = {
        "prompt_tokens": input_tokens,
        "completion_tokens": output_tokens,
        "total_tokens": total,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "cache_read_tokens": cache_read,
        "cache_write_tokens": cache_write,
    }
    reasoning = raw.get("reasoning_tokens")
    if isinstance(reasoning, int):
        out["reasoning_tokens"] = reasoning
    return out


@dataclass
class StreamAssembler:
    """Fold stream-json events into adapter progress parts.

    Assistant events that carry `model_call_id` are buffered flushes and are
    skipped. Deltas (assistant events with `timestamp_ms` and no model call
    id) append text. stream-json also re-emits the still-open buffer once
    when the run succeeds, with neither `model_call_id` nor `timestamp_ms`;
    that copy is dropped when it matches text already accumulated. Text is
    emitted as one reply part when a tool starts or the turn ends, so the
    adapter does not persist one message per token.
    """

    text: str = ""
    session_id: str | None = None
    usage: dict[str, int] | None = None
    result_text: str | None = None
    error: str | None = None
    reply_nodes: list[dict[str, str]] = field(default_factory=list)
    _open_calls: list[tuple[str, str]] = field(default_factory=list)

    def feed(self, event: Mapping[str, Any]) -> list[dict[str, Any]]:
        kind = event.get("type")
        if kind == "system":
            self.session_id = _session_id_from(event) or self.session_id
            return []
        if kind == "assistant":
            if event.get("model_call_id"):
                return []
            chunk = _assistant_text(event)
            # End-of-run flush: the CLI reprints the open buffer with no
            # timestamp after the deltas. Tool-boundary flushes carry
            # model_call_id and are skipped above.
            if "timestamp_ms" not in event and self.text and chunk == self.text:
                return []
            self.text += chunk
            return []
        if kind == "tool_call":
            return self._tool(event)
        if kind == "result":
            self.session_id = _session_id_from(event) or self.session_id
            self.usage = normalize_usage(event.get("usage")) or self.usage
            result = event.get("result")
            if isinstance(result, str):
                self.result_text = result
            if event.get("is_error") is True or event.get("subtype") == "error":
                self.error = str(event.get("error") or result or "cursor run failed")
            return []
        return []

    def flush_text(self) -> list[dict[str, Any]]:
        if not self.text:
            return []
        part = self._reply_part(self.text)
        self.text = ""
        return [part]

    def _reply_part(self, content: str) -> dict[str, Any]:
        message_id = _new_id()
        self.reply_nodes.append(
            {
                "id": message_id,
                "role": "localBot",
                "author_id": "cursor",
                "content": content,
            }
        )
        return {
            "kind": "localBot",
            "branch": "reply",
            "message_id": message_id,
            "content": content,
        }

    def _tool(self, event: Mapping[str, Any]) -> list[dict[str, Any]]:
        parts = self.flush_text()
        tool_call = event.get("tool_call")
        if not isinstance(tool_call, dict):
            tool_call = {}
        name, args, result = _tool_name_and_body(tool_call)
        subtype = str(event.get("subtype") or "")
        call_id = event.get("call_id") or event.get("tool_call_id")
        if subtype == "completed":
            matched = self._take_call(name, str(call_id) if call_id else None)
            content_payload = result if result is not None else args
            parts.append(
                {
                    "kind": "functionResult",
                    "branch": "side",
                    "message_id": _new_id(),
                    "content": _format_tool(name, content_payload),
                    "tool_name": name,
                    "tool_call_id": matched,
                    "is_error": _is_tool_error(result),
                }
            )
            return parts
        cid = str(call_id) if call_id else _new_id()
        self._open_calls.append((name, cid))
        parts.append(
            {
                "kind": "functionCall",
                "branch": "side",
                "message_id": _new_id(),
                "content": _format_tool(name, args),
                "tool_name": name,
                "tool_call_id": cid,
            }
        )
        return parts

    def _take_call(self, name: str, call_id: str | None) -> str:
        if call_id:
            for index, (open_name, open_id) in enumerate(self._open_calls):
                if open_id == call_id or open_name == name:
                    self._open_calls.pop(index)
                    return open_id
            return call_id
        for index, (open_name, open_id) in enumerate(self._open_calls):
            if open_name == name:
                self._open_calls.pop(index)
                return open_id
        if self._open_calls:
            return self._open_calls.pop(0)[1]
        return _new_id()


def _timeouts() -> tuple[float, float]:
    def _read(name: str, default: float) -> float:
        raw = os.environ.get(name)
        if not raw:
            return default
        try:
            return float(raw)
        except ValueError:
            return default

    return (
        _read("STITCH_CURSOR_TIMEOUT_S", DEFAULT_OVERALL_TIMEOUT_S),
        _read("STITCH_CURSOR_IDLE_TIMEOUT_S", DEFAULT_IDLE_TIMEOUT_S),
    )


async def _terminate(proc: asyncio.subprocess.Process) -> None:
    if proc.returncode is not None:
        return
    proc.terminate()
    try:
        await asyncio.wait_for(proc.wait(), timeout=2)
    except asyncio.TimeoutError:
        proc.kill()
        await proc.wait()


async def _run_cli(
    args: list[str],
    *,
    cwd: str,
    env: dict[str, str],
    on_event: Callable[[Mapping[str, Any]], Awaitable[None]] | None = None,
    overall_s: float | None = None,
    idle_s: float | None = None,
) -> tuple[int, str]:
    """Spawn the CLI. Stream stdout JSON lines. Return (rc, stderr tail)."""
    default_overall, default_idle = _timeouts()
    overall = overall_s if overall_s is not None else default_overall
    idle = idle_s if idle_s is not None else default_idle
    hop("py.runtime", "→runtime argv0={} cwd={}", args[0], cwd)
    proc = await asyncio.create_subprocess_exec(
        *args,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        env=env,
        cwd=cwd,
        limit=8 * 1024 * 1024,
    )
    assert proc.stdout is not None
    assert proc.stderr is not None
    stderr_chunks: list[bytes] = []

    async def _drain_stderr() -> None:
        while True:
            chunk = await proc.stderr.read(4096)
            if not chunk:
                return
            stderr_chunks.append(chunk)
            # Keep a bounded tail.
            total = sum(len(c) for c in stderr_chunks)
            while total > 8000 and len(stderr_chunks) > 1:
                total -= len(stderr_chunks.pop(0))

    stderr_task = asyncio.create_task(_drain_stderr())
    loop = asyncio.get_running_loop()
    deadline = loop.time() + overall
    try:
        while True:
            remaining = deadline - loop.time()
            if remaining <= 0:
                raise TimeoutError("cursor agent overall timeout")
            try:
                raw = await asyncio.wait_for(
                    proc.stdout.readline(),
                    timeout=min(idle, remaining),
                )
            except asyncio.TimeoutError as exc:
                raise TimeoutError("cursor agent produced no output") from exc
            if not raw:
                break
            line = raw.decode("utf-8", "replace").strip()
            if not line:
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                hop("py.runtime", "←runtime non-json {}", line[:200])
                continue
            if on_event is not None and isinstance(event, dict):
                await on_event(event)
        rc = await proc.wait()
        await stderr_task
        stderr = b"".join(stderr_chunks).decode("utf-8", "replace")
        hop("py.runtime", "←runtime rc={} stderr_len={}", rc, len(stderr))
        return rc, stderr
    finally:
        stderr_task.cancel()
        await _terminate(proc)


def _build_run_args(
    binary: Path,
    *,
    prompt: str,
    cwd: str,
    model: str | None,
    session_id: str | None,
) -> list[str]:
    args = [
        str(binary),
        "-p",
        "--force",
        "--trust",
        "--workspace",
        cwd,
        "--output-format",
        "stream-json",
        "--stream-partial-output",
    ]
    if model:
        args.extend(["--model", model])
    if session_id:
        args.extend(["--resume", session_id])
    args.append(prompt)
    return args


async def invoke(
    payload: Mapping[str, Any],
    on_progress: ProgressFn | None = None,
) -> dict[str, Any]:
    """One headless CLI run. Result shape matches the old runner terminal line."""
    cwd_raw = payload.get("cwd")
    if not cwd_raw or not str(cwd_raw).strip():
        cwd_raw = str(Path.home())
    cwd = _normalize_cwd(str(cwd_raw))
    context = payload.get("context") or []
    if not isinstance(context, list):
        context = []
    model = payload.get("model")
    model_str = str(model).strip() if model else ""
    fallback_message_id = str(payload.get("assistant_message_id") or _new_id())

    binary = resolve_agent_binary()
    if binary is None:
        return {
            "ok": False,
            "error": "Cursor CLI is not bundled",
            "error_kind": "startup",
            "mode": "miss",
        }
    try:
        binary = prepare_binary(binary)
    except OSError as exc:
        return {
            "ok": False,
            "error": f"Cursor CLI could not be prepared: {exc}",
            "error_kind": "startup",
            "mode": "miss",
        }

    store = get_session_store()
    request_nodes = prefix_nodes(context)
    parent_nodes = request_nodes[:-1]
    parent_fp = fingerprint_for(parent_nodes, cwd)
    entry = store.by_fingerprint.get(parent_fp)
    mode = "hit" if entry is not None else "miss"
    session_id = entry.session_id if entry is not None else None
    prompt = project_hit_delta(context) if mode == "hit" else project_miss_seed(context)

    assembler = StreamAssembler()

    async def on_event(event: Mapping[str, Any]) -> None:
        for part in assembler.feed(event):
            if on_progress is not None:
                await on_progress(part)

    hop(
        "py.runtime",
        "cursor invoke mode={} cwd={} model={} resume={}",
        mode,
        cwd,
        model_str or "-",
        session_id or "-",
    )

    async with workspace_lock(cwd):
        try:
            rc, stderr = await _run_cli(
                _build_run_args(
                    binary,
                    prompt=prompt,
                    cwd=cwd,
                    model=model_str or None,
                    session_id=session_id,
                ),
                cwd=cwd,
                env=subprocess_env(),
                on_event=on_event,
            )
        except Exception as exc:  # noqa: BLE001 — surface as a runner error
            if mode == "hit" and session_id:
                store.drop_session(session_id)
            return {
                "ok": False,
                "error": str(exc),
                "error_kind": "startup",
                "mode": mode,
                "agent_id": session_id,
            }

        for part in assembler.flush_text():
            if on_progress is not None:
                await on_progress(part)

        text = assembler.result_text
        if text is None:
            text = "".join(node["content"] for node in assembler.reply_nodes)
        combined_error = " ".join(bit for bit in (assembler.error, stderr.strip()) if bit)
        if looks_like_auth_failure(combined_error) or looks_like_auth_failure(text or ""):
            invalidate_auth_cache()
            if mode == "hit" and session_id:
                store.drop_session(session_id)
            return {
                "ok": False,
                "error": "Not authenticated",
                "error_kind": "auth",
                "mode": mode,
                "agent_id": session_id,
            }
        if assembler.error or rc != 0:
            if mode == "hit" and session_id:
                store.drop_session(session_id)
            return {
                "ok": False,
                "error": combined_error or f"cursor agent exited {rc}",
                "error_kind": "run",
                "mode": mode,
                "agent_id": assembler.session_id or session_id,
                "text": text or "",
            }
        if not (text or "").strip() and not assembler.reply_nodes:
            return {
                "ok": False,
                "error": "cursor run finished with no assistant text",
                "error_kind": "run",
                "mode": mode,
                "agent_id": assembler.session_id,
            }

        new_session = assembler.session_id or session_id
        reply_nodes = list(assembler.reply_nodes)
        if not reply_nodes and text:
            reply_nodes = [
                {
                    "id": fallback_message_id,
                    "role": "localBot",
                    "author_id": "cursor",
                    "content": text,
                }
            ]
        fingerprint = None
        if new_session:
            fingerprint = store.advance(
                session_id=new_session,
                cwd=cwd,
                request_nodes=request_nodes,
                reply_nodes=reply_nodes,
            )

        return {
            "ok": True,
            "status": "finished",
            "event": "done",
            "text": text or "",
            "usage": assembler.usage,
            "mode": mode,
            "agent_id": new_session,
            "run_id": new_session,
            "fingerprint": fingerprint,
            "assistant_message_id": (
                reply_nodes[-1]["id"] if reply_nodes else fallback_message_id
            ),
            "reply_message_ids": [node["id"] for node in reply_nodes],
        }


_auth_cache: dict[str, Any] | None = None
_auth_lock = asyncio.Lock()


def invalidate_auth_cache() -> None:
    global _auth_cache
    _auth_cache = None


def _api_key_configured() -> bool:
    return bool(os.environ.get("CURSOR_API_KEY", "").strip())


async def _status_uncached() -> dict[str, Any]:
    if _api_key_configured():
        return {"state": "authenticated"}
    binary = resolve_agent_binary()
    if binary is None:
        return {
            "state": "unavailable",
            "detail": "Cursor CLI is not bundled",
        }
    try:
        binary = prepare_binary(binary)
    except OSError as exc:
        return {"state": "unavailable", "detail": str(exc)}
    hop("py.runtime", "agent status bin={}", binary)
    proc = await asyncio.create_subprocess_exec(
        str(binary),
        "status",
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        env=subprocess_env(),
    )
    try:
        out, err = await asyncio.wait_for(proc.communicate(), timeout=STATUS_TIMEOUT_S)
    except asyncio.TimeoutError:
        await _terminate(proc)
        return {"state": "unauthenticated", "detail": "agent status timed out"}
    text = (out + b"\n" + err).decode("utf-8", "replace").strip()
    state = interpret_status(proc.returncode or 0, text)
    detail = None if state == "authenticated" else (text[-500:] or None)
    return {"state": state, "detail": detail}


async def status(*, refresh: bool = False) -> dict[str, Any]:
    global _auth_cache
    async with _auth_lock:
        if _auth_cache is not None and not refresh:
            return dict(_auth_cache)
        _auth_cache = await _status_uncached()
        return dict(_auth_cache)


def _store_auth(snap: dict[str, Any]) -> dict[str, Any]:
    global _auth_cache
    _auth_cache = snap
    return dict(snap)


async def begin_login() -> dict[str, Any]:
    """Run `agent login`. The CLI opens the system default browser."""
    if _api_key_configured():
        return _store_auth({"state": "authenticated"})

    binary = resolve_agent_binary()
    if binary is None:
        return _store_auth(
            {"state": "unavailable", "detail": "Cursor CLI is not bundled"}
        )
    try:
        binary = prepare_binary(binary)
    except OSError as exc:
        return _store_auth({"state": "unavailable", "detail": str(exc)})

    hop("py.runtime", "agent login bin={}", binary)
    proc = await asyncio.create_subprocess_exec(
        str(binary),
        "login",
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.STDOUT,
        env=subprocess_env(),
    )
    assert proc.stdout is not None
    lines: list[str] = []

    async def _read() -> None:
        while True:
            raw = await proc.stdout.readline()
            if not raw:
                return
            line = raw.decode("utf-8", "replace").strip()
            if line:
                lines.append(line)

    try:
        await asyncio.wait_for(_read(), timeout=LOGIN_TIMEOUT_S)
        rc = await proc.wait()
    except asyncio.TimeoutError:
        await _terminate(proc)
        return _store_auth({"state": "unauthenticated", "detail": "Sign-in timed out"})

    invalidate_auth_cache()
    if rc != 0:
        detail = lines[-1] if lines else f"agent login exited {rc}"
        return _store_auth({"state": "unauthenticated", "detail": detail})
    return await status(refresh=True)
