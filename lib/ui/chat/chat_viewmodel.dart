import 'package:flutter/foundation.dart';

import '../../core/notifications/notification_service.dart';
import '../../data/models/chat_message.dart';
import '../../data/repositories/chat_repository.dart';

class ChatViewModel extends ChangeNotifier {
  final ChatRepository _repository;
  final NotificationService _notifications;
  final List<ChatMessage> messages = [];
  String? _lastUserMessageId;

  ChatViewModel(this._repository, this._notifications) {
    _repository.events.listen(_handleEvent);
  }

  Future<void> initialize() => _repository.connect();

  void sendMessage(String content) {
    if (content.trim().isEmpty) return;
    final userMessage = _repository.sendMessage(content, parentId: _lastUserMessageId);
    _lastUserMessageId = userMessage.id;
    messages.add(userMessage);
    notifyListeners();
  }

  void _handleEvent(ChatEvent event) {
    switch (event) {
      case MessageStarted(:final messageId, :final parentMessageId):
        messages.add(ChatMessage(
          id: messageId,
          parentId: parentMessageId,
          role: 'bot',
          content: '',
          isStreaming: true,
        ));
        notifyListeners();
      case MessageCompleted(:final messageId, :final content):
        _updateMessage(messageId, (m) => m.copyWith(content: content, isStreaming: false));
        notifyListeners();
      case ChatErrorOccurred(:final error):
        // Routed through the shared surface, not held locally, so every
        // error in the app renders the same way regardless of source.
        _notifications.showError(error);
    }
  }

  void _updateMessage(String messageId, ChatMessage Function(ChatMessage) update) {
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index != -1) messages[index] = update(messages[index]);
  }
}
