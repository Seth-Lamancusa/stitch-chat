import 'dart:convert';

import '../../core/logging/stitch_log.dart';
import '../models/cloud_sync_status.dart';
import '../models/message.dart';
import '../models/message_tag.dart';
import '../models/participant_profile.dart';
import 'stitch_http_client.dart';

class CloudMessageCreateResult {
  const CloudMessageCreateResult.success(this.cloudMessageId)
      : error = null,
        success = true;

  const CloudMessageCreateResult.failure(this.error)
      : cloudMessageId = null,
        success = false;

  final bool success;
  final String? cloudMessageId;
  final String? error;
}

/// Cloud recipient payload for `POST /v1/messages`.
class CloudRecipientInput {
  const CloudRecipientInput({
    required this.uid,
    this.notify = true,
    this.isPublic = true,
  });

  final String uid;
  final bool notify;
  final bool isPublic;
}

/// Creates messages on Stitch cloud for notify/sync (authenticated).
class CloudMessageApi {
  CloudMessageApi(this._http);

  final StitchHttpClient _http;

  Future<CloudMessageCreateResult> createMessage({
    required String content,
    String? parentCloudMessageId,
    required List<CloudRecipientInput> cloudRecipients,
    List<String> tags = const [],
    List<Map<String, dynamic>> context = const [],
  }) async {
    if (cloudRecipients.isEmpty) {
      return const CloudMessageCreateResult.failure('No cloud recipients');
    }

    final recipients = [
      for (final r in cloudRecipients)
        {
          'uid': r.uid,
          'notify': r.notify,
          'public': r.isPublic,
        },
    ];

    final payload = <String, dynamic>{
      'content': content,
      'recipients': recipients,
      'public': false,
      if (tags.isNotEmpty) 'tags': tags,
      if (parentCloudMessageId != null && parentCloudMessageId.isNotEmpty)
        'parent_id': parentCloudMessageId,
      // Client-provided ancestors for bot history — not persisted; pass-through
      // into notification content.context (same as stitch-frontend sendReply).
      if (context.isNotEmpty) 'context': context,
    };

    StitchLog.hop(
      'dart.cloud',
      '→api create parent=${parentCloudMessageId ?? "-"} '
          'recipients=${recipients.length} tags=${tags.length} '
          'context=${context.length}',
    );

    final response = await _http.post('/v1/messages', body: payload);
    if (response.statusCode != 200) {
      final detail = _extractError(response.body) ?? 'HTTP ${response.statusCode}';
      StitchLog.hop('dart.cloud', '←api create failed $detail');
      return CloudMessageCreateResult.failure(detail);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List || decoded.isEmpty) {
      return const CloudMessageCreateResult.failure('Empty create response');
    }

    final first = decoded.first;
    if (first is! Map<String, dynamic>) {
      return const CloudMessageCreateResult.failure('Invalid create response');
    }

    if (first['success'] != true) {
      final err = first['error']?.toString() ?? 'create_failed';
      return CloudMessageCreateResult.failure(err);
    }

    final message = first['message'];
    if (message is! Map<String, dynamic>) {
      return const CloudMessageCreateResult.failure('Missing message body');
    }

    final id = message['id'] as String?;
    if (id == null || id.isEmpty) {
      return const CloudMessageCreateResult.failure('Missing cloud message id');
    }

    StitchLog.hop('dart.cloud', '←api create id=$id');
    return CloudMessageCreateResult.success(id);
  }

  /// Fetch a single cloud message (`GET /v1/messages/{id}`), including
  /// adjacency fields (`child_ids`, `stitch_*_ids`) used for edge reconcile.
  /// Returns null on 404 / non-success (caller treats as skip).
  Future<Map<String, dynamic>?> fetchMessage(String cloudMessageId) async {
    if (cloudMessageId.isEmpty) return null;
    final path = '/v1/messages/${Uri.encodeComponent(cloudMessageId)}';
    StitchLog.hop('dart.cloud', '→api get id=$cloudMessageId');
    final response = await _http.get(path);
    if (response.statusCode == 404) {
      StitchLog.hop('dart.cloud', '←api get 404 id=$cloudMessageId');
      return null;
    }
    if (response.statusCode != 200) {
      final detail = _extractError(response.body) ?? 'HTTP ${response.statusCode}';
      StitchLog.hop('dart.cloud', '←api get failed id=$cloudMessageId $detail');
      throw StateError('Cloud message fetch failed: $detail');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Cloud message fetch: invalid body');
    }
    final children = decoded['child_ids'];
    final stitchOut = decoded['stitch_child_ids'];
    final stitchIn = decoded['stitch_parent_ids'];
    StitchLog.hop(
      'dart.cloud',
      '←api get id=$cloudMessageId '
          'child_ids=${children is List ? children.length : 0} '
          'stitch_out=${stitchOut is List ? stitchOut.length : 0} '
          'stitch_in=${stitchIn is List ? stitchIn.length : 0}',
    );
    return decoded;
  }

  String? _extractError(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map && json['detail'] != null) {
        return json['detail'].toString();
      }
    } catch (_) {}
    return body.isNotEmpty ? body : null;
  }
}

/// Maps WS/API message payloads into local graph messages + enrichment.
class CloudMessageMapper {
  static Message messageFromWire(Map<String, dynamic> json) {
    final author = json['author'];
    String? authorId;
    if (author is Map<String, dynamic>) {
      authorId = author['uid'] as String?;
    }
    authorId ??= json['content_author'] as String?;

    final createdAtRaw = json['timestamp'] as String?;
    DateTime? createdAt;
    if (createdAtRaw != null) {
      createdAt = DateTime.tryParse(createdAtRaw)?.toUtc();
    }

    return Message(
      id: json['id'] as String,
      role: MessageRole.user,
      authorId: authorId,
      content: json['content'] as String? ?? '',
      createdAt: createdAt ?? DateTime.now().toUtc(),
      cloudMessageId: json['id'] as String,
      syncStatus: CloudSyncStatus.synced,
    );
  }

  static ParticipantProfile? authorProfileFromWire(Map<String, dynamic> json) {
    final author = json['author'];
    if (author is! Map<String, dynamic>) return null;
    final uid = author['uid'] as String?;
    if (uid == null || uid.isEmpty) return null;
    return ParticipantProfile(
      uid: uid,
      userTag: author['user_tag'] as String?,
      displayName: author['display_name'] as String?,
      isBot: author['is_bot'] as bool? ?? false,
    );
  }

  /// Parse wire `tags` (string or object forms) into local [MessageTag]s.
  static List<MessageTag> tagsFromWire(Map<String, dynamic> json) {
    final raw = json['tags'];
    if (raw is! List) return const [];
    final out = <MessageTag>[];
    final seen = <String>{};
    for (final entry in raw) {
      String? name;
      DateTime? createdAt;
      String? addedBy;
      String? addedByTag;
      if (entry is String) {
        name = entry.trim().toLowerCase();
      } else if (entry is Map) {
        final map = Map<String, dynamic>.from(entry);
        name = (map['name'] as String?)?.trim().toLowerCase();
        final createdRaw = map['created_at'] as String?;
        if (createdRaw != null) {
          createdAt = DateTime.tryParse(createdRaw)?.toUtc();
        }
        addedBy = map['added_by'] as String?;
        addedByTag = map['added_by_tag'] as String?;
      }
      if (name == null || name.isEmpty || !seen.add(name)) continue;
      out.add(MessageTag(
        name: name,
        createdAt: createdAt,
        addedBy: addedBy,
        addedByTag: addedByTag,
      ));
    }
    return out;
  }

  /// Parse wire recipients into local edges + optional profiles to upsert.
  static List<({RecipientRef edge, ParticipantProfile? profile})>
      recipientsFromWire(Map<String, dynamic> json) {
    final raw = json['recipients'];
    if (raw is! List) return const [];
    final out = <({RecipientRef edge, ParticipantProfile? profile})>[];
    final seen = <String>{};
    for (final entry in raw) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final uid = map['uid'] as String?;
      if (uid == null || uid.isEmpty || !seen.add(uid)) continue;

      final isPublic = map['is_public'] as bool? ??
          map['public'] as bool? ??
          true;
      final addedBy = map['added_by'] as String?;
      DateTime? addedAt;
      final ts = map['timestamp'] as String?;
      if (ts != null) {
        addedAt = DateTime.tryParse(ts)?.toUtc();
      }

      final isBot = map['is_bot'] as bool? ?? false;
      final userTag = map['user_tag'] as String?;
      final displayName = map['display_name'] as String?;

      out.add((
        edge: RecipientRef(
          recipientId: uid,
          kind: RecipientKind.cloudUser,
          isCloudBot: isBot,
          isPublic: isPublic,
          notify: true,
          addedBy: addedBy,
          addedAt: addedAt,
        ),
        profile: ParticipantProfile(
          uid: uid,
          userTag: userTag,
          displayName: displayName,
          isBot: isBot,
        ),
      ));
    }
    return out;
  }
}
