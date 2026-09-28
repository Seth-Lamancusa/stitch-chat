import '../data/models/message.dart';
import '../data/repositories/column_repository.dart';
import '../data/repositories/message_repository.dart';
import 'message_store.dart';

/// Which edge direction a boundary operation targets: `incoming` walks
/// upward (ancestors, the top of a column), `outgoing` walks downward
/// (descendants, the bottom) — matches `ColumnUiState.topLoading`/
/// `bottomLoading` naming throughout (incoming = top, outgoing = bottom).
enum Direction { incoming, outgoing }

/// The reply-candidate/stitch-candidate split at one boundary message, in
/// one direction. [replyCandidate] is the single default-eligible reply
/// child/parent (most-recent for outgoing, the 0-1 reply parent for
/// incoming); [stitchCandidates] is never auto-followed — see
/// `docs/plans/message-loading-plan.md` §4a/§4b.
typedef BoundaryCandidates = ({
  Message? replyCandidate,
  List<Message> stitchCandidates,
});

/// Pure resolution and reads over the conversation tree + a column's
/// persisted branch pointers. Per `docs/plans/message-loading-plan.md`, this
/// class never mutates `ColumnUiState` or calls `notifyListeners` — that
/// orchestration (loading markers, persistence choreography) lives in
/// `ColumnsViewModel`. This class answers "what's the next candidate?" and
/// "what does the column currently show?"; it never decides to load more.
class BranchPathService {
  BranchPathService(this._messages, this._columns, this._store);

  final MessageRepository _messages;
  final ColumnRepository _columns;
  final MessageStore _store;

  /// [columnId]'s currently-materialized branch around [anchorMessageId]:
  /// walks `ColumnBranchPointers` only, both directions, stopping at the
  /// first unset pointer in each direction. No resolution logic, no
  /// fallback, no writes — a pure pointer read. Returns an empty list if
  /// [anchorMessageId] doesn't exist.
  Future<List<Message>> materializedTrajectory(
    String columnId,
    String anchorMessageId,
  ) async {
    final anchor = await _store.load(anchorMessageId);
    if (anchor == null) return const [];

    final above = <Message>[];
    var currentId = anchorMessageId;
    while (true) {
      final parentId = await _columns.getVisibleIncoming(columnId, currentId);
      if (parentId == null) break;
      final parent = await _store.load(parentId);
      if (parent == null) break;
      above.insert(0, parent);
      currentId = parentId;
    }

    final below = <Message>[anchor];
    currentId = anchorMessageId;
    while (true) {
      final childId = await _columns.getVisibleOutgoing(columnId, currentId);
      if (childId == null) break;
      final child = await _store.load(childId);
      if (child == null) break;
      below.add(child);
      currentId = childId;
    }

    return [...above, ...below];
  }

  /// The reply/stitch candidate pools at [boundaryId] in [direction] — one
  /// `getOutgoing`/`getIncoming` call, split into the single default-eligible
  /// reply candidate and the stitch pool. Shared by [resolveDefaultCandidate],
  /// [resolveForcedStitchCandidate], and the column marker/stitch-count
  /// computation in `ColumnsViewModel._refresh`.
  Future<BoundaryCandidates> candidatesAt(
    String boundaryId,
    Direction direction,
  ) async {
    if (direction == Direction.outgoing) {
      final outgoing = await _messages.getOutgoing(boundaryId);
      return (
        replyCandidate: outgoing.replyOutgoing.isEmpty
            ? null
            : _mostRecentOf(outgoing.replyOutgoing),
        stitchCandidates: outgoing.stitchedOutgoing,
      );
    }
    final incoming = await _messages.getIncoming(boundaryId);
    return (
      replyCandidate: incoming.replyIncoming.isEmpty
          ? null
          : incoming.replyIncoming.first,
      stitchCandidates: incoming.stitchedIncoming,
    );
  }

  /// The automatic default candidate at an unset [boundaryId] boundary:
  /// reply-only, most-recent. **Never** considers stitch candidates — an
  /// unset fork should never silently auto-follow into stitch-linked
  /// content (Surgical Loading).
  Future<Message?> resolveDefaultCandidate(
    String boundaryId,
    Direction direction,
  ) async {
    return (await candidatesAt(boundaryId, direction)).replyCandidate;
  }

  /// The forced-stitch candidate for a "Load stitches" action at
  /// [boundaryId]: the first stitch candidate, regardless of load state —
  /// Surgical Loading has no load-state exception, the click is always
  /// required at a stitch boundary.
  Future<Message?> resolveForcedStitchCandidate(
    String boundaryId,
    Direction direction,
  ) async {
    final stitches = (await candidatesAt(
      boundaryId,
      direction,
    )).stitchCandidates;
    return stitches.isEmpty ? null : stitches.first;
  }

  /// The next/previous candidate id in [columnId]'s outgoing pool below
  /// [parentId] (reply children first, then stitch children — the full
  /// combined pool: an explicit switch is user-driven and allowed to cross
  /// into stitch-linked content, unlike automatic default selection).
  /// Clamps at either end rather than wrapping. Pure read — no persistence.
  Future<String?> resolveExplicitOutgoing(
    String columnId,
    String parentId, {
    required bool forward,
  }) async {
    final candidates = (await _messages.getOutgoing(parentId)).all;
    if (candidates.isEmpty) return null;

    final currentChildId = await _columns.getVisibleOutgoing(
      columnId,
      parentId,
    );
    final currentIndex = candidates.indexWhere((m) => m.id == currentChildId);

    final nextIndex = currentIndex == -1
        ? (forward ? 0 : candidates.length - 1)
        : (forward ? currentIndex + 1 : currentIndex - 1).clamp(
            0,
            candidates.length - 1,
          );

    return candidates[nextIndex].id;
  }

  /// Mirrors [resolveExplicitOutgoing] for the incoming pool above
  /// [childId] (reply parent first, then stitch parents).
  Future<String?> resolveExplicitIncoming(
    String columnId,
    String childId, {
    required bool forward,
  }) async {
    final candidates = (await _messages.getIncoming(childId)).all;
    if (candidates.isEmpty) return null;

    final currentParentId = await _columns.getVisibleIncoming(
      columnId,
      childId,
    );
    final currentIndex = candidates.indexWhere((m) => m.id == currentParentId);

    final nextIndex = currentIndex == -1
        ? (forward ? 0 : candidates.length - 1)
        : (forward ? currentIndex + 1 : currentIndex - 1).clamp(
            0,
            candidates.length - 1,
          );

    return candidates[nextIndex].id;
  }

  /// Descends via the most-recent immediate child at each fork (no
  /// column/persistence involved — a pure structural query) until a leaf is
  /// reached.
  Future<Message> findLatestDescendant(String messageId) async {
    var current = await _messages.getMessage(messageId);
    if (current == null) {
      throw ArgumentError.value(messageId, 'messageId', 'Message not found');
    }

    while (true) {
      final outgoing = (await _messages.getOutgoing(current!.id)).all;
      if (outgoing.isEmpty) return current;
      current = _mostRecentOf(outgoing);
    }
  }

  /// Whether [childId] is (or will be) the visible outgoing under [parentId]
  /// in [columnId] — the stitch-frontend `parent.branch_child === id` check.
  ///
  /// An unset pointer counts as on-path only for the default non-hidden
  /// reply pick (most recent). Hidden-only children are never on-path until
  /// an explicit reveal / sibling navigation sets a pointer.
  Future<bool> isNextOnVisibleOutgoing(
    String columnId,
    String parentId,
    String childId,
  ) async {
    final visibleChildId = await _columns.getVisibleOutgoing(columnId, parentId);
    if (visibleChildId != null) return visibleChildId == childId;

    final replyOutgoing = (await _messages.getOutgoing(parentId)).replyOutgoing;
    if (replyOutgoing.isEmpty) return false;
    return _mostRecentOf(replyOutgoing).id == childId;
  }

  /// Full reply-tree id set for the thread [anchorMessageId] sits in: walk
  /// up to the reply root, then BFS every reply descendant (all forks, not
  /// just the visible branch). Stitch edges are ignored.
  Future<Set<String>> replyTreeIds(String anchorMessageId) async {
    final ancestry = await _messages.getAncestorPath(anchorMessageId);
    if (ancestry.isEmpty) return {};

    final rootId = ancestry.first.id;
    final ids = <String>{rootId};
    final queue = <String>[rootId];
    while (queue.isNotEmpty) {
      final parentId = queue.removeAt(0);
      // Structural reply tree includes hidden edges — only stitch is excluded.
      final outgoing = await _messages.getOutgoing(parentId);
      for (final child in [
        ...outgoing.replyOutgoing,
        ...outgoing.hiddenReplyOutgoing,
      ]) {
        if (ids.add(child.id)) {
          queue.add(child.id);
        }
      }
    }
    return ids;
  }

  /// Whether a new reply [childId] under [parentId] would show on
  /// [columnId]'s currently materialized branch around [anchorMessageId]:
  /// the parent must already be on that branch, and [childId] must be (or
  /// become) the selected outgoing under it.
  Future<bool> wouldLandOnVisibleBranch(
    String columnId,
    String anchorMessageId,
    String parentId,
    String childId,
  ) async {
    final visible = await materializedTrajectory(columnId, anchorMessageId);
    if (!visible.any((m) => m.id == parentId)) return false;
    return isNextOnVisibleOutgoing(columnId, parentId, childId);
  }

  Message _mostRecentOf(List<Message> messages) {
    return messages.reduce(
      (a, b) =>
          (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).isAfter(
            a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          )
          ? b
          : a,
    );
  }
}
