import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_chat/core/notifications/notification_service.dart';
import 'package:stitch_chat/data/models/message.dart';
import 'package:stitch_chat/data/repositories/auth_repository.dart';
import 'package:stitch_chat/data/services/local_identity_service.dart';
import 'package:stitch_chat/domain/branch_path_service.dart';
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
}) =>
    Message(
      id: id,
      role: role,
      authorId: authorId,
      content: content,
      createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
    );

void main() {
  late FakeMessageRepository messages;
  late FakeColumnRepository columns;
  late NotificationService notifications;
  late ColumnsViewModel vm;
  late String columnId;

  setUp(() async {
    messages = FakeMessageRepository();
    columns = FakeColumnRepository();
    notifications = NotificationService();
    vm = ColumnsViewModel(
      messages,
      columns,
      BranchPathService(messages, columns),
      _Identity(),
      notifications: notifications,
    );

    await messages.saveMessage(_msg('root', content: 'root'));
    final meta = await columns.createColumn(anchorMessageId: 'root');
    columnId = meta.id;
    await vm.initialize();
  });

  tearDown(() => vm.dispose());

  test('off-path localBot fires a toast', () async {
    await messages.saveMessage(_msg('older', content: 'older sibling'));
    await messages.addReplyEdge('root', 'older');
    await columns.setBranchPointer(columnId, 'root', 'older');

    await vm.ingestIncomingMessage(
      columnId: columnId,
      parentId: 'root',
      message: _msg(
        'bot-reply',
        role: MessageRole.localBot,
        authorId: 'chatgpt',
        content: 'hello from the other fork',
        createdAt: DateTime.utc(2026, 1, 2),
      ),
    );

    expect(notifications.toasts, hasLength(1));
    final toast = notifications.toasts.single;
    expect(toast.title, 'New message from chatgpt');
    expect(toast.message, 'hello from the other fork');
    expect(toast.onTap, isNotNull);
  });

  test('off-path user (human) fires a toast', () async {
    await messages.saveMessage(_msg('older', content: 'older sibling'));
    await messages.addReplyEdge('root', 'older');
    await columns.setBranchPointer(columnId, 'root', 'older');

    await vm.ingestIncomingMessage(
      columnId: columnId,
      parentId: 'root',
      message: _msg(
        'human-reply',
        role: MessageRole.user,
        authorId: 'alice',
        content: 'cloud human on other fork',
        createdAt: DateTime.utc(2026, 1, 2),
      ),
    );

    expect(notifications.toasts, hasLength(1));
    expect(notifications.toasts.single.title, 'New message from alice');
  });

  test('thinking part does not toast even when off-path', () async {
    await messages.saveMessage(_msg('older', content: 'older'));
    await messages.addReplyEdge('root', 'older');
    await columns.setBranchPointer(columnId, 'root', 'older');

    await vm.ingestIncomingMessage(
      columnId: columnId,
      parentId: 'root',
      message: _msg(
        'think',
        role: MessageRole.thinking,
        authorId: 'cursor',
        content: 'pondering',
      ),
    );

    expect(notifications.toasts, isEmpty);
  });

  test('null pointer (on-path default) does not toast', () async {
    await vm.ingestIncomingMessage(
      columnId: columnId,
      parentId: 'root',
      message: _msg(
        'bot-reply',
        role: MessageRole.localBot,
        authorId: 'chatgpt',
        content: 'first reply',
      ),
    );

    expect(notifications.toasts, isEmpty);
  });

  test('matching visible outgoing does not toast', () async {
    await columns.setBranchPointer(columnId, 'root', 'bot-reply');

    await vm.ingestIncomingMessage(
      columnId: columnId,
      parentId: 'root',
      message: _msg(
        'bot-reply',
        role: MessageRole.localBot,
        authorId: 'chatgpt',
        content: 'already selected',
      ),
    );

    expect(notifications.toasts, isEmpty);
  });

  test('reply under off-visible fork in the same tree still toasts', () async {
    // Visible path: root → b. Off-path fork: root → a.
    await messages.saveMessage(_msg('a', content: 'fork a'));
    await messages.saveMessage(_msg('b', content: 'fork b', createdAt: DateTime.utc(2026, 1, 2)));
    await messages.addReplyEdge('root', 'a');
    await messages.addReplyEdge('root', 'b');
    await columns.setBranchPointer(columnId, 'root', 'b');
    await columns.updateColumnAnchor(columnId, 'b');
    await vm.reloadAll();

    await vm.ingestIncomingMessage(
      columnId: columnId,
      parentId: 'a',
      message: _msg(
        'a-child',
        role: MessageRole.user,
        authorId: 'bob',
        content: 'reply on the hidden fork',
        createdAt: DateTime.utc(2026, 1, 3),
      ),
    );

    expect(notifications.toasts, hasLength(1));
    expect(notifications.toasts.single.title, 'New message from bob');
  });

  test('reply under a parent outside the column reply tree does not toast', () async {
    await messages.saveMessage(_msg('other-root', content: 'unrelated'));

    await vm.ingestIncomingMessage(
      columnId: columnId,
      parentId: 'other-root',
      message: _msg(
        'orphan-reply',
        role: MessageRole.user,
        authorId: 'eve',
        content: 'not in this column tree',
      ),
    );

    expect(notifications.toasts, isEmpty);
  });

  test('toast onTap jumps to the off-path message', () async {
    await messages.saveMessage(_msg('older', content: 'older'));
    await messages.addReplyEdge('root', 'older');
    await columns.setBranchPointer(columnId, 'root', 'older');

    await vm.ingestIncomingMessage(
      columnId: columnId,
      parentId: 'root',
      message: _msg(
        'bot-reply',
        role: MessageRole.localBot,
        authorId: 'chatgpt',
        content: 'jump here',
        createdAt: DateTime.utc(2026, 1, 2),
      ),
    );

    final onTap = notifications.toasts.single.onTap!;
    await onTap();

    expect(await columns.getVisibleOutgoing(columnId, 'root'), 'bot-reply');
    expect(
      vm.columns.single.rows.map((r) => r.message.id).toList(),
      ['root', 'bot-reply'],
    );
  });
}
