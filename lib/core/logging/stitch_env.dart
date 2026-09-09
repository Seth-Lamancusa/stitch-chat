import 'dart:io';

import 'package:path/path.dart' as p;

import 'stitch_log_level.dart';

/// Reads process env plus an optional project-root `.env` file.
///
/// `STITCH_LOG_LEVEL` and `STITCH_LOG_DIR` are the shared logging knobs used
/// by both Dart and the Python bridge (Python also accepts them when started
/// outside Flutter).
class StitchEnv {
  StitchEnv._(this.values, this.projectRoot);

  final Map<String, String> values;
  final String projectRoot;

  static StitchEnv load({String? projectRoot}) {
    final root = projectRoot ?? Directory.current.path;
    final merged = <String, String>{
      ...Platform.environment,
      ..._parseEnvFile(File(p.join(root, '.env'))),
    };
    return StitchEnv._(merged, root);
  }

  String? operator [](String key) => values[key];

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
