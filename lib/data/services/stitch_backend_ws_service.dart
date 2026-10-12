import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';

import '../../core/logging/stitch_log.dart';
import '../repositories/auth_repository.dart';
import '../repositories/message_repository.dart';
import 'session_vault.dart';

typedef CloudMessageIngest = Future<void> Function(
  Map<String, dynamic> messagePayload,
);

/// Authenticated Stitch backend `/ws/v1` for inbound cloud notifications.
class StitchBackendWsService {
  StitchBackendWsService({
    required this.apiBaseUrl,
    required SessionVault vault,
    required AuthRepository auth,
    required MessageRepository messages,
    required this.onMessage,
  })  : _vault = vault,
        _auth = auth,
        _messages = messages;

  final String apiBaseUrl;
  final SessionVault _vault;
  final AuthRepository _auth;
  final MessageRepository _messages;
  final CloudMessageIngest onMessage;

  IOWebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  VoidCallback? _authListener;
  bool _connecting = false;

  Future<void> start() async {
    _authListener ??= () {
      unawaited(_syncConnection());
    };
    _auth.removeListener(_authListener!);
    _auth.addListener(_authListener!);
    await _syncConnection();
  }

  Future<void> dispose() async {
    if (_authListener != null) {
      _auth.removeListener(_authListener!);
      _authListener = null;
    }
    await _disconnect();
  }

  Future<void> _syncConnection() async {
    if (!_auth.state.isAuthenticated) {
      await _disconnect();
      return;
    }
    if (_channel != null) return;
    if (_connecting) return;
    _connecting = true;
    try {
      final token = await _vault.readSessionToken();
      if (token == null || token.isEmpty) return;

      final wsUri = _wsUri(token);
      StitchLog.hop('dart.cloud.ws', 'connect $wsUri');
      final channel = IOWebSocketChannel.connect(
        wsUri,
        headers: {'Authorization': 'Bearer $token'},
      );
      await channel.ready;
      _channel = channel;
      _subscription = channel.stream.listen(
        _onRaw,
        onError: (Object e, StackTrace st) {
          StitchLog.error('cloud ws error', tag: 'dart.cloud.ws', error: e, stackTrace: st);
          unawaited(_disconnect());
          unawaited(_syncConnection());
        },
        onDone: () {
          StitchLog.hop('dart.cloud.ws', 'closed');
          unawaited(_disconnect());
          if (_auth.state.isAuthenticated) {
            Future.delayed(const Duration(seconds: 2), () => unawaited(_syncConnection()));
          }
        },
      );
      StitchLog.hop('dart.cloud.ws', 'ready');
    } catch (e, st) {
      StitchLog.error('cloud ws connect failed', tag: 'dart.cloud.ws', error: e, stackTrace: st);
      await _disconnect();
    } finally {
      _connecting = false;
    }
  }

  Uri _wsUri(String token) {
    final base = Uri.parse(apiBaseUrl);
    final wsScheme = base.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: wsScheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '/ws/v1',
    );
  }

  Future<void> _disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void _onRaw(dynamic raw) {
    // Backend health monitor sends plain-text "ping" and requires "pong"
    // (or client "ping") within ~20s — same contract as Vue WebSocketClient.
    if (raw == 'ping') {
      _channel?.sink.add('pong');
      return;
    }
    if (raw == 'pong') return;
    Map<String, dynamic> data;
    try {
      data = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    if (data['type'] == 'connection_established') return;

    if (data['type'] != 'notification') return;

    final payload = data['data'];
    if (payload is! Map<String, dynamic>) return;

    final content = payload['content'];
    final messages = <Map<String, dynamic>>[];
    if (content is Map && content['messages'] is List) {
      for (final m in content['messages'] as List) {
        if (m is Map<String, dynamic>) messages.add(m);
      }
    } else if (payload['messages'] is List) {
      for (final m in payload['messages'] as List) {
        if (m is Map<String, dynamic>) messages.add(m);
      }
    }

    for (final msg in messages) {
      unawaited(_ingestIfNew(msg));
    }
  }

  Future<void> _ingestIfNew(Map<String, dynamic> msg) async {
    final cloudId = msg['id'] as String?;
    if (cloudId == null || cloudId.isEmpty) return;

    if (await _messages.getMessage(cloudId) != null) return;
    if (await _messages.getMessageByCloudId(cloudId) != null) return;

    await onMessage(msg);
  }
}
