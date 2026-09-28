import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_chat/data/repositories/drift_column_repository.dart';
import 'package:stitch_chat/data/repositories/drift_message_repository.dart';
import 'package:stitch_chat/data/services/app_database.dart';
import 'package:stitch_chat/data/services/mock_stitch_sibling.dart';
import 'package:stitch_chat/data/services/mock_stitch_sibling_seed.dart';
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

  test('seed shows reply branch; stitch sibling not auto-followed', () async {
    await seedMockStitchSiblingFixtures(
      messages: messages,
      columns: columns,
      currentUserId: 'me',
    );
    await seedMockStitchSiblingFixtures(
      messages: messages,
      columns: columns,
      currentUserId: 'me',
    );

    final cols = await columns.getColumns();
    expect(cols, hasLength(1));
    final columnId = cols.single.id;

    final outgoing =
        await messages.getOutgoing(MockStitchSibling.fixtureTriggerId);
    expect(outgoing.replyOutgoing.map((m) => m.id), [
      MockStitchSibling.fixtureReplyId,
    ]);
    expect(outgoing.stitchedOutgoing.map((m) => m.id), [
      MockStitchSibling.fixtureSideRootId,
    ]);

    final branch = await BranchPathService(messages, columns)
        .getFullVisibleBranch(columnId, MockStitchSibling.fixtureTriggerId);
    expect(branch.map((m) => m.id).toList(), [
      MockStitchSibling.fixtureTriggerId,
      MockStitchSibling.fixtureReplyId,
    ]);
  });
}
