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
