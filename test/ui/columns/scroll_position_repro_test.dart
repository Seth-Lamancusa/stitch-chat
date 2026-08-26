import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stitch_chat/data/models/message.dart';
import 'package:stitch_chat/data/repositories/column_repository.dart';
import 'package:stitch_chat/data/services/local_identity_service.dart';
import 'package:stitch_chat/domain/branch_path_service.dart';
import 'package:stitch_chat/ui/columns/columns_view.dart';
import 'package:stitch_chat/ui/columns/columns_viewmodel.dart';
import 'package:stitch_chat/ui/core/theme/app_theme.dart';

import '../../domain/branch_path_service_test.dart' show FakeMessageRepository;

class FakeIdentityService implements LocalIdentityService {
  @override
  String get currentUserId => 'me';

  @override
  Future<void> initialize() async {}
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
        providers: [ChangeNotifierProvider<ColumnsViewModel>.value(value: vm)],
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
}
