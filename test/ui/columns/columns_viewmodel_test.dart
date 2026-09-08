import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_chat/data/models/message.dart';
import 'package:stitch_chat/data/services/local_identity_service.dart';
import 'package:stitch_chat/domain/branch_path_service.dart';
import 'package:stitch_chat/domain/message_store.dart';
import 'package:stitch_chat/ui/core/adaptive_marker.dart';
import 'package:stitch_chat/ui/columns/columns_viewmodel.dart';

import '../../domain/branch_path_service_test.dart' show FakeColumnRepository, FakeMessageRepository;

class _FakeIdentityService implements LocalIdentityService {
  @override
  String get currentUserId => 'me';

  @override
  Future<void> initialize() async {}
}

class _ThrowingColumnRepository extends FakeColumnRepository {
  bool shouldThrow = false;

  @override
  Future<void> setBranchPointer(String columnId, String parentId, String childId) {
    if (shouldThrow) throw Exception('boom');
    return super.setBranchPointer(columnId, parentId, childId);
  }
}

void main() {
  late FakeMessageRepository messages;
  late FakeColumnRepository columns;
  late MessageStore store;
  late BranchPathService branchPathService;
  late ColumnsViewModel vm;
  // FakeColumnRepository ids columns 'col-<n>' by creation order within its
  // own instance; every test here creates exactly one column, so it's
  // always 'col-0' — whether via the shared `columns` or a test-local fake.
  const columnId = 'col-0';

  Message msg(String id, DateTime createdAt) =>
      Message(id: id, role: MessageRole.user, content: id, createdAt: createdAt);

  setUp(() {
    messages = FakeMessageRepository();
    columns = FakeColumnRepository();
    store = MessageStore(messages);
    branchPathService = BranchPathService(messages, columns, store);
    vm = ColumnsViewModel(messages, columns, branchPathService, store, _FakeIdentityService());
  });

  group('selectCandidate', () {
    test('persists via setBranchPointer for outgoing and toggles bottomLoading', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('child', DateTime.utc(2026, 1, 2)));
      await columns.createColumn(anchorMessageId: 'root');
      await vm.initialize();

      await vm.selectCandidate(columnId, 'root', 'child', Direction.outgoing);

      expect(await columns.getVisibleOutgoing(columnId, 'root'), 'child');
      expect(vm.columns.first.bottomLoading, isFalse);
    });

    test('persists via setVisibleIncoming for incoming and toggles topLoading', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('child', DateTime.utc(2026, 1, 2)));
      await columns.createColumn(anchorMessageId: 'child');
      await vm.initialize();

      await vm.selectCandidate(columnId, 'child', 'root', Direction.incoming);

      expect(await columns.getVisibleIncoming(columnId, 'child'), 'root');
      expect(vm.columns.first.topLoading, isFalse);
    });
  });

  group('defaultPage', () {
    test('batches through reply defaults and reports hasMore at the batch cap', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      String prev = 'root';
      for (var i = 0; i < 5; i++) {
        final id = 'm$i';
        await messages.saveMessage(msg(id, DateTime.utc(2026, 1, 2 + i)));
        await messages.addReplyEdge(prev, id);
        prev = id;
      }
      await columns.createColumn(anchorMessageId: 'root');
      await vm.initialize();

      final result = await vm.defaultPage(columnId, 'root', Direction.outgoing, 3);

      expect(result.messages.map((m) => m.id).toList(), ['m0', 'm1', 'm2']);
      expect(result.hasMore, isTrue);
      expect(result.stitchCount, 0);
    });

    test('stops at a stitch boundary with hasMore false and the stitch count', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('stitchA', DateTime.utc(2026, 1, 2)));
      await messages.saveMessage(msg('stitchB', DateTime.utc(2026, 1, 3)));
      await messages.addStitchEdge('root', 'stitchA');
      await messages.addStitchEdge('root', 'stitchB');
      await columns.createColumn(anchorMessageId: 'root');
      await vm.initialize();

      final result = await vm.defaultPage(columnId, 'root', Direction.outgoing, 5);

      expect(result.messages, isEmpty);
      expect(result.hasMore, isFalse);
      expect(result.stitchCount, 2);
    });

    test('stops at a true end with stitchCount 0', () async {
      await messages.saveMessage(msg('leaf', DateTime.utc(2026, 1, 1)));
      await columns.createColumn(anchorMessageId: 'leaf');
      await vm.initialize();

      final result = await vm.defaultPage(columnId, 'leaf', Direction.outgoing, 5);

      expect(result.messages, isEmpty);
      expect(result.hasMore, isFalse);
      expect(result.stitchCount, 0);
    });
  });

  group('revealStitch', () {
    test('persists the forced stitch hop then continues via defaultPage', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('stitchChild', DateTime.utc(2026, 1, 2)));
      await messages.saveMessage(msg('grandchild', DateTime.utc(2026, 1, 3)));
      await messages.addStitchEdge('root', 'stitchChild');
      await messages.addReplyEdge('stitchChild', 'grandchild');
      await columns.createColumn(anchorMessageId: 'root');
      await vm.initialize();

      await vm.revealStitch(columnId, 'root', Direction.outgoing);

      expect(await columns.getVisibleOutgoing(columnId, 'root'), 'stitchChild');
      expect(
        vm.columns.first.rows.map((r) => r.message.id).toList(),
        ['root', 'stitchChild', 'grandchild'],
      );
    });
  });

  group('loadInitialWindow / fresh-anchor _refresh', () {
    test('windows to kDefaultRadius hops rather than the whole chain', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      String prev = 'root';
      final total = kDefaultRadius + 10;
      for (var i = 0; i < total; i++) {
        final id = 'm$i';
        await messages.saveMessage(msg(id, DateTime.utc(2026, 1, 2).add(Duration(days: i))));
        await messages.addReplyEdge(prev, id);
        prev = id;
      }
      await columns.createColumn(anchorMessageId: 'root');

      await vm.initialize();

      // anchor + kDefaultRadius below (nothing above the root).
      expect(vm.columns.first.rows.length, kDefaultRadius + 1);
      expect(vm.columns.first.bottomMarker, MarkerVisualState.waiting);
    });

    test('an ordinary rerender after the window is established does not re-batch further', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      String prev = 'root';
      for (var i = 0; i < kDefaultRadius + 10; i++) {
        final id = 'm$i';
        await messages.saveMessage(msg(id, DateTime.utc(2026, 1, 2).add(Duration(days: i))));
        await messages.addReplyEdge(prev, id);
        prev = id;
      }
      await columns.createColumn(anchorMessageId: 'root');
      await vm.initialize();
      final rowCountAfterInit = vm.columns.first.rows.length;

      // navigateOutgoing re-anchors at 'root' (the parent) and refreshes via
      // plain materializedTrajectory (no isFreshAnchor) — since 'root' is
      // already within the loaded window, the recentered walk should surface
      // the same total row count, not extend it further.
      await vm.navigateOutgoing(columnId, 'root', forward: true);

      expect(vm.columns.first.rows.length, rowCountAfterInit);
    });
  });

  group('error handling', () {
    test('a failed extend sets the error and a later successful one clears it', () async {
      // A chain longer than kDefaultRadius so initialize's windowed load
      // (which runs before `shouldThrow` is set) doesn't already consume
      // every node — extendBelow needs an unresolved hop left to attempt.
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      var prev = 'root';
      for (var i = 0; i < kDefaultRadius + 5; i++) {
        final id = 'm$i';
        await messages.saveMessage(msg(id, DateTime.utc(2026, 1, 2).add(Duration(days: i))));
        await messages.addReplyEdge(prev, id);
        prev = id;
      }
      final throwingColumns = _ThrowingColumnRepository();
      final throwingStore = MessageStore(messages);
      final throwingBranchPathService = BranchPathService(messages, throwingColumns, throwingStore);
      final throwingVm = ColumnsViewModel(
        messages,
        throwingColumns,
        throwingBranchPathService,
        throwingStore,
        _FakeIdentityService(),
      );
      await throwingColumns.createColumn(anchorMessageId: 'root');
      await throwingVm.initialize();

      throwingColumns.shouldThrow = true;
      await throwingVm.extendBelow(columnId);
      expect(throwingVm.columns.first.bottomError, isNotNull);

      throwingColumns.shouldThrow = false;
      await throwingVm.extendBelow(columnId);
      expect(throwingVm.columns.first.bottomError, isNull);
    });
  });
}
