import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_chat/data/repositories/drift_column_repository.dart';
import 'package:stitch_chat/data/repositories/drift_message_repository.dart';
import 'package:stitch_chat/data/services/app_database.dart';
import 'package:stitch_chat/data/services/mock_typing_cue.dart';
import 'package:stitch_chat/data/services/mock_typing_seed.dart';

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

  test('seedMockTypingFixtures is idempotent and tags mid + leaf', () async {
    await seedMockTypingFixtures(
      messages: messages,
      columns: columns,
      currentUserId: 'me',
    );
    await seedMockTypingFixtures(
      messages: messages,
      columns: columns,
      currentUserId: 'me',
    );

    final mid = await messages.getMessage(MockTypingCue.fixtureMidId);
    final leaf = await messages.getMessage(MockTypingCue.fixtureLeafId);
    expect(mid, isNotNull);
    expect(leaf, isNotNull);
    expect(MockTypingCue.authorsOf(mid!.content), ['cursor', 'chatgpt']);
    expect(MockTypingCue.authorsOf(leaf!.content), ['claude']);

    final cols = await columns.getColumns();
    expect(cols, hasLength(1));
    expect(cols.single.anchorMessageId, MockTypingCue.fixtureRootId);
  });
}
