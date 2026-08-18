import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_chat/data/models/message.dart';
import 'package:stitch_chat/data/repositories/column_repository.dart';
import 'package:stitch_chat/data/repositories/message_repository.dart';
import 'package:stitch_chat/domain/branch_path_service.dart';

class FakeMessageRepository implements MessageRepository {
  final Map<String, Message> _messages = {};
  final Map<String, String> _replyParentOf = {};
  final Map<String, List<String>> _replyChildrenOf = {};
  final Map<String, List<String>> _stitchChildrenOf = {};
  final Map<String, List<String>> _stitchParentsOf = {};

  @override
  Future<void> saveMessage(Message message) async {
    _messages[message.id] = message;
  }

  @override
  Future<Message?> getMessage(String id) async => _messages[id];

  @override
  Future<OutgoingEdges> getOutgoing(String parentId) async {
    List<Message> sorted(List<String> ids) {
      final list = ids.map((id) => _messages[id]!).toList();
      list.sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
      return list;
    }

    return OutgoingEdges(
      replyOutgoing: sorted(_replyChildrenOf[parentId] ?? const []),
      stitchedOutgoing: sorted(_stitchChildrenOf[parentId] ?? const []),
    );
  }

  @override
  Future<IncomingEdges> getIncoming(String childId) async {
    final replyParentId = _replyParentOf[childId];
    final stitchParentIds = _stitchParentsOf[childId] ?? const [];
    return IncomingEdges(
      replyIncoming: [if (replyParentId != null) _messages[replyParentId]!],
      stitchedIncoming: stitchParentIds.map((id) => _messages[id]!).toList(),
    );
  }

  @override
  Future<List<Message>> getAncestorPath(String messageId) async {
    final path = <Message>[];
    String? current = messageId;
    while (current != null && _messages.containsKey(current)) {
      path.insert(0, _messages[current]!);
      current = _replyParentOf[current];
    }
    return path;
  }

  @override
  Stream<List<Message>> watchReplyOutgoing(String parentId) =>
      Stream.fromFuture(getOutgoing(parentId).then((e) => e.replyOutgoing));

  @override
  Future<void> addReplyEdge(String parentId, String childId) async {
    _replyParentOf[childId] = parentId;
    (_replyChildrenOf[parentId] ??= []).add(childId);
  }

  @override
  Future<void> addStitchEdge(String fromId, String toId, {String? createdByAuthorId}) async {
    (_stitchChildrenOf[fromId] ??= []).add(toId);
    (_stitchParentsOf[toId] ??= []).add(fromId);
  }

  @override
  Future<void> addRecipientEdge(String messageId, String recipientId, RecipientKind kind) async {}

  @override
  Future<void> deleteMessage(String id) async => _messages.remove(id);
}

class FakeColumnRepository implements ColumnRepository {
  final Map<String, ColumnMeta> _columns = {};
  final Map<String, Map<String, String>> _visibleOutgoing = {};
  final Map<String, Map<String, String>> _visibleIncoming = {};

  @override
  Future<ColumnMeta> createColumn({String? anchorMessageId, double? width}) async {
    final id = 'col-${_columns.length}';
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
    final oldParentId = _visibleIncoming[columnId]?[childId];
    if (oldParentId != null) {
      _visibleOutgoing[columnId]?.remove(oldParentId);
    }
    (_visibleOutgoing[columnId] ??= {})[newParentId] = childId;
    (_visibleIncoming[columnId] ??= {})[childId] = newParentId;
  }
}

void main() {
  late FakeMessageRepository messages;
  late FakeColumnRepository columns;
  late BranchPathService service;
  const columnId = 'col-1';

  setUp(() {
    messages = FakeMessageRepository();
    columns = FakeColumnRepository();
    service = BranchPathService(messages, columns);
  });

  Message msg(String id, DateTime createdAt) =>
      Message(id: id, role: MessageRole.user, content: id, createdAt: createdAt);

  group('boundaries', () {
    test('a root with no children returns just itself', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));

      final branch = await service.getFullVisibleBranch(columnId, 'root');

      expect(branch.map((m) => m.id).toList(), ['root']);
    });

    test('a leaf anchor returns its ancestry followed by itself, with nothing below', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('leaf', DateTime.utc(2026, 1, 2)));
      await messages.addReplyEdge('root', 'leaf');

      final branch = await service.getFullVisibleBranch(columnId, 'leaf');

      expect(branch.map((m) => m.id).toList(), ['root', 'leaf']);
    });

    test('an unknown anchor returns an empty branch', () async {
      expect(await service.getFullVisibleBranch(columnId, 'missing'), isEmpty);
    });
  });

  group('fork defaulting', () {
    test('defaults to the most-recently-created child at an unset fork, and persists it', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('older', DateTime.utc(2026, 1, 2)));
      await messages.saveMessage(msg('newer', DateTime.utc(2026, 1, 3)));
      await messages.addReplyEdge('root', 'older');
      await messages.addReplyEdge('root', 'newer');

      final branch = await service.getFullVisibleBranch(columnId, 'root');

      expect(branch.map((m) => m.id).toList(), ['root', 'newer']);
      expect(await columns.getVisibleOutgoing(columnId, 'root'), 'newer');
    });

    test('an already-persisted pointer overrides the most-recent default', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('older', DateTime.utc(2026, 1, 2)));
      await messages.saveMessage(msg('newer', DateTime.utc(2026, 1, 3)));
      await messages.addReplyEdge('root', 'older');
      await messages.addReplyEdge('root', 'newer');
      await columns.setBranchPointer(columnId, 'root', 'older');

      final branch = await service.getFullVisibleBranch(columnId, 'root');

      expect(branch.map((m) => m.id).toList(), ['root', 'older']);
    });

    test('defaulting continues recursively down multiple forks', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('mid', DateTime.utc(2026, 1, 2)));
      await messages.saveMessage(msg('leafA', DateTime.utc(2026, 1, 3)));
      await messages.saveMessage(msg('leafB', DateTime.utc(2026, 1, 4)));
      await messages.addReplyEdge('root', 'mid');
      await messages.addReplyEdge('mid', 'leafA');
      await messages.addReplyEdge('mid', 'leafB');

      final branch = await service.getFullVisibleBranch(columnId, 'root');

      expect(branch.map((m) => m.id).toList(), ['root', 'mid', 'leafB']);
    });

    test('defaulting never auto-follows a stitch child, even if it is the only child', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('stitchChild', DateTime.utc(2026, 1, 2)));
      await messages.addStitchEdge('root', 'stitchChild');

      final branch = await service.getFullVisibleBranch(columnId, 'root');

      expect(branch.map((m) => m.id).toList(), ['root']);
    });
  });

  group('findLatestDescendant', () {
    test('descends via the most-recent child at each fork until a leaf', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('older', DateTime.utc(2026, 1, 2)));
      await messages.saveMessage(msg('newer', DateTime.utc(2026, 1, 3)));
      await messages.saveMessage(msg('newerLeaf', DateTime.utc(2026, 1, 4)));
      await messages.addReplyEdge('root', 'older');
      await messages.addReplyEdge('root', 'newer');
      await messages.addReplyEdge('newer', 'newerLeaf');

      final latest = await service.findLatestDescendant('root');

      expect(latest.id, 'newerLeaf');
    });

    test('a leaf is its own latest descendant', () async {
      await messages.saveMessage(msg('leaf', DateTime.utc(2026, 1, 1)));

      expect((await service.findLatestDescendant('leaf')).id, 'leaf');
    });
  });

  group('navigateOutgoing', () {
    setUp(() async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('a', DateTime.utc(2026, 1, 2)));
      await messages.saveMessage(msg('b', DateTime.utc(2026, 1, 3)));
      await messages.saveMessage(msg('c', DateTime.utc(2026, 1, 4)));
      await messages.addReplyEdge('root', 'a');
      await messages.addReplyEdge('root', 'b');
      await messages.addReplyEdge('root', 'c');
    });

    test('forward from unset moves to the first sibling', () async {
      final branch = await service.navigateOutgoing(columnId, 'root', forward: true);
      expect(branch.map((m) => m.id).toList(), ['root', 'a']);
    });

    test('backward from unset moves to the last sibling', () async {
      final branch = await service.navigateOutgoing(columnId, 'root', forward: false);
      expect(branch.map((m) => m.id).toList(), ['root', 'c']);
    });

    test('forward advances to the next sibling and clamps at the end', () async {
      await columns.setBranchPointer(columnId, 'root', 'a');

      var branch = await service.navigateOutgoing(columnId, 'root', forward: true);
      expect(branch.map((m) => m.id).toList(), ['root', 'b']);

      branch = await service.navigateOutgoing(columnId, 'root', forward: true);
      expect(branch.map((m) => m.id).toList(), ['root', 'c']);

      branch = await service.navigateOutgoing(columnId, 'root', forward: true);
      expect(branch.map((m) => m.id).toList(), ['root', 'c']);
    });

    test('backward retreats to the previous sibling and clamps at the start', () async {
      await columns.setBranchPointer(columnId, 'root', 'c');

      var branch = await service.navigateOutgoing(columnId, 'root', forward: false);
      expect(branch.map((m) => m.id).toList(), ['root', 'b']);

      branch = await service.navigateOutgoing(columnId, 'root', forward: false);
      expect(branch.map((m) => m.id).toList(), ['root', 'a']);

      branch = await service.navigateOutgoing(columnId, 'root', forward: false);
      expect(branch.map((m) => m.id).toList(), ['root', 'a']);
    });

    test('switching outgoing re-derives the path below the switch point', () async {
      await messages.saveMessage(msg('aChild', DateTime.utc(2026, 1, 5)));
      await messages.addReplyEdge('a', 'aChild');
      await columns.setBranchPointer(columnId, 'root', 'a');
      await columns.setBranchPointer(columnId, 'a', 'aChild');

      final branch = await service.navigateOutgoing(columnId, 'root', forward: true);

      expect(branch.map((m) => m.id).toList(), ['root', 'b']);
    });

    test('a parent with no children returns its unchanged branch', () async {
      final branch = await service.navigateOutgoing(columnId, 'a', forward: true);
      expect(branch.map((m) => m.id).toList(), ['root', 'a']);
    });
  });

  group('navigateIncoming', () {
    setUp(() async {
      await messages.saveMessage(msg('replyParent', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('stitchParentA', DateTime.utc(2026, 1, 2)));
      await messages.saveMessage(msg('stitchParentB', DateTime.utc(2026, 1, 3)));
      await messages.saveMessage(msg('child', DateTime.utc(2026, 1, 4)));
      await messages.addReplyEdge('replyParent', 'child');
      await messages.addStitchEdge('stitchParentA', 'child');
      await messages.addStitchEdge('stitchParentB', 'child');
    });

    test('forward from unset lands on the first pool entry (the reply parent itself)', () async {
      final branch = await service.navigateIncoming(columnId, 'child', forward: true);
      expect(branch.map((m) => m.id).toList(), ['replyParent', 'child']);
    });

    test('backward from unset wraps to the last stitch parent', () async {
      final branch = await service.navigateIncoming(columnId, 'child', forward: false);
      expect(branch.map((m) => m.id).toList(), ['stitchParentB', 'child']);
    });

    test('forward cycles through the pool in reply-then-stitch order and clamps at the end', () async {
      var branch = await service.navigateIncoming(columnId, 'child', forward: true);
      expect(branch.map((m) => m.id).toList(), ['replyParent', 'child']);

      branch = await service.navigateIncoming(columnId, 'child', forward: true);
      expect(branch.map((m) => m.id).toList(), ['stitchParentA', 'child']);

      branch = await service.navigateIncoming(columnId, 'child', forward: true);
      expect(branch.map((m) => m.id).toList(), ['stitchParentB', 'child']);

      branch = await service.navigateIncoming(columnId, 'child', forward: true);
      expect(branch.map((m) => m.id).toList(), ['stitchParentB', 'child']);
    });

    test('backward from a stitch parent returns to the reply parent', () async {
      await columns.setVisibleIncoming(columnId, 'child', 'stitchParentA');

      final branch = await service.navigateIncoming(columnId, 'child', forward: false);

      expect(branch.map((m) => m.id).toList(), ['replyParent', 'child']);
    });

    test('a child with no incoming edges returns its unchanged branch', () async {
      await messages.saveMessage(msg('lonely', DateTime.utc(2026, 1, 5)));
      final branch = await service.navigateIncoming(columnId, 'lonely', forward: true);
      expect(branch.map((m) => m.id).toList(), ['lonely']);
    });

    test('switching incoming re-derives everything above the switch point', () async {
      await messages.saveMessage(msg('grandparent', DateTime.utc(2025, 12, 31)));
      await messages.addReplyEdge('grandparent', 'stitchParentA');
      await columns.setVisibleIncoming(columnId, 'child', 'replyParent');

      final branch = await service.navigateIncoming(columnId, 'child', forward: true);

      expect(branch.map((m) => m.id).toList(), ['grandparent', 'stitchParentA', 'child']);
    });
  });

  group('combined reply + stitch pool', () {
    test('outgoing defaulting sees reply children only, but explicit navigation sees stitch children too', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('replyChild', DateTime.utc(2026, 1, 2)));
      await messages.saveMessage(msg('stitchChild', DateTime.utc(2026, 1, 3)));
      await messages.addReplyEdge('root', 'replyChild');
      await messages.addStitchEdge('root', 'stitchChild');

      final forwardOnce = await service.navigateOutgoing(columnId, 'root', forward: true);
      expect(forwardOnce.map((m) => m.id).toList(), ['root', 'replyChild']);

      final forwardTwice = await service.navigateOutgoing(columnId, 'root', forward: true);
      expect(forwardTwice.map((m) => m.id).toList(), ['root', 'stitchChild']);
    });
  });
}
