import 'dart:async';

import '../../core/logging/stitch_log.dart';
import 'stitch_ws_client.dart';

/// One completed bot reply from the Python bridge (singular-part for now).
class BotBridgeReply {
  const BotBridgeReply({
    required this.messageId,
    required this.parentMessageId,
    required this.botId,
    required this.content,
    this.usage,
  });

  final String messageId;
  final String parentMessageId;
  final String botId;
  final String content;
  final Map<String, dynamic>? usage;
}

/// Thin facade over [StitchWsClient]: connect, invoke a bot with Stitch
/// context, correlate start/end/error by parent (trigger) message id.
///
/// No Cursor session cache, no cwd — Completions-first path only.
class BotBridgeService {
  BotBridgeService(this._client);

  final StitchWsClient _client;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  final _pending = <String, _PendingInvocation>{};
  bool _connected = false;

  bool get isConnected => _connected;

  Future<void> connect() async {
    if (_connected) return;
    StitchLog.hop('dart.bridge', 'connect');
    await _client.connect();
    _subscription = _client.envelopes.listen(_onEnvelope);
    _connected = true;
    StitchLog.hop('dart.bridge', 'ready');
  }

  /// Invokes [botId] with [triggerMessageId] as the parent of emitted
  /// replies. [context] is already sliced through the reply target.
  Future<BotBridgeReply> invoke({
    required String botId,
    required String triggerMessageId,
    required String content,
    required List<Map<String, dynamic>> context,
  }) async {
    if (!_connected) {
      throw StateError('BotBridgeService.connect() must complete before invoke');
    }
    if (_pending.containsKey(triggerMessageId)) {
      throw StateError('invocation already pending for $triggerMessageId');
    }

    final pending = _PendingInvocation(botId: botId);
    _pending[triggerMessageId] = pending;

    StitchLog.hop(
      'dart.bridge',
      '→py invoke bot=$botId trigger=$triggerMessageId context=${context.length} content_len=${content.length}',
    );
    _client.send({
      'type': 'user_message',
      'message_id': triggerMessageId,
      'bot_id': botId,
      'content': content,
      'context': context,
    });

    try {
      final reply = await pending.completer.future;
      StitchLog.hop(
        'dart.bridge',
        '←py reply bot=$botId trigger=$triggerMessageId reply_id=${reply.messageId} chars=${reply.content.length} usage=${reply.usage}',
      );
      return reply;
    } catch (e, st) {
      StitchLog.error(
        'invoke failed bot=$botId trigger=$triggerMessageId',
        tag: 'dart.bridge',
        error: e,
        stackTrace: st,
      );
      rethrow;
    } finally {
      _pending.remove(triggerMessageId);
    }
  }

  void _onEnvelope(Map<String, dynamic> envelope) {
    final type = envelope['type'] as String?;
    final parentId = envelope['parent_message_id'] as String?;
    if (type == 'ready') {
      StitchLog.hop('dart.bridge', '←py ready');
      return;
    }
    if (parentId == null) return;
    final pending = _pending[parentId];
    if (pending == null) {
      StitchLog.hop('dart.bridge', '←py unmatched type=$type parent=$parentId');
      return;
    }

    switch (type) {
      case 'message_start':
        pending.replyMessageId = envelope['message_id'] as String?;
        pending.botId = (envelope['bot_id'] as String?) ?? pending.botId;
        StitchLog.hop(
          'dart.bridge',
          '←py message_start reply_id=${pending.replyMessageId} parent=$parentId',
        );
      case 'message_end':
        if (pending.completer.isCompleted) return;
        StitchLog.hop(
          'dart.bridge',
          '←py message_end reply_id=${envelope['message_id']} parent=$parentId',
        );
        pending.completer.complete(
          BotBridgeReply(
            messageId: (envelope['message_id'] as String?) ??
                pending.replyMessageId ??
                'srv-unknown',
            parentMessageId: parentId,
            botId: (envelope['bot_id'] as String?) ?? pending.botId,
            content: (envelope['content'] as String?) ?? '',
            usage: envelope['usage'] as Map<String, dynamic>?,
          ),
        );
      case 'error':
        if (pending.completer.isCompleted) return;
        StitchLog.hop(
          'dart.bridge',
          '←py error parent=$parentId err=${envelope['error']}',
        );
        pending.completer.completeError(
          BotBridgeException((envelope['error'] as String?) ?? 'unknown bridge error'),
        );
    }
  }

  Future<void> close() async {
    StitchLog.hop('dart.bridge', 'close');
    await _subscription?.cancel();
    _subscription = null;
    for (final pending in _pending.values) {
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(BotBridgeException('bridge closed'));
      }
    }
    _pending.clear();
    await _client.close();
    _connected = false;
  }
}

class BotBridgeException implements Exception {
  BotBridgeException(this.message);
  final String message;

  @override
  String toString() => 'BotBridgeException: $message';
}

class _PendingInvocation {
  _PendingInvocation({required this.botId});

  String botId;
  String? replyMessageId;
  final completer = Completer<BotBridgeReply>();
}
