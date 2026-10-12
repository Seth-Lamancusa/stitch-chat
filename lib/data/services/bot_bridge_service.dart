import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/logging/stitch_log.dart';
import '../../data/models/message.dart';
import '../../domain/bot_registry.dart';
import 'stitch_ws_client.dart';
import 'typing_cue_store.dart';

/// Ephemeral sign-in snapshot for one bot. Not a message.
class BotAuthSnapshot {
  const BotAuthSnapshot({
    required this.botId,
    required this.state,
    this.url,
    this.detail,
  });

  final String botId;

  /// `authenticated` | `unauthenticated` | `pending` | `unavailable`.
  final String state;
  final String? url;
  final String? detail;

  bool get needsPrompt => state != 'authenticated';
}
class BotBridgePart {
  const BotBridgePart({
    required this.messageId,
    required this.parentMessageId,
    required this.botId,
    required this.content,
    required this.role,
    this.isFinal = false,
    this.hidden = false,
    this.usage,
    this.toolName,
    this.toolCallId,
    this.isError,
  });

  final String messageId;
  final String parentMessageId;
  final String botId;
  final String content;
  final MessageRole role;
  final bool isFinal;

  /// When true, the reply edge from [parentMessageId] to this part is hidden
  /// (default walk skips it; UI must reveal).
  final bool hidden;
  final Map<String, dynamic>? usage;
  final String? toolName;
  final String? toolCallId;
  final bool? isError;
}

/// Terminal outcome of [BotBridgeService.invoke] (final part, skip, or error).
class BotBridgeReply {
  const BotBridgeReply({
    required this.messageId,
    required this.parentMessageId,
    required this.botId,
    required this.content,
    this.role = MessageRole.localBot,
    this.usage,
    this.skipped = false,
    this.skipReason,
  });

  final String messageId;
  final String parentMessageId;
  final String botId;
  final String content;
  final MessageRole role;
  final Map<String, dynamic>? usage;

  /// Bridge declined to run the adapter (e.g. missing cwd). Not a failure.
  final bool skipped;
  final String? skipReason;
}

MessageRole messageRoleFromWire(String? raw) {
  switch (raw) {
    case 'thinking':
      return MessageRole.thinking;
    case 'functionCall':
      return MessageRole.functionCall;
    case 'functionResult':
      return MessageRole.functionResult;
    case 'localBot':
    case 'bot':
      return MessageRole.localBot;
    case 'user':
      return MessageRole.user;
    default:
      return MessageRole.localBot;
  }
}

/// Thin facade over [StitchWsClient]: connect, invoke a bot with Stitch
/// context, correlate start/end/error/skip by invoke root (trigger) id.
///
/// Session affinity (fingerprint → opaque handle) stays adapter-private on
/// the Python side. [cwd] is a column tag forwarded on each invoke.
class BotBridgeService {
  BotBridgeService(this._client);

  final StitchWsClient _client;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  final _pending = <String, _PendingInvocation>{};
  final _cueController = StreamController<TypingCueEvent>.broadcast();
  final authStates = ValueNotifier<Map<String, BotAuthSnapshot>>(const {});
  bool _connected = false;
  BotRegistry _registry = const BotRegistry.empty();

  bool get isConnected => _connected;

  /// Tag -> bot id lookup derived from the `bots` field of the server's
  /// `ready` envelope. Empty until [connect] completes.
  BotRegistry get registry => _registry;

  /// Fire-and-forget typing cues from the bridge (not tied to invoke Futures).
  Stream<TypingCueEvent> get cues => _cueController.stream;

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

  /// Invokes [botId] with [triggerMessageId] as the invoke root.
  /// Intermediate parts call [onPart]; the Future completes on the final
  /// part (`is_final`), skip, or error.
  Future<BotBridgeReply> invoke({
    required String botId,
    required String triggerMessageId,
    required List<Map<String, dynamic>> context,
    String? cwd,
    FutureOr<void> Function(BotBridgePart part)? onPart,
  }) async {
    if (!_connected) {
      throw StateError('BotBridgeService.connect() must complete before invoke');
    }
    if (_pending.containsKey(triggerMessageId)) {
      throw StateError('invocation already pending for $triggerMessageId');
    }

    final pending = _PendingInvocation(botId: botId, onPart: onPart);
    _pending[triggerMessageId] = pending;

    StitchLog.hop(
      'dart.bridge',
      '→py invoke bot=$botId trigger=$triggerMessageId cwd=${cwd ?? "-"} context=${context.length}',
    );
    _send({
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
    if (type == 'ready') {
      final bots = envelope['bots'];
      if (bots is List) {
        _registry = BotRegistry.fromWire(bots);
      }
      StitchLog.hop('dart.bridge', '←py ready bots=${bots is List ? bots.length : 0}');
      return;
    }
    if (type == 'cue') {
      _onCue(envelope);
      return;
    }
    if (type == 'auth_state') {
      _onAuthState(envelope);
      return;
    }

    final rootId = envelope['invoke_root_id'] as String? ?? envelope['parent_message_id'] as String?;
    if (rootId == null) return;
    final pending = _pending[rootId];
    if (pending == null) {
      StitchLog.hop('dart.bridge', '←py unmatched type=$type root=$rootId');
      return;
    }

    switch (type) {
      case 'message_start':
        pending.replyMessageId = envelope['message_id'] as String?;
        pending.botId = (envelope['bot_id'] as String?) ?? pending.botId;
        pending.pendingRole = messageRoleFromWire(envelope['role'] as String?);
        StitchLog.hop(
          'dart.bridge',
          '←py message_start reply_id=${pending.replyMessageId} root=$rootId parent=${envelope['parent_message_id']}',
        );
      case 'message_end':
        final messageId =
            (envelope['message_id'] as String?) ?? pending.replyMessageId ?? 'srv-unknown';
        final parentId = (envelope['parent_message_id'] as String?) ?? rootId;
        final role = messageRoleFromWire(envelope['role'] as String?);
        final isFinal = envelope.containsKey('is_final')
            ? envelope['is_final'] == true
            : true; // legacy single-part adapters omit is_final
        final part = BotBridgePart(
          messageId: messageId,
          parentMessageId: parentId,
          botId: (envelope['bot_id'] as String?) ?? pending.botId,
          content: (envelope['content'] as String?) ?? '',
          role: role,
          isFinal: isFinal,
          hidden: envelope['hidden'] == true,
          usage: envelope['usage'] as Map<String, dynamic>?,
          toolName: envelope['tool_name'] as String?,
          toolCallId: envelope['tool_call_id'] as String?,
          isError: envelope['is_error'] as bool?,
        );
        StitchLog.hop(
          'dart.bridge',
          '←py message_end reply_id=$messageId root=$rootId parent=$parentId final=$isFinal role=${role.name}',
        );
        // Serialize part delivery so onPart persist/refresh can't race
        // (concurrent unawaited delivers were clobbering column anchors).
        pending.deliverChain = pending.deliverChain.then(
          (_) => _deliverPart(pending, part, isFinal: isFinal),
        );
      case 'invoke_skipped':
        if (pending.completer.isCompleted) return;
        final reason = envelope['reason'] as String? ?? 'skipped';
        StitchLog.hop(
          'dart.bridge',
          '←py invoke_skipped root=$rootId reason=$reason',
        );
        pending.completer.complete(
          BotBridgeReply(
            messageId: (envelope['message_id'] as String?) ?? 'skipped',
            parentMessageId: rootId,
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
          '←py error root=$rootId err=${envelope['error']}',
        );
        pending.completer.completeError(
          BotBridgeException((envelope['error'] as String?) ?? 'unknown bridge error'),
        );
    }
  }

  void _onCue(Map<String, dynamic> envelope) {
    final authorId = envelope['author_id'] as String?;
    final targetId = envelope['target_message_id'] as String?;
    final typing = envelope['typing'];
    if (authorId == null || targetId == null || typing is! bool) {
      StitchLog.hop('dart.bridge', '←py cue ignored malformed');
      return;
    }
    StitchLog.hop(
      'dart.bridge',
      '←py cue author=$authorId target=$targetId typing=$typing',
    );
    if (!_cueController.isClosed) {
      _cueController.add(
        TypingCueEvent(
          authorId: authorId,
          targetMessageId: targetId,
          typing: typing,
        ),
      );
    }
  }

  void _onAuthState(Map<String, dynamic> envelope) {
    final botId = envelope['bot_id'] as String?;
    final state = envelope['state'] as String?;
    if (botId == null || state == null) {
      StitchLog.hop('dart.bridge', '←py auth_state ignored malformed');
      return;
    }
    final next = Map<String, BotAuthSnapshot>.from(authStates.value);
    next[botId] = BotAuthSnapshot(
      botId: botId,
      state: state,
      url: envelope['url'] as String?,
      detail: envelope['detail'] as String?,
    );
    authStates.value = next;
    StitchLog.hop('dart.bridge', '←py auth_state bot=$botId state=$state');
  }

  /// Asks the bridge to run [botId]'s auth handler. State arrives on
  /// [authStates]; this method does not wait for the handler to finish.
  void beginAuth(String botId) {
    if (!_connected) {
      throw StateError('BotBridgeService.connect() must complete before beginAuth');
    }
    StitchLog.hop('dart.bridge', '→py auth_begin bot=$botId');
    _send({'type': 'auth_begin', 'bot_id': botId});
  }

  void _send(Map<String, dynamic> envelope) {
    debugSent.add(envelope);
    debugOnSend?.call(envelope);
    _client.send(envelope);
  }

  /// Test hook invoked synchronously from [_send], before the socket write.
  @visibleForTesting
  void Function(Map<String, dynamic> envelope)? debugOnSend;

  /// Envelopes this service handed to the socket. Tests read this instead
  /// of a live WebSocket.
  @visibleForTesting
  final List<Map<String, dynamic>> debugSent = [];

  /// Test harness: mark the socket up and optionally install a registry
  /// without connecting.
  @visibleForTesting
  void debugConnect({BotRegistry? registry}) {
    _connected = true;
    if (registry != null) _registry = registry;
  }

  /// Test harness: feed a cue envelope without a pending invoke.
  @visibleForTesting
  void debugEmitEnvelope(Map<String, dynamic> envelope) => _onEnvelope(envelope);

  Future<void> _deliverPart(
    _PendingInvocation pending,
    BotBridgePart part, {
    required bool isFinal,
  }) async {
    final onPart = pending.onPart;
    if (onPart != null) {
      try {
        await onPart(part);
      } catch (e, st) {
        StitchLog.error(
          'onPart failed part=${part.messageId}',
          tag: 'dart.bridge',
          error: e,
          stackTrace: st,
        );
      }
    }
    if (!isFinal) return;
    if (pending.completer.isCompleted) return;
    pending.completer.complete(
      BotBridgeReply(
        messageId: part.messageId,
        parentMessageId: part.parentMessageId,
        botId: part.botId,
        content: part.content,
        role: part.role,
        usage: part.usage,
      ),
    );
  }

  /// Test harness: register a pending invoke and drive envelopes without WS.
  @visibleForTesting
  Future<BotBridgeReply> invokeDriven({
    required String botId,
    required String triggerMessageId,
    FutureOr<void> Function(BotBridgePart part)? onPart,
    required Future<void> Function(void Function(Map<String, dynamic>) emit) drive,
  }) async {
    if (_pending.containsKey(triggerMessageId)) {
      throw StateError('invocation already pending for $triggerMessageId');
    }
    final pending = _PendingInvocation(botId: botId, onPart: onPart);
    _pending[triggerMessageId] = pending;
    try {
      await drive(_onEnvelope);
      await pending.deliverChain;
      return await pending.completer.future;
    } finally {
      _pending.remove(triggerMessageId);
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
    await _cueController.close();
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
  _PendingInvocation({required this.botId, this.onPart});

  String botId;
  String? replyMessageId;
  MessageRole pendingRole = MessageRole.localBot;
  final FutureOr<void> Function(BotBridgePart part)? onPart;
  final completer = Completer<BotBridgeReply>();

  /// Chains message_end deliveries so onPart runs strictly in order.
  Future<void> deliverChain = Future.value();
}
