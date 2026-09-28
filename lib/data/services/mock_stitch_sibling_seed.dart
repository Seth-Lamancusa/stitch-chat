import '../models/message.dart';
import '../repositories/column_repository.dart';
import '../repositories/message_repository.dart';
import 'mock_stitch_sibling.dart';

/// Seeds a column where the visible branch already follows a reply child
/// while a stitch-linked side thread sits as an unrevealed sibling.
///
/// Gated by [StitchEnv.mockStitchSibling] at the call site. Idempotent:
/// skips message inserts when the trigger already exists, and only opens a
/// column when none is anchored inside the fixture set.
///
/// Expected UX today (Surgical Loading + exclusivity rule):
/// - Column shows `T → A1` (reply). Side chain is **not** auto-followed.
/// - `A1` gets sibling arrows (`OutgoingNavArrow`); the next arrow is
///   stitch-green because the next pool entry is the stitch sibling.
/// - Bottom marker is plain "End of thread" — **not** "Load stitches",
///   because a reply child already occupies the slot (navigators, not the
///   boundary marker, own this case).
/// - Clicking the green next arrow swaps `A1` for `S1` and walks the side
///   reply chain (`S1 → S2 → S3`).
Future<void> seedMockStitchSiblingFixtures({
  required MessageRepository messages,
  required ColumnRepository columns,
  required String currentUserId,
}) async {
  if (await messages.getMessage(MockStitchSibling.fixtureTriggerId) == null) {
    var t = DateTime.utc(2026, 3, 2, 12);
    DateTime next() => t = t.add(const Duration(minutes: 1));

    Future<void> save({
      required String id,
      required MessageRole role,
      required String content,
      String? authorId,
    }) {
      return messages.saveMessage(
        Message(
          id: id,
          role: role,
          authorId: authorId,
          content: content,
          createdAt: next(),
        ),
      );
    }

    await save(
      id: MockStitchSibling.fixtureTriggerId,
      role: MessageRole.user,
      authorId: currentUserId,
      content:
          '@cursor go do something for me — stitch-sibling fixture trigger.',
    );

    // Main fork (reply). Created "first" in wall-clock terms so the race
    // case matches: final response already on the visible branch.
    await save(
      id: MockStitchSibling.fixtureReplyId,
      role: MessageRole.localBot,
      authorId: 'cursor',
      content:
          'Final response on the main reply fork. Sibling arrows on this '
          'card should offer a green "next" into the unrevealed stitch '
          'side thread.',
    );
    await messages.addReplyEdge(
      MockStitchSibling.fixtureTriggerId,
      MockStitchSibling.fixtureReplyId,
    );

    // Side fork root — stitch edge only (not reply). Whole branch below
    // attaches via ordinary reply edges so one sibling swap reveals it all.
    await save(
      id: MockStitchSibling.fixtureSideRootId,
      role: MessageRole.thinking,
      authorId: 'cursor',
      content: 'Side-fork root (thinking). Linked from the trigger by a '
          'stitch edge — not auto-followed.',
    );
    await messages.addStitchEdge(
      MockStitchSibling.fixtureTriggerId,
      MockStitchSibling.fixtureSideRootId,
    );

    await save(
      id: MockStitchSibling.fixtureSideMidId,
      role: MessageRole.functionCall,
      authorId: 'cursor',
      content: '**grep**\n```json\n{"pattern": "hidden hop"}\n```',
    );
    await messages.addReplyEdge(
      MockStitchSibling.fixtureSideRootId,
      MockStitchSibling.fixtureSideMidId,
    );

    await save(
      id: MockStitchSibling.fixtureSideLeafId,
      role: MessageRole.functionResult,
      authorId: 'cursor',
      content: '```\n(fixture) 3 matches in branch_path_service.dart\n```',
    );
    await messages.addReplyEdge(
      MockStitchSibling.fixtureSideMidId,
      MockStitchSibling.fixtureSideLeafId,
    );
  }

  final existing = await columns.getColumns();
  final hasFixtureColumn = existing.any(
    (c) =>
        c.anchorMessageId != null &&
        MockStitchSibling.fixtureIds.contains(c.anchorMessageId),
  );
  if (!hasFixtureColumn) {
    final column = await columns.createColumn(
      anchorMessageId: MockStitchSibling.fixtureTriggerId,
    );
    // Pin the visible fork to the main reply so the column opens on the
    // race-case layout even if other reply siblings appear later.
    await columns.setBranchPointer(
      column.id,
      MockStitchSibling.fixtureTriggerId,
      MockStitchSibling.fixtureReplyId,
    );
  }
}
