import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_chat/data/models/message.dart';
import 'package:stitch_chat/data/repositories/column_repository.dart';
import 'package:stitch_chat/data/repositories/message_repository.dart';
import 'package:stitch_chat/domain/branch_path_service.dart';
import 'package:stitch_chat/domain/message_store.dart';

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
      list.sort(
        (a, b) =>
            (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)),
      );
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
  Future<void> addStitchEdge(
    String fromId,
    String toId, {
    String? createdByAuthorId,
  }) async {
    (_stitchChildrenOf[fromId] ??= []).add(toId);
    (_stitchParentsOf[toId] ??= []).add(fromId);
  }

  @override
  Future<void> addRecipientEdge(
    String messageId,
    String recipientId,
    RecipientKind kind,
  ) async {}

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
  Future<ColumnMeta> createColumn({
    String? anchorMessageId,
    double? width,
  }) async {
    final id = 'col-${_columns.length}';
    final meta = ColumnMeta(
      id: id,
      anchorMessageId: anchorMessageId,
      width: width,
    );
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
    );
  }

  @override
  Future<void> updateColumnAnchor(String id, String anchorMessageId) async {
    final existing = _columns[id]!;
    _columns[id] = ColumnMeta(
      id: existing.id,
      anchorMessageId: anchorMessageId,
      width: existing.width,
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
  late MessageStore store;
  late BranchPathService service;
  const columnId = 'col-1';

  setUp(() {
    messages = FakeMessageRepository();
    columns = FakeColumnRepository();
    store = MessageStore(messages);
    service = BranchPathService(messages, columns, store);
  });

  Message msg(String id, DateTime createdAt) => Message(
    id: id,
    role: MessageRole.user,
    content: id,
    createdAt: createdAt,
  );

  group('materializedTrajectory', () {
    test('an unknown anchor returns an empty branch', () async {
      expect(
        await service.materializedTrajectory(columnId, 'missing'),
        isEmpty,
      );
    });

    test('a root with no pointers set returns just itself', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));

      final branch = await service.materializedTrajectory(columnId, 'root');

      expect(branch.map((m) => m.id).toList(), ['root']);
    });

    test(
      'never falls back to reply-structural ancestry when no incoming pointer is set',
      () async {
        // Unlike the old getFullVisibleBranch/_visibleOrStructuralIncoming,
        // materializedTrajectory is a pure pointer read — an unset incoming
        // pointer stops the walk, even though 'leaf' has a real reply parent.
        await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
        await messages.saveMessage(msg('leaf', DateTime.utc(2026, 1, 2)));
        await messages.addReplyEdge('root', 'leaf');

        final branch = await service.materializedTrajectory(columnId, 'leaf');

        expect(branch.map((m) => m.id).toList(), ['leaf']);
      },
    );

    test(
      'walks both directions via persisted pointers, stopping at the first unset one',
      () async {
        await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
        await messages.saveMessage(msg('mid', DateTime.utc(2026, 1, 2)));
        await messages.saveMessage(msg('leaf', DateTime.utc(2026, 1, 3)));
        await messages.saveMessage(msg('beyond', DateTime.utc(2026, 1, 4)));
        await messages.addReplyEdge('root', 'mid');
        await messages.addReplyEdge('mid', 'leaf');
        await messages.addReplyEdge('leaf', 'beyond');
        await columns.setBranchPointer(columnId, 'root', 'mid');
        await columns.setBranchPointer(columnId, 'mid', 'leaf');
        // No pointer set below 'leaf' or above 'root' — walk stops there even
        // though 'beyond' exists structurally.

        final branch = await service.materializedTrajectory(columnId, 'mid');

        expect(branch.map((m) => m.id).toList(), ['root', 'mid', 'leaf']);
      },
    );
  });

  group('candidatesAt / resolveDefaultCandidate', () {
    test(
      'resolves the most-recent reply child outgoing, ignoring stitch children',
      () async {
        await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
        await messages.saveMessage(msg('older', DateTime.utc(2026, 1, 2)));
        await messages.saveMessage(msg('newer', DateTime.utc(2026, 1, 3)));
        await messages.saveMessage(
          msg('stitchChild', DateTime.utc(2026, 1, 4)),
        );
        await messages.addReplyEdge('root', 'older');
        await messages.addReplyEdge('root', 'newer');
        await messages.addStitchEdge('root', 'stitchChild');

        final candidate = await service.resolveDefaultCandidate(
          'root',
          Direction.outgoing,
        );

        expect(candidate?.id, 'newer');
      },
    );

    test('resolves the single reply parent incoming', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('leaf', DateTime.utc(2026, 1, 2)));
      await messages.addReplyEdge('root', 'leaf');

      final candidate = await service.resolveDefaultCandidate(
        'leaf',
        Direction.incoming,
      );

      expect(candidate?.id, 'root');
    });

    test(
      'is null when only a stitch child exists, even though it is the only child',
      () async {
        await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
        await messages.saveMessage(
          msg('stitchChild', DateTime.utc(2026, 1, 2)),
        );
        await messages.addStitchEdge('root', 'stitchChild');

        final candidate = await service.resolveDefaultCandidate(
          'root',
          Direction.outgoing,
        );

        expect(candidate, isNull);
      },
    );

    test('is null at a true dead end', () async {
      await messages.saveMessage(msg('leaf', DateTime.utc(2026, 1, 1)));

      expect(
        await service.resolveDefaultCandidate('leaf', Direction.outgoing),
        isNull,
      );
      expect(
        await service.resolveDefaultCandidate('leaf', Direction.incoming),
        isNull,
      );
    });

    test(
      'candidatesAt reports the stitch pool alongside the reply candidate',
      () async {
        await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
        await messages.saveMessage(msg('replyChild', DateTime.utc(2026, 1, 2)));
        await messages.saveMessage(
          msg('stitchChild', DateTime.utc(2026, 1, 3)),
        );
        await messages.addReplyEdge('root', 'replyChild');
        await messages.addStitchEdge('root', 'stitchChild');

        final candidates = await service.candidatesAt(
          'root',
          Direction.outgoing,
        );

        expect(candidates.replyCandidate?.id, 'replyChild');
        expect(candidates.stitchCandidates.map((m) => m.id).toList(), [
          'stitchChild',
        ]);
      },
    );
  });

  group('resolveForcedStitchCandidate', () {
    test('returns the first stitch candidate outgoing', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('stitchA', DateTime.utc(2026, 1, 2)));
      await messages.saveMessage(msg('stitchB', DateTime.utc(2026, 1, 3)));
      await messages.addStitchEdge('root', 'stitchA');
      await messages.addStitchEdge('root', 'stitchB');

      final candidate = await service.resolveForcedStitchCandidate(
        'root',
        Direction.outgoing,
      );

      expect(candidate?.id, 'stitchA');
    });

    test('returns the first stitch parent incoming', () async {
      await messages.saveMessage(
        msg('stitchParentA', DateTime.utc(2026, 1, 1)),
      );
      await messages.saveMessage(
        msg('stitchParentB', DateTime.utc(2026, 1, 2)),
      );
      await messages.saveMessage(msg('child', DateTime.utc(2026, 1, 3)));
      await messages.addStitchEdge('stitchParentA', 'child');
      await messages.addStitchEdge('stitchParentB', 'child');

      final candidate = await service.resolveForcedStitchCandidate(
        'child',
        Direction.incoming,
      );

      expect(candidate?.id, 'stitchParentA');
    });

    test('is null with no stitch candidates', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      expect(
        await service.resolveForcedStitchCandidate('root', Direction.outgoing),
        isNull,
      );
    });
  });

  group('resolveExplicitOutgoing', () {
    setUp(() async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('a', DateTime.utc(2026, 1, 2)));
      await messages.saveMessage(msg('b', DateTime.utc(2026, 1, 3)));
      await messages.saveMessage(msg('c', DateTime.utc(2026, 1, 4)));
      await messages.addReplyEdge('root', 'a');
      await messages.addReplyEdge('root', 'b');
      await messages.addReplyEdge('root', 'c');
    });

    test('forward from unset resolves to the first sibling', () async {
      expect(
        await service.resolveExplicitOutgoing(columnId, 'root', forward: true),
        'a',
      );
    });

    test('backward from unset resolves to the last sibling', () async {
      expect(
        await service.resolveExplicitOutgoing(columnId, 'root', forward: false),
        'c',
      );
    });

    test(
      'forward advances to the next sibling and clamps at the end',
      () async {
        await columns.setBranchPointer(columnId, 'root', 'a');

        expect(
          await service.resolveExplicitOutgoing(
            columnId,
            'root',
            forward: true,
          ),
          'b',
        );
        await columns.setBranchPointer(columnId, 'root', 'b');
        expect(
          await service.resolveExplicitOutgoing(
            columnId,
            'root',
            forward: true,
          ),
          'c',
        );
        await columns.setBranchPointer(columnId, 'root', 'c');
        expect(
          await service.resolveExplicitOutgoing(
            columnId,
            'root',
            forward: true,
          ),
          'c',
        );
      },
    );

    test(
      'backward retreats to the previous sibling and clamps at the start',
      () async {
        await columns.setBranchPointer(columnId, 'root', 'c');

        expect(
          await service.resolveExplicitOutgoing(
            columnId,
            'root',
            forward: false,
          ),
          'b',
        );
        await columns.setBranchPointer(columnId, 'root', 'b');
        expect(
          await service.resolveExplicitOutgoing(
            columnId,
            'root',
            forward: false,
          ),
          'a',
        );
        await columns.setBranchPointer(columnId, 'root', 'a');
        expect(
          await service.resolveExplicitOutgoing(
            columnId,
            'root',
            forward: false,
          ),
          'a',
        );
      },
    );

    test(
      'sees the combined reply-then-stitch pool, unlike default resolution',
      () async {
        await messages.saveMessage(
          msg('stitchChild', DateTime.utc(2026, 1, 5)),
        );
        await messages.addStitchEdge('root', 'stitchChild');
        await columns.setBranchPointer(columnId, 'root', 'c');

        expect(
          await service.resolveExplicitOutgoing(
            columnId,
            'root',
            forward: true,
          ),
          'stitchChild',
        );
      },
    );

    test('a parent with no children resolves to null', () async {
      expect(
        await service.resolveExplicitOutgoing(columnId, 'a', forward: true),
        isNull,
      );
    });
  });

  group('resolveExplicitIncoming', () {
    setUp(() async {
      await messages.saveMessage(msg('replyParent', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(
        msg('stitchParentA', DateTime.utc(2026, 1, 2)),
      );
      await messages.saveMessage(
        msg('stitchParentB', DateTime.utc(2026, 1, 3)),
      );
      await messages.saveMessage(msg('child', DateTime.utc(2026, 1, 4)));
      await messages.addReplyEdge('replyParent', 'child');
      await messages.addStitchEdge('stitchParentA', 'child');
      await messages.addStitchEdge('stitchParentB', 'child');
    });

    test('forward from unset resolves to the reply parent first', () async {
      expect(
        await service.resolveExplicitIncoming(columnId, 'child', forward: true),
        'replyParent',
      );
    });

    test('backward from unset resolves to the last stitch parent', () async {
      expect(
        await service.resolveExplicitIncoming(
          columnId,
          'child',
          forward: false,
        ),
        'stitchParentB',
      );
    });

    test('forward cycles reply-then-stitch and clamps at the end', () async {
      expect(
        await service.resolveExplicitIncoming(columnId, 'child', forward: true),
        'replyParent',
      );
      await columns.setVisibleIncoming(columnId, 'child', 'replyParent');
      expect(
        await service.resolveExplicitIncoming(columnId, 'child', forward: true),
        'stitchParentA',
      );
      await columns.setVisibleIncoming(columnId, 'child', 'stitchParentA');
      expect(
        await service.resolveExplicitIncoming(columnId, 'child', forward: true),
        'stitchParentB',
      );
      await columns.setVisibleIncoming(columnId, 'child', 'stitchParentB');
      expect(
        await service.resolveExplicitIncoming(columnId, 'child', forward: true),
        'stitchParentB',
      );
    });

    test('a child with no incoming edges resolves to null', () async {
      await messages.saveMessage(msg('lonely', DateTime.utc(2026, 1, 5)));
      expect(
        await service.resolveExplicitIncoming(
          columnId,
          'lonely',
          forward: true,
        ),
        isNull,
      );
    });
  });

  group('findLatestDescendant', () {
    test(
      'descends via the most-recent child at each fork until a leaf',
      () async {
        await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
        await messages.saveMessage(msg('older', DateTime.utc(2026, 1, 2)));
        await messages.saveMessage(msg('newer', DateTime.utc(2026, 1, 3)));
        await messages.saveMessage(msg('newerLeaf', DateTime.utc(2026, 1, 4)));
        await messages.addReplyEdge('root', 'older');
        await messages.addReplyEdge('root', 'newer');
        await messages.addReplyEdge('newer', 'newerLeaf');

        final latest = await service.findLatestDescendant('root');

        expect(latest.id, 'newerLeaf');
      },
    );

    test('a leaf is its own latest descendant', () async {
      await messages.saveMessage(msg('leaf', DateTime.utc(2026, 1, 1)));

      expect((await service.findLatestDescendant('leaf')).id, 'leaf');
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

      expect(
        await service.resolveDefaultCandidate('root', Direction.outgoing),
        isNull,
      );
      expect(
        (await service.materializedTrajectory(columnId, 'root')).map((m) => m.id),
        ['root'],
      );
    });

    test('explicit navigation can select a hidden child', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('hidden', DateTime.utc(2026, 1, 2)));
      await messages.saveMessage(msg('hiddenLeaf', DateTime.utc(2026, 1, 3)));
      await messages.addReplyEdge('root', 'hidden', hidden: true);
      await messages.addReplyEdge('hidden', 'hiddenLeaf');

      expect(
        await service.resolveExplicitOutgoing(columnId, 'root', forward: true),
        'hidden',
      );
    });

    test('non-hidden reply wins default; nav can reach hidden sibling', () async {
      await messages.saveMessage(msg('root', DateTime.utc(2026, 1, 1)));
      await messages.saveMessage(msg('reply', DateTime.utc(2026, 1, 2)));
      await messages.saveMessage(msg('hidden', DateTime.utc(2026, 1, 3)));
      await messages.addReplyEdge('root', 'reply');
      await messages.addReplyEdge('root', 'hidden', hidden: true);

      expect(
        (await service.resolveDefaultCandidate('root', Direction.outgoing))?.id,
        'reply',
      );

      // Hidden is first in `.all`, so from the reply slot step backward.
      await columns.setBranchPointer(columnId, 'root', 'reply');
      expect(
        await service.resolveExplicitOutgoing(columnId, 'root', forward: false),
        'hidden',
      );
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
