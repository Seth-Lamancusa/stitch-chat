import '../data/models/message.dart';
import '../data/repositories/column_repository.dart';
import '../data/repositories/message_repository.dart';

/// Derives and updates the linear thread a column shows, per the message
/// data model doc's "derived, not stored" rule: a column's rendered thread
/// is computed by walking out from an anchor message — up via reply
/// ancestry, down via each column's persisted branch pointers — not stored
/// as its own list anywhere.

class BranchPathService {
  BranchPathService(this._messages, this._columns);

  final MessageRepository _messages;
  final ColumnRepository _columns;

  /// The full thread [columnId] shows around [anchorMessageId]: ancestors
  /// above it (via persisted visible-incoming pointers, falling back to
  /// reply structure), then the anchor, then its persisted-or-defaulted
  /// branch below. Returns an empty list if [anchorMessageId] doesn't exist.
  Future<List<Message>> getFullVisibleBranch(String columnId, String anchorMessageId) async {
    final anchor = await _messages.getMessage(anchorMessageId);
    if (anchor == null) return const [];

    final above = <Message>[];
    var current = anchor;
    while (true) {
      final incoming = await _visibleOrStructuralIncoming(columnId, current.id);
      if (incoming == null) break;
      above.insert(0, incoming);
      current = incoming;
    }

    final below = <Message>[anchor];
    current = anchor;
    while (true) {
      final next = await _visibleOrDefaultOutgoing(columnId, current.id);
      if (next == null) break;
      below.add(next);
      current = next;
    }

    return [...above, ...below];
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

  /// Moves [columnId]'s visible outgoing message below [parentId] to the
  /// next/previous candidate in `getOutgoing(parentId)` (reply children
  /// first, then stitch children — deliberately the full combined pool:
  /// unlike automatic default-path selection, an explicit outgoing switch is
  /// a user-driven action allowed to cross into stitch-linked content).
  /// Clamps at either end rather than wrapping. Re-derives everything below
  /// the switch point, since the old branch below it no longer applies.
  Future<List<Message>> navigateOutgoing(
    String columnId,
    String parentId, {
    required bool forward,
  }) async {
    final candidates = (await _messages.getOutgoing(parentId)).all;
    if (candidates.isEmpty) {
      return getFullVisibleBranch(columnId, parentId);
    }

    final currentChildId = await _columns.getVisibleOutgoing(columnId, parentId);
    final currentIndex = candidates.indexWhere((m) => m.id == currentChildId);

    int nextIndex;
    if (currentIndex == -1) {
      nextIndex = forward ? 0 : candidates.length - 1;
    } else {
      nextIndex = (forward ? currentIndex + 1 : currentIndex - 1)
          .clamp(0, candidates.length - 1);
    }

    final chosen = candidates[nextIndex];
    await _columns.setBranchPointer(columnId, parentId, chosen.id);
    return getFullVisibleBranch(columnId, chosen.id);
  }

  /// Moves [columnId]'s visible incoming message above [childId] to the
  /// next/previous candidate in `getIncoming(childId)` (reply parent first,
  /// then stitch parents — same "explicit switch sees the full pool" rule as
  /// [navigateOutgoing], mirrored upward). Clamps at either end. Re-derives
  /// everything above the switch point, since the old ancestry no longer
  /// applies once the incoming pointer changes.
  Future<List<Message>> navigateIncoming(
    String columnId,
    String childId, {
    required bool forward,
  }) async {
    final candidates = (await _messages.getIncoming(childId)).all;
    if (candidates.isEmpty) {
      return getFullVisibleBranch(columnId, childId);
    }

    final currentParentId = await _columns.getVisibleIncoming(columnId, childId);
    final currentIndex = candidates.indexWhere((m) => m.id == currentParentId);

    int nextIndex;
    if (currentIndex == -1) {
      nextIndex = forward ? 0 : candidates.length - 1;
    } else {
      nextIndex = (forward ? currentIndex + 1 : currentIndex - 1)
          .clamp(0, candidates.length - 1);
    }

    final chosen = candidates[nextIndex];
    await _columns.setVisibleIncoming(columnId, childId, chosen.id);
    return getFullVisibleBranch(columnId, childId);
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
  /// [columnId]'s current visible branch around [anchorMessageId]: the
  /// parent must already be on that branch, and [childId] must be (or
  /// become) the selected outgoing under it.
  Future<bool> wouldLandOnVisibleBranch(
    String columnId,
    String anchorMessageId,
    String parentId,
    String childId,
  ) async {
    final visible = await getFullVisibleBranch(columnId, anchorMessageId);
    if (!visible.any((m) => m.id == parentId)) return false;
    return isNextOnVisibleOutgoing(columnId, parentId, childId);
  }

  Future<Message?> _visibleOrStructuralIncoming(String columnId, String childId) async {
    final visibleParentId = await _columns.getVisibleIncoming(columnId, childId);
    if (visibleParentId != null) {
      return _messages.getMessage(visibleParentId);
    }

    // Never visited from this column: fall back to the reply-structural
    // parent (the only parent that exists before any pointer has been set).
    final ancestry = await _messages.getAncestorPath(childId);
    if (ancestry.length < 2) return null; // childId is already a reply-root
    return ancestry[ancestry.length - 2];
  }

  Future<Message?> _visibleOrDefaultOutgoing(String columnId, String parentId) async {
    final visibleChildId = await _columns.getVisibleOutgoing(columnId, parentId);
    if (visibleChildId != null) {
      return _messages.getMessage(visibleChildId);
    }

    // Unset fork: default to the most recent *non-hidden reply* child only,
    // and persist the choice. Reply-only (not hidden replies or stitches)
    // per Surgical Loading — an unset fork never silently auto-follows into
    // hidden-reply or stitch-linked content; those need an explicit reveal
    // or sibling navigation.
    final replyOutgoing = (await _messages.getOutgoing(parentId)).replyOutgoing;
    if (replyOutgoing.isEmpty) return null;

    final chosen = _mostRecentOf(replyOutgoing);
    await _columns.setBranchPointer(columnId, parentId, chosen.id);
    return chosen;
  }

  Message _mostRecentOf(List<Message> messages) {
    return messages.reduce(
      (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .isAfter(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          ? b
          : a,
    );
  }
}
