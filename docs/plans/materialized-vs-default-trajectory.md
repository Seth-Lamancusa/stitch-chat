# Materialized vs. default-derived trajectory loading

> **Superseded by `message-loading-plan.md`.** Kept for history of the
> resume-vs-load split rationale; the consolidated doc is current.

## Context

`column-ui-impl-plan.md` §1 introduced windowed loading (`BranchWindow`,
`loadInitialWindow`/`extendAbove`/`extendBelow`, `kDefaultRadius`/
`kDefaultBatch`) and `message-loading-architecture.md` §3 reconciled it with
`MessageStore`, unifying `loadInitialWindow`/`extendAbove`/`extendBelow`/the
reply-only default descent into "one walk-one-hop helper." Neither is built
yet — `BranchPathService.getFullVisibleBranch` still resolves a whole branch
in one un-windowed walk today.

Gap found while designing the actual walk: both prior docs treat **resuming a
column on relaunch** as re-running the same bounded, defaulting walk
(`loadInitialWindow(columnId, persistedAnchor, radius: kDefaultRadius)`).
That only reproduces a fixed radius from the anchor — it doesn't recover
however far the column had actually been extended in a prior session (10
messages? 200, after repeated scroll-triggered extends?). But since every
defaulting hop persists a `ColumnBranchPointers` row as it's taken, *everything
a column has ever shown is already fully recoverable by reading pointers
alone* — no radius, no domain computation, no re-derivation needed. Resume and
first-time/extend loading are not the same operation and shouldn't share one
code path. This doc splits them into two explicit primitives and describes how
`ColumnsViewModel` composes them.

## a) Materialized trajectory walk — pure pointer read

```dart
Future<List<Message>> materializedTrajectory(String columnId, String anchorId)
```

Walks `ColumnBranchPointers` only, both directions from `anchorId`, stopping
at the first unset pointer in each direction. No domain computation (no
reply-recency comparison, no stitch consideration), no writes. Not
paged/bounded — it doesn't need to be, since by construction it can never be
longer than whatever a prior run of (b) actually persisted. This is the only
thing that runs on:

- Initial `_refresh` for every column, including app-relaunch resume.
- Re-render after any navigation or send that moves the anchor (the
  already-materialized rows below/above the switch point are trusted as-is,
  same as today's `getFullVisibleBranch` re-derivation, just without
  recomputing defaults along the way).

## b) Default-derived page — bounded, paged, domain logic

```dart
Future<List<Message>> defaultPage(
  String columnId,
  String boundaryId,
  Direction direction, {
  int pageSize = kDefaultPageSize,
})
```

Repeatedly selects the most-recent reply edge in `direction` from `boundaryId`,
persisting a pointer at every hop (`setBranchPointer` going down,
`setVisibleIncoming` going up — **both directions now persist**, closing an
existing asymmetry: today's `_visibleOrStructuralIncoming`,
branch_path_service.dart:127-138, computes the reply-structural fallback via
`getAncestorPath` but never writes it, while `_visibleOrDefaultOutgoing` does
persist its default). Stops early, before `pageSize`, the instant a node has
no reply edge in that direction — never inspects or crosses stitch edges,
regardless of remaining page budget.

Called only:

1. Once in each direction, from the anchor, when a column's anchor has no
   materialized pointer at all yet (brand-new column, or an anchor placed on a
   node never before visited from this column). This is the entire "initial
   load" for that case — not a loop, not a target row-count.
2. Once, in one direction, per `AdaptiveMarker` "load more" trigger at a
   boundary. No auto-iteration — a marker click gets exactly one page.

**Explicitly not doing:** trying (a) before computing (b) for the same
column/node. `ColumnBranchPointers` is already keyed by `(columnId, ...)`, so
by the time (b) is invoked for a given column at a given node, (a) has already
been tried and missed for that exact key — checking again is a guaranteed
no-op. (Whether *another* column has already derived a default at the same
graph node is irrelevant and deliberately not consulted: one column choosing a
default trajectory says nothing about what another column should show.)

## Composition in `ColumnsViewModel._refresh`

1. **Resume / any re-render** → `materializedTrajectory` only.
2. **New column, or fresh anchor with nothing materialized for this column** →
   `defaultPage` once upward and once downward from the anchor
   (`pageSize` messages each direction) as the initial view.
3. **`AdaptiveMarker` "load more" trigger** → one `defaultPage` call in that
   direction from the current boundary row.

## Boundary marker state (waiting vs. end vs. loading)

An (a)-only walk stops at "pointer unset," which is ambiguous between "never
derived from this column" and "true reply dead-end" — so marker state can't be
read off pointers alone. Compute it live at the boundary message: query reply
presence in that direction (`getOutgoing(id).replyOutgoing.isEmpty` /
`getIncoming(id).replyIncoming.isEmpty`). Nonempty → `waiting` (a `defaultPage`
call is available); empty → `end`. Same shape as the existing stitch-count
computation already in `columns_viewmodel.dart:246-251`
(`topStitchCount`/`bottomStitchCount`), just checking reply-edge presence
instead of stitch-edge presence, and driving the `waiting`/`end` marker state
rather than the "Load stitches (N)" button.

## Interaction with `MessageStore`/id-content split (message-loading-architecture.md §1-2)

Orthogonal, not in conflict: `MessageStore.isLoaded`/content caching answers
"do we already have this message's content," shared *across* columns; the
a)/b) split above answers "which trajectory does *this* column show,"
necessarily per-column. Once the id/content split lands, `defaultPage` should
walk `getOutgoingIds`/`getIncomingIds` (cheap, ordered, last id = default) and
hydrate the page's ids in one `getMessages` batch call at the end, rather than
one `getMessage` per hop. `defaultPage`'s incoming direction should use the
single-hop `getIncomingIds(id).replyIncomingIds.firstOrNull` primitive
directly instead of a full ancestor walk — `getAncestorPath` is already slated
for retirement there for the same reason.

## Open questions

- `kDefaultPageSize` value — `column-ui-impl-plan.md` used 30 as a placeholder
  for `kDefaultRadius`/`kDefaultBatch`; this discussion floated 10. Not
  architecturally load-bearing, needs a number before implementation.
- Whether the reply-presence check for marker state should be cached
  alongside the page result (since `defaultPage`'s last hop already knows it
  hit a dead end) versus always freshly queried — likely free to cache when
  `defaultPage` itself terminates early, only needs the live query when
  displaying a boundary that (a) stopped at without ever calling (b).

## Explicitly unchanged

- No provenance flag distinguishing default-derived pointers from
  explicit-navigation ones — both write the same `ColumnBranchPointers` row
  shape, matching the pointer-pair model in `message-tree-data-model.md` §3.
- Stitch-edge crossing rules and the navigator/marker exclusivity rule
  (`column-ui-impl-plan.md` §4-5) are unaffected by this split.
