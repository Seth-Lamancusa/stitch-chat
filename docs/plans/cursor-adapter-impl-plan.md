# Cursor adapter (local SDK) — implementation plan

## Context

Completions E2E and pre-flight for Cursor are done:

- Bridge dispatches by bot id (`adapters.ADAPTERS`); `@cursor` is registered.
- Column `cwd` is a tag on invoke; bots with `requires_cwd` get composer
  advisory + post-send fade, and the bridge returns `invoke_skipped` (not
  `error`) when cwd is missing.
- Invoke context is one Stitch message list with the trigger as the last node.
- `runtimes/cursor/` has an isolated venv + smoke test; the bridge stub does
  not import `cursor-sdk`.

This plan covers replacing the stub with a real local Cursor SDK adapter
without letting Cursor’s durable Agent shape Stitch or the bridge wire.

Canonical SDK reference: [Python SDK docs](https://cursor.com/docs/sdk/python)
and the Cursor `/sdk` skill. Pin a usage-capable `cursor-sdk` (≥ ~1.0.23 for
`result.usage`; current smoke pin `0.1.9` is too old).

## Goals (v1)

1. `@cursor` with column cwd set → local agent run → singular `localBot`
   reply under the trigger (same envelope shape as Completions).
2. Adapter-private affinity: fingerprint → opaque `agent_id`; Stitch has no
   Agent type.
3. Token usage on `message_end` when the runtime reports it (`result.usage`).
4. One-shot and durable are the same stack (`create`/`resume` + `send` +
   `wait`); throw the Run away when you don’t need the stream.

Non-goals for v1: multi-part tool/thinking messages, cloud runtime, MCP,
Gemini-style projectors, billed `get_usage()`, UI for active-context budgets.

## Locked decisions

| Topic | Decision |
|---|---|
| Runtime | Local only; always pass `LocalAgentOptions(cwd=...)`. |
| Invocation | Pattern 2: `AsyncAgent` create/resume + `send` + `wait`. Not `Agent.prompt` (no resume path). |
| Client | Async (`AsyncClient.launch_bridge` + `AsyncAgent`) — matches the asyncio bridge. |
| Affinity key | Exact match on each agent’s **current** last-known Stitch prefix **plus cwd**. Historical prefixes are not matched (forks must miss). |
| Prefix | Ordered Stitch context window as sent on the wire (ids + roles + content), excluding nothing after a successful turn that advanced the key. |
| Miss | `create` at cwd; first `send` seeds with full projected window (trigger last); store `agent_id` + last-known prefix. |
| Hit | `resume(agent_id)`; `send` only the **delta** (final user node / trigger text); advance last-known to the new full window after success. |
| Failure | Do not advance last-known on `CursorAgentError` or `result.status != "finished"`. |
| Fork | Reply higher in the tree → different prefix → miss → new agent. |
| Isolation | Real SDK code lives under `runtimes/cursor/` (own venv). Bridge process does not import `cursor-sdk`. |
| Wire | Unchanged singular-part path; bridge never sees `agent_id`. |
| Settings | Do not set `setting_sources` (inline only). |
| Concurrency | Serialize per `agent_id` (no concurrent `send` on the same handle). |

## Architecture

```
Dart  --user_message(context[], cwd)-->  bridge (server.py)
                                            |
                                            v
                                      adapters.cursor  (thin in-process shim)
                                            |
                                            v  NDJSON / subprocess
                                      runtimes/cursor/agent_runner.py
                                            |
                                            v
                                      cursor-sdk (AsyncClient + AsyncAgent)
```

- **Shim** (`python-server/cursor_adapter.py` or replace `cursor_stub.py`):
  same `handle(...)` signature as Completions; forwards invoke to the runner;
  maps runner result → `message_start` / `message_end` / `error`.
- **Runner**: owns fingerprint cache, create/resume/send/wait, projection,
  usage extraction, disposal of agent handles after each invoke (cache stores
  `agent_id` strings, not live handles).
- **Bridge workspace vs cwd**: local list/get/resume is workspace-scoped.
  Launch/attach the SDK bridge with workspace aligned to the column cwd (or
  equivalent so resume resolves). Do not default missing cwd to `"."`.

Exact IPC between shim and runner (stdio NDJSON vs long-lived sidecar) can
follow the reusable `SubprocessSdkHandler` shape from
`docs/plans/dart-python-interface.md`, scoped to Cursor first — no need to
generalize for Claude/Codex in this plan.

## Fingerprint and projection

**Fingerprint input:** canonical serialization of the context window nodes
that define the agent’s last-known Stitch prefix, plus normalized cwd.
Suggested: hash of JSON list `[{id, role, author_id, content}, ...]` + cwd
string. Only the adapter reads this.

**Projection (adapter-local):** Stitch nodes → one user prompt string for
miss-seed (concatenate or structured text; keep multi-author on Stitch nodes,
no Gemini alternation). Hit path: prompt = last node’s content only (the
trigger).

**Cache entry:** `{ fingerprint, agent_id, last_known_prefix, cwd }`.
In-memory for first slice is acceptable; persistence across bridge restart is
a follow-up (without it, affinity cold-starts and orphans local agents on
disk). Call that out in code comments so we don’t pretend resume works across
process death until the map is durable.

## Failure mapping

| SDK outcome | Bridge envelope |
|---|---|
| Missing cwd | Already: `invoke_skipped` / `requires_cwd` (no adapter). |
| `CursorAgentError` (never started) | `error` with message; retryable flagged in logs only for v1. |
| `result.status == "error"` / cancelled | `error` (run executed but failed); do not advance fingerprint. |
| `result.status == "finished"` | `message_start` + `message_end` with text + optional `usage`. |

Do not surface skips or affinity misses as Dart toast errors; composer cwd UX
already covers the cwd case.

## Usage wire shape

Prefer aligning Completions-era `usage` on `message_end` with a small
superset so Dart can ignore unknown fields:

```json
{
  "prompt_tokens": ...,
  "completion_tokens": ...,
  "total_tokens": ...,
  "input_tokens": ...,
  "output_tokens": ...,
  "cache_read_tokens": ...,
  "cache_write_tokens": ...
}
```

Map from SDK `TokenUsage` (`input_tokens`, `output_tokens`, etc.). Persist /
column budgets are out of scope for this plan (wire + log first).

## Implementation slices

### 1. Runner foundation

- Bump `runtimes/cursor/requirements.txt` to a usage-capable SDK; refresh venv.
- Extend smoke test: create → send → wait → print `result.usage` / text;
  explicit `LocalAgentOptions(cwd=...)`.
- Add `agent_runner.py` entrypoint: one invoke JSON in → result JSON out
  (status, text, usage, error) for the miss path only (always create), no
  cache yet.

### 2. Wire shim through the bridge

- Replace `cursor_stub.handle` with shim that spawns/calls the runner.
- End-to-end: set column cwd, `@cursor` hello → `localBot` under trigger.
- Confirm Completions path unchanged; cwd skip path unchanged.

### 3. Affinity cache

- Implement fingerprint + last-known prefix store (in-memory).
- Miss vs hit behavior as locked above.
- Serialize per `agent_id`.
- Advance last-known only after successful `finished` + shim emitted
  `message_end` (or runner success before emit — pick one place and document).
- Tests: same prefix+cwd → same agent_id; mutated prefix → new agent;
  failure does not advance; fork prefix → new agent.

### 4. Usage + hardening

- Attach usage on `message_end`.
- Distinguish startup vs run failure in logs (`agent_id` / `run.id` on send).
- Dispose agent handles after each invoke; keep process-level
  `AsyncClient` lifecycle clear (per-cwd client vs single client — decide in
  slice 1 based on SDK workspace rules).

### 5. Follow-ups (separate plans)

- Persist fingerprint → `agent_id` map across bridge restarts.
- Multi-part tool/thinking emissions.
- Model/version from `@cursor:…` tags.
- Column/active-context token UI.

## Test plan

- Unit: fingerprint stability; miss/hit/fork; no advance on error.
- Integration (CURSOR_API_KEY): runner miss-seed; hit delta; usage present when
  runtime reports it.
- App E2E: cwd advisory → set cwd → `@cursor` reply persists; without cwd,
  trigger persists, skip banner, no error toast.
- Regression: `@chatgpt` still works with no cwd.

## Open points (decide in slice 1)

1. **Long-lived vs per-invoke SDK bridge process** — sidecar with
   `connect(base_url)` vs `launch_bridge` per invoke. Prefer long-lived if
   resume/workspace state is happier; measure startup cost.
2. **Miss-seed prompt format** — single blob vs multiple `send`s before the
   trigger. Prefer single blob for v1.
3. **Cache persistence format/location** — defer; if needed soon, store under
   app support dir keyed by cwd, not in Drift (affinity stays adapter-private).
