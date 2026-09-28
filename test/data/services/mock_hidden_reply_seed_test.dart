import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_chat/data/repositories/drift_column_repository.dart';
import 'package:stitch_chat/data/repositories/drift_message_repository.dart';
import 'package:stitch_chat/data/services/app_database.dart';
import 'package:stitch_chat/data/services/mock_hidden_reply.dart';
import 'package:stitch_chat/data/services/mock_hidden_reply_seed.dart';
import 'package:stitch_chat/domain/branch_path_service.dart';

void main() {
  late AppDatabase db;
  late DriftMessageRepository messages;
  late DriftColumnRepository columns;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    messages = DriftMessageRepository(db);
    columns = DriftColumnRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('seed: race column shows reply; reveal column stays on trigger', () async {
    await seedMockHiddenReplyFixtures(
      messages: messages,
      columns: columns,
      currentUserId: 'me',
    );

    final outgoing =
        await messages.getOutgoing(MockHiddenReply.fixtureTriggerId);
    expect(outgoing.replyOutgoing.map((m) => m.id), [
      MockHiddenReply.fixtureReplyId,
    ]);
    expect(outgoing.hiddenReplyOutgoing.map((m) => m.id), [
      MockHiddenReply.fixtureSideRootId,
    ]);

    final cols = await columns.getColumns();
    expect(cols, hasLength(2));

    final race = cols.firstWhere(
      (c) => c.anchorMessageId == MockHiddenReply.fixtureReplyId,
    );
    final raceBranch = await BranchPathService(messages, columns)
        .getFullVisibleBranch(race.id, MockHiddenReply.fixtureTriggerId);
    expect(raceBranch.map((m) => m.id).toList(), [
      MockHiddenReply.fixtureTriggerId,
      MockHiddenReply.fixtureReplyId,
    ]);

    final reveal = cols.firstWhere(
      (c) => c.anchorMessageId == MockHiddenReply.fixtureRevealTriggerId,
    );
    final revealBranch = await BranchPathService(messages, columns)
        .getFullVisibleBranch(
      reveal.id,
      MockHiddenReply.fixtureRevealTriggerId,
    );
    expect(revealBranch.map((m) => m.id).toList(), [
      MockHiddenReply.fixtureRevealTriggerId,
    ]);

    final revealOutgoing =
        await messages.getOutgoing(MockHiddenReply.fixtureRevealTriggerId);
    expect(revealOutgoing.replyOutgoing, isEmpty);
    expect(revealOutgoing.hiddenReplyOutgoing, isNotEmpty);
  });
}
