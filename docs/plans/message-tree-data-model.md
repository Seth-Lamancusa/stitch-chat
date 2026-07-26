# Message tree data model & multi-column thread rendering — plan

## Context

The README defines the fundamental data model: the message, connected by reply
ancestry into conversation trees, deliberately not centered on a linear
"thread." This plan settles the concrete Dart-side data model and the state
architecture for the multi-column UI before porting it, drawing on three
sibling repos that each hold a piece of the answer:

- **stitch-backend** (`~/code/stitch/stitch-backend`) — the data model's
  conceptual source. ArangoDB graph store: messages are vertices, thread
  topology lives *only* in edge collections (`replies`, `links`), one
  direction persisted, reverse adjacency computed at query time
  (`app/db/README.md`, `app/db/queries/fragments.py:183,298`). No persisted
  Conversation/Thread entity — a "conversation" is emergent from edges.
- **stitch-frontend** (`~/code/stitch/stitch-frontend`) — the rendering and
  interaction logic's source. `ThreadView.vue` + `store/modules/messages.js`
  implement branch-pointer linearization, sibling/parent navigation,
  depth-windowed incremental loading, and stitch-boundary crossing. The
  design doc `_docs/stitch.md` records the intent: two edge families kept as
  separate graph layers, "Surgical Loading," deliberate friction when
  crossing trees.
- **stitch-flutter** (`~/code/stitch/stitch-flutter`) — the multi-column
  desktop precedent and the local-filesystem chatlog pattern.
  `ChatLayoutViewModel` + `ResizableColumnLayout` + per-column branch maps
  are directly reusable shapes; its JSON persistence
  (`open-chats/`/`all-chats/`) informs the filesystem-mirror component here.

## Decisions

### 1. Storage: SQLite as source of truth, filesystem JSON as a readable mirror

SQLite (via drift, for type-safe reactive queries) is the application
database and single source of truth for messages, edges, and column layout.
Indexed `children-of`/`parents-of` queries and watch-streams are what make
windowed rendering over large trees possible — stitch-flutter's
whole-file-JSON approach structurally can't load "just what's visible" (its
`fetchThread` pulls a depth-50 subtree in one call and holds everything in
memory; no SQLite/hive/drift exists anywhere in that repo — confirmed).

Alongside, chat logs are mirrored to human-readable JSON files on the user's
filesystem — not as a store the app reads back from, but purely for end-user
copyability and access: the user should have their chats *on their computer*,
not abstracted behind a database file. Modeled on stitch-flutter's
`_persistToOpenChats`/`_persistToAllChats`
(`packages/feature_chat/lib/src/viewmodels/chat_layout_viewmodel.dart:994-1063`)
and its date-bucketed `all-chats/chat-<YYYY-MM-DD>.json` merge-by-uid format —
but one-directional here (SQLite → JSON), avoiding stitch-flutter's dual-role
ambiguity where the same files were sometimes cache, sometimes source of
truth. No file-watching/hot-reload of these mirrors in scope. Tool outputs
are part of the chat log (they're messages), so they land in both stores;
no separate blob storage needed for now.

Cloud sync (ArangoDB backend, human-to-human messages over a Dart↔cloud WS)
is a future, separate design decision. The repository interface is the seam
where it plugs in; nothing here should preclude it.

### 2. Model: message + two edge tables

Matching stitch-backend's storage shape (single-direction edges, reverse
adjacency derived) and `_docs/stitch.md`'s "separate graph layer" decision:

```dart
enum MessageRole { user, bot, functionCall, functionResult }

class Message {
  final String id;
  final MessageRole role;   // message kind
  final String? authorId;   // identity: bot_id, or human user_id (future
                            // cloud path); null for functionCall/Result
  final String content;
  final String? gitCommit;
  final DateTime? createdAt; // null until persisted
  final bool isStreaming;    // transient; false once loaded from storage
}

class ReplyEdge  { final String parentId, childId; }
class StitchEdge { final String fromId, toId;
                   final String? createdByAuthorId;
                   final DateTime createdAt; }

enum RecipientKind { localBot, cloudUser }
class RecipientEdge { final String messageId;
                      final String recipientId;  // bot_id, or cloud user_id
                      final RecipientKind kind; }
```

- `role` and `authorId` are separate fields (kind vs identity). This is what
  makes columns bot-agnostic and human-ready: identity lives on the message,
  not the column.
- No `parentId` field on Message, and no stored `childIds` anywhere —
  topology lives only in the edge tables, reverse adjacency is a query.
  stitch-backend confirmed this is the right shape (vertex documents carry
  no parent/child fields; `child_ids` on the wire is a per-request AQL
  projection). stitch-frontend's manually-synchronized denormalized
  `child_ids` cache (`messages.js` delete/link mutations) is the failure
  mode to avoid.
- The unified Message here supersedes/extends the one decided in
  `dart-python-interface.md` component 4 (`conversationId` and `parentId`
  drop off the message; edges replace them — reconcile when implementing).
- **`RecipientEdge`** — a message can address multiple recipients, kept as
  its own edge table rather than folded into `authorId`/reply-parent.
  Mirrors stitch-backend's `receivers` edge collection
  (`app/db/recipients.py:37-67`), where a local bot and a cloud human are
  the same edge shape, distinguished only by a flag (`is_bot` there,
  `RecipientKind` here) — not by different tables or dispatch-time
  branching in the model itself. `kind` only says which dispatch path
  handles this recipient (local runtime registry vs. Stitch cloud); it
  records addressing, not delivery outcome — delivery/sync status per
  recipient is a `cloud-sync.md` concern (§9 there), not this table's.

**Edge semantics.** Replies and stitches are the two edge types on a
simply-connected DAG-plus-links structure:

- **ReplyEdge** — structural. Acyclic *by construction*: a message's reply
  parent is set at creation and never reassigned (same guarantee the Vue app
  relies on; its cycle guards are purely defensive). Today: exactly one
  reply parent per child, enforced as an application-level constraint
  (unique index on `childId`) — **not** a schema shape. Multi-parent replies
  (e.g. automation replying to many messages at once) fold in later by
  relaxing that index, with no model or rendering changes (see §4).
- **StitchEdge** — semantic, many-to-many, may be cyclic, no write-time
  validation (matching the backend: `createLink` does no cycle check).
  Product meaning per `_docs/stitch.md`: splice histories together so the
  user can scroll up from the end of one thread into the beginning of
  another. Not needed for v1 of the port, but the table and rendering
  candidate-pool logic are designed in from the start so it bolts on
  without reshaping anything.

### 3. Column state: shared message set, per-column linear path

Fundamental framing: **app state is one shared set of loaded messages
(SQLite-backed, cached in memory); each column is a linear path through that
same set.** The same message may appear in multiple columns — there is no
uniqueness constraint; columns rendering overlapping territory simply
display the same shared message.

```dart
class ColumnState {
  final String id;
  final String anchorMessageId; // not necessarily the root
  // Paired pointers, always updated atomically as (parent, child) pairs —
  // the per-column analog of the Vue store's SET_BRANCH_LINK.
  final Map<String, String> visibleParent; // messageId -> chosen parent
  final Map<String, String> visibleChild;  // messageId -> chosen child
  final double? width;                     // null = flexible
}
```

- The pointer-pair mechanism is lifted directly from stitch-frontend's
  `branch_parent`/`branch_child` (`messages.js:364-377 SET_BRANCH_LINK`),
  with one critical fix: the Vue store writes these **globally onto the
  shared message objects**, which only works because its router mounts
  exactly one ThreadView at a time (`router.js:165-169`) — a structural
  precondition, not a data-model guarantee. This app's premise is multiple
  simultaneous thread views, so the pair is scoped per column. Messages
  stay immutable (per `docs/flutter-best-practices.md`); navigation state
  never touches them. stitch-flutter already half-made this move with its
  per-column `_branchChildren`/`_branchParents` maps
  (`chat_layout_viewmodel.dart:49-50`).
- Both directions are kept (not redundant): SiblingNavigator needs O(1)
  "what's shown under this parent," LinkSwitcher needs O(1) "what's shown
  above this child." But they are never independent decisions — one atomic
  pair update, exactly like SET_BRANCH_LINK.
- The rendered linear thread is **derived, not stored**: walk out from
  `anchorMessageId` following the pointer pairs (up via `visibleParent`,
  down via `visibleChild`), defaulting to most-recent child at unset forks
  (both prior apps' behavior — `prepareBranchPath`, messages.js:619;
  `_ensureBranchPathDown` in stitch-flutter). Port of
  `getFullVisibleBranch` (messages.js:1962) / `getAncestorPath`
  (messages.js:1935), cached per column and extended incrementally as more
  messages load rather than recomputed from scratch.
- Column CRUD/resize/persistence: port from stitch-flutter's
  `ChatLayoutViewModel` (add/remove/load-into-column) and
  `ResizableColumnLayout`
  (`packages/feature_desktop/lib/src/widgets/resizable_column_layout.dart`)
  — drag handles, min-width, flexible-vs-fixed widths. Heed its own
  `// ARCHITECTURE TODO` (chat_layout_viewmodel.dart:626): linearization/
  traversal logic goes in a testable domain service, not the ViewModel.

### 4. Navigation candidate pools — where the symmetry lives

Every message node in a column exposes up to two navigators, mathematically
symmetric (one navigates among a node's children, the other among its
parents), both drawing from **combined edge-type-agnostic candidate pools**:

- **SiblingNavigator** (port of `SiblingNavigator.vue`) — prev/next over
  `[...replyChildren, ...stitchChildren]` of the active parent (the Vue
  `getChildIds` pool, messages.js:1897; reply children ordered first). On
  tap: atomic pointer-pair update, re-derive the path below that point.
  Stitch-target neighbors get distinct styling (Vue: green
  `target-is-stitch`).
- **LinkSwitcher** (port of `LinkSwitcher.vue:67-84`) — prev/next plus an
  origin pill ("Reply origin" / "Linked origin (i/total)") over
  `[replyParent, ...stitchParents]`. Same pair update, opposite direction.
  Also serves as origin transparency: shows when a node's upward context
  came via a stitch rather than a reply.

Because both navigators consume flat candidate lists and never care which
edge table a candidate came from, **multi-parent replies fold in cleanly**:
relax the ReplyEdge unique index and the LinkSwitcher pool becomes
`[...replyParents, ...stitchParents]` — no changes to ColumnState, the
pointer-pair mechanism, or either widget. This is the forward-compatibility
requirement, satisfied structurally rather than by speculative code. (The
Vue app never anticipated multi-parent replies — `parent_id` is scalar
everywhere — but its own LinkSwitcher already proves the combined-pool
rendering works, since multiple stitch parents are exactly that.)

### 5. Incremental loading & thread boundaries

- **AdaptiveMarker** (port of `AdaptiveMarker.vue`) — sentinel widget at top
  and bottom of each column's list. States `waiting | loading | end |
  error`. In `waiting`, visibility (Flutter analog of its
  IntersectionObserver, rootMargin 200px — a scroll-extent check or
  visibility detector) auto-triggers load-more, once per waiting cycle.
  `end`/`error` never auto-trigger; they render "Beginning/End of thread,"
  a Retry button on error, and — when the boundary message has stitch
  neighbors (incoming at top or outgoing at bottom) — an explicit "Load 
  stitches (N)" button. That manual step is a
  deliberate product decision from `_docs/stitch.md` ("Surgical Loading" /
  friction-by-design for origin transparency), preserved intentionally.
- **Load unit**: since the local SQLite store is authoritative and cheap to
  query, "loading" means paging rows into the in-memory set and extending
  the derived path — depth-radius fetches (the Vue app's depth-5 traversal
  calls against a remote API) become simple indexed queries; the marker
  states key off "does the boundary message have edges whose far end isn't
  loaded yet," same computation as `topMarkerState`/`bottomMarkerState`
  (ThreadView.vue:580,695). When the cloud backend arrives, the same marker
  states drive remote traversal fetches through the repository seam.
- **Scroll stability**: port the "eye-tracking" fix from `_docs/stitch.md` /
  `loadMoreParents` (ThreadView.vue:1266) — capture a reference message's
  viewport offset before prepending/branch-switching, restore it after, so
  loads and branch switches never visually jump.
- **Live messages**: WS arrivals (per `dart-python-interface.md`'s protocol)
  write straight to SQLite; drift watch-streams update the shared set; a
  column auto-follows a new message only when its parent currently has no
  visibleChild set (the Vue auto-follow rule, `handleIncomingWsMessage`,
  ThreadView.vue:535).

### 6. Filesystem chatlog mirror

One-way SQLite → JSON export, written on message persist (debounced),
somewhere user-convenient (location configurable; default alongside app
data). Format: date-bucketed cumulative logs modeled on stitch-flutter's
`all-chats/chat-<date>.json` (merge by id, sorted by timestamp), plus
optionally per-column snapshots like `open-chats/chat_<id>.json` with the
column's current linearized path.

## Components (each → its own focused plan before implementation)

1. **Schema + repositories** — drift tables (messages, reply_edges,
   stitch_edges, recipient_edges, columns), `MessageRepository`/
   `ColumnRepository` (abstract + drift impls per best-practices),
   watch-stream queries for children/parents-of.
2. **Path derivation service** — pure Dart port of
   `prepareBranchPath`/`getFullVisibleBranch`/`getAncestorPath`/
   `navigateToSibling` against the pointer-pair maps; unit-tested against
   fork/stitch/boundary fixtures before any UI exists.
3. **Multi-column shell** — ResizableColumnLayout port + ColumnState CRUD +
   layout persistence.
4. **Column thread view** — message list, SiblingNavigator, LinkSwitcher,
   AdaptiveMarker, scroll stability, WS auto-follow wiring.
5. **Filesystem mirror** — export service, debounce, location setting.

Sequencing: 1 → 2 are the foundation (2 is pure logic, testable
immediately). 3 and 4 depend on both; 5 hangs off 1 and can land anytime.
Component 4 of `dart-python-interface.md` (unified Message model) should be
reconciled with §2 here when its plan is written — edges replace
`parentId`/`conversationId` on the message.

## Key reference files

| Repo | File | What to take |
|---|---|---|
| stitch-backend | `app/db/README.md` | canonical edge-collection schema; one-direction storage |
| stitch-backend | `app/db/queries/fragments.py`, `message_queries.py` | derived adjacency, bounded traversal shape |
| stitch-frontend | `_docs/stitch.md` | design intent: edge families, surgical loading, friction, eye-tracking |
| stitch-frontend | `src/store/modules/messages.js` | SET_BRANCH_LINK pair semantics; prepareBranchPath; getFullVisibleBranch; navigateToSibling; getChildIds combined pool; WS auto-follow |
| stitch-frontend | `src/views/app_views/ThreadView.vue` | marker states, loadMoreParents/Children scroll restore, stitch boundary flow |
| stitch-frontend | `src/views/app_views/GraphView.vue` | Rendering, example incremental loading for all edge types |
| stitch-frontend | `src/components/SiblingNavigator.vue`, `LinkSwitcher.vue`, `AdaptiveMarker.vue` | the three widgets to port, incl. exact state machines |
| stitch-flutter | `packages/feature_chat/.../chat_layout_viewmodel.dart` | column CRUD, per-column branch maps precedent, JSON persistence format; its ARCHITECTURE TODO |
| stitch-flutter | `packages/feature_desktop/.../resizable_column_layout.dart` | resizable multi-column layout widget |
| stitch-flutter | `packages/stitch_core/.../message_repository.dart` | traversal-fetch shape (and its no-pagination gap to avoid) |

## Next step

Write the focused implementation plan for component 1 (schema +
repositories), since everything else is written against it.
