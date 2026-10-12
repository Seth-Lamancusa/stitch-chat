import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_chat/data/models/cloud_sync_status.dart';
import 'package:stitch_chat/data/models/message.dart';
import 'package:stitch_chat/data/models/message_tag.dart';
import 'package:stitch_chat/data/models/participant_profile.dart';
import 'package:stitch_chat/data/repositories/message_repository.dart';
import 'package:stitch_chat/domain/cloud_edge_reconciler.dart';

class _FakeMessages implements MessageRepository {
  final Map<String, Message> messages = {};
  final Map<String, String> replyParentOf = {};
  final Map<String, List<String>> replyChildrenOf = {};
  final Map<String, List<String>> stitchChildrenOf = {};
  final Map<String, List<String>> stitchParentsOf = {};

  @override
  Future<void> saveMessage(Message message) async {
    messages[message.id] = message;
  }

  @override
  Future<Message?> getMessage(String id) async => messages[id];

  @override
  Future<OutgoingEdges> getOutgoing(String parentId) async {
    Message? of(String id) => messages[id];
    return OutgoingEdges(
      replyOutgoing: [
        for (final id in replyChildrenOf[parentId] ?? const <String>[])
          if (of(id) != null) of(id)!,
      ],
      stitchedOutgoing: [
        for (final id in stitchChildrenOf[parentId] ?? const <String>[])
          if (of(id) != null) of(id)!,
      ],
    );
  }

  @override
  Future<IncomingEdges> getIncoming(String childId) async {
    final parent = replyParentOf[childId];
    return IncomingEdges(
      replyIncoming: [
        if (parent != null && messages[parent] != null) messages[parent]!,
      ],
      stitchedIncoming: [
        for (final id in stitchParentsOf[childId] ?? const <String>[])
          if (messages[id] != null) messages[id]!,
      ],
    );
  }

  @override
  Future<List<Message>> getAncestorPath(String messageId) async => const [];

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
  }) async {
    replyParentOf[childId] = parentId;
    final list = replyChildrenOf.putIfAbsent(parentId, () => []);
    if (!list.contains(childId)) list.add(childId);
  }

  @override
  Future<void> addStitchEdge(
    String fromId,
    String toId, {
    String? createdByAuthorId,
  }) async {
    final out = stitchChildrenOf.putIfAbsent(fromId, () => []);
    if (!out.contains(toId)) out.add(toId);
    final incoming = stitchParentsOf.putIfAbsent(toId, () => []);
    if (!incoming.contains(fromId)) incoming.add(fromId);
  }

  @override
  Future<void> addRecipientEdge(
    String messageId,
    String recipientId,
    RecipientKind kind, {
    bool isCloudBot = false,
    bool isPublic = true,
    bool notify = true,
    String? addedBy,
    DateTime? addedAt,
  }) async {}

  @override
  Future<List<RecipientRef>> getRecipients(String messageId) async =>
      const [];

  @override
  Future<void> setMessageTags(String messageId, List<MessageTag> tags) async {}

  @override
  Future<List<MessageTag>> getMessageTags(String messageId) async =>
      const [];

  @override
  Future<void> deleteMessage(String id) async => messages.remove(id);

  @override
  Future<String?> resolveGraphMessageId(String cloudOrLocalId) async {
    if (messages.containsKey(cloudOrLocalId)) return cloudOrLocalId;
    final byCloud = await getMessageByCloudId(cloudOrLocalId);
    return byCloud?.id;
  }

  @override
  Future<Message?> getMessageByCloudId(String cloudMessageId) async {
    for (final m in messages.values) {
      if (m.cloudMessageId == cloudMessageId) return m;
    }
    return null;
  }

  @override
  Future<void> updateCloudSync({
    required String localMessageId,
    CloudSyncStatus? syncStatus,
    String? cloudMessageId,
    String? syncError,
  }) async {}

  @override
  Future<void> upsertParticipantProfile(ParticipantProfile profile) async {}

  @override
  Future<ParticipantProfile?> getParticipantProfile(String uid) async => null;

  @override
  Future<int> rewriteAuthorId({
    required String fromAuthorId,
    required String toAuthorId,
  }) async =>
      0;
}

Map<String, dynamic> _wireMessage({
  required String id,
  String content = 'hi',
  List<String> childIds = const [],
  List<String> stitchChildIds = const [],
  List<String> stitchParentIds = const [],
}) {
  return {
    'id': id,
    'content': content,
    'timestamp': DateTime.utc(2026, 1, 1).toIso8601String(),
    'author': {'uid': 'u1', 'user_tag': 'alice', 'display_name': 'Alice'},
    'child_ids': childIds,
    'stitch_child_ids': stitchChildIds,
    'stitch_parent_ids': stitchParentIds,
  };
}

void main() {
  test('hydrates missing reply child under a synced tip', () async {
    final repo = _FakeMessages();
    final tip = Message(
      id: 'local-tip',
      role: MessageRole.user,
      content: 'parent',
      cloudMessageId: 'cloud-tip',
      syncStatus: CloudSyncStatus.synced,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    await repo.saveMessage(tip);

    final cloud = <String, Map<String, dynamic>>{
      'cloud-tip': _wireMessage(
        id: 'cloud-tip',
        childIds: ['cloud-child'],
      ),
      'cloud-child': _wireMessage(id: 'cloud-child', content: 'reply from cloud'),
    };

    final reconciler = CloudEdgeReconciler(
      messages: repo,
      fetchMessage: (id) async => cloud[id],
    );

    final changed = await reconciler.reconcileBranch([tip]);
    expect(changed, isTrue);
    expect(repo.messages.containsKey('cloud-child'), isTrue);
    expect(repo.replyParentOf['cloud-child'], 'local-tip');
    expect(repo.replyChildrenOf['local-tip'], ['cloud-child']);
  });

  test('links stitch neighbors and skips already-known edges', () async {
    final repo = _FakeMessages();
    final tip = Message(
      id: 'local-tip',
      role: MessageRole.user,
      content: 'parent',
      cloudMessageId: 'cloud-tip',
      syncStatus: CloudSyncStatus.synced,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final existing = Message(
      id: 'cloud-stitch',
      role: MessageRole.user,
      content: 'stitched',
      cloudMessageId: 'cloud-stitch',
      syncStatus: CloudSyncStatus.synced,
      createdAt: DateTime.utc(2026, 1, 2),
    );
    await repo.saveMessage(tip);
    await repo.saveMessage(existing);
    await repo.addStitchEdge('local-tip', 'cloud-stitch');

    final cloud = <String, Map<String, dynamic>>{
      'cloud-tip': _wireMessage(
        id: 'cloud-tip',
        stitchChildIds: ['cloud-stitch', 'cloud-new-stitch'],
      ),
      'cloud-new-stitch': _wireMessage(
        id: 'cloud-new-stitch',
        content: 'new stitch',
      ),
    };

    final reconciler = CloudEdgeReconciler(
      messages: repo,
      fetchMessage: (id) async => cloud[id],
    );

    final changed = await reconciler.reconcileBranch([tip]);
    expect(changed, isTrue);
    expect(repo.stitchChildrenOf['local-tip'], ['cloud-stitch', 'cloud-new-stitch']);
    expect(repo.messages['cloud-new-stitch']?.content, 'new stitch');
  });

  test('ignores unsynced branch messages', () async {
    final repo = _FakeMessages();
    final localOnly = Message(
      id: 'local-only',
      role: MessageRole.user,
      content: 'no cloud',
      syncStatus: CloudSyncStatus.none,
    );
    await repo.saveMessage(localOnly);

    var fetches = 0;
    final reconciler = CloudEdgeReconciler(
      messages: repo,
      fetchMessage: (id) async {
        fetches++;
        return null;
      },
    );

    final changed = await reconciler.reconcileBranch([localOnly]);
    expect(changed, isFalse);
    expect(fetches, 0);
  });
}
