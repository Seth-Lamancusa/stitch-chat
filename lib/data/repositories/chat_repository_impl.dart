import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../services/stitch_ws_client.dart';
import 'chat_repository.dart';

const _defaultBotId = 'openai-default';
const _uuid = Uuid();

class ChatRepositoryImpl implements ChatRepository {
  final StitchWsClient _wsClient;

  ChatRepositoryImpl(this._wsClient);

  @override
  Stream<ChatEvent> get events => _wsClient.envelopes.map(_toEvent).where((e) => e != null).cast<ChatEvent>();

  @override
  Future<void> connect() => _wsClient.connect();

  @override
  ChatMessage sendMessage(String content, {String? parentId}) {
    final messageId = _uuid.v4();
    _wsClient.send({
      'type': 'user_message',
      'message_id': messageId,
      'parent_message_id': parentId,
      'bot_id': _defaultBotId,
      'content': content,
    });
    return ChatMessage(id: messageId, parentId: parentId, role: 'user', content: content);
  }

  ChatEvent? _toEvent(Map<String, dynamic> envelope) {
    switch (envelope['type']) {
      case 'message_start':
        return MessageStarted(
          envelope['message_id'] as String,
          envelope['parent_message_id'] as String?,
        );
      case 'message_end':
        return MessageCompleted(
          envelope['message_id'] as String,
          envelope['content'] as String,
        );
      case 'error':
        return ChatErrorOccurred(
          envelope['message_id'] as String?,
          envelope['error'] as String,
        );
      default:
        return null; // e.g. 'ready' — handled by StitchWsClient itself
    }
  }
}
