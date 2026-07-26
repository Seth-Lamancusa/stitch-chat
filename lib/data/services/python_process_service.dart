import 'dart:async';
import 'dart:io';

/// Spawns, health-checks, and tears down the local Python server subprocess.
///
/// Dev-mode only: assumes `flutter run` is launched from the project root
/// (so `Directory.current` resolves to it) and that `python-server/venv`
/// already has dependencies installed. PyInstaller/bundled-binary lookup is
/// deferred until packaging is actually needed.
class PythonProcessService {
  Process? _process;

  Future<void> start() async {
    final projectRoot = Directory.current.path;
    final serverDir = Directory('$projectRoot/python-server');
    final pythonBin = '${serverDir.path}/venv/bin/python';
    final envFile = File('$projectRoot/.env');

    final environment = <String, String>{
      ...Platform.environment,
      ..._parseEnvFile(envFile),
    };

    _process = await Process.start(
      pythonBin,
      ['server.py'],
      workingDirectory: serverDir.path,
      environment: environment,
    );

    _process!.stdout
        .transform(SystemEncoding().decoder)
        .listen((line) => stdout.write('[python] $line'));
    _process!.stderr
        .transform(SystemEncoding().decoder)
        .listen((line) => stderr.write('[python] $line'));
  }

  Map<String, String> _parseEnvFile(File file) {
    if (!file.existsSync()) return {};
    final result = <String, String>{};
    for (final line in file.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final separatorIndex = trimmed.indexOf('=');
      if (separatorIndex == -1) continue;
      final key = trimmed.substring(0, separatorIndex).trim();
      final value = trimmed.substring(separatorIndex + 1).trim();
      result[key] = value;
    }
    return result;
  }

  void stop() {
    _process?.kill(ProcessSignal.sigterm);
    _process = null;
  }
}
