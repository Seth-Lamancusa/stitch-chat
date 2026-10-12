import '../core/logging/stitch_log.dart';
import '../data/models/cloud_sync_status.dart';
import '../data/models/message.dart';
import '../data/repositories/message_repository.dart';
import '../data/services/cloud_message_api.dart';

/// Pulls reply/stitch adjacency from cloud for already-synced local messages
/// and materializes any missing neighbors into the local graph.
///
/// Used on window/toolbar refresh for messages on the visible branch — not
/// on every column `_refresh` (that stays local-only).
class CloudEdgeReconciler {
  CloudEdgeReconciler({
    required MessageRepository messages,
    required Future<Map<String, dynamic>?> Function(String cloudMessageId)
        fetchMessage,
  })  : _messages = messages,
        _fetchMessage = fetchMessage;

  final MessageRepository _messages;
  final Future<Map<String, dynamic>?> Function(String cloudMessageId)
      _fetchMessage;

  /// Reconcile every [branch] message with `syncStatus == synced` and a
  /// `cloudMessageId`. Returns whether the local graph changed.
  Future<bool> reconcileBranch(
    List<Message> branch, {
    String? columnId,
  }) async {
    final synced = [
      for (final m in branch)
        if (m.syncStatus == CloudSyncStatus.synced &&
            m.cloudMessageId != null &&
            m.cloudMessageId!.isNotEmpty)
          m,
    ];
    final col = columnId ?? '-';
    StitchLog.hop(
      'dart.cloud',
      'reconcile branch column=$col branch=${branch.length} synced=${synced.length}',
    );
    if (synced.isEmpty) return false;

    var changed = false;
    var edgesAdded = 0;
    var hydrated = 0;
    for (final message in synced) {
      final cloudId = message.cloudMessageId!;
      final wire = await _fetchMessage(cloudId);
      if (wire == null) {
        StitchLog.hop(
          'dart.cloud',
          'reconcile skip-missing column=$col local=${message.id} cloud=$cloudId',
        );
        continue;
      }
      final childIds = _stringIds(wire['child_ids']);
      final stitchOut = _stringIds(wire['stitch_child_ids']);
      final stitchIn = _stringIds(wire['stitch_parent_ids']);
      StitchLog.hop(
        'dart.cloud',
        'reconcile msg column=$col local=${message.id} cloud=$cloudId '
            'child_ids=${childIds.length} stitch_out=${stitchOut.length} '
            'stitch_in=${stitchIn.length}',
      );

      final reply = await _ensureReplyChildren(
        parent: message,
        childCloudIds: childIds,
        columnId: col,
      );
      final stitch = await _ensureStitchNeighbors(
        message: message,
        stitchChildren: stitchOut,
        stitchParents: stitchIn,
        columnId: col,
      );
      edgesAdded += reply.edgesAdded + stitch.edgesAdded;
      hydrated += reply.hydrated + stitch.hydrated;
      if (reply.edgesAdded > 0 || stitch.edgesAdded > 0) changed = true;
    }
    StitchLog.hop(
      'dart.cloud',
      'reconcile done column=$col changed=$changed edgesAdded=$edgesAdded '
          'hydrated=$hydrated',
    );
    return changed;
  }

  Future<_ReconcileDelta> _ensureReplyChildren({
    required Message parent,
    required List<String> childCloudIds,
    required String columnId,
  }) async {
    if (childCloudIds.isEmpty) return const _ReconcileDelta();

    final outgoing = await _messages.getOutgoing(parent.id);
    final known = <String>{};
    for (final child in [
      ...outgoing.replyOutgoing,
      ...outgoing.hiddenReplyOutgoing,
    ]) {
      known.add(child.id);
      final cloud = child.cloudMessageId;
      if (cloud != null && cloud.isNotEmpty) known.add(cloud);
    }

    var edgesAdded = 0;
    var hydrated = 0;
    var skippedKnown = 0;
    for (final childCloudId in childCloudIds) {
      if (known.contains(childCloudId)) {
        skippedKnown++;
        continue;
      }
      final ensured = await _ensureLocalMessage(childCloudId);
      if (ensured == null) {
        StitchLog.hop(
          'dart.cloud',
          'reconcile reply-fetch-miss column=$columnId '
              'parent=${parent.id} cloud=$childCloudId',
        );
        continue;
      }
      if (ensured.hydrated) hydrated++;
      if (known.contains(ensured.localId)) {
        skippedKnown++;
        continue;
      }
      await _messages.addReplyEdge(parent.id, ensured.localId);
      known.add(ensured.localId);
      known.add(childCloudId);
      edgesAdded++;
      StitchLog.hop(
        'dart.cloud',
        'reconcile reply column=$columnId ${parent.id} → ${ensured.localId} '
            '(cloud=$childCloudId hydrated=${ensured.hydrated})',
      );
    }
    if (skippedKnown > 0) {
      StitchLog.hop(
        'dart.cloud',
        'reconcile reply-known column=$columnId parent=${parent.id} '
            'skipped=$skippedKnown',
      );
    }
    return _ReconcileDelta(edgesAdded: edgesAdded, hydrated: hydrated);
  }

  Future<_ReconcileDelta> _ensureStitchNeighbors({
    required Message message,
    required List<String> stitchChildren,
    required List<String> stitchParents,
    required String columnId,
  }) async {
    if (stitchChildren.isEmpty && stitchParents.isEmpty) {
      return const _ReconcileDelta();
    }

    final outgoing = await _messages.getOutgoing(message.id);
    final incoming = await _messages.getIncoming(message.id);
    final knownOut = <String>{
      for (final m in outgoing.stitchedOutgoing) ...[
        m.id,
        if (m.cloudMessageId != null && m.cloudMessageId!.isNotEmpty)
          m.cloudMessageId!,
      ],
    };
    final knownIn = <String>{
      for (final m in incoming.stitchedIncoming) ...[
        m.id,
        if (m.cloudMessageId != null && m.cloudMessageId!.isNotEmpty)
          m.cloudMessageId!,
      ],
    };

    var edgesAdded = 0;
    var hydrated = 0;

    for (final otherCloudId in stitchChildren) {
      if (knownOut.contains(otherCloudId)) continue;
      final ensured = await _ensureLocalMessage(otherCloudId);
      if (ensured == null || knownOut.contains(ensured.localId)) continue;
      if (ensured.hydrated) hydrated++;
      await _messages.addStitchEdge(message.id, ensured.localId);
      knownOut.add(ensured.localId);
      knownOut.add(otherCloudId);
      edgesAdded++;
      StitchLog.hop(
        'dart.cloud',
        'reconcile stitch column=$columnId ${message.id} → ${ensured.localId} '
            '(cloud=$otherCloudId hydrated=${ensured.hydrated})',
      );
    }
    for (final otherCloudId in stitchParents) {
      if (knownIn.contains(otherCloudId)) continue;
      final ensured = await _ensureLocalMessage(otherCloudId);
      if (ensured == null || knownIn.contains(ensured.localId)) continue;
      if (ensured.hydrated) hydrated++;
      await _messages.addStitchEdge(ensured.localId, message.id);
      knownIn.add(ensured.localId);
      knownIn.add(otherCloudId);
      edgesAdded++;
      StitchLog.hop(
        'dart.cloud',
        'reconcile stitch column=$columnId ${ensured.localId} → ${message.id} '
            '(cloud=$otherCloudId hydrated=${ensured.hydrated})',
      );
    }
    return _ReconcileDelta(edgesAdded: edgesAdded, hydrated: hydrated);
  }

  Future<_EnsuredMessage?> _ensureLocalMessage(String cloudMessageId) async {
    final existing = await _messages.resolveGraphMessageId(cloudMessageId);
    if (existing != null) {
      return _EnsuredMessage(localId: existing, hydrated: false);
    }

    StitchLog.hop('dart.cloud', 'reconcile hydrate cloud=$cloudMessageId');
    final wire = await _fetchMessage(cloudMessageId);
    if (wire == null) {
      StitchLog.hop(
        'dart.cloud',
        'reconcile hydrate-miss cloud=$cloudMessageId',
      );
      return null;
    }

    final message = CloudMessageMapper.messageFromWire(wire);
    await _messages.saveMessage(message);
    await _persistEnrichment(message.id, wire);
    StitchLog.hop(
      'dart.cloud',
      'reconcile hydrated id=${message.id} cloud=$cloudMessageId '
          'chars=${message.content.length}',
    );
    return _EnsuredMessage(localId: message.id, hydrated: true);
  }

  Future<void> _persistEnrichment(
    String messageId,
    Map<String, dynamic> json,
  ) async {
    final tags = CloudMessageMapper.tagsFromWire(json);
    if (tags.isNotEmpty) {
      await _messages.setMessageTags(messageId, tags);
    }
    for (final entry in CloudMessageMapper.recipientsFromWire(json)) {
      final profile = entry.profile;
      if (profile != null) {
        await _messages.upsertParticipantProfile(profile);
      }
      await _messages.addRecipientEdge(
        messageId,
        entry.edge.recipientId,
        entry.edge.kind,
        isCloudBot: entry.edge.isCloudBot,
        isPublic: entry.edge.isPublic,
        notify: entry.edge.notify,
        addedBy: entry.edge.addedBy,
        addedAt: entry.edge.addedAt,
      );
    }
    final author = CloudMessageMapper.authorProfileFromWire(json);
    if (author != null) {
      await _messages.upsertParticipantProfile(author);
    }
  }

  static List<String> _stringIds(Object? raw) {
    if (raw is! List) return const [];
    final out = <String>[];
    final seen = <String>{};
    for (final entry in raw) {
      final id = entry?.toString().trim() ?? '';
      if (id.isEmpty || !seen.add(id)) continue;
      out.add(id);
    }
    return out;
  }
}

class _ReconcileDelta {
  const _ReconcileDelta({this.edgesAdded = 0, this.hydrated = 0});

  final int edgesAdded;
  final int hydrated;
}

class _EnsuredMessage {
  const _EnsuredMessage({required this.localId, required this.hydrated});

  final String localId;
  final bool hydrated;
}
