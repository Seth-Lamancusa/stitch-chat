import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_chat/data/models/message.dart';
import 'package:stitch_chat/data/repositories/drift_column_repository.dart';
import 'package:stitch_chat/data/repositories/drift_message_repository.dart';
import 'package:stitch_chat/data/services/app_database.dart';

void main() {
  late AppDatabase db;
  late DriftColumnRepository columnRepo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    columnRepo = DriftColumnRepository(db);
    final messageRepo = DriftMessageRepository(db);
    for (final id in ['root', 'a', 'b']) {
      await messageRepo.saveMessage(Message(id: id, role: MessageRole.user, content: id));
    }
  });

  tearDown(() => db.close());

  test('createColumn persists and getColumns restores it', () async {
    final created = await columnRepo.createColumn(anchorMessageId: 'root', width: 240);

    final columns = await columnRepo.getColumns();

    expect(columns, hasLength(1));
    expect(columns.single.id, created.id);
    expect(columns.single.anchorMessageId, 'root');
    expect(columns.single.width, 240);
  });

  test('createColumn defaults width to null (flexible)', () async {
    final created = await columnRepo.createColumn(anchorMessageId: 'root');
    expect(created.width, isNull);
  });

  test('updateColumnWidth updates the stored width', () async {
    final created = await columnRepo.createColumn(anchorMessageId: 'root', width: 100);

    await columnRepo.updateColumnWidth(created.id, 300);

    expect((await columnRepo.getColumns()).single.width, 300);
  });

  test('updateColumnAnchor updates the anchor message', () async {
    final created = await columnRepo.createColumn(anchorMessageId: 'root');

    await columnRepo.updateColumnAnchor(created.id, 'a');

    expect((await columnRepo.getColumns()).single.anchorMessageId, 'a');
  });

  test('deleteColumn removes it from getColumns', () async {
    final created = await columnRepo.createColumn(anchorMessageId: 'root');

    await columnRepo.deleteColumn(created.id);

    expect(await columnRepo.getColumns(), isEmpty);
  });

  test('setBranchPointer is queryable from both directions', () async {
    final column = await columnRepo.createColumn(anchorMessageId: 'root');

    await columnRepo.setBranchPointer(column.id, 'root', 'a');

    expect(await columnRepo.getVisibleOutgoing(column.id, 'root'), 'a');
    expect(await columnRepo.getVisibleIncoming(column.id, 'a'), 'root');
  });

  test('setBranchPointer overwrites the previous child for the same parent (atomic upsert)', () async {
    final column = await columnRepo.createColumn(anchorMessageId: 'root');

    await columnRepo.setBranchPointer(column.id, 'root', 'a');
    await columnRepo.setBranchPointer(column.id, 'root', 'b');

    expect(await columnRepo.getVisibleOutgoing(column.id, 'root'), 'b');
    expect(await columnRepo.getVisibleIncoming(column.id, 'a'), isNull);
    expect(await columnRepo.getVisibleIncoming(column.id, 'b'), 'root');
  });

  test('branch pointers are scoped per column', () async {
    final columnA = await columnRepo.createColumn(anchorMessageId: 'root');
    final columnB = await columnRepo.createColumn(anchorMessageId: 'root');

    await columnRepo.setBranchPointer(columnA.id, 'root', 'a');
    await columnRepo.setBranchPointer(columnB.id, 'root', 'b');

    expect(await columnRepo.getVisibleOutgoing(columnA.id, 'root'), 'a');
    expect(await columnRepo.getVisibleOutgoing(columnB.id, 'root'), 'b');
  });

  test('deleting a column cascades its branch pointers', () async {
    final column = await columnRepo.createColumn(anchorMessageId: 'root');
    await columnRepo.setBranchPointer(column.id, 'root', 'a');

    await columnRepo.deleteColumn(column.id);

    expect(await columnRepo.getVisibleOutgoing(column.id, 'root'), isNull);
  });

  test('setting a child under a different parent atomically moves it', () async {
    final column = await columnRepo.createColumn(anchorMessageId: 'root');
    await columnRepo.setBranchPointer(column.id, 'root', 'a');

    await columnRepo.setBranchPointer(column.id, 'b', 'a');

    expect(await columnRepo.getVisibleIncoming(column.id, 'a'), 'b');
    expect(await columnRepo.getVisibleOutgoing(column.id, 'root'), isNull);
    expect(await columnRepo.getVisibleOutgoing(column.id, 'b'), 'a');
  });

  test('setVisibleIncoming switches which parent a child is visible under', () async {
    final column = await columnRepo.createColumn(anchorMessageId: 'root');
    await columnRepo.setBranchPointer(column.id, 'root', 'a');

    await columnRepo.setVisibleIncoming(column.id, 'a', 'b');

    expect(await columnRepo.getVisibleIncoming(column.id, 'a'), 'b');
    expect(await columnRepo.getVisibleOutgoing(column.id, 'b'), 'a');
  });

  test('setVisibleIncoming deletes the old pointer row, not just shadows it', () async {
    final column = await columnRepo.createColumn(anchorMessageId: 'root');
    await columnRepo.setBranchPointer(column.id, 'root', 'a');

    await columnRepo.setVisibleIncoming(column.id, 'a', 'b');

    // The old (root, a) row must be gone, or root would still show 'a' as
    // its own visible outgoing even though 'a' now points to 'b' instead.
    expect(await columnRepo.getVisibleOutgoing(column.id, 'root'), isNull);
  });
}
