import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_chat/data/models/message.dart';
import 'package:stitch_chat/data/repositories/column_repository.dart';
import 'package:stitch_chat/data/repositories/message_repository.dart';
import 'package:stitch_chat/domain/branch_path_service.dart';

class FakeMessageRepository implements MessageRepository {
  final Map<String, Message> _messages = {};
  final Map<String, String> _replyParentOf = {};
  final Map<String, bool> _replyEdgeHidden = {};
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

    final children = _replyChildrenOf[parentId] ?? const [];
    final visible = <String>[];
    final hidden = <String>[];
    for (final id in children) {
      if (_replyEdgeHidden[id] == true) {
        hidden.add(id);
      } else {
        visible.add(id);
      }
    }

    return OutgoingEdges(
      replyOutgoing: sorted(visible),
      hiddenReplyOutgoing: sorted(hidden),
      stitchedOutgoing: sorted(_stitchChildrenOf[parentId] ?? const []),
    );
  }

  @override
  Future<IncomingEdges> getIncoming(String childId) async {
    final replyParentId = _replyParentOf[childId];
    final stitchParentIds = _stitchParentsOf[childId] ?? const [];
    final hidden = _replyEdgeHidden[childId] == true;
    return IncomingEdges(
      replyIncoming: [
        if (replyParentId != null && !hidden) _messages[replyParentId]!,
      ],
      hiddenReplyIncoming: [
        if (replyParentId != null && hidden) _messages[replyParentId]!,
      ],
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
  Future<List<Message>> getThreadRoots() async {
    final roots = _messages.values
        .where((m) => !_replyParentOf.containsKey(m.id))
        .toList();
    roots.sort((a, b) {
      final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final byTime = bt.compareTo(at);
      if (byTime != 0) return byTime;
      return a.id.compareTo(b.id);
    });
    return roots;
  }

  @override
  Stream<List<Message>> watchThreadRoots() =>
      Stream.fromFuture(getThreadRoots());

  @override
  Future<void> addReplyEdge(
    String parentId,
    String childId, {
    bool hidden = false,
  }) async {
    _replyParentOf[childId] = parentId;
    _replyEdgeHidden[childId] = hidden;
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
  Future<List<RecipientRef>> getRecipients(String messageId) async => const [];

  @override
  Future<void> deleteMessage(String id) async => _messages.remove(id);

  @override
  Future<int> rewriteAuthorId({
    required String fromAuthorId,
    required String toAuthorId,
  }) async {
    if (fromAuthorId.isEmpty || fromAuthorId == toAuthorId) return 0;
    var count = 0;
    for (final entry in _messages.entries.toList()) {
      if (entry.value.authorId == fromAuthorId) {
        _messages[entry.key] = Message(
          id: entry.value.id,
          role: entry.value.role,
          authorId: toAuthorId,
          content: entry.value.content,
          gitCommit: entry.value.gitCommit,
          createdAt: entry.value.createdAt,
          isStreaming: entry.value.isStreaming,
        );
        count++;
      }
    }
    return count;
  }
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

  group('isNextOnVisibleOutgoing', () {
    test('null pointer is on-path only for the default non-hidden reply', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('older', DateTime.utc(2026, 1, 2)));
      await messages.saveMessage(msg('newer', DateTime.utc(2026, 1, 3)));
      await messages.addReplyEdge('root', 'older');
      await messages.addReplyEdge('root', 'newer');

      expect(
        await service.isNextOnVisibleOutgoing(columnId, 'root', 'newer'),
        isTrue,
      );
      expect(
        await service.isNextOnVisibleOutgoing(columnId, 'root', 'older'),
        isFalse,
      );
    });

    test('null pointer is off-path for hidden-only children', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('hidden', DateTime.utc(2026, 1, 2)));
      await messages.addReplyEdge('root', 'hidden', hidden: true);

      expect(
        await service.isNextOnVisibleOutgoing(columnId, 'root', 'hidden'),
        isFalse,
      );
    });

    test('matching pointer is on-path', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('new', DateTime.utc(2026, 1, 2)));
      await messages.addReplyEdge('root', 'new');
      await columns.setBranchPointer(columnId, 'root', 'new');
      expect(
        await service.isNextOnVisibleOutgoing(columnId, 'root', 'new'),
        isTrue,
      );
    });

    test('sibling pointer is off-path', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('older', DateTime.utc(2026, 1, 2)));
      await messages.saveMessage(msg('new', DateTime.utc(2026, 1, 3)));
      await messages.addReplyEdge('root', 'older');
      await messages.addReplyEdge('root', 'new');
      await columns.setBranchPointer(columnId, 'root', 'older');
      expect(
        await service.isNextOnVisibleOutgoing(columnId, 'root', 'new'),
        isFalse,
      );
    });
  });

  group('hidden reply edges', () {
    test('default walk skips hidden children', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('hidden', DateTime.utc(2026, 1, 2)));
      await messages.addReplyEdge('root', 'hidden', hidden: true);

      final branch = await service.getFullVisibleBranch(columnId, 'root');
      expect(branch.map((m) => m.id).toList(), ['root']);
    });

    test('explicit navigation crosses into a hidden child', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('hidden', DateTime.utc(2026, 1, 2)));
      await messages.saveMessage(msg('hiddenLeaf', DateTime.utc(2026, 1, 3)));
      await messages.addReplyEdge('root', 'hidden', hidden: true);
      await messages.addReplyEdge('hidden', 'hiddenLeaf');

      final branch =
          await service.navigateOutgoing(columnId, 'root', forward: true);
      expect(branch.map((m) => m.id).toList(), ['root', 'hidden', 'hiddenLeaf']);
    });

    test('non-hidden reply wins default; nav can reach hidden sibling', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('reply', DateTime.utc(2026, 1, 2)));
      await messages.saveMessage(msg('hidden', DateTime.utc(2026, 1, 3)));
      await messages.addReplyEdge('root', 'reply');
      await messages.addReplyEdge('root', 'hidden', hidden: true);

      final defaults = await service.getFullVisibleBranch(columnId, 'root');
      expect(defaults.map((m) => m.id).toList(), ['root', 'reply']);

      // Hidden is first in `.all`, so from the reply slot step backward.
      final revealed =
          await service.navigateOutgoing(columnId, 'root', forward: false);
      expect(revealed.map((m) => m.id).toList(), ['root', 'hidden']);
    });

    test('replyTreeIds includes hidden reply descendants', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('hidden', DateTime.utc(2026, 1, 2)));
      await messages.addReplyEdge('root', 'hidden', hidden: true);

      expect(await service.replyTreeIds('root'), {'root', 'hidden'});
    });
  });

  group('replyTreeIds', () {
    test('includes every reply fork under the thread root, not just the visible path', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('a', DateTime.utc(2026, 1, 2)));
      await messages.saveMessage(msg('b', DateTime.utc(2026, 1, 3)));
      await messages.saveMessage(msg('a1', DateTime.utc(2026, 1, 4)));
      await messages.addReplyEdge('root', 'a');
      await messages.addReplyEdge('root', 'b');
      await messages.addReplyEdge('a', 'a1');
      await columns.setBranchPointer(columnId, 'root', 'b');

      final ids = await service.replyTreeIds('b');

      expect(ids, {'root', 'a', 'b', 'a1'});
    });

    test('ignores stitch-only neighbors', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('stitched', DateTime.utc(2026, 1, 2)));
      await messages.addStitchEdge('root', 'stitched');

      expect(await service.replyTreeIds('root'), {'root'});
    });
  });

  group('wouldLandOnVisibleBranch', () {
    test('true when parent is on the visible path and child is the default pick', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('new', DateTime.utc(2026, 1, 2)));
      await messages.addReplyEdge('root', 'new');
      expect(
        await service.wouldLandOnVisibleBranch(columnId, 'root', 'root', 'new'),
        isTrue,
      );
    });

    test('false when parent is on the visible path but another sibling is selected', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('older', DateTime.utc(2026, 1, 2)));
      await messages.addReplyEdge('root', 'older');
      await columns.setBranchPointer(columnId, 'root', 'older');

      expect(
        await service.wouldLandOnVisibleBranch(columnId, 'older', 'root', 'new'),
        isFalse,
      );
    });

    test('false when parent is in the reply tree but off the visible path', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('a', DateTime.utc(2026, 1, 2)));
      await messages.saveMessage(msg('b', DateTime.utc(2026, 1, 3)));
      await messages.addReplyEdge('root', 'a');
      await messages.addReplyEdge('root', 'b');
      await columns.setBranchPointer(columnId, 'root', 'b');

      expect(
        await service.wouldLandOnVisibleBranch(columnId, 'b', 'a', 'a-child'),
        isFalse,
      );
    });
  });
}
