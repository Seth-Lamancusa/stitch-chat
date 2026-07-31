/// The one message type shared by the live WS chat stream and the
/// persisted conversation tree — supersedes the split `ChatMessage`/
/// `PersistedMessage` types. Thread topology is not modeled here: it lives
/// exclusively in edge tables owned by [MessageRepository], not as fields
/// on this class.
enum MessageRole { user, localBot, functionCall, functionResult }

/// Who a message is addressed to, for [MessageRepository.addRecipientEdge].
enum RecipientKind { localBot, cloudUser }

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

  const Message({
    required this.id,
    required this.role,
    required this.content,
    this.authorId,
    this.gitCommit,
    this.createdAt,
    this.isStreaming = false,
  });

  Message copyWith({
    String? content,
    bool? isStreaming,
    DateTime? createdAt,
  }) {
    return Message(
      id: id,
      role: role,
      authorId: authorId,
      content: content ?? this.content,
      gitCommit: gitCommit,
      createdAt: createdAt ?? this.createdAt,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}
