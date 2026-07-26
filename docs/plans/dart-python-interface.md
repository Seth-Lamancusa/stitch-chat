# Generalize the Dart <-> Python bot protocol — high-level outline

## Context

The README describes a universal bot contract (multi-part responses chained by
parent id, function calls/results as messages, model/cwd specification,
dispatch via a `RuntimeRegistry` of `BotConfig`s across API/SDK handler
regimes). Today only a single hardcoded path exists: one non-threaded OpenAI
call, `bot_id` ignored, and a WS envelope shape that supports exactly one
streaming text message per turn. This outline breaks the gap into components,
each of which gets its own focused plan before implementation.

Research already done (to inform those later plans, not re-litigate now):
every SDK's real streaming is at the block/item level, not tokens — Claude
Agent SDK yields whole content blocks (text/tool_use, tool_results come back
as a `UserMessage`), Cursor emits assistant/tool_call(running→completed)/
thinking events, Codex yields `item.completed`/`turn.completed`. None of this
is unified today; `PersistedMessage` (roles: user/bot/function_call/
function_result) already anticipates the shape the *live* WS protocol
(`ChatMessage`/`ChatEvent`) doesn't yet have.

Constraint that shapes the SDK-handler component: each SDK lives in its own
venv (`runtimes/{sdk}/venv`), isolated from the main server's venv per the
README's dependency-isolation guidance — so SDK handlers can't just import
their SDK into the main process; they need a subprocess bridge. Evaluated and
confirmed as the right call (not "just use one venv"): these SDKs pin
independent, vendor-specific client/HTTP dependency versions on different
release cadences, so a shared venv risks an unresolvable dependency set (or a
resolvable-today set one upgrade away from breaking silently). The four
`runtimes/*/venv` directories already exist on this basis. The subprocess
bridge cost is bounded to one reusable class and buys crash isolation for a
long-running desktop process — worth keeping.

## Components (each → its own plan before implementation)

1. **WS envelope protocol generalization** (`python-server/protocol.py` +
   `server.py`) — extend the envelope shape so a turn is N chained messages
   (parts) instead of one: a `role` on `message_start` (`bot` /
   `function_call` / `function_result`), tool metadata (`tool_name`,
   `tool_call_id`), `is_error` on completion, and a `manifest` envelope for
   available bots. Chaining reuses the existing `parent_message_id` field —
   no structurally new concept, just consistent multi-message use of it.

2. **BotConfig / RuntimeRegistry / BotHandler abstraction** (new
   `python-server/bot_config.py`, `registry.py`) — the dispatch layer the
   README describes but doesn't exist yet. Hardcoded bot list for now (no
   config persistence). Replaces `server.py`'s hardcoded call into
   `openai_handler`.

3. **Handler implementations**:
   - Migrate today's OpenAI hello-world into `OpenAICompatibleHandler`
     conforming to the new `BotHandler` interface — reference case for
     "singular part" (one message per turn, no chained parts). Uses the
     Responses API (`client.responses.create`), not Chat Completions:
     decided against token-delta reveal (UI shows a typing indicator
     instead), and Chat Completions has no clean per-part completion
     boundary for multi-item turns, while the Responses API's
     `response.output_item.done` event fires per output item as it
     finishes — the same granularity the multi-part protocol needs, so
     this handler is already shaped for it even though today it only ever
     emits one item. `protocol.CONTENT_DELTA`/`content_delta` no longer
     exist — removed along with the Dart `ContentDeltaReceived` event when
     this handler stopped emitting deltas.
   - Generic `SubprocessSdkHandler` bridge (spawn `runtimes/{sdk}/venv/bin/
     python agent_runner.py`, NDJSON stdin/stdout, translate to WS envelopes)
     — reusable across all four SDK-regime bots.
   - One SDK fully wired through it as proof (Claude Code — best documented),
     covering multi-part text + function call/result end-to-end. Other three
     stay interface-conforming stubs that answer "not yet implemented."

4. **Dart message model/viewmodel updates** (`chat_message.dart`,
   `persisted_message.dart`, `chat_repository(_impl).dart`,
   `chat_viewmodel.dart`, `chat_view.dart`) — carry the new role/tool fields
   through `ChatEvent`/`Message`, minimal view styling per role.

   **Decision: unify `ChatMessage`/`PersistedMessage` into one `Message`
   model** rather than keep them split. The original rationale for splitting
   them (different mutable-streaming-vs-durable lifecycle) is weaker than it
   looked: per the README, streaming is at content-part granularity, not
   tokens held open indefinitely — a "live" message is just a normal message
   that hasn't been written to storage yet, not a fundamentally different
   entity. The two structs already duplicate `id`/`parentId`/`role`/`content`,
   the role enum is informally defined in both places, and no code today
   actually bridges a completed `ChatMessage` into a `PersistedMessage` — that
   translation layer doesn't exist yet, so nothing is currently being kept in
   sync by having two types. Matches the README's own framing of the message
   as *the* fundamental data model, singular. Accepted cost: the type system
   no longer prevents "impossible" states (e.g. reading `isStreaming` off a
   row loaded from SQLite) — that becomes a discipline/assert concern instead
   of a compile-time one. Worth it at this app's current size; revisit if the
   model accretes enough persisted-only/live-only fields that the nullability
   gets unwieldy.

   The unified model's exact shape is now settled in
   `docs/plans/message-tree-data-model.md` §2, which supersedes the field
   list originally sketched here: `id`/`role`/`content` required, plus
   `authorId` (identity — bot_id or future human user_id — separate from
   `role`, which is message *kind*); `gitCommit`/`createdAt` nullable (unset
   until persisted); `isStreaming` transient. Notably there is **no
   `parentId` and no `conversationId` on the message**: thread topology
   lives exclusively in separate edge tables (`ReplyEdge`, `StitchEdge`),
   with reverse adjacency derived by query, and "conversation" is emergent
   from edges rather than a stored foreign key. The WS envelope's
   `parent_message_id` field (component 1) is unaffected — it's wire-level
   addressing; on the Dart side the repository translates it into a
   `ReplyEdge` row at persist time instead of a field on `Message`.

5. **Persistence** (out of scope until its own plan) — `MessageStoreRepository`
   is already stubbed pending this, and now targets the unified `Message`
   model from component 4 rather than `PersistedMessage`. The direction
   question is now decided in `docs/plans/message-tree-data-model.md`
   §1/§6: SQLite (drift) as the authoritative store for messages, edges,
   and column layout (stitch_desktop has no backend, so the local store is
   the source of truth — unlike stitch-flutter's JSON files mirroring a
   remote ArangoDB), plus a one-way SQLite → JSON filesystem mirror of chat
   logs for end-user readability/copyability — an export artifact, never
   read back by the app. Tool outputs are ordinary messages in the chat
   log; no separate blob storage planned. Schema and repository details
   belong to that plan's component 1.

## Suggested sequencing

1 → 2 → 3 (protocol before registry before handlers, since handlers are
written against both). 4 can follow 1 in parallel with 2/3 since Dart only
needs the envelope shape, not the Python-side dispatch internals. 5 is
independent and can start anytime, but nothing in 1-4 should block on it —
`ChatViewModel` keeps holding in-memory-only state until 5 lands.

## Next step

Write a focused implementation plan for component 1 (protocol) first, since
2-4 depend on its shape being settled.
