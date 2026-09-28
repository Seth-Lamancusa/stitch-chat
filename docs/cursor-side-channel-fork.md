# Cursor side-channel fork (as-built)

Documents the implemented multi-part `@cursor` reply shape: thinking and tool
events on a **side fork** under the trigger, assistant text on a sibling
**reply branch**. Forward-looking history lives in
`docs/plans/cursor-adapter-impl-plan.md` (v1 was singular-part; this supersedes
that non-goal). Wire generalization context:
`docs/plans/dart-python-interface.md`.

Canonical SDK reference: [Cursor Python SDK](https://cursor.com/docs/sdk/python)
(`SendOptions.on_step`, conversation steps).

## Target tree

For one `@cursor` invoke on trigger `T`:

```
T  (user trigger)
├── S1  thinking | functionCall | functionResult   ← side fork (T→S1 hidden)
│   └── S2 …
│       └── Sn
└── A1  localBot (assistant text)                  ← reply branch
    └── A2 …
        └── An  (is_final + usage)
```

- First side part parents to `T` with **`hidden: true`** on `message_end`
  (persisted on the reply edge). Later side parts chain under that fork with
  normal (non-hidden) reply edges so one reveal shows the whole branch.
- Default path walks skip the hidden hop: while only the side fork exists,
  the column shows AdaptiveMarker **Reveal hidden thread**; once `A1`
  arrives it auto-fills the slot; sibling nav can still open the side fork.
- First assistant text parents to `T` (sibling of the side-fork root); later
  assistant texts chain on the reply branch.
- Last reply-branch `message_end` carries `is_final: true` and `usage` when
  present. No duplicate bubble from `result.result` when assistant steps were
  already streamed; fallback single `localBot` under `T` only if the run
  finishes with text and zero assistant steps.

## Pipeline

```
Dart BotBridgeService / ColumnsViewModel
        │  user_message (trigger = T, context[])
        ▼
python-server cursor_adapter (shim)
        │  one `agent_runner --once` subprocess per invoke (parallel-safe)
        │  NDJSON on stdout: progress lines + terminal done
        ▼
runtimes/cursor/agent_runner.py
        │  AsyncAgent.send(SendOptions(on_step=…)) + wait()
        ▼
cursor-sdk  completed ConversationSteps
```

### Granularity (important)

Emit Stitch parts from **`on_step`**, not from `run.messages()`.

`run.messages()` can yield thinking / assistant text in sub-step chunks (many
tiny Stitch nodes). `SendOptions.on_step` fires once per **completed**
conversation step: `thinkingMessage`, `assistantMessage`, or `toolCall`
(tool batch). That is the partition we map to messages.

| Step type | Stitch role(s) | Branch |
|---|---|---|
| `thinkingMessage` | `thinking` | side |
| `toolCall` | `functionCall` then `functionResult` | side |
| `assistantMessage` | `localBot` | reply |

Tool call/result content is markdown: bold tool name + fenced `json` args;
results in fenced blocks (plain fence for string bodies).

## Wire fields

Envelope types unchanged (`message_start` / `message_end` / `error`). Optional
fields used by this path (documented in `python-server/protocol.py`):

| Field | Meaning |
|---|---|
| `role` | `thinking` \| `functionCall` \| `functionResult` \| `localBot` |
| `invoke_root_id` | Always `T` — correlate multi-part turns when `parent_message_id` is a prior part |
| `is_final` | `true` on the last reply-branch `message_end` (completes the Dart invoke) |
| `hidden` | `true` on the first side-fork `message_end` only (`parent == T`) |
| `tool_name` / `tool_call_id` / `is_error` | Tool metadata on function parts |
| `usage` | Attached on the final reply `message_end` when the runtime reports it |

ChatGPT stays singular-part but sets `is_final: true`. Dart treats a missing
`is_final` as final (legacy).

## Shim chaining (`cursor_adapter.py`)

- `invoke_root_id = T` on every envelope.
- Two parents, both start at `T`: `side_parent`, `reply_parent`.
- **Side:** `message_start` + `message_end` immediately; advance `side_parent`.
- **Reply:** `message_start` immediately; **buffer** `message_end`. A newer
  reply part flushes the prior end (not final). On terminal success, flush the
  buffered end with `is_final` + `usage`, or emit the fallback `localBot`.

Runner IPC: multiple NDJSON lines per request `id` —
`{"event":"progress","part":{…}}` then a terminal `ok` / error record.

## Dart bridge + column

- `BotBridgeService` keys pending invokes by `invoke_root_id ?? parent_message_id`.
- Each non-final `message_end` → `onPart`; Future completes only on `is_final`
  / skip / error.
- Part delivery is **serialized** per invoke (`deliverChain`) so concurrent
  persists cannot race column anchors.
- `ColumnsViewModel` persists each part with `parent_message_id`, role, and
  `hidden` on the reply edge when set.
- **Visible path / anchor:**
  - Hidden first hop is never auto-followed; AdaptiveMarker offers reveal
    until a non-hidden reply child exists under `T`.
  - Once a reply-branch root exists it occupies the slot; sibling nav can
    cross the hidden edge into the side fork. Later side parts update the
    tree but do not steal the scroll center onto a node off the visible
    branch.
- `MessageRole.thinking` + THINKING chip in `MessageCard` (same pattern as
  function call/result).

## Affinity (runner-private)

`last_known_prefix` = request context nodes + **reply-branch** `localBot`
nodes only (ids/content as on the wire). Side-fork nodes are siblings under
`T` and are not on the default visible path after the reply is selected, so
they are omitted from the fingerprint. Miss/hit/fork rules otherwise match
the original Cursor adapter plan.

## Key files

| Layer | Path |
|---|---|
| Runner | `python-server/runtimes/cursor/agent_runner.py` |
| Shim | `python-server/cursor_adapter.py` |
| Protocol notes | `python-server/protocol.py` |
| Bridge | `lib/data/services/bot_bridge_service.dart` |
| Persist / pointers | `lib/ui/columns/columns_viewmodel.dart` |
| Role + UI | `lib/data/models/message.dart`, `lib/ui/core/message_card.dart` |
| Tests | `python-server/test_cursor_runner.py`, `python-server/test_adapters.py`, `test/data/services/bot_bridge_service_test.dart` |

## Out of scope (still)

- Token-level deltas (`on_delta`)
- ChatGPT multi-part
- Cue-channel (non-persisted) thinking
- Upstream SDK gaps (e.g. missing `tool_call` error completions on the message stream — we rely on completed `on_step` tool batches instead)
