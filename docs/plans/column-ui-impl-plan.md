# Port multi-column thread UI + navigators into stitch-desktop

## Context

`stitch-desktop/docs/plans/message-tree-data-model.md` lays out a 5-component plan for a multi-column, branch-navigable chat UI. Components 1 (schema/repositories) and 2 (`BranchPathService`, fully unit-tested) are already built. Components 3–5 (multi-column shell, column thread view with navigators, filesystem mirror) are not started — the app's actual running UI (`lib/ui/chat/chat_view.dart` + `chat_viewmodel.dart`) is still a single-thread "hello world" chat screen that talks to the local Python WS bot and keeps messages in a plain in-memory list. **It never touches `AppDatabase`/`MessageRepository`/`ColumnRepository` at all** — nothing persisted by drift today came from a real conversation, only from the repository unit tests. So before any column UI can render anything real, the live chat flow has to start writing into SQLite.

Per your direction: building this in **stitch-desktop** (not stitch-flutter), using **drift/SQLite** (already there), with **full stitch-edge support** (reply + stitch siblings/ancestors).

Confirming the branch-pointer question: yes, `visibleParent`/`visibleChild` are structurally guaranteed to always agree — `ColumnBranchPointers` is a single table with one row per `(columnId, parentId, childId)` triple (PK on `(columnId, parentId)`, unique key on `(columnId, childId)`). `getVisibleChild` and `getVisibleParent` both read the *same* row from two different angles, and `setBranchPointer` is the only writer. This holds today for the downward (sibling) direction. It does **not** yet hold for the upward (ancestor-switching) direction — closing that gap is part of this plan (§2).

**North star, per your correction:** the current `BranchPathService.getFullVisibleBranch` resolves the *entire* root-to-leaf path in one synchronous walk. That's wrong to build on — even though SQLite is local and cheap, `MessageRepository` should be treated like a remote paged backend (i.e., like stitch-backend), and the UI should incrementally load ancestors/descendants on scroll via the AdaptiveMarker state machine, exactly like stitch-frontend does against its real remote API. This plan replaces the "always return the whole branch" design with a windowed one. Below, "LinkSwitcher" is called **AncestorSwitcher** throughout (your naming) — it's still the direct port of stitch-frontend's `LinkSwitcher.vue`.

## Reference material already read in full

- `stitch-desktop/docs/plans/message-tree-data-model.md` — the authoritative spec.
- `stitch-desktop/lib/data/services/app_database.dart`, `column_repository.dart` + `drift_column_repository.dart`, `message_repository.dart` + `drift_message_repository.dart`, `domain/branch_path_service.dart` — current component 1+2 implementation.
- `stitch-desktop/lib/main.dart`, `lib/ui/chat/chat_view.dart`, `chat_viewmodel.dart`, `data/repositories/chat_repository_impl.dart` — the current live (unpersisted) chat flow to be replaced.
- stitch-flutter's `ChatLayoutViewModel`/`chat_view.dart` (columns, resizer, CRUD) — precedent for the shell (per-column `_branchChildren`/`_branchParents`, `_ColumnResizer`, `addEmptyColumn`/`removeColumn`/`setActiveColumn`/`updateColumnWidth`).
- stitch-frontend `main` branch — `SiblingNavigator.vue`, `LinkSwitcher.vue`, `AdaptiveMarker.vue`, `ThreadView.vue` (`topMarkerState`/`bottomMarkerState` computed properties, `loadMoreParents`/`loadMoreChildren`, `handleLoadStitchBoundary`, `handleIncomingWsMessage` auto-follow), `messages.js` (`SET_BRANCH_LINK`, `navigateToSibling`, `getChildIds`/`getAncestorPath`/`getFullVisibleBranch`, depth-5 traversal fetches), `_docs/stitch.md` (Surgical Loading, eye-tracking), and `LinksModal.vue` (stitch-edge creation: pick a message from a searchable list, dispatch `createLink({messageIdFrom, messageIdTo})`).

## Implementation plan

### 0. Wire the live chat into SQLite (prerequisite, blocks everything else)

Replace `ChatViewModel` with a new `ColumnsViewModel` (see §3) that persists through `MessageRepository` instead of an in-memory list:
- On `MessageStarted`: keep the existing transient in-memory streaming placeholder (empty content, `isStreaming: true`) — don't persist yet (`Message.isStreaming` doc comment: "transient; false once loaded from storage").
- On `MessageCompleted`: `messages.saveMessage(...)`, then `messages.addReplyEdge(parentId, messageId)` if `parentId != null`.
- On `sendMessage` (content already final): persist immediately, same way, before adding to view state.

**No global "last message" field.** The old `ChatViewModel._lastUserMessageId` doesn't get ported — that's the exact per-column-scoping bug this plan exists to fix, just relocated into the composer instead of the branch pointer. A send from column `C` always targets `C`'s own current bottom message (`ColumnUiState.window`'s last id) as `parentId`. If `C` has no messages yet (a brand-new, anchor-less column — see §3), the send has no parent at all: it's a fresh root message, and that column's anchor gets set to it for the first time.

`main.dart` wiring: construct `AppDatabase()`, `DriftMessageRepository(db)`, `DriftColumnRepository(db)`, `BranchPathService(messages, columns)`; pass into `ColumnsViewModel` alongside the existing `PythonProcessService`/`StitchWsClient`/`ChatRepositoryImpl`. `ColumnsView` (§3) replaces `ChatView` as `NotificationOverlay`'s child. On startup, `ColumnsViewModel` calls `ColumnRepository.getColumns()` to restore whatever columns were persisted (including anchor-less ones) rather than assuming a column always exists — see §3 for the empty-column bootstrapping this requires.

### 1. Windowed loading model in `BranchPathService` (replaces "return the whole branch")

This is the core change driving everything else. Treat vertical traversal (ancestors/descendants) as bounded, paged reads — the local-SQLite analog of stitch-backend's depth-N traversal calls (`fragments.py`) that stitch-frontend fetches in batches — even though a single indexed query could technically return everything. Sibling/parent *candidate pools* at a single fork (`getChildren`/`getParents`) stay unbounded/unpaged, matching stitch-frontend (a fork rarely has more than a handful of candidates); only the **chain length** of a column's rendered thread is windowed.

New shape:

```dart
class BranchWindow {
  final List<Message> messages;   // ordered root-old -> leaf-new, currently loaded
  final bool hasMoreAbove;        // more reply-structural ancestors exist beyond the window
  final bool hasMoreBelow;        // more reply-structural descendants exist beyond the window
  final int stitchAboveCount;     // unloaded stitch parents at the current top boundary (only meaningful once hasMoreAbove is false)
  final int stitchBelowCount;     // unloaded stitch children at the current bottom boundary (only meaningful once hasMoreBelow is false)
}
```

`BranchPathService` methods (replacing `getFullVisibleBranch`'s "walk to true root/leaf" behavior):
- `Future<BranchWindow> loadInitialWindow(String columnId, String anchorMessageId, {int aboveRadius = kDefaultRadius, int belowRadius = kDefaultRadius})` — walk up to `aboveRadius` steps up (via `visibleParent`, defaulting to reply-structural parent, per existing `_visibleOrStructuralParent`) and `belowRadius` steps down (via `visibleChild`, defaulting reply-only — see §1a below), computing the `hasMore*`/`stitch*Count` flags at whichever boundary was hit.
- `Future<BranchWindow> extendAbove(String columnId, String currentTopMessageId, {int batch = kDefaultBatch})` — continues walking up from the current top of the window.
- `Future<BranchWindow> extendBelow(String columnId, String currentBottomMessageId, {int batch = kDefaultBatch})` — continues walking down.
- `Future<BranchWindow> revealStitchAbove(String columnId, String boundaryMessageId)` / `revealStitchBelow(...)` — the "Load stitches (N)" action (see §6): since the combined candidate pool orders stitch entries after reply entries, this is just `navigateToParent`/`navigateToSibling` with `forward: true` from the reply-only boundary (which lands on the first stitch entry) followed by `extendAbove`/`extendBelow` from there for one batch.
- `kDefaultRadius`/`kDefaultBatch` are named constants in `branch_path_service.dart` (e.g. 30) — explicitly documented as "the local-SQLite equivalent of the frontend's depth-5 remote traversal calls," larger because local queries are cheap, but still bounded on purpose so a 10,000-message thread never renders as one Flutter list.

`navigateToSibling`/`navigateToParent` (§2) stop calling `getFullVisibleBranch`. A sibling switch only invalidates the window **below** the switch point (above is untouched — the old messages there are still valid and already loaded); a parent switch only invalidates **above**. Both re-window just the affected side with `loadInitialWindow`-style radius from the switch point and splice it into the existing `BranchWindow`, rather than reloading everything.

**Fork breadth is always fetched whole; only chain depth is paged.** Every step of `loadInitialWindow`/`extendAbove`/`extendBelow` calls `getChildren`/`getParents` at that node to (a) pick the reply-only default to continue walking, and (b) capture the *full* candidate list (reply + stitch, however many of each) for that node's `SiblingNavigator`/`AncestorSwitcher` — one query, not one-candidate-at-a-time. This is also where `stitchAboveCount`/`stitchBelowCount` at a boundary come from: by the time a marker can even render "Load stitches (N)," that query has already run and already knows exactly which N messages they are.

**Both directions are fetched for every message added to the window, not just the walk direction.** Adding a message to the window (either direction) means calling *both* `getChildren(id)` (outgoing: reply + stitch children) and `getParents(id)` (incoming: reply + stitch parents) for it — the walk-direction call drives extension/boundary detection, the other-direction call is what `SiblingNavigator`/`AncestorSwitcher` need if that message also happens to fork on the side we're not currently walking. Both are cheap unpaged queries (previous point), so there's no reason to fetch one lazily-on-render later — a message is never partially loaded. (Implementation note for later: for a `kDefaultBatch`-sized extend this is naively 2×batch queries; worth batching into a single `IN (...)` join per extend call if profiling ever calls for it, not required for correctness.)

#### 1a. Reply-only defaulting (still required, now expressed via windowing)

`_visibleOrDefaultChild`'s current default (most-recent child from the **combined** reply+stitch pool) must become reply-only, via a new `MessageRepository.getReplyChildren(String parentId)` (abstract + drift impl — the drift impl already has this exact query as the private `_replyChildren` helper, `drift_message_repository.dart:111-119`; just expose it). This is what makes `stitchBelowCount`/`stitchAboveCount` meaningful: hitting `hasMoreBelow == false` on the reply-only walk is the real thread boundary, and only past it do stitch neighbors count as "available but not auto-followed" — Surgical Loading, expressed structurally rather than as a one-off UI rule.

#### 1b. Shared message identity, not per-column copies

The data model doc's own framing: "app state is one shared set of loaded messages; each column is a linear path through that same set... the same message may appear in multiple columns." `ColumnsViewModel` must therefore hold **one** shared `Map<String, Message> _messages` cache (populated as messages are loaded/persisted), and `BranchWindow.messages` becomes `List<String> messageIds` — an ordering into that shared cache, not a copy. This matters concretely for streaming: when `MessageCompleted` updates a message's content, or a WS auto-follow (§8) adds one, there's exactly one place to update, and every column currently displaying that id reflects it via the same `notifyListeners()` call — no per-column copy can go stale relative to another.

#### 1c. Cyclic stitch edges are allowed, on purpose

`StitchEdges` "may be cyclic, no write-time validation, matching the backend." Per your call: no cycle guard is added — a stitch walk is allowed to loop back to an already-loaded message, and it's fine for that message to appear more than once in a window's `messageIds`. One implementation consequence: since Flutter widget keys must be unique, list items must be keyed by **position in `messageIds`**, not by message id alone (an id can legitimately repeat in the same window).

### 2. Ancestor-switching in the repository/domain layer (AncestorSwitcher needs this; doesn't exist yet)

`ColumnBranchPointers`' PK is `(columnId, parentId)` with a **unique key on `(columnId, childId)`** — a child can be the visible-child of only one parent per column. `navigateToSibling` never violates this (parent fixed, child changes). Switching a child's *visible parent* (child fixed, parent changes) would try to insert a second row with the same `childId` under a new `parentId` — a unique-constraint violation, since the old `(columnId, oldParentId, childId)` row is still there.

Add:
- `ColumnRepository.setVisibleParent(String columnId, String childId, String newParentId)` — in `DriftColumnRepository`, wrapped in `_db.transaction()`: delete the existing row for `(columnId, childId)` if one exists, then insert `(columnId, newParentId, childId)`.
- `BranchPathService.navigateToParent(String columnId, String childId, {required bool forward})` — symmetric to `navigateToSibling` (`branch_path_service.dart:91-115`): candidates = `_messages.getParents(childId)` (reply parent first, then stitch parents — already implemented), clamp forward/backward against the current `getVisibleParent`, `setVisibleParent`, then re-window above per §1.
- Unit tests mirroring `branch_path_service_test.dart`'s sibling-navigation cases (fork defaulting, clamping, stitch-ordered-after-reply) for the parent direction, plus a repository test asserting the old pointer row is actually deleted (not just shadowed) after a parent switch.

**Forward-compat note (not built now, just confirming the design holds):** if `ReplyEdges`' unique index on `childId` is ever relaxed for multi-parent replies, nothing here changes shape — the automatic/manual line is drawn by **edge type**, never cardinality. Today `_visibleOrDefaultChild` already picks a default among *multiple* reply children (most-recent) and lets `SiblingNavigator` cycle the rest; multi-parent replies would need the identical rule mirrored upward in `_visibleOrStructuralParent` (default to e.g. most-recent reply parent), with `AncestorSwitcher` cycling the rest exactly as it already does for stitch parents. Stitch edges stay manual-only regardless of how many reply parents/children exist.

### 3. Multi-column shell (port of stitch-flutter's `ChatLayoutViewModel` + resizer)

**Schema change: `Columns.anchorMessageId` becomes nullable.** It's currently a non-nullable FK to `Messages` — which makes it impossible to create a column before at least one message exists anywhere (a real problem on a fresh install: zero messages, so zero possible anchors). Per your call, a column is allowed to have no messages at all. `ColumnMeta.anchorMessageId` becomes `String?`, `createColumn({String? anchorMessageId, double? width})` accepts null, and `BranchPathService.loadInitialWindow` returns an empty `BranchWindow` (`messageIds: []`, both `hasMore*` false, both stitch counts 0) when the anchor is null.

**The anchor is a persisted, moving reference point — this is what makes session-restore work with no separate global state.** Whenever a column's window advances at the bottom (a new message sent from it, or WS auto-follow per §8), call `ColumnRepository.updateColumnAnchor(columnId, newestMessageId)`. On the very first message sent into an anchor-less column, this is also what gives it an anchor for the first time. The payoff: restoring a column on app relaunch is nothing but `loadInitialWindow(columnId, persistedAnchor)` using that column's already-persisted branch-pointer rows — the exact same derivation path used everywhere else, including "Load stitches" boundaries reconstructing correctly if that's where the column was left (no special-cased restore logic, no separate "current session" concept, matching how stitch-frontend resumes a thread from persisted `branch_parent`/`branch_child` rather than any client-side session state). This is also why C's fix doesn't need anything extra to support multi-parent replies later: the anchor is just an entry point into the shared message set (§1b) — which specific parent is "above" it in a given column is entirely determined by that column's `ColumnBranchPointers` rows, never by the anchor field itself.

New `lib/ui/columns/columns_viewmodel.dart` (`ColumnsViewModel extends ChangeNotifier`) owns:
- One shared `Map<String, Message> _messages` (§1b) plus:
  ```dart
  class ColumnUiState {
    final String id;
    final double? width;
    final bool isActive;
    final BranchWindow window;       // messageIds + hasMore/stitch flags, from §1
    final MarkerState topMarker;     // derived, see §6
    final MarkerState bottomMarker;
  }
  ```
  backed by `ColumnRepository.getColumns()`/`createColumn`/`deleteColumn`/`updateColumnWidth`/`updateColumnAnchor` and `BranchPathService.loadInitialWindow`/`extendAbove`/`extendBelow`.
- `addColumn({String? anchorMessageId})` — defaults to duplicating the active column's current anchor if one exists, or creates a genuinely empty (anchor-less) column otherwise (one conversation tree in this app; "new column" means "view a different branch of the same tree side by side," not loading a different chat log like stitch-flutter's `originId`/`localPath`). An anchor-less column renders with no messages and no markers until its first send.
- `removeColumn(id)`, `setActiveColumn(id)`, `updateColumnWidth(id, width)` — direct ports of stitch-flutter's equivalents.
- `navigateSibling(columnId, parentId, {forward})` / `navigateParent(columnId, childId, {forward})`, `loadMoreAbove(columnId)` / `loadMoreBelow(columnId)`, `loadStitchAbove(columnId)` / `loadStitchBelow(columnId)` — thin wrappers over `BranchPathService`, updating that column's `window` and `notifyListeners()`. Each sets `topMarker`/`bottomMarker` to `loading` for the duration of the call (see §6).
- The persistence wiring from §0 lives here too, replacing `ChatViewModel`, including the per-column send-target rule (§0) and anchor-advancing above.

New `lib/ui/columns/columns_view.dart` — top-level screen: a `Row` of column widgets with draggable resize handles (port stitch-flutter's `_ColumnResizer` pattern) and an "Add Column" toolbar action. New `lib/ui/columns/column_view.dart` — one column: header (active indicator, close button), message list (with markers, see §6), composer bar when active. Absorbs `chat_view.dart`'s bubble rendering and composer logic; `chat_view.dart`/`chat_viewmodel.dart` get deleted once these fully replace them.

### 4–5. The exclusivity rule: inline navigator vs. boundary marker, never both

Both navigators are adornments on a message that is *currently displayed* — they let you replace that displayed child/parent with a sibling from the same already-fetched pool (§1's "fork breadth fetched whole"). They can only render where a reply-anchored default already put something on screen. So:

- If a parent **has** reply children, one is always auto-displayed (§1a), and `SiblingNavigator` renders on it whenever the combined pool (reply + stitch) has more than one entry — cycling through the rest of the reply children *and* any stitch children, all already known.
- If a parent has **zero** reply children but has stitch children, nothing auto-displays below it at all — there's no bubble for an inline navigator to attach to, no matter whether there's 1 stitch child or 10. That boundary is a marker's job (§6), not the navigator's. Clicking "Load stitches (N)" makes the first stitch candidate the new displayed child; if there was more than one, `SiblingNavigator` now appears on it (nothing else changed — it's the same "pool > 1" rule, just evaluated after the pointer moved).
- Symmetric upward for `AncestorSwitcher`/reply parents/stitch parents.

Net effect: **no separate "unloaded stitch" state is needed on either navigator.** Every pool a navigator can ever show is already fully resolved the instant it's asked for (unpaged query); "unloaded" only exists at the vertical window boundary, which is exclusively `AdaptiveMarker`'s concern. A message is never in both an "inline nav available" and "boundary marker available" state simultaneously in the same direction.

**Worked example (a newly-revealed message can trigger a navigator that couldn't have existed before it loaded):** bottom marker under message `X` reads "End of thread — Load stitches (2)," derived purely from `getChildren(X)` (X's *outgoing* pool — this says nothing about anyone else's parents). Clicking it runs `navigateToSibling(columnId, X.id, forward: true)`, landing on the first stitch child `C`, setting `X` as `C`'s visible parent, and loading `C` into the window — which per the "both directions fetched" rule above also runs `getParents(C)` for the first time ever. If that comes back with more than one entry (say `C` also has its own reply parent), `AncestorSwitcher` now appears on `C`, starting at "Linked origin (1/2)" since `X` occupies that slot in `C`'s pool. This isn't special to stitch-revealed messages — it's true of *any* message the moment it first enters a window (an ordinarily reply-auto-extended message could just as well turn out to have a stitch parent nobody knew about yet); the stitch-reveal case just makes the "before load: unknowable, after load: fully resolved" boundary vivid because it's gated behind a deliberate click instead of an automatic scroll-extend.

### 4. SiblingNavigator (`lib/ui/core/sibling_navigator.dart`)

Shown per message when `getChildren(parentId).length > 1` **and** a reply-anchored child is currently displayed (see exclusivity rule above). Prev/next arrows, calls `ColumnsViewModel.navigateSibling`. Stitch-linked candidates get the same **green tint** stitch-frontend uses for `target-is-stitch` (`SiblingNavigator.vue`) — applied to the arrow/pip when stepping onto a stitch candidate — using the reply-count boundary within the `getChildren` pool to know where stitch entries start (always computable immediately, per §1's fork-breadth-fetched-whole note).

### 5. AncestorSwitcher (`lib/ui/core/ancestor_switcher.dart`)

Port of `LinkSwitcher.vue:67-84`, named `AncestorSwitcher` per your preference. Shown per message when `getParents(childId).length > 1` **and** a reply-anchored parent is currently displayed above it (exclusivity rule above). Prev/next plus the origin pill: "Reply origin" vs green-tinted "Linked origin (i/total)" — same green treatment as `SiblingNavigator`'s stitch styling, matching stitch-frontend's origin-transparency intent (a node's upward context came via a stitch, not a reply). Calls `ColumnsViewModel.navigateParent`.

### 6. AdaptiveMarker (`lib/ui/core/adaptive_marker.dart`)

Sentinel at column list top/bottom, states `waiting | loading | end | error` — state is computed in `ColumnsViewModel`/`ColumnUiState` from the `BranchWindow`, not in the widget (mirrors stitch-frontend's split: marker is presentational, `ThreadView.vue`'s `topMarkerState`/`bottomMarkerState` computed properties own the logic). Per the exclusivity rule in §4–5, this is the *only* place "there are stitch messages you haven't seen yet" gets surfaced — it only ever applies at a true reply dead-end (zero reply children/parents), which is exactly when no inline navigator could have shown that count instead:

| Window state | Marker state | Behavior |
|---|---|---|
| `hasMoreAbove/Below == true`, not currently loading | `waiting` | Visibility/intersection check (Flutter analog of `IntersectionObserver`, ~200px trigger margin) auto-calls `loadMoreAbove`/`loadMoreBelow` once per waiting cycle |
| an `extendAbove`/`extendBelow`/`revealStitch*` call in flight | `loading` | Spinner, no auto-trigger |
| `hasMore == false`, stitch count == 0 | `end` | "Beginning/End of thread," no auto-trigger |
| `hasMore == false`, stitch count > 0 | `end` + `stitchCount` prop | "Beginning/End of thread" **plus** a "Load stitches (N)" button (port of `AdaptiveMarker.vue`'s `main`-branch `stitchCount` prop) — calls `loadStitchAbove`/`loadStitchBelow`, never auto-triggered (Surgical Loading, deliberate friction) |
| last query threw | `error` | Message + Retry button, no auto-trigger |

Note: since `MessageRepository` is local SQLite today, `loading` will typically resolve near-instantly and `error` will be rare — but the state machine and the `MessageRepository` interface boundary are built as if backed by a real remote traversal API (the north star), so swapping in cloud sync later is a repository-implementation change, not a UI/state-machine change.

### 7. Scroll stability ("eye-tracking fix")

`extendAbove`/`revealStitchAbove` (prepending above) and both navigate-and-rewindow operations (§1/§2) must not visually jump. Use the `scrollable_positioned_list` package (new dependency) in `column_view.dart` instead of hand-rolling pixel-offset capture/restore like `loadMoreParents` (`ThreadView.vue:1266`) — its `itemScrollController`/`itemPositionsListener` are index-based, which is a more robust fit for Flutter than replicating the Vue pixel-math approach, and composes naturally with windowed batches from §1 (each extend/reveal call just prepends/appends a bounded slice to the index list).

### 8. WS auto-follow

In `ColumnsViewModel`'s event handler (§0): after persisting a new message into the shared cache (§1b), if its parent currently has no `visibleChild` set *for a given column* (`ColumnRepository.getVisibleChild`), auto-advance that column via `setBranchPointer`, append the new message's id to that column's `BranchWindow.messageIds` directly (no need to re-window), and call `updateColumnAnchor` (§3) to move that column's persisted anchor forward — port of `ThreadView.vue`'s `handleIncomingWsMessage` auto-follow rule, scoped per-column rather than global.

### 9. Stitch-edge creation UI

Nothing writes `StitchEdges` today even though `MessageRepository.addStitchEdge` already exists (`drift_message_repository.dart:84-93`) — without a way to create them, AncestorSwitcher/sibling-stitch-styling/"Load stitches" have nothing to show. Port a trimmed version of stitch-frontend's `LinksModal.vue`: a modal opened from a message (`lib/ui/core/links_modal.dart`) with a searchable list of existing messages (simple content/id filter via `MessageRepository`, no need for the Vue version's "mine vs all" toggle) and an incoming/outgoing choice. Selecting a target calls `addStitchEdge(fromId, toId)`. Minimal creation affordance only — not a port of the full `GraphView`/`StitchPlaygroundView` graph canvas (out of scope, below).

## Explicitly out of scope for this plan

- **Component 5 (filesystem JSON mirror)** — independent, can land anytime per the doc's own sequencing note.
- **Cloud sync / remote backend** — the windowed `BranchPathService`/`MessageRepository` interface from §1 is the seam for it; nothing here precludes it, that's the point of the north star.
- **Full graph canvas** (`GraphView.vue`/`StitchPlaygroundView.vue` equivalent) — only the minimal link-creation modal (§9).
- **Multi-parent reply edges** (relaxing `ReplyEdges`' unique index on `childId`) — stitch edges already cover "multiple ancestors" for this port.

## Verification

- `flutter test` — existing `test/domain/branch_path_service_test.dart`, `test/data/repositories/drift_column_repository_test.dart`, `drift_message_repository_test.dart` must keep passing; add cases for `loadInitialWindow`/`extendAbove`/`extendBelow` (radius/batch boundaries, `hasMore*`/`stitch*Count` correctness, a null-anchor column returning an empty window), `navigateToParent`, `setVisibleParent`'s old-row deletion, `getReplyChildren`, reply-only defaulting, and a stitch cycle producing a repeated id across two window positions without hanging or crashing.
- Widget tests for `SiblingNavigator`/`AncestorSwitcher` pool math (reply-first ordering, count-based visibility, position-keyed list items tolerating a duplicate id) and `AdaptiveMarker`'s state→rendering table above, using fake repositories.
- A restore test: persist a column with a non-null anchor and some `ColumnBranchPointers` rows (including one crossing a stitch edge), simulate relaunch by constructing a fresh `ColumnsViewModel` against the same `AppDatabase`, and confirm the restored window matches without any extra input.
- Manual run (`flutter run -d linux`/`macos`, boots `python-server` via `PythonProcessService`): regenerate a bot response at least twice to create sibling branches, confirm `SiblingNavigator` arrows appear and switch branches live; set a small `kDefaultRadius`/`kDefaultBatch` temporarily and confirm `AdaptiveMarker` shows `waiting`→`loading`→more-messages on scroll, and `end` at true boundaries; open the link modal on two messages in different columns to create a stitch edge, confirm `AncestorSwitcher`'s "Linked origin" pill appears and cycling works, and confirm the boundary marker switches from plain "end" to "Load stitches (N)"; add a column with no anchor, confirm it renders empty until its first send; quit and relaunch the app, confirm every column resumes exactly where it was; add/remove/resize columns and confirm each renders an independent, independently-windowed branch of the same tree.
