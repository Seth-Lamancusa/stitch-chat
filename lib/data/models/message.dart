import 'cloud_sync_status.dart';

/// The one message type shared by the live WS chat stream and the
/// persisted conversation tree — supersedes the split `ChatMessage`/
/// `PersistedMessage` types. Thread topology is not modeled here: it lives
/// exclusively in edge tables owned by [MessageRepository], not as fields
/// on this class.
enum MessageRole { user, localBot, functionCall, functionResult, thinking }

/// Who a message is addressed to, for [MessageRepository.addRecipientEdge].
enum RecipientKind { localBot, cloudUser }

/// One existing recipient edge on a message, as returned by
/// [MessageRepository.getRecipients].
///
/// Mirrors stitch-backend `receivers` edge fields used for CC/BCC and
/// provenance. [notify] is send-intent only (not stored on the server).
class RecipientRef {
  final String recipientId;
  final RecipientKind kind;

  /// For [RecipientKind.cloudUser], whether the uid is a cloud bot (`is_bot`).
  final bool isCloudBot;

  /// CC (`true`) vs BCC (`false`) — maps to backend `public`.
  final bool isPublic;

  /// Whether cloud create should notify this recipient.
  final bool notify;

  /// UID of who added this recipient; null when unknown.
  final String? addedBy;

  /// Null = original create-time recipient; set when added later.
  final DateTime? addedAt;

  const RecipientRef({
    required this.recipientId,
    required this.kind,
    this.isCloudBot = false,
    this.isPublic = true,
    this.notify = true,
    this.addedBy,
    this.addedAt,
  });
}

class Message {
  final String id;
  final MessageRole role;
  final String? authorId;
  final String content;
  final String? gitCommit;

  /// Null until the message has been persisted.
  final DateTime? createdAt;

  /// Transient UI state for a live WS reply still streaming in — never
  /// persisted, always false on a message loaded from storage.
  final bool isStreaming;

  /// Transient UI state for an optimistic outbound send that has not yet
  /// finished local persist (+ cloud notify when required). Never persisted;
  /// always false on a message loaded from storage.
  final bool isSending;

  /// Stitch cloud message id when this row has been created on the backend.
  final String? cloudMessageId;

  final CloudSyncStatus syncStatus;

  /// Last cloud notify/create error (for contextual menu / hover).
  final String? syncError;

  const Message({
    required this.id,
    required this.role,
    required this.content,
    this.authorId,
    this.gitCommit,
    this.createdAt,
    this.isStreaming = false,
    this.isSending = false,
    this.cloudMessageId,
    this.syncStatus = CloudSyncStatus.none,
    this.syncError,
  });

  bool get isSyncedOnCloud =>
      syncStatus == CloudSyncStatus.synced &&
      cloudMessageId != null &&
      cloudMessageId!.isNotEmpty;

  Message copyWith({
    String? authorId,
    String? content,
    bool? isStreaming,
    bool? isSending,
    DateTime? createdAt,
    String? cloudMessageId,
    CloudSyncStatus? syncStatus,
    String? syncError,
  }) {
    return Message(
      id: id,
      role: role,
      authorId: authorId ?? this.authorId,
      content: content ?? this.content,
      gitCommit: gitCommit,
      createdAt: createdAt ?? this.createdAt,
      isStreaming: isStreaming ?? this.isStreaming,
      isSending: isSending ?? this.isSending,
      cloudMessageId: cloudMessageId ?? this.cloudMessageId,
      syncStatus: syncStatus ?? this.syncStatus,
      syncError: syncError ?? this.syncError,
    );
  }
}
