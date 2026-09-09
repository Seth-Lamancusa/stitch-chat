import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'stitch_log_level.dart';

/// Process-wide logger: console ([debugPrint]) + rotating `logs/dart.log`.
///
/// Rotation matches the Python loguru defaults: 10 MB, keep 5 files
/// (`dart.log`, `dart.log.1` … `dart.log.4`).
///
/// Call [initialize] once at startup before other logging. Level comes from
/// `STITCH_LOG_LEVEL` (see [StitchEnv]).
///
/// Prefer [hop] for pipeline traces — greppable `hop=<stage>` markers:
/// `dart.column` → `dart.bridge` → `dart.ws` → `py.ws` → `py.server` →
/// `py.adapter` → `py.runtime` and back.
class StitchLog {
  StitchLog._();

  static const _maxBytes = 10 * 1024 * 1024;
  static const _retention = 5; // active file + N-1 rotated siblings

  static StitchLogLevel _level = StitchLogLevel.debug;
  static IOSink? _sink;
  static File? _file;
  static String? _logFilePath;
  static int _bytesWritten = 0;
  static final _writeQueue = StreamController<String>(sync: true);
  static StreamSubscription<String>? _writer;
  static Future<void> _writeChain = Future<void>.value();

  static StitchLogLevel get level => _level;
  static String? get logFilePath => _logFilePath;

  static Future<void> initialize({
    required String logDir,
    StitchLogLevel level = StitchLogLevel.debug,
  }) async {
    await _writer?.cancel();
    await _writeChain;
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
    _file = null;

    _level = level;
    final dir = Directory(logDir);
    await dir.create(recursive: true);
    _file = File(p.join(dir.path, 'dart.log'));
    _logFilePath = _file!.path;
    _bytesWritten = await _file!.exists() ? await _file!.length() : 0;
    _sink = _file!.openWrite(mode: FileMode.append);

    _writer = _writeQueue.stream.listen((line) {
      _writeChain = _writeChain.then((_) => _appendLine(line));
    });

    info('StitchLog initialized level=${level.envName} file=$_logFilePath rotation=${_maxBytes}B x$_retention');
  }

  /// Scannable pipeline breadcrumb: `hop=<stage> | message`.
  static void hop(String stage, String message) =>
      debug('hop=$stage | $message', tag: 'hop');

  static void trace(String message, {String tag = 'dart'}) =>
      _log(StitchLogLevel.trace, tag, message);

  static void debug(String message, {String tag = 'dart'}) =>
      _log(StitchLogLevel.debug, tag, message);

  static void info(String message, {String tag = 'dart'}) =>
      _log(StitchLogLevel.info, tag, message);

  static void warning(String message, {String tag = 'dart', Object? error, StackTrace? stackTrace}) =>
      _log(StitchLogLevel.warning, tag, message, error: error, stackTrace: stackTrace);

  static void error(String message, {String tag = 'dart', Object? error, StackTrace? stackTrace}) =>
      _log(StitchLogLevel.error, tag, message, error: error, stackTrace: stackTrace);

  static Future<void> close() async {
    await _writer?.cancel();
    _writer = null;
    await _writeChain;
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
    _file = null;
  }

  static void _log(
    StitchLogLevel incoming,
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_level.allows(incoming)) return;
    final ts = DateTime.now().toUtc().toIso8601String();
    final buffer = StringBuffer('$ts | ${incoming.envName.padRight(7)} | $tag | $message');
    if (error != null) buffer.write(' | error=$error');
    if (stackTrace != null) buffer.write('\n$stackTrace');
    final line = buffer.toString();
    debugPrint(line);
    if (!_writeQueue.isClosed) {
      _writeQueue.add(line);
    }
  }

  static Future<void> _appendLine(String line) async {
    final encoded = utf8.encode('$line\n');
    await _rotateIfNeeded(encoded.length);
    _sink?.add(encoded);
    _bytesWritten += encoded.length;
  }

  static Future<void> _rotateIfNeeded(int nextBytes) async {
    if (_file == null || _logFilePath == null) return;
    if (_bytesWritten + nextBytes <= _maxBytes) return;

    await _sink?.flush();
    await _sink?.close();
    _sink = null;

    final oldest = File('$_logFilePath.$_retention');
    if (await oldest.exists()) {
      await oldest.delete();
    }
    for (var i = _retention - 1; i >= 1; i--) {
      final src = File('$_logFilePath.$i');
      if (await src.exists()) {
        await src.rename('$_logFilePath.${i + 1}');
      }
    }
    if (await _file!.exists()) {
      await _file!.rename('$_logFilePath.1');
    }

    _bytesWritten = 0;
    _sink = _file!.openWrite(mode: FileMode.append);
  }
}
