"""Unit tests for Cursor runner fingerprint / projection (no live API)."""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest

_RUNNER_PATH = (
    Path(__file__).resolve().parent / "runtimes" / "cursor" / "agent_runner.py"
)


def _load_runner():
    """Load agent_runner from the Cursor runtime path without installing it."""
    # Prefer the runtime venv's cursor_sdk if present; otherwise skip.
    venv_site = (
        Path(__file__).resolve().parent
        / "runtimes"
        / "cursor"
        / "venv"
        / "lib"
    )
    # Importing agent_runner requires cursor_sdk. Use runtime venv python via
    # path injection when site-packages exists.
    site_candidates = list(venv_site.glob("python*/site-packages"))
    if not site_candidates:
        pytest.skip("cursor runtime venv not installed")
    sys.path.insert(0, str(site_candidates[0]))
    try:
        spec = importlib.util.spec_from_file_location(
            "cursor_agent_runner", _RUNNER_PATH
        )
        assert spec and spec.loader
        mod = importlib.util.module_from_spec(spec)
        # Register before exec so dataclasses can resolve string annotations.
        sys.modules[spec.name] = mod
        spec.loader.exec_module(mod)
        return mod
    finally:
        sys.path.pop(0)


@pytest.fixture(scope="module")
def runner():
    return _load_runner()


def test_fingerprint_stable(runner):
    nodes = [
        {"id": "a", "role": "user", "author_id": "", "content": "hi"},
        {"id": "b", "role": "localBot", "author_id": "cursor", "content": "yo"},
    ]
    fp1 = runner.fingerprint_for(nodes, "/tmp/proj")
    fp2 = runner.fingerprint_for(nodes, "/tmp/proj")
    assert fp1 == fp2
    assert fp1 != runner.fingerprint_for(nodes, "/tmp/other")


def test_fingerprint_changes_when_prefix_mutates(runner):
    a = [{"id": "a", "role": "user", "author_id": "", "content": "hi"}]
    b = [{"id": "a", "role": "user", "author_id": "", "content": "hi!"}]
    assert runner.fingerprint_for(a, "/tmp/p") != runner.fingerprint_for(b, "/tmp/p")


def test_hit_delta_is_last_node_only(runner):
    ctx = [
        {"id": "a", "role": "user", "content": "one"},
        {"id": "b", "role": "localBot", "author_id": "cursor", "content": "two"},
        {"id": "c", "role": "user", "content": "three"},
    ]
    assert runner.project_hit_delta(ctx) == "three"


def test_miss_seed_concatenates(runner):
    ctx = [
        {"id": "a", "role": "user", "author_id": "", "content": "one"},
        {"id": "b", "role": "localBot", "author_id": "cursor", "content": "two"},
    ]
    seed = runner.project_miss_seed(ctx)
    assert "[user]" in seed and "one" in seed
    assert "[localBot/cursor]" in seed and "two" in seed


def test_advance_only_current_prefix_hits(runner):
    state = runner.RunnerState()
    cwd = "/tmp/proj"
    nodes = [{"id": "u1", "role": "user", "author_id": "", "content": "hi"}]
    fp = state.advance(
        agent_id="agent-1",
        cwd=cwd,
        request_nodes=nodes,
        assistant_message_id="bot-1",
        assistant_text="hello",
    )
    last = state.by_fingerprint[fp].last_known_prefix
    assert runner.fingerprint_for(last, cwd) == fp
    # Parent of next turn (= last_known) hits.
    assert fp in state.by_fingerprint
    # Historical request-only prefix must not remain keyed.
    assert runner.fingerprint_for(nodes, cwd) not in state.by_fingerprint

    # Second advance replaces prior key for same agent.
    nodes2 = [
        *last,
        {"id": "u2", "role": "user", "author_id": "", "content": "again"},
    ]
    fp2 = state.advance(
        agent_id="agent-1",
        cwd=cwd,
        request_nodes=nodes2,
        assistant_message_id="bot-2",
        assistant_text="ok",
    )
    assert fp not in state.by_fingerprint
    assert fp2 in state.by_fingerprint


def test_advance_with_reply_nodes(runner):
    state = runner.RunnerState()
    cwd = "/tmp/proj"
    nodes = [{"id": "u1", "role": "user", "author_id": "", "content": "hi"}]
    reply = [
        {
            "id": "a1",
            "role": "localBot",
            "author_id": "cursor",
            "content": "first",
        },
        {
            "id": "a2",
            "role": "localBot",
            "author_id": "cursor",
            "content": "second",
        },
    ]
    fp = state.advance(
        agent_id="agent-1",
        cwd=cwd,
        request_nodes=nodes,
        reply_nodes=reply,
    )
    last = state.by_fingerprint[fp].last_known_prefix
    assert [n["id"] for n in last] == ["u1", "a1", "a2"]
    # Side-fork nodes are not in last_known — only reply branch.
    assert all(n["role"] == "localBot" or n["id"] == "u1" for n in last)


def test_conversation_step_to_parts_completed_granularity(runner):
    class ThinkingMsg:
        text = "full reasoning about the task"

    class ThinkingStep:
        type = "thinkingMessage"
        message = ThinkingMsg()

    class AsstMsg:
        text = "Here is the complete reply."

    class AsstStep:
        type = "assistantMessage"
        message = AsstMsg()

    class ToolStep:
        type = "toolCall"
        message = {
            "type": "read",
            "args": {"path": "a.py"},
            "result": "print(1)\n",
            "callId": "c1",
        }

    think = runner.conversation_step_to_parts(ThinkingStep())
    assert len(think) == 1
    assert think[0]["kind"] == "thinking"
    assert think[0]["content"] == "full reasoning about the task"

    asst = runner.conversation_step_to_parts(AsstStep())
    assert len(asst) == 1
    assert asst[0]["kind"] == "localBot"
    assert asst[0]["branch"] == "reply"
    assert asst[0]["content"] == "Here is the complete reply."

    tools = runner.conversation_step_to_parts(ToolStep())
    assert len(tools) == 2
    assert tools[0]["kind"] == "functionCall"
    assert tools[0]["tool_name"] == "read"
    assert "**read**" in tools[0]["content"]
    assert "```json" in tools[0]["content"]
    assert '"path"' in tools[0]["content"]
    assert tools[1]["kind"] == "functionResult"
    assert "```" in tools[1]["content"]
    assert "print(1)" in tools[1]["content"]


def test_format_function_call_markdown(runner):
    text = runner._format_function_call("grep", {"pattern": "foo"})
    assert text.startswith("**grep**")
    assert "```json" in text
    assert '"pattern"' in text


def test_sdk_message_to_parts_thinking_tool_assistant(runner):
    class Thinking:
        type = "thinking"
        text = "reason"

    class ToolRunning:
        type = "tool_call"
        status = "running"
        name = "read"
        call_id = "c1"
        args = {"path": "a.py"}
        result = None

    class ToolDone:
        type = "tool_call"
        status = "completed"
        name = "read"
        call_id = "c1"
        args = None
        result = "ok"

    class TextBlock:
        type = "text"
        text = "hello"

    class MsgContent:
        content = [TextBlock()]

    class Assistant:
        type = "assistant"
        message = MsgContent()

    think = runner.sdk_message_to_parts(Thinking())
    assert len(think) == 1
    assert think[0]["kind"] == "thinking"
    assert think[0]["branch"] == "side"

    call = runner.sdk_message_to_parts(ToolRunning())
    assert call[0]["kind"] == "functionCall"
    assert call[0]["tool_name"] == "read"
    assert "**read**" in call[0]["content"]

    result = runner.sdk_message_to_parts(ToolDone())
    assert result[0]["kind"] == "functionResult"
    assert result[0]["is_error"] is False
    assert "```" in result[0]["content"]

    asst = runner.sdk_message_to_parts(Assistant())
    assert len(asst) == 1
    assert asst[0]["kind"] == "localBot"
    assert asst[0]["branch"] == "reply"
    assert asst[0]["content"] == "hello"


def test_usage_to_dict_maps_sdk_fields(runner):
    class U:
        input_tokens = 3
        output_tokens = 5
        cache_read_tokens = 1
        cache_write_tokens = 0
        total_tokens = 9
        reasoning_tokens = None

    d = runner.usage_to_dict(U())
    assert d["prompt_tokens"] == 3
    assert d["completion_tokens"] == 5
    assert d["input_tokens"] == 3
    assert d["total_tokens"] == 9
