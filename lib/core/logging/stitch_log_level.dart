import 'dart:io';

/// Shared log severity for Dart and the Python bridge.
///
/// Wired through `STITCH_LOG_LEVEL` (env or `.env`). Same names on both sides.
enum StitchLogLevel {
  trace,
  debug,
  info,
  warning,
  error;

  static StitchLogLevel parse(String? raw, {StitchLogLevel fallback = StitchLogLevel.info}) {
    if (raw == null || raw.trim().isEmpty) return fallback;
    switch (raw.trim().toLowerCase()) {
      case 'trace':
        return StitchLogLevel.trace;
      case 'debug':
        return StitchLogLevel.debug;
      case 'info':
        return StitchLogLevel.info;
      case 'warn':
      case 'warning':
        return StitchLogLevel.warning;
      case 'error':
        return StitchLogLevel.error;
      default:
        return fallback;
    }
  }

  /// Env / loguru spelling (upper-case).
  String get envName => name.toUpperCase();

  bool allows(StitchLogLevel incoming) => incoming.index >= index;
}
