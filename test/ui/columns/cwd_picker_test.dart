import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stitch_chat/data/models/message.dart';
import 'package:stitch_chat/data/repositories/auth_repository.dart';
import 'package:stitch_chat/data/repositories/column_repository.dart';
import 'package:stitch_chat/data/repositories/message_repository.dart';
import 'package:stitch_chat/data/services/local_identity_service.dart';
import 'package:stitch_chat/domain/branch_path_service.dart';
import 'package:stitch_chat/domain/message_store.dart';
import 'package:stitch_chat/ui/columns/column_view.dart';
import 'package:stitch_chat/ui/columns/columns_viewmodel.dart';
import 'package:stitch_chat/ui/core/theme/app_theme.dart';

class _Messages implements MessageRepository {
  @override
  Future<void> saveMessage(Message message) => throw UnimplementedError();

  @override
  Future<Message?> getMessage(String id) async => null;

  @override
  Future<OutgoingEdges> getOutgoing(String parentId) =>
      throw UnimplementedError();

  @override
  Future<IncomingEdges> getIncoming(String childId) =>
      throw UnimplementedError();

  @override
  Future<List<Message>> getAncestorPath(String messageId) =>
      throw UnimplementedError();

  @override
  Future<List<Message>> getThreadRoots() async => const [];

  @override
  Stream<List<Message>> watchThreadRoots() => const Stream.empty();

  @override
  Stream<List<Message>> watchReplyOutgoing(String parentId) =>
      const Stream.empty();

  @override
  Future<void> addReplyEdge(
    String parentId,
    String childId, {
    bool hidden = false,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> addStitchEdge(
    String fromId,
    String toId, {
    String? createdByAuthorId,
  }) => throw UnimplementedError();

  @override
  Future<void> addRecipientEdge(
    String messageId,
    String recipientId,
    RecipientKind kind,
  ) => throw UnimplementedError();

  @override
  Future<List<RecipientRef>> getRecipients(String messageId) async => const [];

  @override
  Future<void> deleteMessage(String id) => throw UnimplementedError();

  @override
  Future<int> rewriteAuthorId({
    required String fromAuthorId,
    required String toAuthorId,
  }) =>
      throw UnimplementedError();
}

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

class _Columns implements ColumnRepository {
  ColumnMeta? meta;

  @override
  Future<ColumnMeta> createColumn({
    String? anchorMessageId,
    double? width,
  }) async {
    meta = ColumnMeta(
      id: 'column-01',
      anchorMessageId: anchorMessageId,
      width: width,
    );
    return meta!;
  }

  @override
  Future<void> deleteColumn(String id) async => meta = null;

  @override
  Future<List<ColumnMeta>> getColumns() async => [?meta];

  @override
  Future<void> updateColumnCwd(String id, String? cwd) async {
    final existing = meta!;
    meta = ColumnMeta(
      id: existing.id,
      anchorMessageId: existing.anchorMessageId,
      width: existing.width,
      scrollOffset: existing.scrollOffset,
      cwd: cwd,
    );
  }

  @override
  Future<void> updateColumnWidth(String id, double? width) =>
      throw UnimplementedError();

  @override
  Future<void> updateColumnAnchor(String id, String anchorMessageId) =>
      throw UnimplementedError();

  @override
  Future<void> updateColumnScrollOffset(String id, double? scrollOffset) =>
      throw UnimplementedError();

  @override
  Future<void> setBranchPointer(
    String columnId,
    String parentId,
    String childId,
  ) => throw UnimplementedError();

  @override
  Future<String?> getVisibleOutgoing(String columnId, String messageId) =>
      throw UnimplementedError();

  @override
  Future<String?> getVisibleIncoming(String columnId, String messageId) =>
      throw UnimplementedError();

  @override
  Future<void> setVisibleIncoming(
    String columnId,
    String childId,
    String newParentId,
  ) => throw UnimplementedError();
}

void main() {
  tearDown(() => debugColumnDirectoryPicker = null);

  testWidgets('column cwd is chosen with a folder picker', (tester) async {
    final columns = _Columns();
    final messages = _Messages();
    final store = MessageStore(messages);
    final vm = ColumnsViewModel(
      messages,
      columns,
      BranchPathService(messages, columns, store),
      store,
      _Identity(),
    );
    await columns.createColumn();
    await vm.initialize();

    String? requestedInitial;
    String? nextPath = '/tmp/agents';
    debugColumnDirectoryPicker = ({String? initialDirectory}) async {
      requestedInitial = initialDirectory;
      return nextPath;
    };

    await tester.pumpWidget(
      ChangeNotifierProvider<ColumnsViewModel>.value(
        value: vm,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: ColumnView(state: vm.columns.single)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Set column cwd'));
    await tester.pumpAndSettle();

    expect(find.text('Column cwd'), findsOneWidget);
    expect(find.text('No folder selected'), findsOneWidget);
    expect(find.text('Choose folder'), findsOneWidget);
    expect(find.text('Clear'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      findsNothing,
    );

    await tester.tap(find.text('Choose folder'));
    await tester.pumpAndSettle();

    expect(requestedInitial, isNull);
    expect(find.text('/tmp/agents'), findsOneWidget);
    expect(find.text('Change folder'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(vm.columns.single.cwd, isNull);

    await tester.tap(find.byTooltip('Set column cwd'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose folder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(vm.columns.single.cwd, '/tmp/agents');
    expect(columns.meta!.cwd, '/tmp/agents');

    requestedInitial = null;
    nextPath = '/tmp/other';
    await tester.tap(find.byTooltip('/tmp/agents'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change folder'));
    await tester.pumpAndSettle();
    expect(requestedInitial, '/tmp/agents');
    expect(find.text('/tmp/other'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(vm.columns.single.cwd, isNull);
    expect(columns.meta!.cwd, isNull);
  });
}
