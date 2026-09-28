import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'stitch_log_level.dart';

/// Reads process env plus an optional project-root `.env` file.
///
/// Shared knobs:
/// - `STITCH_LOG_LEVEL` / `STITCH_LOG_DIR` — logging (Dart + Python bridge)
/// - `STITCH_API_URL` — **dev override** for the Stitch backend base URL.
///   When unset, the app talks to production (`https://api.stitch.fyi`).
///   For local backend: `STITCH_API_URL=http://localhost:8081` in `.env`.
/// - `STITCH_MOCK_TYPING_CUES` — when truthy (`1`/`true`/`yes`), seed a
///   short fixture branch and honor `[[mockTyping:…]]` markers on messages
///   as sticky typing chrome (visual UI work only).
/// - `STITCH_MOCK_STITCH_SIBLING` — when truthy, seed a column whose visible
///   branch follows a reply child while a stitch-linked side thread sits as
///   an unrevealed sibling (Surgical Loading / sibling-navigator UX).
/// - `STITCH_MOCK_HIDDEN_REPLY` — when truthy, seed columns for hidden-reply
///   edges (reveal button + sibling-nav race case).
class StitchEnv {
  StitchEnv._(this.values, this.projectRoot);

  final Map<String, String> values;
  final String projectRoot;

  /// Shipped default: production API. Override with `STITCH_API_URL` in dev.
  static const String defaultApiBaseUrl = 'https://api.stitch.fyi';

  @visibleForTesting
  factory StitchEnv.forTest(Map<String, String> values, {String projectRoot = '.'}) {
    return StitchEnv._(Map<String, String>.from(values), projectRoot);
  }

  static StitchEnv load({String? projectRoot}) {
    final root = projectRoot ?? Directory.current.path;
    final merged = <String, String>{
      ...Platform.environment,
      ..._parseEnvFile(File(p.join(root, '.env'))),
    };
    return StitchEnv._(merged, root);
  }

  String? operator [](String key) => values[key];

  /// Directory containing the Python bridge server + its venv.
  ///
  /// In a packaged Linux build, `flutter_distributor`/CMake installs
  /// `python-server` next to the executable under `data/`. When that's
  /// present, prefer it (the executable's cwd is unreliable when launched
  /// from an AppImage or a desktop shortcut). Otherwise fall back to
  /// dev-mode's `<projectRoot>/python-server` (`flutter run` from the repo
  /// root).
  String get pythonServerDir {
    final bundled = p.join(p.dirname(Platform.resolvedExecutable), 'data', 'python-server');
    if (Directory(bundled).existsSync()) return bundled;
    return p.join(projectRoot, 'python-server');
  }

  /// Backend origin for `/v1/...` calls. Trailing slashes stripped.
  ///
  /// Defaults to [defaultApiBaseUrl] (production). Set `STITCH_API_URL` only
  /// when you need to point at a non-prod host (e.g. local `:8081`).
  String get apiBaseUrl {
    final raw = values['STITCH_API_URL']?.trim();
    if (raw == null || raw.isEmpty) return defaultApiBaseUrl;
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  StitchLogLevel get logLevel =>
      StitchLogLevel.parse(values['STITCH_LOG_LEVEL'], fallback: StitchLogLevel.debug);

  /// Directory for `dart.log` / `python.log`. Defaults to `<projectRoot>/logs`.
  String get logDir {
    final override = values['STITCH_LOG_DIR']?.trim();
    if (override != null && override.isNotEmpty) {
      return p.isAbsolute(override) ? override : p.join(projectRoot, override);
    }
    return p.join(projectRoot, 'logs');
  }

  /// When true, seed typing-indicator fixtures and treat `[[mockTyping:…]]`
  /// message markers as persistent typing chrome.
  bool get mockTypingCues => _truthy(values['STITCH_MOCK_TYPING_CUES']);

  /// When true, seed the reply-visible + stitch-sibling fixture column.
  bool get mockStitchSibling => _truthy(values['STITCH_MOCK_STITCH_SIBLING']);

  /// When true, seed hidden-reply fixture columns.
  bool get mockHiddenReply => _truthy(values['STITCH_MOCK_HIDDEN_REPLY']);

  static bool _truthy(String? raw) {
    final v = raw?.trim().toLowerCase();
    return v == '1' || v == 'true' || v == 'yes' || v == 'on';
  }

  /// Env map to inject into the Python subprocess (includes log knobs).
  Map<String, String> pythonProcessEnvironment() {
    return {
      ...values,
      'STITCH_LOG_LEVEL': logLevel.envName,
      'STITCH_LOG_DIR': logDir,
    };
  }

  static Map<String, String> _parseEnvFile(File file) {
    if (!file.existsSync()) return {};
    final result = <String, String>{};
    for (final line in file.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final separatorIndex = trimmed.indexOf('=');
      if (separatorIndex == -1) continue;
      final key = trimmed.substring(0, separatorIndex).trim();
      var value = trimmed.substring(separatorIndex + 1).trim();
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }
      result[key] = value;
    }
    return result;
  }
}
