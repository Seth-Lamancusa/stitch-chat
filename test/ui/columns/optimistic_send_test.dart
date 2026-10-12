import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_chat/data/models/message.dart';
import 'package:stitch_chat/data/repositories/auth_repository.dart';
import 'package:stitch_chat/data/services/local_identity_service.dart';
import 'package:stitch_chat/domain/branch_path_service.dart';
import 'package:stitch_chat/domain/message_store.dart';
import 'package:stitch_chat/ui/columns/columns_viewmodel.dart';

import '../../domain/branch_path_service_test.dart'
    show FakeColumnRepository, FakeMessageRepository;

class _Identity implements LocalIdentityService {
  @override
  String get currentUserId => 'me';

  @override
  String get localUserId => 'me';

  @override
  bool get authenticatedOnline => false;

  @override
  void bindAuthRepository(AuthRepository auth) {}

  @override
  Future<void> initialize({Directory? supportDirectory}) async {}

  @override
  void dispose() {}
}

Message _msg(
  String id, {
  MessageRole role = MessageRole.user,
  String? authorId = 'me',
  String content = '',
  DateTime? createdAt,
}) => Message(
  id: id,
  role: role,
  authorId: authorId,
  content: content,
  createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
);

void main() {
  late FakeMessageRepository messages;
  late FakeColumnRepository columns;
  late ColumnsViewModel vm;
  late String columnId;

  setUp(() async {
    messages = FakeMessageRepository();
    columns = FakeColumnRepository();
    final store = MessageStore(messages);
    vm = ColumnsViewModel(
      messages,
      columns,
      BranchPathService(messages, columns, store),
      store,
      _Identity(),
    );

    await messages.saveMessage(_msg('root', content: 'root'));
    final meta = await columns.createColumn(anchorMessageId: 'root');
    columnId = meta.id;
    await vm.initialize();
  });

  tearDown(() => vm.dispose());

  test('sendMessage shows isSending before persist completes', () async {
    final gate = Completer<void>();
    messages.onSaveMessage = (message) async {
      if (message.id == 'root') return;
      await gate.future;
    };

    final future = vm.sendMessage(columnId, 'hello optimistic');
    await Future<void>.delayed(Duration.zero);

    final column = vm.columns.singleWhere((c) => c.id == columnId);
    expect(column.rows, hasLength(2));
    expect(column.rows.last.message.content, 'hello optimistic');
    expect(column.rows.last.message.isSending, isTrue);
    expect(await messages.getMessage(column.rows.last.message.id), isNull);

    gate.complete();
    expect(await future, isTrue);

    final settled = vm.columns.singleWhere((c) => c.id == columnId);
    expect(settled.rows.last.message.content, 'hello optimistic');
    expect(settled.rows.last.message.isSending, isFalse);
    expect(await messages.getMessage(settled.rows.last.message.id), isNotNull);
  });

  test('sendMessage fork truncates visible branch optimistically', () async {
    await messages.saveMessage(_msg('child-a', content: 'A'));
    await messages.saveMessage(
      _msg('child-b', content: 'B', createdAt: DateTime.utc(2026, 1, 2)),
    );
    await messages.addReplyEdge('root', 'child-a');
    await messages.addReplyEdge('root', 'child-b');
    await columns.setBranchPointer(columnId, 'root', 'child-b');
    await vm.reloadAll(reason: 'test');

    vm.setReplyTarget(columnId, 'root');

    final gate = Completer<void>();
    messages.onSaveMessage = (message) async {
      if (message.id == 'root' ||
          message.id == 'child-a' ||
          message.id == 'child-b') {
        return;
      }
      await gate.future;
    };

    final future = vm.sendMessage(columnId, 'fork tip');
    await Future<void>.delayed(Duration.zero);

    final column = vm.columns.singleWhere((c) => c.id == columnId);
    expect(column.rows.map((r) => r.message.content), ['root', 'fork tip']);
    expect(column.rows.last.message.isSending, isTrue);

    gate.complete();
    expect(await future, isTrue);

    final settled = vm.columns.singleWhere((c) => c.id == columnId);
    expect(settled.rows.map((r) => r.message.content), ['root', 'fork tip']);
    expect(settled.rows.last.message.isSending, isFalse);
  });
}
