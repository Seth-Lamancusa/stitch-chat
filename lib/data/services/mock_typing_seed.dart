import '../models/message.dart';
import '../repositories/column_repository.dart';
import '../repositories/message_repository.dart';
import 'mock_typing_cue.dart';

/// Seeds a short linear branch + column for typing-indicator visual work.
///
/// Gated by [StitchEnv.mockTypingCues] at the call site. Idempotent: skips
/// message inserts when [MockTypingCue.fixtureRootId] already exists, and
/// only opens a column when none is anchored inside the fixture set.
///
/// Fixtures:
/// - **Mid-branch + multi-author** — cue on [MockTypingCue.fixtureMidId]
///   (`cursor`, `chatgpt`) with a reply below so it is not last-in-column.
/// - **End of visible chain** — cue on [MockTypingCue.fixtureLeafId]
///   (`claude`) so chrome sits under the last card.
Future<void> seedMockTypingFixtures({
  required MessageRepository messages,
  required ColumnRepository columns,
  required String currentUserId,
}) async {
  if (await messages.getMessage(MockTypingCue.fixtureRootId) == null) {
    var t = DateTime.utc(2026, 3, 1, 12);
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
      id: MockTypingCue.fixtureRootId,
      role: MessageRole.user,
      authorId: currentUserId,
      content: 'Typing chrome fixtures — root of a short visible branch.',
    );
    await save(
      id: MockTypingCue.fixtureMidId,
      role: MessageRole.user,
      authorId: currentUserId,
      content: MockTypingCue.embed(
        const ['cursor', 'chatgpt'],
        'Intermediate message — multi-author cue should sit on this card '
        '(not last in column).',
      ),
    );
    await messages.addReplyEdge(
      MockTypingCue.fixtureRootId,
      MockTypingCue.fixtureMidId,
    );

    await save(
      id: MockTypingCue.fixtureContId,
      role: MessageRole.localBot,
      authorId: 'cursor',
      content: 'Continuation so the mid cue stays above the leaf.',
    );
    await messages.addReplyEdge(
      MockTypingCue.fixtureMidId,
      MockTypingCue.fixtureContId,
    );

    await save(
      id: MockTypingCue.fixtureLeafId,
      role: MessageRole.user,
      authorId: currentUserId,
      content: MockTypingCue.embed(
        const ['claude'],
        'Leaf of the visible chain — single-author cue under this card.',
      ),
    );
    await messages.addReplyEdge(
      MockTypingCue.fixtureContId,
      MockTypingCue.fixtureLeafId,
    );
  }

  final existing = await columns.getColumns();
  final hasFixtureColumn = existing.any(
    (c) =>
        c.anchorMessageId != null &&
        MockTypingCue.fixtureIds.contains(c.anchorMessageId),
  );
  if (!hasFixtureColumn) {
    // Anchor at root so the default downward walk shows mid + leaf together.
    await columns.createColumn(anchorMessageId: MockTypingCue.fixtureRootId);
  }
}
