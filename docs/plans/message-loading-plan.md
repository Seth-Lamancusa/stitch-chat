# Message loading: consolidated plan

**Supersedes:** `column-ui-impl-plan.md` §1/§1a/§1b, `message-loading-architecture.md`
§2–§3, `materialized-vs-default-trajectory.md` in full. Those three docs designed
this feature in three passes, each refining and partly renaming the last, and
ended up naming more concepts than the design actually has. This doc is the
single current source of truth for message loading. Everything below is
**unbuilt** — today `BranchPathService.getFullVisibleBranch` still resolves a
whole branch in one un-windowed walk (`lib/domain/branch_path_service.dart:21-44`),
and `ColumnsViewModel._refresh` calls it unconditionally
(`lib/ui/columns/columns_viewmodel.dart:227`).

## Why a rewrite instead of a fourth patch

Across the three prior docs, the following names were introduced for what
turns out to be one mechanism, called with different arguments:
`loadInitialWindow`, `extendAbove`/`extendBelow`, the "reply-only default
descent," the unnamed "one walk-one-hop helper," and (separately)
`_visibleOrDefaultOutgoing`/`_visibleOrStructuralIncoming`. Likewise
`LoadedMessages`, a proposed persisted Drift table for tracking which messages
had been fetched, turned out to be unnecessary: nothing needs to survive
restart except what's already durable in `ColumnBranchPointers`
(`lib/domain/branch_path_service.dart` via `ColumnRepository`) — the in-memory
hydration cache is allowed to be cold on every launch and refill itself
naturally. This doc names the actual mechanisms once and derives everything
else from them.

## Core distinction: resolving a candidate vs. acting on it

Every place a column moves its view — scrolling further into a branch,
clicking "Load stitches," cycling a navigator — reduces to two separable
questions:

1. **Resolution**: given a boundary message and a direction, what is the next
   candidate id? (automatic default, forced stitch, or explicit user pick)
2. **The hop**: given a chosen candidate id, make it real — load it, persist
   it as the visible pointer, reflect loading state in the UI.

The hop is the same code no matter how the candidate was resolved. Only
resolution differs per caller. That's the whole design.

## 1. `MessageStore` — hydration cache

- `MessageStore.load(id)` — ensure a message's content and edge-id pools
  (`replyOutgoing`/`stitchedOutgoing`/`replyIncoming`/`stitchedIncoming`) are
  in the in-memory cache. Checks the cache first; only hits
  `MessageRepository` if absent. No-op cost when already cached.
- `MessageStore.peek(id)` — synchronous, cache-only, no fetch.
- **No persisted "loaded" table.** `isLoaded(id) ≡ peek(id) != null`. On
  relaunch the cache starts cold; it refills as `materializedTrajectory`
  and `defaultPage` re-touch content. Nothing is lost, because everything a
  column has ever shown is already recoverable from `ColumnBranchPointers`.
- Fork breadth (reply **and** stitch ids together) is always fetched whole in
  one call per node — `getOutgoing`/`getIncoming` already do this
  (`lib/domain/branch_path_service.dart`, `docs/column-ui-architecture.md:54-58`).
  Only *content* hydration is ever deferred; *which candidates exist* at a
  fork is always known as soon as you're standing at it.

## 2. `materializedTrajectory` — pure read, powers every rerender

```dart
Future<List<Message>> materializedTrajectory(String columnId, String anchorId)
```

Walks `ColumnBranchPointers` only, both directions from `anchorId`, stopping
at the first unset pointer in each direction. No resolution logic, no
fallback, no writes, no `MessageRepository` edge queries beyond reading the
rows the pointers name. This is what `ColumnsViewModel._refresh` calls on
every ordinary rerender (resume, notifyListeners cycles, anything that isn't a
fresh anchor or an explicit load trigger). It replaces
`_visibleOrDefaultOutgoing`/`_visibleOrStructuralIncoming`'s pointer-read half
and all of `getFullVisibleBranch`.

## 3. The hop primitive — `selectCandidate`

```dart
Future<void> selectCandidate(
  String columnId,
  String parentId,
  String chosenId,
  Direction direction,
)
```

The **only** function that ever moves a branch pointer:

1. Set the column's loading marker for `direction` (`topLoading`/
   `bottomLoading`) to `true`, notify.
2. `MessageStore.load(chosenId)` — cache-checked, cheap or real.
3. `ColumnRepository.setBranchPointer(columnId, parentId, chosenId)`.
4. Set loading marker back to `false`, notify.

This is what `_visibleOrDefaultOutgoing`'s "else apply default and persist"
half becomes, generalized to accept *any* chosen id — not just a
reply-default. It's also literally what a navigator click does, and what one
hop of `revealStitch` does. There is no separate "navigator logic" or
"reveal-stitch logic" for the act of moving a pointer — only different ways of
picking `chosenId` before calling this.

## 4. Resolution: three ways to produce a `chosenId`

### a) Default (automatic, reply-only) — used by `defaultPage`

At a boundary with no explicit pointer set: pick the most recent id from
`replyOutgoing`/`replyIncoming`. **Never** considers `stitchedOutgoing`/
`stitchedIncoming`. This is the "reply-only default descent" and
`_visibleOrDefaultOutgoing`'s reply-fallback half, now just the resolution
rule `defaultPage` feeds into `selectCandidate` on each hop. If there is no
reply candidate, `defaultPage` does not fall through to a stitch candidate —
it stops (see §5).

### b) Forced stitch (one hop, on click) — used by `revealStitch`

Pick the first stitch candidate at the boundary, regardless of whether it's
already in `MessageStore`. **No load-state exception.** Surgical Loading is a
structural rule with zero exceptions: a stitch boundary always requires the
click, even if the content happens to already be cached — cache state only
affects how cheap the resulting `MessageStore.load` call is, never whether the
click is required. (This corrects the earlier draft of this design, which
proposed silently auto-crossing an already-loaded stitch boundary; rejected —
see decision log below.)

### c) Explicit user pick — used by `IncomingNavigator`/`OutgoingNavigator`

The navigator already has the full candidate pool for its position (reply +
stitch ids, fetched whole per §1). Cycling to any candidate — another stitch
sibling `revealStitch` didn't pick, or a reply sibling — is just
`selectCandidate` with `chosenId` = whatever the user selected. No friction
gate applies here: the click *is* the manual action Surgical Loading requires,
so there's nothing further to gate. This is the mechanism for reaching
additional stitch siblings beyond the one `revealStitch` initially picks, and
for reaching an unloaded reply sibling/aunt — same function, same code path,
just a different source for `chosenId`.

## 5. `defaultPage` — the only DB-loading/batching primitive

```dart
Future<PageResult> defaultPage(
  String columnId,
  String boundaryId,
  Direction direction,
  int batchSize,
)
```

Loop, up to `batchSize` hops:

- Resolve the next candidate via §4a (default, reply-only).
- If no reply candidate exists:
  - If a stitch candidate exists, stop the loop and return with
    `hasMore = false`, `stitchCount = candidates.length`. This is what
    `AdaptiveMarker` renders as "Load stitches (N)" — never auto-triggered.
  - If no candidate exists at all, stop with `hasMore = false`,
    `stitchCount = 0` ("Beginning/End of thread").
- Otherwise call `selectCandidate(columnId, boundaryId, chosenId, direction)`,
  append the loaded message, advance `boundaryId = chosenId`, continue.
- If the loop reaches `batchSize` with a reply candidate still available,
  return with `hasMore = true`.

This single function *is* everything previously named `loadInitialWindow`,
`extendAbove`, `extendBelow`, and the unnamed "one walk-one-hop helper" —
those were all the same loop with different callers:

- **`loadInitialWindow(columnId, anchorId, radius)`** — not a separate
  function, just: call `defaultPage(anchorId, up, radius)` and
  `defaultPage(anchorId, down, radius)`, concatenate the two results plus the
  anchor into one window, return it. Kept as a named entry point only because
  it's a distinct trigger condition (`_refresh` sees a fresh anchor with
  nothing materialized) — its body is pure composition, no new resolution
  logic.
- **`extendAbove`/`extendBelow`** — `defaultPage` called from the column's
  current top/bottom boundary in one direction. Not separate functions.

`revealStitch(columnId, boundaryId, direction)`: resolve via §4b (forced,
ignoring load state) for exactly one hop, call `selectCandidate`, then resume
the same `defaultPage` loop (§4a resolution) from the new boundary to fill out
the rest of the batch. Not a separate mode — one resolution override, then
falls back into the ordinary loop.

## 6. `ColumnsViewModel._refresh` — composition

1. **Ordinary rerender** (resume, any notifyListeners cycle where the column
   already has a materialized trajectory): call `materializedTrajectory` only.
   Pure pointer read, no `MessageRepository` edge queries, no writes.
2. **New column, or fresh anchor with nothing materialized**: call
   `loadInitialWindow(columnId, anchorId, kDefaultRadius)` — one `defaultPage`
   call per direction — to establish the initial view.
3. **`AdaptiveMarker` "load more" trigger** (`waiting` state, scrolled into
   view): one `defaultPage` call in that direction, `batchSize = kDefaultBatch`.
4. **`AdaptiveMarker` "Load stitches (N)" trigger**: `revealStitch` in that
   direction.

`getFullVisibleBranch`, `_visibleOrDefaultOutgoing`, and
`_visibleOrStructuralIncoming` are retired once this lands — fully replaced by
(2)/(6) above.

## 7. Marker states — mostly already built

`MarkerVisualState { waiting, loading, end, error }` and `AdaptiveMarker`'s
rendering of all four (including the `loading` spinner) already exist
(`lib/ui/core/adaptive_marker.dart:5,52-60`). `ColumnUiState.topLoading`/
`bottomLoading` and `topError`/`bottomError` already exist and are already
wired into the widget (`lib/ui/columns/column_view.dart:352-363,393-404`).

What's missing is coverage, not new UI:

- `topLoading`/`bottomLoading` are today only ever set by
  `loadStitchAbove`/`loadStitchBelow` (`lib/ui/columns/columns_viewmodel.dart`
  ~143-169). `selectCandidate` (§3) becomes the single place that sets these,
  so both the auto-triggered `defaultPage` path and the `revealStitch` path
  get the spinner for free — no widget changes needed.
- `topMarker`/`bottomMarker` are today hardcoded to `MarkerVisualState.end`
  (`columns_viewmodel.dart:269-270,283,287`), because nothing computes
  `hasMoreAbove/Below` yet. Once `defaultPage`'s result feeds
  `ColumnUiState`, `waiting` becomes reachable and the intersection-observer
  auto-trigger (~200px margin, per `column-ui-impl-plan.md`'s original spec)
  can call `defaultPage` on scroll.

## Decision log (resolved during design)

- **Rejected**: persisting a `LoadedMessages` table to track fetched-ness
  durably. Unnecessary — `ColumnBranchPointers` is the only state that needs
  to survive relaunch; the hydration cache is fine to start cold.
- **Rejected**: silently auto-crossing an already-cached stitch boundary
  without a click. Surgical Loading has no load-state exception — the click
  is always required at a stitch boundary, full stop. Cache state only
  affects the cost of the resulting load, never whether the click fires.
- **Confirmed**: fork breadth (reply + stitch ids) is always fetched whole;
  only chain depth is paged/batched.
- **Confirmed**: one hop primitive (`selectCandidate`) backs `defaultPage`'s
  automatic hops, `revealStitch`'s forced hop, and navigator-driven explicit
  picks — including reaching an unloaded reply sibling/aunt, which uses the
  identical code path as reaching an unloaded stitch sibling.
