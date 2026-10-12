import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:stitch_chat/core/notifications/notification_service.dart';
import 'package:stitch_chat/core/settings/message_font_service.dart';
import 'package:stitch_chat/data/models/message.dart';
import 'package:stitch_chat/data/repositories/auth_repository.dart';
import 'package:stitch_chat/data/repositories/column_repository.dart';
import 'package:stitch_chat/data/repositories/fake_auth_repository.dart';
import 'package:stitch_chat/data/services/cloud_user_directory.dart';
import 'package:stitch_chat/data/services/local_identity_service.dart';
import 'package:stitch_chat/data/services/session_vault.dart';
import 'package:stitch_chat/data/services/stitch_http_client.dart';
import 'package:stitch_chat/domain/branch_path_service.dart';
import 'package:stitch_chat/ui/auth/login_viewmodel.dart';
import 'package:stitch_chat/ui/columns/column_view.dart';
import 'package:stitch_chat/ui/columns/columns_view.dart';
import 'package:stitch_chat/ui/columns/columns_viewmodel.dart';
import 'package:stitch_chat/ui/core/theme/app_theme.dart';

import '../../domain/branch_path_service_test.dart' show FakeMessageRepository;
import '../message_font_test_helper.dart';
import '../pump_helpers.dart';

/// Same as the scroll-position suite: header does `id.substring(0, 8)`.
class _LongIdColumnRepository implements ColumnRepository {
  final Map<String, ColumnMeta> _columns = {};
  final Map<String, Map<String, String>> _visibleOutgoing = {};
  final Map<String, Map<String, String>> _visibleIncoming = {};
  int _n = 0;

  @override
  Future<ColumnMeta> createColumn({String? anchorMessageId, double? width}) async {
    final id = 'longcolid-${_n++}';
    final meta = ColumnMeta(id: id, anchorMessageId: anchorMessageId, width: width);
    _columns[id] = meta;
    return meta;
  }

  @override
  Future<void> deleteColumn(String id) async {
    _columns.remove(id);
    _visibleOutgoing.remove(id);
    _visibleIncoming.remove(id);
  }

  @override
  Future<List<ColumnMeta>> getColumns() async => _columns.values.toList();

  @override
  Future<void> updateColumnWidth(String id, double? width) async {
    final existing = _columns[id]!;
    _columns[id] = ColumnMeta(
      id: existing.id,
      anchorMessageId: existing.anchorMessageId,
      width: width,
      scrollOffset: existing.scrollOffset,
      cwd: existing.cwd,
    );
  }

  @override
  Future<void> updateColumnAnchor(String id, String anchorMessageId) async {
    final existing = _columns[id]!;
    _columns[id] = ColumnMeta(
      id: existing.id,
      anchorMessageId: anchorMessageId,
      width: existing.width,
      scrollOffset: existing.scrollOffset,
      cwd: existing.cwd,
    );
  }

  @override
  Future<void> updateColumnScrollOffset(String id, double? scrollOffset) async {
    final existing = _columns[id]!;
    _columns[id] = ColumnMeta(
      id: existing.id,
      anchorMessageId: existing.anchorMessageId,
      width: existing.width,
      scrollOffset: scrollOffset,
      cwd: existing.cwd,
    );
  }

  @override
  Future<void> updateColumnCwd(String id, String? cwd) async {
    final existing = _columns[id]!;
    _columns[id] = ColumnMeta(
      id: existing.id,
      anchorMessageId: existing.anchorMessageId,
      width: existing.width,
      scrollOffset: existing.scrollOffset,
      cwd: cwd,
    );
  }

  @override
  Future<void> setBranchPointer(
    String columnId,
    String parentId,
    String childId,
  ) async {
    (_visibleOutgoing[columnId] ??= {})[parentId] = childId;
    (_visibleIncoming[columnId] ??= {})[childId] = parentId;
  }

  @override
  Future<String?> getVisibleOutgoing(String columnId, String messageId) async =>
      _visibleOutgoing[columnId]?[messageId];

  @override
  Future<String?> getVisibleIncoming(String columnId, String messageId) async =>
      _visibleIncoming[columnId]?[messageId];

  @override
  Future<void> setVisibleIncoming(
    String columnId,
    String childId,
    String newParentId,
  ) async {
    (_visibleIncoming[columnId] ??= {})[childId] = newParentId;
  }
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

Message _msg(
  String id, {
  String content = '',
  DateTime? createdAt,
}) =>
    Message(
      id: id,
      role: MessageRole.user,
      authorId: 'me',
      content: content,
      createdAt: createdAt ?? DateTime.utc(2024, 1, 1),
    );

void main() {
  late FakeMessageRepository messages;
  late _LongIdColumnRepository columns;
  late ColumnsViewModel vm;
  late String columnId;
  late LoginViewModel loginVm;
  late MessageFontService messageFontService;

  setUp(() async {
    ColumnView.debugSuppressComposerAutoFocus = true;
    messages = FakeMessageRepository();
    columns = _LongIdColumnRepository();
    loginVm = LoginViewModel(
      authRepository: FakeAuthRepository(),
      notifications: NotificationService(),
    );
    messageFontService = await createTestMessageFontService();
    vm = ColumnsViewModel(
      messages,
      columns,
      BranchPathService(messages, columns),
      _Identity(),
    );

    await messages.saveMessage(_msg('fork0001', content: 'fork parent'));
    await messages.saveMessage(
      _msg('child-a1', content: 'branch A', createdAt: DateTime.utc(2024, 1, 2)),
    );
    await messages.saveMessage(
      _msg('leaf-a01', content: 'leaf A', createdAt: DateTime.utc(2024, 1, 3)),
    );
    await messages.addReplyEdge('fork0001', 'child-a1');
    await messages.addReplyEdge('child-a1', 'leaf-a01');

    // Anchor on the tip so the scroll center starts away from the fork parent
    // — the case that needs pin preservation after a mid-thread reply.
    final meta = await columns.createColumn(anchorMessageId: 'leaf-a01');
    columnId = meta.id;
    await columns.setBranchPointer(columnId, 'fork0001', 'child-a1');
    await columns.setBranchPointer(columnId, 'child-a1', 'leaf-a01');
    await vm.initialize();
  });

  tearDown(() {
    vm.dispose();
    loginVm.dispose();
  });

  List<SingleChildWidget> providers() => [
        ChangeNotifierProvider<ColumnsViewModel>.value(value: vm),
        ChangeNotifierProvider<LoginViewModel>.value(value: loginVm),
        ChangeNotifierProvider<MessageFontService>.value(
          value: messageFontService,
        ),
        Provider<CloudUserDirectory>.value(
          value: CloudUserDirectory(
            StitchHttpClient(
              baseUrl: 'http://127.0.0.1:1',
              vault: InMemorySessionVault(),
            ),
          ),
        ),
      ];

  test('scrollPinParentForSend is the mid-thread reply parent', () {
    expect(vm.scrollPinParentForSend(columnId), isNull);

    vm.setReplyTarget(columnId, 'fork0001');
    expect(vm.scrollPinParentForSend(columnId), 'fork0001');
  });

  test('mid-thread send anchors the column on the reply parent', () async {
    vm.setReplyTarget(columnId, 'fork0001');
    final ok = await vm.sendMessage(columnId, 'new fork tip');
    expect(ok, isTrue);

    expect(vm.anchorOf(columnId), 'fork0001');
    final ids = vm.columns.single.rows.map((r) => r.message.id).toList();
    expect(ids.first, 'fork0001');
    expect(ids.length, 2);
    expect(ids.last, isNot('child-a1'));
    expect(ids.last, isNot('leaf-a01'));
  });

  test('tip append does not relocate the scroll-center anchor', () async {
    expect(vm.anchorOf(columnId), 'leaf-a01');
    final ok = await vm.sendMessage(columnId, 'append at tip');
    expect(ok, isTrue);
    expect(vm.anchorOf(columnId), 'leaf-a01');
    expect(vm.scrollPinParentForSend(columnId), isNull);
  });

  testWidgets(
    'mid-thread reply keeps the parent at a stable viewport Y',
    (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: providers(),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
              body: SizedBox(height: 800, child: ColumnsView()),
            ),
          ),
        ),
      );
      await pumpUiSettle(tester);

      expect(vm.anchorOf(columnId), 'leaf-a01');

      double topY(String id) {
        final box = tester.renderObject(
          find.byKey(ValueKey(id), skipOffstage: false),
        ) as RenderBox;
        return box.localToGlobal(Offset.zero).dy;
      }

      final parentFinder =
          find.byKey(const ValueKey('fork0001'), skipOffstage: false);
      expect(parentFinder, findsOneWidget);
      await tester.ensureVisible(parentFinder);
      await pumpUiSettle(tester);
      final parentYBefore = topY('fork0001');

      // Reply is hover-chrome; set the target directly, then send via the
      // composer so [_ColumnViewState._send] runs pin preservation.
      vm.setReplyTarget(columnId, 'fork0001');
      await pumpUiSettle(tester);

      await tester.enterText(find.byType(TextField), 'branch B');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      // Send is fire-and-forget from the composer; settle twice so the
      // post-frame pin drift correction inside navigatePreservingPin can run.
      await pumpUiSettle(tester);
      await pumpUiSettle(tester);

      expect(vm.anchorOf(columnId), 'fork0001');
      expect(
        topY('fork0001'),
        moreOrLessEquals(parentYBefore, epsilon: 3.0),
        reason:
            'Mid-thread fork send must keep the reply parent at the same '
            'viewport Y after center relocation',
      );
    },
  );
}
