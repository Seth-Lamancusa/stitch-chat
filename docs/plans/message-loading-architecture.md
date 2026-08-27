# Message loading architecture: MessageStore, windowing, and bootstrap

> **Superseded by `message-loading-plan.md`.** Kept for history of how the
> `MessageStore`/edge-id-split idea emerged; the consolidated doc is current.

## Context

`column-ui-impl-plan.md` §1 already designed windowed loading in real detail —
`BranchWindow`, `loadInitialWindow`/`extendAbove`/`extendBelow`/
`revealStitchAbove`/`revealStitchBelow`, `kDefaultRadius`/`kDefaultBatch` — none
of it built yet (`BranchPathService.getFullVisibleBranch` still resolves a
whole branch in one un-windowed walk, per `docs/column-ui-architecture.md`).
That plan assumed `ColumnsViewModel` would own a single `Map<String, Message>`
cache (§1b) populated as messages are "loaded/persisted," with no further
distinction drawn between *knowing a neighbor exists* and *having fetched its
content*.

That gap surfaced concretely: when a column's `IncomingNavigator` switches to a
message already visible in a *different* column (reached there via an
independent stitch edge), nothing should have to re-fetch or re-prompt for it —
it's already known. Chasing that down raised the real question underneath: our
schema keeps reply/stitch adjacency in separate edge tables, with no adjacency
fields on `Message` itself. stitch-frontend gets "cheap sibling knowledge
without fetching sibling content" for free, because its Vuex store denormalizes
`child_ids`/`stitch_child_ids` onto the message row — reading a sibling pool's
size never costs a fetch beyond the parent you already have. Our shape doesn't
get that for free and needs a deliberate interface split to earn it, since a
real remote backend later (`StitchApiMessageRepository`, currently an
unimplemented stub) will make "fetch full content for every sibling just to
know the count" a genuine network cost per candidate, not a free join.

This doc:
- **Introduces `MessageStore`**, a new layer between `MessageRepository` (the
  swappable backend) and `BranchPathService`/`ColumnsViewModel`, that didn't
  exist in either prior plan.
- **Splits `MessageRepository`** into cheap edge/id queries and separate
  content hydration, retiring `getAncestorPath`.
- **Supersedes `column-ui-impl-plan.md` §1b** (shared cache ownership moves
  from `ColumnsViewModel` to `MessageStore`) and refines §1/§1a's windowing
  mechanics to route through it. §2 (ancestor-switching), §4–5 (exclusivity
  rule), and §6 (marker state table) are unaffected in shape — the marker's
  stitch-count computation now just resolves through `MessageStore` instead of
  raw repository calls.
- **Adds bootstrap/root-listing scope** neither prior doc addresses — how the
  app behaves with zero columns and how a user finds an existing thread to
  open, given `column-ui-impl-plan.md` §3 only covers "an anchor-less column
  becomes rooted on its first send," not "browse and open an existing one."
- **Retires `dev_seed.dart`'s column-wiring**, which post-dates both prior
  plan docs and isn't part of either's scope.

## 1. `MessageRepository`: split cheap edges from expensive content

Current interface (`lib/data/repositories/message_repository.dart`) returns
fully-hydrated `Message` lists for edge queries — `OutgoingEdges`/
`IncomingEdges` each embed full `Message` objects, and `getAncestorPath`
returns the whole hydrated ancestor chain. That's free today (local SQLite,
always-cheap joins) but doesn't generalize: under a remote backend, computing
a navigator's pool size would mean fetching full content for every candidate,
not just their ids.

New shape:

```dart
class OutgoingEdgeIds {
  final List<String> replyOutgoingIds;    // ordered oldest -> newest
  final List<String> stitchedOutgoingIds; // ordered oldest -> newest
}
class IncomingEdgeIds {
  final List<String> replyIncomingIds;
  final List<String> stitchedIncomingIds;
}

Future<OutgoingEdgeIds> getOutgoingIds(String parentId);
Future<IncomingEdgeIds> getIncomingIds(String childId);

Future<Message?> getMessage(String id);           // unchanged
Future<List<Message>> getMessages(Iterable<String> ids); // new, batched hydration
```

Ordering moves into the query itself (`ORDER BY created_at`), so
`BranchPathService._mostRecentOf` — which today hydrates every candidate just
to compare `createdAt` — goes away entirely. "Pick the default" becomes "take
the last id in the appropriate list."

**`getAncestorPath` is retired, not replaced 1:1.** Its only real caller
(`_visibleOrStructuralIncoming`) fetches the *whole* ancestor chain just to
read one element off the end — the immediate reply parent. Since a message has
exactly one reply parent today, that's exactly
`getIncomingIds(childId).replyIncomingIds.firstOrNull` — the same primitive
every other single-hop lookup already uses. One less method, fully symmetric
with the outgoing side. (Current callers to update:
`branch_path_service.dart:156`; current coverage in
`drift_message_repository_test.dart:82,94` moves to whatever test covers
`getIncomingIds`.)

`getRootMessages` is a new, unrelated addition — see §4.

## 2. `MessageStore`: the loaded set, unifying "known" and "shown"

```dart
class LoadedMessage {
  final Message message;
  final OutgoingEdgeIds outgoing;
  final IncomingEdgeIds incoming;
}

class MessageStore {
  // The one loading primitive. BranchPathService/ColumnsViewModel never call
  // MessageRepository.getMessage/getOutgoingIds/getIncomingIds directly.
  Future<LoadedMessage> load(String id) async {
    final message = await _repo.getMessage(id);
    final outgoing = await _repo.getOutgoingIds(id);
    final incoming = await _repo.getIncomingIds(id);
    final loaded = LoadedMessage(message: message!, outgoing: outgoing, incoming: incoming);
    _cache[id] = loaded;
    await _markLoaded(id);   // persisted, local-only bookkeeping — see below
    return loaded;
  }

  LoadedMessage? peek(String id) => _cache[id];  // sync, no fetch
  bool isLoaded(String id) => ...;                // persisted-set membership
}
```

**One membership concept, not two.** A message only ever enters the loaded set
by being pulled into some column's window via `load()` — and per
`column-ui-impl-plan.md`'s own invariant ("a message is never partially
loaded" — both edge directions get queried for every windowed message), that
always resolves content and both edge-id pools together. So "is this id's
content hydrated" and "are this id's edges known" are the same fact, checked
and set in exactly one place. That single persisted fact is what both the
navigator-pool code and the stitch-auto-render check (§3) query.

**The loaded-set table is local bookkeeping, not part of the swappable
backend.** `LoadedMessages(messageId TEXT PRIMARY KEY REFERENCES Messages(id))`
lives in `MessageStore`'s own small repo/table, *not* on the
`MessageRepository` interface. `MessageRepository` is what gets swapped for a
cloud implementation later; "what has this client already pulled down" is
inherently local client state regardless of which backend is active behind it.
`MessageStore.load`/`isLoaded` behave identically whether `_repo` is
`DriftMessageRepository` or a future `StitchApiMessageRepository` — only the
cost of the underlying calls changes.

`MessageRowData` and the navigator widgets read `LoadedMessage` directly
(content + both edge-id pools together) instead of holding separate
`OutgoingEdges`/`IncomingEdges` objects — this is the concrete sense in which
"the UI layer sees roughly what Vue sees": a fully resolved unit per message,
never a partial one.

## 3. Windowing, reconciled with `MessageStore` (supersedes §1b)

`BranchWindow.messageIds` indexes into `MessageStore`'s cache instead of a
`ColumnsViewModel`-local `Map<String, Message>` — that cache doesn't need to
exist separately anymore, `MessageStore` *is* it. `ColumnsViewModel`/
`BranchPathService` hold no message content at all now, just:

```dart
class BranchWindow {
  final List<String> messageIds;   // ordered root-old -> leaf-new
  final bool hasMoreAbove;
  final bool hasMoreBelow;
  final int stitchAboveCount;      // genuinely unloaded stitch candidates only
  final int stitchBelowCount;
}
```

**One walk-one-hop helper, shared by every caller that steps the chain.**
`loadInitialWindow`, `extendAbove`/`extendBelow`, the reply-only default
descent (§1a of the impl plan), and `revealStitchAbove`/`revealStitchBelow`
all reduce to the same primitive: given the current boundary id, find the next
reply candidate (cheap, ordered, last = default); if there isn't one, look at
the *first* stitch candidate. If `MessageStore.isLoaded` says that candidate is
already loaded, step through it silently (`MessageStore.load` is a cache hit,
no-op cost) and keep walking — this is what makes an already-loaded stitch
auto-render without a click, with no separate code path from ordinary
extension. If it isn't loaded, stop and report the count; that's what
`AdaptiveMarker` renders as "Load stitches (N)." `revealStitchAbove/Below` (the
manual click) is then just "force one hop through the first stitch candidate
regardless of loaded state, then resume the normal walk" — unchanged from the
original plan's description, just now expressed as a special-case invocation
of the same shared helper instead of its own logic.

`kDefaultRadius`/`kDefaultBatch` are unchanged in spirit — still sequential
one-hop-at-a-time queries per step, still bounded per call. (The original
plan's note about batching multiple hops into a single `IN (...)` join as a
future, non-blocking optimization still applies here.)

## 4. Bootstrap: empty columns + root listing

`column-ui-impl-plan.md` §3 already covers the empty-column half: nullable
`Columns.anchorMessageId`, `loadInitialWindow` returning an empty window for a
null anchor, an anchor-less column rendering with nothing until its first
send. What it doesn't cover: **finding an existing thread to open** — right
now the only documented path into content is sending a fresh message.

New, minimal addition, mirroring stitch-frontend's flat paginated
`history`/`inbox` list (which returns full summary content directly, not just
ids — the page is small and bounded by construction, so there's no
transitive-fetch risk to guard against the way there is for tree edges):

```dart
Future<List<Message>> getRootMessages({required int skip, required int limit});
```

Roots = messages with no reply parent, ordered by the root's own `createdAt`
descending — no denormalized "last activity in thread" tracking, no write-time
bookkeeping. A "Load thread" UI lists these; selecting one calls
`MessageStore.load` on it and creates a column anchored there via the
already-planned nullable-anchor path.

## 5. Dev seed becomes plain example data

`dev_seed.dart` currently does two unrelated things: inserts a deliberately
curated message/edge graph, *and* wires up three specific columns anchored to
specific messages to showcase specific navigator/marker states. The column
half is retired entirely — with bootstrap now being "start empty, `Load
thread` to open one" (§4), there's no reason for startup to ever pre-create
columns, seeded data or not.

What's left is just: a few example messages and edges already sitting in the
database, indistinguishable from anything a real conversation would produce —
ordinary reply chains, occasionally a stitch edge, no structure curated to
hit every UI state on purpose. Exercising specific navigator/marker states
(the 3-way fork, the reply+2-stitch-parent case, etc.) is a job for the
existing test suite (`branch_path_service_test.dart`'s fixture-based cases,
and the widget tests `column-ui-impl-plan.md`'s verification section already
calls for), not for what happens to be sitting in the dev database.

## Open follow-ups

- `LoadedMessages` needs a schema/migration bump alongside the edge-id query
  changes — sequencing these as one migration vs. separate ones is an
  implementation-time call, not an architectural one.
- Confirm no other caller of the current hydrated `OutgoingEdges`/
  `IncomingEdges`/`getAncestorPath` shapes exists beyond what's cited above
  before removing them (widgets, other tests) — expected to be exhaustive per
  the greps run for this doc, worth re-checking at implementation time.
- Batching multiple hop queries into a single `IN (...)` join (carried over
  from the original plan, still non-blocking).

## Explicitly out of scope (inherited, unchanged)

- Actually implementing `StitchApiMessageRepository` — this doc only firms up
  the interface seam it'll sit behind.
- Full graph canvas, multi-parent reply edges — same as
  `column-ui-impl-plan.md`'s existing out-of-scope list.
