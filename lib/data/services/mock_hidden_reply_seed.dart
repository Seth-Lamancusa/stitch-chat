import '../models/message.dart';
import '../repositories/column_repository.dart';
import '../repositories/message_repository.dart';
import 'mock_hidden_reply.dart';

/// Seeds columns for hidden-reply Surgical Loading UX.
///
/// Gated by [StitchEnv.mockHiddenReply] at the call site. Idempotent.
///
/// Column A — race case: visible branch `T → A1`, hidden side sibling under
/// T reachable via sibling nav.
/// Column B — only-hidden case: trigger `R` with solely a hidden child so
/// AdaptiveMarker shows "Reveal hidden thread".
Future<void> seedMockHiddenReplyFixtures({
  required MessageRepository messages,
  required ColumnRepository columns,
  required String currentUserId,
}) async {
  if (await messages.getMessage(MockHiddenReply.fixtureTriggerId) == null) {
    var t = DateTime.utc(2026, 3, 3, 12);
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
      id: MockHiddenReply.fixtureTriggerId,
      role: MessageRole.user,
      authorId: currentUserId,
      content: '@cursor go do something — hidden-reply race fixture.',
    );

    await save(
      id: MockHiddenReply.fixtureReplyId,
      role: MessageRole.localBot,
      authorId: 'cursor',
      content:
          'Final response on the main reply fork. Sibling arrows should '
          'reach the hidden side thread.',
    );
    await messages.addReplyEdge(
      MockHiddenReply.fixtureTriggerId,
      MockHiddenReply.fixtureReplyId,
    );

    await save(
      id: MockHiddenReply.fixtureSideRootId,
      role: MessageRole.thinking,
      authorId: 'cursor',
      content: 'Side-fork root (thinking). Linked by a hidden reply edge.',
    );
    await messages.addReplyEdge(
      MockHiddenReply.fixtureTriggerId,
      MockHiddenReply.fixtureSideRootId,
      hidden: true,
    );

    await save(
      id: MockHiddenReply.fixtureSideMidId,
      role: MessageRole.functionCall,
      authorId: 'cursor',
      content: '**grep**\n```json\n{"pattern": "hidden hop"}\n```',
    );
    await messages.addReplyEdge(
      MockHiddenReply.fixtureSideRootId,
      MockHiddenReply.fixtureSideMidId,
    );

    await save(
      id: MockHiddenReply.fixtureSideLeafId,
      role: MessageRole.functionResult,
      authorId: 'cursor',
      content: '```\n(fixture) 3 matches in branch_path_service.dart\n```',
    );
    await messages.addReplyEdge(
      MockHiddenReply.fixtureSideMidId,
      MockHiddenReply.fixtureSideLeafId,
    );

    // Separate graph: only a hidden child under R (no non-hidden reply).
    await save(
      id: MockHiddenReply.fixtureRevealTriggerId,
      role: MessageRole.user,
      authorId: currentUserId,
      content: '@cursor explore — hidden-reply reveal-marker fixture.',
    );
    await save(
      id: MockHiddenReply.fixtureRevealSideRootId,
      role: MessageRole.thinking,
      authorId: 'cursor',
      content: 'Only-hidden side root — bottom marker should offer reveal.',
    );
    await messages.addReplyEdge(
      MockHiddenReply.fixtureRevealTriggerId,
      MockHiddenReply.fixtureRevealSideRootId,
      hidden: true,
    );
    await save(
      id: MockHiddenReply.fixtureRevealSideMidId,
      role: MessageRole.functionCall,
      authorId: 'cursor',
      content: '**list**\n```json\n{}\n```',
    );
    await messages.addReplyEdge(
      MockHiddenReply.fixtureRevealSideRootId,
      MockHiddenReply.fixtureRevealSideMidId,
    );
    await save(
      id: MockHiddenReply.fixtureRevealSideLeafId,
      role: MessageRole.functionResult,
      authorId: 'cursor',
      content: '```\nok\n```',
    );
    await messages.addReplyEdge(
      MockHiddenReply.fixtureRevealSideMidId,
      MockHiddenReply.fixtureRevealSideLeafId,
    );
  }

  final existing = await columns.getColumns();

  final hasRaceColumn = existing.any(
    (c) => c.anchorMessageId == MockHiddenReply.fixtureReplyId,
  );
  if (!hasRaceColumn) {
    final column = await columns.createColumn(
      anchorMessageId: MockHiddenReply.fixtureTriggerId,
    );
    await columns.setBranchPointer(
      column.id,
      MockHiddenReply.fixtureTriggerId,
      MockHiddenReply.fixtureReplyId,
    );
    await columns.updateColumnAnchor(column.id, MockHiddenReply.fixtureReplyId);
  }

  final hasRevealColumn = existing.any(
    (c) => c.anchorMessageId == MockHiddenReply.fixtureRevealTriggerId,
  );
  if (!hasRevealColumn) {
    await columns.createColumn(
      anchorMessageId: MockHiddenReply.fixtureRevealTriggerId,
    );
  }
}
