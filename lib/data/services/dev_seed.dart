import '../models/message.dart';
import '../repositories/column_repository.dart';
import '../repositories/message_repository.dart';

/// Seeds a small, deliberately varied conversation graph for visually
/// testing navigation/loading logic — a stand-in for real chat history
/// until §0 of column-ui-impl-plan.md (wiring the live chat into SQLite) is
/// done. No-ops if any columns already exist, so it only ever runs once
/// against a fresh database.
///
/// Covers, by design:
/// - a plain linear stretch (no forks at all)
/// - a 3-way reply fork (exercises [OutgoingNavigator] cycling reply-only)
/// - a stitch edge crossing from one tree into another (exercises the
///   reply-to-stitch tint transition in [OutgoingNavigator], the
///   non-interactive "Linked origin" flag in [IncomingNavigator], and the
///   "Load stitches (N)" button in [AdaptiveMarker] at both a bottom and a
///   top boundary)
/// - a message with two stitch parents in addition to its reply parent
///   (exercises [IncomingNavigator]'s "Linked origin (i/total)" cycling)
Future<void> seedDevDataIfEmpty(MessageRepository messages, ColumnRepository columns) async {
  if ((await columns.getColumns()).isNotEmpty) return;

  var t = DateTime.utc(2026, 1, 1);
  DateTime next() => t = t.add(const Duration(minutes: 1));

  Future<Message> save(String id, MessageRole role, String content) async {
    final message = Message(id: id, role: role, content: content, createdAt: next());
    await messages.saveMessage(message);
    return message;
  }

  // Thread A: root -> a 3-way reply fork -> the latest fork branch -> a leaf
  // that stitches out into thread B.
  await save('seed-a0', MessageRole.user, 'A0 (root) — ask a question');
  await save('seed-a1-early', MessageRole.localBot, 'A1 fork, EARLY regeneration (superseded)');
  await save('seed-a1-mid', MessageRole.localBot, 'A1 fork, MID regeneration (superseded)');
  await save('seed-a1-late', MessageRole.localBot, 'A1 fork, LATEST regeneration (default outgoing)');
  await messages.addReplyEdge('seed-a0', 'seed-a1-early');
  await messages.addReplyEdge('seed-a0', 'seed-a1-mid');
  await messages.addReplyEdge('seed-a0', 'seed-a1-late');

  await save('seed-a2', MessageRole.user, 'A2 — leaf of thread A, has 1 unfollowed stitch below');
  await messages.addReplyEdge('seed-a1-late', 'seed-a2');

  // Thread B: an independent root -> one reply child that has extra
  // incoming stitch edges -> a leaf.
  await save('seed-b0', MessageRole.user, 'B0 (root) — has 1 unfollowed stitch above');
  await save('seed-b1', MessageRole.localBot, 'B1 — reply child of B0, target of A2\'s stitch');
  await save('seed-b2', MessageRole.user,
      'B2 — leaf, has 3 incoming candidates (1 reply + 2 stitch)');
  await messages.addReplyEdge('seed-b0', 'seed-b1');
  await messages.addReplyEdge('seed-b1', 'seed-b2');

  // Stitch edges:
  // - a1-late -> b0: gives a1-late's *outgoing* pool a reply candidate
  //   (a2) and a stitch candidate (b0) side by side, so its
  //   OutgoingNavigator demonstrates the reply-to-stitch tint transition;
  //   symmetrically, b0's *incoming* pool gains an unfollowed stitch parent.
  // - a2 -> b1: a2 is a reply leaf with nothing but this one stitch
  //   outgoing, so it stays below the inline-navigator threshold (pool
  //   size 1) and surfaces instead as a bottom AdaptiveMarker boundary.
  // - a1-early/a1-mid -> b2: gives b2 a reply parent (b1) plus 2 stitch
  //   parents, so its IncomingNavigator cycles "Reply origin" / "Linked
  //   origin (1/2)" / "Linked origin (2/2)".
  await messages.addStitchEdge('seed-a1-late', 'seed-b0');
  await messages.addStitchEdge('seed-a2', 'seed-b1');
  await messages.addStitchEdge('seed-a1-early', 'seed-b2');
  await messages.addStitchEdge('seed-a1-mid', 'seed-b2');

  // Three columns, each demonstrating a different piece of the above:
  // - anchored at the root, to see the 3-way reply fork (OutgoingNavigator
  //   on a0) and then the reply/stitch tint transition one row down
  //   (OutgoingNavigator on a1-late).
  await columns.createColumn(anchorMessageId: 'seed-a0');
  // - anchored at the stitch-crossing leaf, to see the "Load stitches"
  //   bottom boundary button before it's ever clicked.
  await columns.createColumn(anchorMessageId: 'seed-a2');
  // - anchored in thread B, to see the top "Load stitches" boundary at B0
  //   and the pre-resolved 3-candidate IncomingNavigator at B2.
  await columns.createColumn(anchorMessageId: 'seed-b0');
}
