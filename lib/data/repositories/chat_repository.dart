import '../models/chat_message.dart';

/// Events the repository emits as bot replies stream in. Kept separate from
/// [ChatMessage] since a single message is built up from many of these.
sealed class ChatEvent {
  const ChatEvent();
}

class MessageStarted extends ChatEvent {
  final String messageId;
  final String? parentMessageId;
  const MessageStarted(this.messageId, this.parentMessageId);
}

class MessageCompleted extends ChatEvent {
  final String messageId;
  final String content;
  const MessageCompleted(this.messageId, this.content);
}

class ChatErrorOccurred extends ChatEvent {
  final String? messageId;
  final String error;
  const ChatErrorOccurred(this.messageId, this.error);
}

abstract class ChatRepository {
  Stream<ChatEvent> get events;

  Future<void> connect();

  /// Sends a user message and returns the [ChatMessage] representing it
  /// (the caller is responsible for rendering it locally/optimistically).
  ChatMessage sendMessage(String content, {String? parentId});
}
