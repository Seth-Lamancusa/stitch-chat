import 'dart:async';

import '../../core/logging/stitch_log.dart';
import '../../domain/bot_registry.dart';
import 'stitch_ws_client.dart';

/// One completed bot reply from the Python bridge (singular-part for now).
class BotBridgeReply {
  const BotBridgeReply({
    required this.messageId,
    required this.parentMessageId,
    required this.botId,
    required this.content,
    this.usage,
    this.skipped = false,
    this.skipReason,
  });

  final String messageId;
  final String parentMessageId;
  final String botId;
  final String content;
  final Map<String, dynamic>? usage;

  /// Bridge declined to run the adapter (e.g. missing cwd). Not a failure.
  final bool skipped;
  final String? skipReason;
}

/// Thin facade over [StitchWsClient]: connect, invoke a bot with Stitch
/// context, correlate start/end/error/skip by parent (trigger) message id.
///
/// Session affinity (fingerprint → opaque handle) stays adapter-private on
/// the Python side. [cwd] is a column tag forwarded on each invoke.
class BotBridgeService {
  BotBridgeService(this._client);

  final StitchWsClient _client;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  final _pending = <String, _PendingInvocation>{};
  bool _connected = false;
  BotRegistry _registry = const BotRegistry.empty();

  bool get isConnected => _connected;

  /// Tag -> bot id lookup derived from the `bots` field of the server's
  /// `ready` envelope. Empty until [connect] completes.
  BotRegistry get registry => _registry;

  Future<void> connect() async {
    if (_connected) return;
    StitchLog.hop('dart.bridge', 'connect');
    // Subscribe before connecting: the `ready` envelope (which carries the
    // bot registry) arrives on `_client.envelopes` as soon as the client's
    // own connect() completes, and that broadcast stream doesn't replay past
    // events to late listeners.
    _subscription = _client.envelopes.listen(_onEnvelope);
    await _client.connect();
    _connected = true;
    StitchLog.hop('dart.bridge', 'ready');
  }

  /// Invokes [botId] with [triggerMessageId] as the parent of emitted
  /// replies. [context] is the full context window including the trigger
  /// as its last node. [cwd] is the invoking column's working-directory
  /// tag (nullable).
  ///
  /// A skipped invoke (e.g. `requires_cwd`) returns [BotBridgeReply.skipped]
  /// rather than throwing.
  Future<BotBridgeReply> invoke({
    required String botId,
    required String triggerMessageId,
    required List<Map<String, dynamic>> context,
    String? cwd,
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
      '→py invoke bot=$botId trigger=$triggerMessageId cwd=${cwd ?? "-"} context=${context.length}',
    );
    _client.send({
      'type': 'user_message',
      'message_id': triggerMessageId,
      'bot_id': botId,
      'context': context,
      if (cwd != null && cwd.isNotEmpty) 'cwd': cwd,
    });

    try {
      final reply = await pending.completer.future;
      if (reply.skipped) {
        StitchLog.hop(
          'dart.bridge',
          '←py skipped bot=$botId trigger=$triggerMessageId reason=${reply.skipReason}',
        );
      } else {
        StitchLog.hop(
          'dart.bridge',
          '←py reply bot=$botId trigger=$triggerMessageId reply_id=${reply.messageId} chars=${reply.content.length} usage=${reply.usage}',
        );
      }
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
      final bots = envelope['bots'];
      if (bots is List) {
        _registry = BotRegistry.fromWire(bots);
      }
      StitchLog.hop('dart.bridge', '←py ready bots=${bots is List ? bots.length : 0}');
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
      case 'invoke_skipped':
        if (pending.completer.isCompleted) return;
        final reason = envelope['reason'] as String? ?? 'skipped';
        StitchLog.hop(
          'dart.bridge',
          '←py invoke_skipped parent=$parentId reason=$reason',
        );
        pending.completer.complete(
          BotBridgeReply(
            messageId: (envelope['message_id'] as String?) ?? 'skipped',
            parentMessageId: parentId,
            botId: (envelope['bot_id'] as String?) ?? pending.botId,
            content: '',
            skipped: true,
            skipReason: reason,
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
