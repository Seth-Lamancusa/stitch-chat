import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/message.dart';
import '../../data/repositories/column_repository.dart';
import '../../data/repositories/message_repository.dart';
import '../../data/services/local_identity_service.dart';
import '../../domain/branch_path_service.dart';
import '../core/adaptive_marker.dart';
import 'column_ui_state.dart';

/// Owns the multi-column shell: column CRUD/resize/active-selection, and
/// per-column derivation of the currently-displayed branch plus navigator/
/// marker state, via [BranchPathService]/[MessageRepository]/
/// [ColumnRepository]. A thin wrapper over those, per
/// `docs/flutter-best-practices.md`'s MVVM split — no traversal logic lives
/// here, only orchestration + persistence of "which column is active".
///
/// Not yet doing §1's windowed loading (`BranchWindow`/radius/batch) from
/// the column-ui-impl-plan — `BranchPathService.getFullVisibleBranch` still
/// resolves the whole branch in one walk. For the seeded test threads this
/// app ships with, that's an acceptable stand-in: it exercises the same
/// navigator/marker/persistence logic end-to-end, just without pagination.
class ColumnsViewModel extends ChangeNotifier {
  ColumnsViewModel(this._messages, this._columns, this._branchPathService, this._identity);

  final MessageRepository _messages;
  final ColumnRepository _columns;
  final BranchPathService _branchPathService;
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
      _states.add(ColumnUiState(id: meta.id, width: meta.width, initialScrollOffset: meta.scrollOffset));
    }
    if (_states.isNotEmpty) _states.first.isActive = true;
    for (final state in _states) {
      await _refresh(state.id);
    }
    notifyListeners();
  }

  Future<void> addColumn({String? anchorMessageId, double? width}) async {
    final meta = await _columns.createColumn(anchorMessageId: anchorMessageId, width: width);
    _anchors[meta.id] = meta.anchorMessageId;
    for (final state in _states) {
      state.isActive = false;
    }
    _states.add(ColumnUiState(id: meta.id, width: meta.width, isActive: true));
    notifyListeners();
    await _refresh(meta.id);
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

  /// Re-derives the column's branch from [parentId] itself rather than the
  /// column's original anchor once navigation has moved past it: `_refresh`
  /// walks the *whole* branch outward from whatever anchor it's given, and
  /// for any unset fork along the way it persists a fresh default pointer
  /// (`BranchPathService._visibleOrDefaultOutgoing`). Re-deriving from the
  /// stale original anchor would walk back down through [parentId] and
  /// re-assert its old default child — colliding with the switch we just
  /// made, since `ColumnBranchPointers` has a unique key on childId (one
  /// row serves both "this parent's visible child" and "this child's
  /// visible parent"), silently reverting it. [parentId] is safe to anchor
  /// on directly: its own upward context is untouched by this call, and its
  /// downward pointer was *just* set to the new child by
  /// [BranchPathService.navigateOutgoing], so re-deriving from here walks
  /// through that fresh pointer instead of recomputing a stale default.
  Future<void> navigateOutgoing(String columnId, String parentId, {required bool forward}) async {
    await _branchPathService.navigateOutgoing(columnId, parentId, forward: forward);
    await _columns.updateColumnAnchor(columnId, parentId);
    _anchors[columnId] = parentId;
    await _refresh(columnId);
    notifyListeners();
  }

  /// Mirrors [navigateOutgoing]'s anchor-move for the upward direction:
  /// [childId] is safe to re-anchor on because its own downward pointer is
  /// untouched and [BranchPathService.navigateIncoming] just set its
  /// upward pointer to the new parent, so re-deriving from [childId]
  /// follows that fresh pointer instead of walking back down from the
  /// column's stale original anchor and re-asserting (and thereby
  /// reverting) the old one.
  Future<void> navigateIncoming(String columnId, String childId, {required bool forward}) async {
    await _branchPathService.navigateIncoming(columnId, childId, forward: forward);
    await _columns.updateColumnAnchor(columnId, childId);
    _anchors[columnId] = childId;
    await _refresh(columnId);
    notifyListeners();
  }

  Future<void> loadStitchAbove(String columnId) async {
    final state = _stateFor(columnId);
    if (state.rows.isEmpty) return;
    state.topLoading = true;
    notifyListeners();
    try {
      await _branchPathService.navigateIncoming(columnId, state.rows.first.message.id, forward: true);
      await _refresh(columnId);
    } catch (e) {
      state.topError = e.toString();
    } finally {
      state.topLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadStitchBelow(String columnId) async {
    final state = _stateFor(columnId);
    if (state.rows.isEmpty) return;
    state.bottomLoading = true;
    notifyListeners();
    try {
      await _branchPathService.navigateOutgoing(columnId, state.rows.last.message.id, forward: true);
      await _refresh(columnId);
    } catch (e) {
      state.bottomError = e.toString();
    } finally {
      state.bottomLoading = false;
      notifyListeners();
    }
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
    final parentId = state.replyingToMessageId ?? (state.rows.isNotEmpty ? state.rows.last.message.id : null);
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

  Future<void> _refresh(String columnId) async {
    final state = _stateFor(columnId);
    final anchorId = _anchors[columnId];
    final branch = anchorId == null ? const <Message>[] : await _branchPathService.getFullVisibleBranch(columnId, anchorId);

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
        incomingIndex = incoming.all.indexWhere((m) => m.id == branch[i - 1].id);
      }

      rows.add(MessageRowData(
        message: message,
        outgoing: outgoing,
        outgoingCurrentIndex: outgoingIndex,
        outgoingAnchorId: outgoingAnchorId,
        incoming: incoming,
        incomingCurrentIndex: incomingIndex,
      ));
    }
    state.rows = rows;

    if (branch.isEmpty) {
      state.topMarker = MarkerVisualState.end;
      state.bottomMarker = MarkerVisualState.end;
      state.topStitchCount = 0;
      state.bottomStitchCount = 0;
      return;
    }

    // getFullVisibleBranch always walks reply ancestry/descent to
    // completion (no windowing yet, see class doc) — so the top of the
    // branch is always a true reply root and the bottom a true reply leaf.
    // Any stitch neighbors there are exactly the boundary case the marker
    // needs to surface.
    final topIncoming = await _messages.getIncoming(branch.first.id);
    state.topStitchCount = topIncoming.stitchedIncoming.length;
    state.topMarker = MarkerVisualState.end;

    final bottomOutgoing = await _messages.getOutgoing(branch.last.id);
    state.bottomStitchCount = bottomOutgoing.stitchedOutgoing.length;
    state.bottomMarker = MarkerVisualState.end;
  }
}
