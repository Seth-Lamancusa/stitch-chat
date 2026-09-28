import 'dart:async';

import 'package:flutter/foundation.dart';

/// One author's typing cue keyed to a target message (ephemeral — never persisted).
@immutable
class TypingCueEvent {
  const TypingCueEvent({
    required this.authorId,
    required this.targetMessageId,
    required this.typing,
  });

  final String authorId;
  final String targetMessageId;
  final bool typing;
}

/// In-memory map of who is typing a reply to which message.
///
/// Keyed by `(authorId, targetMessageId)` — one author may type on several
/// targets at once (parallel invokes). Entries expire after [ttl] without
/// refresh.
class TypingCueStore extends ChangeNotifier {
  TypingCueStore({
    this.ttl = const Duration(seconds: 8),
    @visibleForTesting DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration ttl;
  final DateTime Function() _clock;

  /// `(authorId, targetMessageId)` → last refresh time
  final Map<(String, String), DateTime> _active = {};

  Timer? _ttlTimer;

  /// Authors currently typing a reply under [targetMessageId], sorted.
  List<String> authorsTypingAt(String targetMessageId) {
    final authors = <String>[
      for (final e in _active.entries)
        if (e.key.$2 == targetMessageId) e.key.$1,
    ]..sort();
    return authors;
  }

  bool get hasAny => _active.isNotEmpty;

  void apply(TypingCueEvent event) {
    final key = (event.authorId, event.targetMessageId);
    if (event.typing) {
      _active[key] = _clock();
      _ensureTtlTimer();
    } else if (_active.containsKey(key)) {
      _active.remove(key);
    }
    // typing=false for an unknown or already-cleared pair: ignore
    notifyListeners();
  }

  /// Test / dispose helper.
  void clear() {
    _active.clear();
    _ttlTimer?.cancel();
    _ttlTimer = null;
    notifyListeners();
  }

  @visibleForTesting
  void debugSweepExpired() => _sweepExpired();

  void _ensureTtlTimer() {
    _ttlTimer ??= Timer.periodic(const Duration(seconds: 1), (_) => _sweepExpired());
  }

  void _sweepExpired() {
    final now = _clock();
    final expired = <(String, String)>[
      for (final e in _active.entries)
        if (now.difference(e.value) >= ttl) e.key,
    ];
    if (expired.isEmpty) {
      if (_active.isEmpty) {
        _ttlTimer?.cancel();
        _ttlTimer = null;
      }
      return;
    }
    for (final key in expired) {
      _active.remove(key);
    }
    if (_active.isEmpty) {
      _ttlTimer?.cancel();
      _ttlTimer = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ttlTimer?.cancel();
    _ttlTimer = null;
    super.dispose();
  }
}
