import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stitch_chat/core/notifications/notification_service.dart';
import 'package:stitch_chat/data/models/message.dart';
import 'package:stitch_chat/data/repositories/auth_repository.dart';
import 'package:stitch_chat/data/repositories/column_repository.dart';
import 'package:stitch_chat/data/repositories/fake_auth_repository.dart';
import 'package:stitch_chat/data/services/local_identity_service.dart';
import 'package:stitch_chat/domain/branch_path_service.dart';
import 'package:stitch_chat/ui/auth/login_viewmodel.dart';
import 'package:stitch_chat/ui/columns/columns_view.dart';
import 'package:stitch_chat/ui/columns/columns_viewmodel.dart';
import 'package:stitch_chat/ui/core/theme/app_theme.dart';

import '../../domain/branch_path_service_test.dart' show FakeMessageRepository;

class FakeIdentityService implements LocalIdentityService {
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

// _Header.build does id.substring(0, 8), so ids need to be at least 8 chars.
class InMemoryColumnRepository implements ColumnRepository {
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
    _columns[id] = ColumnMeta(id: existing.id, anchorMessageId: existing.anchorMessageId, width: width);
  }

  @override
  Future<void> updateColumnAnchor(String id, String anchorMessageId) async {
    final existing = _columns[id]!;
    _columns[id] = ColumnMeta(id: existing.id, anchorMessageId: anchorMessageId, width: existing.width);
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
  Future<void> setBranchPointer(String columnId, String parentId, String childId) async {
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
  Future<void> setVisibleIncoming(String columnId, String childId, String newParentId) async {
    (_visibleIncoming[columnId] ??= {})[childId] = newParentId;
  }
}

void main() {
  late LoginViewModel loginVm;

  setUp(() {
    loginVm = LoginViewModel(
      authRepository: FakeAuthRepository(),
      notifications: NotificationService(),
    );
  });

  tearDown(() => loginVm.dispose());

  List<ChangeNotifierProvider> _providers(ColumnsViewModel vm) => [
        ChangeNotifierProvider<ColumnsViewModel>.value(value: vm),
        ChangeNotifierProvider<LoginViewModel>.value(value: loginVm),
      ];

  testWidgets('scroll position is preserved when switching columns', (tester) async {
    final messages = FakeMessageRepository();
    final columns = InMemoryColumnRepository();
    final branchPathService = BranchPathService(messages, columns);
    final vm = ColumnsViewModel(messages, columns, branchPathService, FakeIdentityService());

    // Seed column A with many messages so it's scrollable.
    String? prevA;
    for (var i = 0; i < 40; i++) {
      final m = Message(
        id: 'a$i',
        role: MessageRole.user,
        authorId: 'me',
        content: 'message $i',
        createdAt: DateTime(2024, 1, 1).add(Duration(minutes: i)),
      );
      await messages.saveMessage(m);
      if (prevA != null) await messages.addReplyEdge(prevA, m.id);
      prevA = m.id;
    }
    final colA = await columns.createColumn(anchorMessageId: prevA);
    final colB = await columns.createColumn(anchorMessageId: null);

    await vm.initialize();
    expect(vm.columns.length, 2);

    await tester.pumpWidget(
      MultiProvider(
        providers: _providers(vm),
        child: MaterialApp(theme: AppTheme.light(), home: const ColumnsView()),
      ),
    );
    await tester.pumpAndSettle();

    final scrollableFinder = find.descendant(
      of: find.byKey(ValueKey(colA.id)),
      matching: find.byType(Scrollable),
    );

    await tester.drag(scrollableFinder.first, const Offset(0, 300));
    await tester.pumpAndSettle();

    // Column A's `CustomScrollView` is centered on its persisted anchor
    // (the last/bottom message), so dragging toward older content — which
    // lives in the before-anchor sliver — moves `pixels` negative, not
    // positive as it would in the old `reverse: true` ListView.
    final offsetAfterScroll = tester.state<ScrollableState>(scrollableFinder.first).position.pixels;
    expect(offsetAfterScroll, lessThan(0));

    await tester.tap(find.byKey(ValueKey(colB.id)).first);
    await tester.pumpAndSettle();

    final offsetAfterSwitch = tester.state<ScrollableState>(scrollableFinder.first).position.pixels;
    expect(offsetAfterSwitch, offsetAfterScroll,
        reason: 'Switching the active column must not move column A\'s scroll position');
  });

  testWidgets(
    'scroll position is preserved when a column to the left is removed',
    (tester) async {
      final messages = FakeMessageRepository();
      final columns = InMemoryColumnRepository();
      final branchPathService = BranchPathService(messages, columns);
      final vm = ColumnsViewModel(
        messages,
        columns,
        branchPathService,
        FakeIdentityService(),
      );

      String? prevA;
      for (var i = 0; i < 40; i++) {
        final m = Message(
          id: 'a$i',
          role: MessageRole.user,
          authorId: 'me',
          content: 'message $i',
          createdAt: DateTime(2024, 1, 1).add(Duration(minutes: i)),
        );
        await messages.saveMessage(m);
        if (prevA != null) await messages.addReplyEdge(prevA, m.id);
        prevA = m.id;
      }

      final colLeft = await columns.createColumn(anchorMessageId: null);
      final colRight = await columns.createColumn(anchorMessageId: prevA);

      await vm.initialize();
      expect(vm.columns.length, 2);

      await tester.pumpWidget(
        MultiProvider(
          providers: _providers(vm),
          child: MaterialApp(theme: AppTheme.light(), home: const ColumnsView()),
        ),
      );
      await tester.pumpAndSettle();

      final scrollableRight = find.descendant(
        of: find.byKey(ValueKey(colRight.id)),
        matching: find.byType(Scrollable),
      );

      await tester.drag(scrollableRight.first, const Offset(0, 300));
      await tester.pumpAndSettle();

      final offsetAfterScroll =
          tester.state<ScrollableState>(scrollableRight.first).position.pixels;
      expect(offsetAfterScroll, lessThan(0));

      await vm.removeColumn(colLeft.id);
      await tester.pumpAndSettle();

      expect(vm.columns.single.id, colRight.id);
      final offsetAfterRemove =
          tester.state<ScrollableState>(scrollableRight.first).position.pixels;
      expect(
        offsetAfterRemove,
        offsetAfterScroll,
        reason:
            'Removing a column to the left must not reset the remaining '
            'column\'s scroll position when it shifts to an earlier index',
      );
    },
  );

  testWidgets(
    'first outgoing sibling switch keeps the parent at a stable viewport Y',
    (tester) async {
      final messages = FakeMessageRepository();
      final columns = InMemoryColumnRepository();
      final branchPathService = BranchPathService(messages, columns);
      final vm = ColumnsViewModel(
        messages,
        columns,
        branchPathService,
        FakeIdentityService(),
      );

      Future<Message> save(
        String id,
        String content, {
        DateTime? at,
      }) async {
        final m = Message(
          id: id,
          role: MessageRole.user,
          authorId: 'me',
          content: content,
          createdAt: at ?? DateTime(2024, 1, 1),
        );
        await messages.saveMessage(m);
        return m;
      }

      await save('fork0001', 'fork parent', at: DateTime(2024, 1, 1));
      await save('child-a1', 'branch A child', at: DateTime(2024, 1, 2));
      await save('leaf-a01', 'branch A leaf', at: DateTime(2024, 1, 3));
      await save('child-b1', 'branch B child', at: DateTime(2024, 1, 4));
      await save('leaf-b01', 'branch B leaf', at: DateTime(2024, 1, 5));

      await messages.addReplyEdge('fork0001', 'child-a1');
      await messages.addReplyEdge('child-a1', 'leaf-a01');
      await messages.addReplyEdge('fork0001', 'child-b1');
      await messages.addReplyEdge('child-b1', 'leaf-b01');

      // Anchor on the child that hosts the outgoing navigator (not the
      // parent). The first sibling switch then relocates the center from
      // this child onto the fork parent — the case that needs correction.
      await columns.createColumn(anchorMessageId: 'child-a1');
      await vm.initialize();

      await tester.pumpWidget(
        MultiProvider(
          providers: _providers(vm),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ColumnsView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(vm.anchorOf(vm.columns.single.id), 'child-a1');
      expect(
        vm.columns.single.rows.map((r) => r.message.id),
        containsAll(['fork0001', 'child-a1', 'leaf-a01']),
      );

      double topY(String id) {
        final box = tester.renderObject(
          find.byKey(ValueKey(id), skipOffstage: false),
        ) as RenderBox;
        return box.localToGlobal(Offset.zero).dy;
      }

      expect(
        find.byKey(ValueKey('fork0001'), skipOffstage: false),
        findsOneWidget,
      );

      // Pull older content into view so the fork parent is on-screen and the
      // scroll range has room to apply the center-relocation correction.
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, 240),
      );
      await tester.pumpAndSettle();

      final parentYBefore = topY('fork0001');
      // Sanity: parent and current center are not already the same slot.
      expect(
        topY('fork0001'),
        isNot(moreOrLessEquals(topY('child-a1'), epsilon: 1.0)),
      );

      // Outgoing navigator mounts on the child; Next advances fork → B.
      // The leaf row also builds a disabled Next tooltip, so scope the tap.
      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey('child-a1'), skipOffstage: false),
          matching: find.byTooltip('Next'),
        ),
      );
      await tester.pumpAndSettle();

      expect(vm.anchorOf(vm.columns.single.id), 'fork0001');
      expect(
        topY('fork0001'),
        moreOrLessEquals(parentYBefore, epsilon: 3.0),
        reason:
            'First sibling switch must keep the navigation parent at the '
            'same viewport Y after center relocation',
      );
    },
  );

  testWidgets('first message in a column starts at thread top', (tester) async {
    final messages = FakeMessageRepository();
    final columns = InMemoryColumnRepository();
    final branchPathService = BranchPathService(messages, columns);
    final vm = ColumnsViewModel(
      messages,
      columns,
      branchPathService,
      FakeIdentityService(),
    );
    final col = await columns.createColumn(anchorMessageId: null);
    await vm.initialize();

    await tester.pumpWidget(
      MultiProvider(
        providers: _providers(vm),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: SizedBox(height: 800, child: ColumnsView())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: find.byKey(ValueKey(col.id)),
      matching: find.byType(CustomScrollView),
    );
    final position = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: scrollable,
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;

    expect(position.pixels, position.minScrollExtent);
    expect(position.minScrollExtent, lessThan(0));
  });
}
