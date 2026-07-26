/// A durable node in the conversation tree, as stored by a
/// [MessageStoreRepository]. Distinct from [ChatMessage] in
/// data/models/chat_message.dart, which models a single live WS
/// stream in progress rather than a saved tree node.
class PersistedMessage {
  final String id;
  final String? parentId;
  final String conversationId;
  final String role; // 'user' | 'bot' | 'function_call' | 'function_result'
  final String content;
  final String? botId;
  final String? gitCommit;
  final DateTime createdAt;

  const PersistedMessage({
    required this.id,
    required this.parentId,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.botId,
    this.gitCommit,
  });
}
