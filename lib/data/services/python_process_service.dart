import 'dart:async';
import 'dart:io';

import '../../core/logging/stitch_env.dart';
import '../../core/logging/stitch_log.dart';

/// Port the local Python server listens on (must match python-server/protocol.py).
const _serverPort = 8765;

/// Spawns, health-checks, and tears down the local Python server subprocess.
///
/// Locates `python-server` via [StitchEnv.pythonServerDir]: the bundled copy
/// next to the executable in a packaged build, or `<projectRoot>/python-server`
/// in dev mode (`flutter run` from the repo root). Either way, that
/// directory's `venv` must already have dependencies installed.
class PythonProcessService {
  Process? _process;

  Future<void> start({StitchEnv? env}) async {
    // A previous run may have left the server orphaned (e.g. app killed
    // without a clean shutdown), which would make the new process fail to
    // bind the port. Clear it out before starting.
    await _killExistingOnPort(_serverPort);

    final stitchEnv = env ?? StitchEnv.load();
    final serverDir = Directory(stitchEnv.pythonServerDir);
    final pythonBin = '${serverDir.path}/venv/bin/python';

    if (env == null) await stitchEnv.resolveLogDir();
    await Directory(stitchEnv.logDir).create(recursive: true);

    final environment = stitchEnv.pythonProcessEnvironment();
    StitchLog.hop(
      'dart.process',
      'start python bin=$pythonBin log_level=${stitchEnv.logLevel.envName} log_dir=${stitchEnv.logDir}',
    );

    _process = await Process.start(
      pythonBin,
      ['server.py'],
      workingDirectory: serverDir.path,
      environment: environment,
    );

    _process!.stdout.transform(SystemEncoding().decoder).listen((line) {
      stdout.write('[python] $line');
    });
    _process!.stderr.transform(SystemEncoding().decoder).listen((line) {
      stderr.write('[python] $line');
    });
  }

  void stop() {
    StitchLog.hop('dart.process', 'stop python bridge');
    _process?.kill(ProcessSignal.sigterm);
    _process = null;
  }

  /// Kills whatever is already listening on [port], if anything. Best-effort:
  /// dev-mode only, so silently no-ops on lookup failure (e.g. missing tools).
  Future<void> _killExistingOnPort(int port) async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('netstat', ['-ano']);
        final lines = (result.stdout as String).split('\n');
        final pids = <String>{};
        for (final line in lines) {
          if (!line.contains(':$port ') && !line.contains(':$port\r')) continue;
          final parts = line.trim().split(RegExp(r'\s+'));
          if (parts.isNotEmpty) pids.add(parts.last);
        }
        for (final pid in pids) {
          await Process.run('taskkill', ['/F', '/PID', pid]);
        }
      } else {
        final result = await Process.run('lsof', ['-ti', 'tcp:$port']);
        final pids = (result.stdout as String)
            .split('\n')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty);
        for (final pid in pids) {
          await Process.run('kill', ['-9', pid]);
        }
      }
    } catch (_) {
      // Best-effort cleanup; if it fails, Process.start below will surface
      // the real "address already in use" error.
    }
  }
}
