import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Owns the single persistent WebSocket connection to the Python server.
/// Transport-only: parses/encodes JSON envelopes, has no opinion about
/// message content or bot dispatch.
class StitchWsClient {
  final Uri uri;
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _envelopes =
      StreamController<Map<String, dynamic>>.broadcast();

  StitchWsClient(this.uri);

  Stream<Map<String, dynamic>> get envelopes => _envelopes.stream;

  /// Connects and completes once the server's `ready` envelope arrives.
  /// Retries a few times with backoff since the Python process may still be
  /// binding its port right after being spawned.
  Future<void> connect({int maxAttempts = 10}) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final channel = WebSocketChannel.connect(uri);
        await channel.ready;

        final readyCompleter = Completer<void>();

        channel.stream.listen(
          (raw) {
            final envelope = jsonDecode(raw as String) as Map<String, dynamic>;
            if (envelope['type'] == 'ready' && !readyCompleter.isCompleted) {
              readyCompleter.complete();
            }
            _envelopes.add(envelope);
          },
          onError: _envelopes.addError,
        );

        _channel = channel;

        await readyCompleter.future.timeout(const Duration(seconds: 5));
        return;
      } catch (_) {
        if (attempt == maxAttempts) rethrow;
        await Future.delayed(Duration(milliseconds: 200 * attempt));
      }
    }
  }

  void send(Map<String, dynamic> envelope) {
    _channel?.sink.add(jsonEncode(envelope));
  }

  Future<void> close() async {
    await _channel?.sink.close();
    await _envelopes.close();
  }
}
