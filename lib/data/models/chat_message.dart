class ChatMessage {
  final String id;
  final String? parentId;
  final String role; // 'user' | 'bot'
  final String content;
  final bool isStreaming;

  const ChatMessage({
    required this.id,
    required this.parentId,
    required this.role,
    required this.content,
    this.isStreaming = false,
  });

  ChatMessage copyWith({String? content, bool? isStreaming}) {
    return ChatMessage(
      id: id,
      parentId: parentId,
      role: role,
      content: content ?? this.content,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}
