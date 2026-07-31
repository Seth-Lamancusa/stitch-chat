# Column UI Architecture

This documents the current, implemented shape of the multi-column branch-navigable
chat UI — as opposed to `docs/plans/column-ui-impl-plan.md` and
`docs/plans/message-tree-data-model.md`, which are the forward-looking design docs
that motivated it. Read those for *why*; read this for *what exists now*.

Not yet built: §1's windowed loading (`BranchPathService` still resolves a whole
branch in one walk, no radius/batch/`BranchWindow`), §0's live-chat-to-SQLite wiring
(the WS bot doesn't persist through this yet — `chat_view.dart`/`chat_viewmodel.dart`
still own that, unwired from `main.dart`), §9's stitch-edge creation modal, and the
filesystem JSON mirror. `main.dart` currently boots into seeded test data
(`lib/data/services/dev_seed.dart`) rather than a real conversation.

## Vocabulary: incoming and outgoing, not parent and child

Every message has two edge directions out of it, each split by edge type:

- **replyOutgoing** / **stitchedOutgoing** — messages this one points to as a reply
  parent, or via a stitch edge it originates.
- **replyIncoming** / **stitchedIncoming** — messages that point to this one the same
  two ways.

"Outgoing" and "incoming" name the *data-model* relationship. The two navigator
widgets are UI placements of that same relationship, not a third concept:

- **OutgoingNavigator** (port of stitch-frontend's `SiblingNavigator.vue`) cycles
  the outgoing pool of the message *above* it in the branch — this message's own
  siblings under that parent. It sits *beside* this message rather than the
  parent, matching where `SiblingNavigator.vue` actually mounts (on the child,
  parent id passed in only for pool lookup): "which sibling occupies this slot"
  reads naturally next to the slot's current occupant, not next to the parent.
- **IncomingNavigator** (port of `LinkSwitcher.vue`) cycles a message's incoming
  pool. It sits *inline above* the message, because that's where "which parent is
  this shown under" reads naturally.

Same operation (pick one candidate from a pool, reply candidates always ordered
before stitch candidates), opposite edge direction, different screen position for
UX reasons only. Don't reintroduce "parent/child" or "sibling/ancestor" naming in
new code in this area — incoming/outgoing is the vocabulary the whole stack (repos,
domain service, widgets, view model) is built on.

## Data layer

### `MessageRepository` (`lib/data/repositories/message_repository.dart`)

```dart
Future<OutgoingEdges> getOutgoing(String parentId);
Future<IncomingEdges> getIncoming(String childId);
Future<List<Message>> getAncestorPath(String messageId); // reply-only, root first
Stream<List<Message>> watchReplyOutgoing(String parentId);
```

`OutgoingEdges{replyOutgoing, stitchedOutgoing}` and
`IncomingEdges{replyIncoming, stitchedIncoming}` each expose an `.all` getter for
the combined, reply-first pool a navigator needs. `getOutgoing`/`getIncoming` are
always fetched whole (never paged) — a fork rarely has more than a handful of
candidates; only *chain depth* is meant to be windowed eventually, not fork
breadth. `DriftMessageRepository` implements this against `ReplyEdges`/`StitchEdges`;
`StitchApiMessageRepository` is an unimplemented stub for a future remote store.

### `ColumnRepository` (`lib/data/repositories/column_repository.dart`)

```dart
Future<String?> getVisibleOutgoing(String columnId, String messageId);
Future<String?> getVisibleIncoming(String columnId, String messageId);
Future<void> setBranchPointer(String columnId, String parentId, String childId);
Future<void> setVisibleIncoming(String columnId, String childId, String newParentId);
```

Backed by the `ColumnBranchPointers` table: one row per `(columnId, parentId,
childId)`, PK on `(columnId, parentId)`, unique key on `(columnId, childId)`. A
child can be the visible-child of only one parent per column, so switching a
child's visible *incoming* pointer (`setVisibleIncoming`) has to delete the old row
before inserting the new one — `setBranchPointer` alone would collide with the
unique key. `getVisibleOutgoing`/`getVisibleIncoming` read the same table from
opposite ends.

### `BranchPathService` (`lib/domain/branch_path_service.dart`)

Derives a column's rendered thread by walking out from an anchor message —
`getFullVisibleBranch(columnId, anchorMessageId)` — up via
persisted-visible-incoming-or-reply-structural-fallback, down via
persisted-visible-outgoing-or-most-recent-reply-child. Because the downward
fallback only ever considers `replyOutgoing` (never `stitchedOutgoing`), an
untouched fork never auto-follows into stitch-linked content — that's the
"Surgical Loading" principle from `_docs/stitch.md` in stitch-frontend, enforced
structurally rather than as a UI rule.

```dart
Future<List<Message>> navigateOutgoing(String columnId, String parentId, {required bool forward});
Future<List<Message>> navigateIncoming(String columnId, String childId, {required bool forward});
```

Both are explicit, user-driven switches and *do* see the full combined pool
(reply candidates first, then stitch). Both clamp at either end of the pool rather
than wrapping. `navigateOutgoing` re-derives everything below the switch point;
`navigateIncoming` re-derives everything above it. Because `getFullVisibleBranch`
isn't windowed yet, the branch it returns always terminates in a true reply root
above and a true reply leaf below — any stitch neighbors at those two ends are
exactly the "unfollowed stitch" boundary case `AdaptiveMarker` surfaces.

## UI widgets (`lib/ui/core/`)

**Exclusivity rule** (from column-ui-impl-plan.md §4-5, unchanged by naming):
a navigator can only render where a reply-anchored default already put something
on screen. If a message has zero reply children/parents but some stitch
children/parents, no navigator has anywhere to attach — that's `AdaptiveMarker`'s
job, not `OutgoingNavigator`'s or `IncomingNavigator`'s. Concretely: both
navigators key off whether a message has a *previous* message displayed above it
— that previous message is the parent whose pool this message occupies a slot in.
`OutgoingNavigator` wraps the message itself (matching stitch-frontend's
`SiblingNavigator.vue`, which mounts on the child and takes the parent id only for
pool lookup — not on the parent, despite the name suggesting "beside the message
that owns the pool"), so switching it swaps which sibling occupies this slot.
`IncomingNavigator` renders inline above that same message, cycling its own
incoming pool (its other parents). The very top of a branch never gets either
inline navigator — only the top `AdaptiveMarker`; the bottom message still gets an
`OutgoingNavigator` (it's a slot in its parent's pool like any other) but never an
`IncomingNavigator` target below it, since there's nothing rendered further down.

- **`MessageCard`** — the bubble. User right/primary, everything else left;
  `functionCall`/`functionResult` get a small label chip on top of the shared
  "other" styling (a deliberately small improvement over stitch-frontend's fully
  role-agnostic bubble, since our `Message.role` has four values worth
  distinguishing).
- **`OutgoingNavigator`** — wraps a message; renders prev/next arrows beside it
  only when its outgoing pool has more than one candidate. Stitch-target arrows
  get the green tint (`StitchColors.stitchGreen*`) ported from stitch-frontend's
  `target-is-stitch` styling.
- **`IncomingNavigator`** — renders inline above a message: "Reply origin" or
  "Linked origin (i/total)" in a pill, with prev/next arrows when the pool has more
  than one candidate. Shown even with a single candidate if that candidate is a
  stitch parent (non-interactive "Linked origin" flag) — origin transparency, so a
  stitch-derived context is never silently indistinguishable from a reply.
- **`AdaptiveMarker`** — sentinel at the top/bottom of a column's list. States
  `waiting | loading | end | error`, computed by the caller (`ColumnsViewModel`),
  not derived internally. `end` renders "Beginning/End of thread"; if the boundary
  message has unfollowed stitch neighbors, it additionally renders a green
  "Load N stitches" button. This is the *only* place an unloaded stitch count is
  surfaced, by construction of the exclusivity rule above.

`StitchColors` (`lib/ui/core/stitch_colors.dart`) centralizes the green tokens so
every "this crossed into stitch-linked content" cue stays visually consistent.

## Multi-column shell (`lib/ui/columns/`)

- **`ColumnUiState`** / **`MessageRowData`** (`column_ui_state.dart`) — per-column
  render state: `rows` (one `MessageRowData` per displayed message, carrying its
  precomputed outgoing/incoming pool + current index so widgets don't query
  themselves) plus top/bottom marker state, stitch counts, loading/error flags.
- **`ColumnsViewModel`** (`columns_viewmodel.dart`) — a `ChangeNotifier` owning
  column CRUD (`addColumn`/`removeColumn`/`setActiveColumn`/`updateColumnWidth`),
  navigation (`navigateOutgoing`/`navigateIncoming`/`loadStitchAbove`/
  `loadStitchBelow`), and `sendMessage` (persists a real message + reply edge,
  advances the column's persisted anchor — column-ui-impl-plan.md §3's "anchor is a
  persisted, moving reference point"). Holds no traversal logic itself; it's a thin
  orchestration layer over `BranchPathService`/`MessageRepository`/
  `ColumnRepository`, per `docs/flutter-best-practices.md`'s MVVM split.
- **`ColumnsView`** (`columns_view.dart`) — the screen: a `Row` of columns with a
  4px drag-to-resize handle between each pair (port of stitch-flutter's
  `_ColumnResizer`), and an "Add Column" action that duplicates the active
  column's current anchor into a new one.
- **`ColumnView`** (`column_view.dart`) — one column: 48px header (active
  indicator via a 4px accent-colored left border, close button), scrollable
  message list (top `AdaptiveMarker`, rows, bottom `AdaptiveMarker`), composer bar
  shown only when the column is active.

## Dev seed data (`lib/data/services/dev_seed.dart`)

`seedDevDataIfEmpty` populates a fixed nine-message graph on first launch (no-ops
if any column already exists) so the UI has something to navigate before real chat
persistence (§0) lands. It deliberately covers:

- a plain linear stretch,
- a 3-way reply fork (`OutgoingNavigator` cycling reply-only candidates),
- a message whose outgoing pool mixes one reply and one stitch candidate
  (`OutgoingNavigator`'s reply-to-stitch tint transition),
- a reply leaf whose only outgoing edge is a stitch (below the inline-navigator
  threshold, surfaces as a bottom `AdaptiveMarker` boundary instead),
- a reply root with one unfollowed incoming stitch (top `AdaptiveMarker`
  boundary), and
- a message with one reply parent plus two stitch parents (`IncomingNavigator`
  cycling "Reply origin" / "Linked origin (1/2)" / "Linked origin (2/2)").

Three columns are seeded, each anchored to surface a different piece of the above
without requiring navigation first.
