import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/message.dart';
import '../../data/repositories/column_repository.dart';
import '../../data/repositories/message_repository.dart';
import '../../data/services/local_identity_service.dart';
import '../../domain/branch_path_service.dart';
import '../../domain/message_store.dart';
import '../core/adaptive_marker.dart';
import 'column_ui_state.dart';

/// How many hops [ColumnsViewModel.loadInitialWindow] resolves in each
/// direction when a column shows an anchor it hasn't materialized before.
const kDefaultRadius = 20;

/// How many hops [ColumnsViewModel.extendAbove]/[extendBelow]/[revealStitch]
/// resolve per batch.
const kDefaultBatch = 20;

/// Owns the multi-column shell: column CRUD/resize/active-selection, and
/// per-column derivation of the currently-displayed branch plus navigator/
/// marker state, via [BranchPathService]/[MessageStore]/[MessageRepository]/
/// [ColumnRepository]. Per `docs/plans/message-loading-plan.md`, this is
/// where the "hop" primitive ([selectCandidate]) and its batching
/// ([defaultPage]) live — [BranchPathService] stays pure resolution/reads,
/// this class owns persistence and the `ChangeNotifier`/loading-marker
/// state that comes with it.
class ColumnsViewModel extends ChangeNotifier {
  ColumnsViewModel(
    this._messages,
    this._columns,
    this._branchPathService,
    this._store,
    this._identity,
  );

  final MessageRepository _messages;
  final ColumnRepository _columns;
  final BranchPathService _branchPathService;
  final MessageStore _store;
  final LocalIdentityService _identity;
  static const _uuid = Uuid();

  final List<ColumnUiState> _states = [];
  final Map<String, String?> _anchors = {};

  List<ColumnUiState> get columns => List.unmodifiable(_states);

  /// Who "You" refers to in the UI — resolves to the cloud user id once
  /// cloud auth exists, but is always answerable locally in the meantime.
  String get currentUserId => _identity.currentUserId;

  String? anchorOf(String columnId) => _anchors[columnId];

  Future<void> initialize() async {
    final metas = await _columns.getColumns();
    for (final meta in metas) {
      _anchors[meta.id] = meta.anchorMessageId;
      _states.add(
        ColumnUiState(
          id: meta.id,
          width: meta.width,
          initialScrollOffset: meta.scrollOffset,
        ),
      );
    }
    if (_states.isNotEmpty) _states.first.isActive = true;
    for (final state in _states) {
      await _refresh(state.id, isFreshAnchor: true);
    }
    notifyListeners();
  }

  Future<void> addColumn({String? anchorMessageId, double? width}) async {
    final meta = await _columns.createColumn(
      anchorMessageId: anchorMessageId,
      width: width,
    );
    _anchors[meta.id] = meta.anchorMessageId;
    for (final state in _states) {
      state.isActive = false;
    }
    _states.add(ColumnUiState(id: meta.id, width: meta.width, isActive: true));
    notifyListeners();
    await _refresh(meta.id, isFreshAnchor: true);
    notifyListeners();
  }

  Future<void> removeColumn(String id) async {
    await _columns.deleteColumn(id);
    final wasActive = _states.firstWhere((s) => s.id == id).isActive;
    _states.removeWhere((s) => s.id == id);
    _anchors.remove(id);
    if (wasActive && _states.isNotEmpty) {
      _states.first.isActive = true;
    }
    notifyListeners();
  }

  void setActiveColumn(String id) {
    for (final state in _states) {
      state.isActive = state.id == id;
    }
    notifyListeners();
  }

  Future<void> updateColumnWidth(String id, double? width) async {
    await _columns.updateColumnWidth(id, width);
    _stateFor(id).width = width;
    notifyListeners();
  }

  /// Straight-through, non-notifying write for debounced scroll-position
  /// persistence — the caller ([_MessageListState] in column_view.dart) owns
  /// the debounce timer; this is just the atomic (single-row) DB write it
  /// targets. Deliberately skips `notifyListeners()`: scroll position isn't
  /// part of any widget's build output, and firing on every debounced save
  /// would rebuild the whole column tree for nothing.
  Future<void> updateColumnScrollOffset(String id, double? scrollOffset) {
    return _columns.updateColumnScrollOffset(id, scrollOffset);
  }

  /// The single hop primitive — the only function that ever moves a branch
  /// pointer (`docs/plans/message-loading-plan.md` §3). Sets the direction's
  /// loading marker, hydrates [chosenId] via [MessageStore], persists the
  /// pointer, then clears the marker. Used identically by [defaultPage]'s
  /// automatic hops, [revealStitch]'s forced hop, and navigator-driven
  /// explicit picks ([navigateOutgoing]/[navigateIncoming]) — only how
  /// [chosenId] was picked differs per caller.
  Future<void> selectCandidate(
    String columnId,
    String boundaryId,
    String chosenId,
    Direction direction,
  ) async {
    final state = _stateFor(columnId);
    _setLoading(state, direction, true);
    notifyListeners();
    await _store.load(chosenId);
    if (direction == Direction.outgoing) {
      await _columns.setBranchPointer(columnId, boundaryId, chosenId);
    } else {
      await _columns.setVisibleIncoming(columnId, boundaryId, chosenId);
    }
    _setLoading(state, direction, false);
    notifyListeners();
  }

  /// The only DB-loading/batching primitive. Resolves up to [batchSize] hops
  /// from [boundaryId] in [direction]: walks any already-persisted pointer
  /// for free, and only invokes [BranchPathService.resolveDefaultCandidate]
  /// (persisting via [selectCandidate]) once the walk reaches genuinely
  /// unset territory. Stops early at a stitch boundary (`hasMore: false`,
  /// `stitchCount` set — never auto-triggered, this is what "Load stitches
  /// (N)" renders) or a true end (`stitchCount: 0`).
  Future<PageResult> defaultPage(
    String columnId,
    String boundaryId,
    Direction direction,
    int batchSize,
  ) async {
    final messages = <Message>[];
    for (var i = 0; i < batchSize; i++) {
      final existing = direction == Direction.outgoing
          ? await _columns.getVisibleOutgoing(columnId, boundaryId)
          : await _columns.getVisibleIncoming(columnId, boundaryId);
      if (existing != null) {
        final message = await _store.load(existing);
        if (message == null) break;
        messages.add(message);
        boundaryId = message.id;
        continue;
      }

      final replyCandidate = await _branchPathService.resolveDefaultCandidate(
        boundaryId,
        direction,
      );
      if (replyCandidate == null) {
        final stitches = (await _branchPathService.candidatesAt(
          boundaryId,
          direction,
        )).stitchCandidates;
        return PageResult(
          messages: messages,
          hasMore: false,
          stitchCount: stitches.length,
        );
      }

      await selectCandidate(columnId, boundaryId, replyCandidate.id, direction);
      messages.add(replyCandidate);
      boundaryId = replyCandidate.id;
    }
    return PageResult(messages: messages, hasMore: true, stitchCount: 0);
  }

  /// Establishes the initial windowed view for a column showing an anchor
  /// it hasn't materialized before: [kDefaultRadius] hops of [defaultPage]
  /// in each direction from [anchorId]. Not a separate traversal — pure
  /// composition, kept as a named entry point only because it's a distinct
  /// `_refresh` trigger condition (a fresh anchor with nothing materialized).
  Future<void> loadInitialWindow(String columnId, String anchorId) async {
    await _store.load(anchorId);
    await defaultPage(columnId, anchorId, Direction.incoming, kDefaultRadius);
    await defaultPage(columnId, anchorId, Direction.outgoing, kDefaultRadius);
  }

  /// One forced hop across a stitch boundary (`AdaptiveMarker`'s "Load
  /// stitches (N)" action), then resumes the ordinary [defaultPage] loop
  /// from the new boundary to fill out the rest of the batch. Not a
  /// separate mode — one resolution override, then falls back into the
  /// ordinary loop.
  Future<void> revealStitch(
    String columnId,
    String boundaryId,
    Direction direction,
  ) async {
    final state = _stateFor(columnId);
    _setError(state, direction, null);
    try {
      final stitch = await _branchPathService.resolveForcedStitchCandidate(
        boundaryId,
        direction,
      );
      if (stitch == null) return;
      await selectCandidate(columnId, boundaryId, stitch.id, direction);
      await defaultPage(columnId, stitch.id, direction, kDefaultBatch);
    } catch (e) {
      _setError(state, direction, e.toString());
    } finally {
      await _refresh(columnId);
      notifyListeners();
    }
  }

  /// `AdaptiveMarker`'s scroll-proximity auto-trigger for the top/bottom
  /// "waiting" state: one [defaultPage] batch from the column's current
  /// top/bottom boundary.
  Future<void> extendAbove(String columnId) =>
      _extend(columnId, Direction.incoming);
  Future<void> extendBelow(String columnId) =>
      _extend(columnId, Direction.outgoing);

  Future<void> _extend(String columnId, Direction direction) async {
    final state = _stateFor(columnId);
    if (state.rows.isEmpty) return;
    final boundaryId = direction == Direction.incoming
        ? state.rows.first.message.id
        : state.rows.last.message.id;
    _setError(state, direction, null);
    try {
      await defaultPage(columnId, boundaryId, direction, kDefaultBatch);
    } catch (e) {
      _setError(state, direction, e.toString());
    } finally {
      await _refresh(columnId);
      notifyListeners();
    }
  }

  void _setLoading(ColumnUiState state, Direction direction, bool value) {
    if (direction == Direction.incoming) {
      state.topLoading = value;
    } else {
      state.bottomLoading = value;
    }
  }

  void _setError(ColumnUiState state, Direction direction, String? message) {
    if (direction == Direction.incoming) {
      state.topError = message;
    } else {
      state.bottomError = message;
    }
  }

  /// Re-derives the column's branch from [parentId] itself rather than the
  /// column's original anchor once navigation has moved past it: [parentId]
  /// is safe to anchor on directly because its own upward context is
  /// untouched by this call, and its downward pointer was *just* set to the
  /// new child by [selectCandidate], so re-deriving from here (via
  /// `_refresh`'s ordinary `materializedTrajectory` walk) picks up that
  /// fresh pointer instead of recomputing a stale default.
  Future<void> navigateOutgoing(
    String columnId,
    String parentId, {
    required bool forward,
  }) async {
    final chosenId = await _branchPathService.resolveExplicitOutgoing(
      columnId,
      parentId,
      forward: forward,
    );
    if (chosenId != null) {
      await selectCandidate(columnId, parentId, chosenId, Direction.outgoing);
    }
    await _columns.updateColumnAnchor(columnId, parentId);
    _anchors[columnId] = parentId;
    await _refresh(columnId);
    notifyListeners();
  }

  /// Mirrors [navigateOutgoing]'s anchor-move for the upward direction:
  /// [childId] is safe to re-anchor on because its own downward pointer is
  /// untouched and [selectCandidate] just set its upward pointer to the new
  /// parent, so re-deriving from [childId] follows that fresh pointer
  /// instead of walking back down from the column's stale original anchor.
  Future<void> navigateIncoming(
    String columnId,
    String childId, {
    required bool forward,
  }) async {
    final chosenId = await _branchPathService.resolveExplicitIncoming(
      columnId,
      childId,
      forward: forward,
    );
    if (chosenId != null) {
      await selectCandidate(columnId, childId, chosenId, Direction.incoming);
    }
    await _columns.updateColumnAnchor(columnId, childId);
    _anchors[columnId] = childId;
    await _refresh(columnId);
    notifyListeners();
  }

  /// Marks [messageId] as the parent the next [sendMessage] call in
  /// [columnId] should reply under, overriding the default bottom-row
  /// target — set by a message's "reply to" action. Pass `null` to cancel
  /// and fall back to the default. Also activates [columnId]: replying is
  /// only actionable through the active column's composer, so triggering it
  /// from a non-active column (another visible branch) must switch focus
  /// there, same as clicking the column itself would.
  void setReplyTarget(String columnId, String? messageId) {
    for (final state in _states) {
      state.isActive = state.id == columnId;
    }
    _stateFor(columnId).replyingToMessageId = messageId;
    notifyListeners();
  }

  /// Sends [content] as a reply under [columnId]'s pending reply target
  /// ([ColumnUiState.replyingToMessageId], set via [setReplyTarget]) if one
  /// is set, otherwise under the column's current bottom message (or as a
  /// fresh root if the column has no messages yet). Forking under a
  /// non-terminal target is a single [ColumnRepository.setBranchPointer]
  /// call away from also becoming the visible branch: that table is
  /// uniquely keyed on `(columnId, parentId)`, so pointing the fork
  /// message's pointer at the new message atomically both creates the
  /// branch and switches the column to it — no separate rewrite step is
  /// needed for ancestors, which are untouched, or for the new leaf, which
  /// has no descendants yet. Advances the column's persisted anchor to the
  /// new message either way — per column-ui-impl-plan.md §3, "the anchor is
  /// a persisted, moving reference point."
  Future<void> sendMessage(String columnId, String content) async {
    if (content.trim().isEmpty) return;
    final state = _stateFor(columnId);
    final parentId =
        state.replyingToMessageId ??
        (state.rows.isNotEmpty ? state.rows.last.message.id : null);
    final newMessage = Message(
      id: _uuid.v4(),
      role: MessageRole.user,
      authorId: _identity.currentUserId,
      content: content,
      createdAt: DateTime.now().toUtc(),
    );
    await _messages.saveMessage(newMessage);

    if (parentId != null) {
      await _messages.addReplyEdge(parentId, newMessage.id);
      await _columns.setBranchPointer(columnId, parentId, newMessage.id);
    }

    state.replyingToMessageId = null;
    await _columns.updateColumnAnchor(columnId, newMessage.id);
    _anchors[columnId] = newMessage.id;
    await _refresh(columnId);
    notifyListeners();
  }

  ColumnUiState _stateFor(String id) => _states.firstWhere((s) => s.id == id);

  Future<void> _refresh(String columnId, {bool isFreshAnchor = false}) async {
    final state = _stateFor(columnId);
    final anchorId = _anchors[columnId];

    if (anchorId == null) {
      state.rows = const [];
      state.topMarker = MarkerVisualState.end;
      state.bottomMarker = MarkerVisualState.end;
      state.topStitchCount = 0;
      state.bottomStitchCount = 0;
      return;
    }

    if (isFreshAnchor) {
      await loadInitialWindow(columnId, anchorId);
    }

    final branch = await _branchPathService.materializedTrajectory(
      columnId,
      anchorId,
    );

    final rows = <MessageRowData>[];
    for (var i = 0; i < branch.length; i++) {
      final message = branch[i];

      // The outgoing pool belongs to the parent (previous row) — this
      // message just occupies one slot in it — but per stitch-frontend's
      // SiblingNavigator (mounted on the child with the parent passed in
      // only for lookup), the navigator itself attaches to *this* row.
      OutgoingEdges? outgoing;
      var outgoingIndex = -1;
      String? outgoingAnchorId;
      if (i > 0) {
        final parent = branch[i - 1];
        outgoing = await _messages.getOutgoing(parent.id);
        outgoingIndex = outgoing.all.indexWhere((m) => m.id == message.id);
        outgoingAnchorId = parent.id;
      }

      IncomingEdges? incoming;
      var incomingIndex = -1;
      if (i > 0) {
        incoming = await _messages.getIncoming(message.id);
        incomingIndex = incoming.all.indexWhere(
          (m) => m.id == branch[i - 1].id,
        );
      }

      rows.add(
        MessageRowData(
          message: message,
          outgoing: outgoing,
          outgoingCurrentIndex: outgoingIndex,
          outgoingAnchorId: outgoingAnchorId,
          incoming: incoming,
          incomingCurrentIndex: incomingIndex,
        ),
      );
    }
    state.rows = rows;

    if (branch.isEmpty) {
      state.topMarker = MarkerVisualState.end;
      state.bottomMarker = MarkerVisualState.end;
      state.topStitchCount = 0;
      state.bottomStitchCount = 0;
      return;
    }

    final top = await _branchPathService.candidatesAt(
      branch.first.id,
      Direction.incoming,
    );
    state.topStitchCount = top.stitchCandidates.length;
    state.topMarker = top.replyCandidate != null
        ? MarkerVisualState.waiting
        : MarkerVisualState.end;

    final bottom = await _branchPathService.candidatesAt(
      branch.last.id,
      Direction.outgoing,
    );
    state.bottomStitchCount = bottom.stitchCandidates.length;
    state.bottomMarker = bottom.replyCandidate != null
        ? MarkerVisualState.waiting
        : MarkerVisualState.end;
  }
}

/// Result of one [ColumnsViewModel.defaultPage] batch.
class PageResult {
  final List<Message> messages;
  final bool hasMore;
  final int stitchCount;
  const PageResult({
    required this.messages,
    required this.hasMore,
    required this.stitchCount,
  });
}
