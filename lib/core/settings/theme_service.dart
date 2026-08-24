import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persists the user's light/dark choice to a plain file, following
/// [LocalIdentityService]'s convention for single-scalar settings (no
/// schema/migration needed, no extra dependency for a single flag).
///
/// Defaults to the platform's brightness on first launch, then remembers
/// whatever the user picks in the settings modal from then on.
class ThemeService extends ChangeNotifier {
  static const _fileName = 'theme_mode.txt';

  bool? _isDarkMode;

  bool get isDarkMode {
    final value = _isDarkMode;
    if (value == null) {
      throw StateError('ThemeService.initialize() must complete before isDarkMode is read');
    }
    return value;
  }

  Future<void> initialize() async {
    final file = await _file();
    if (await file.exists()) {
      _isDarkMode = (await file.readAsString()).trim() == 'dark';
      return;
    }
    _isDarkMode = PlatformDispatcher.instance.platformBrightness == Brightness.dark;
  }

  Future<void> setDarkMode(bool value) async {
    if (value == _isDarkMode) return;
    _isDarkMode = value;
    notifyListeners();
    final file = await _file();
    await file.writeAsString(value ? 'dark' : 'light');
  }

  Future<File> _file() async {
    final supportDir = await getApplicationSupportDirectory();
    return File(p.join(supportDir.path, _fileName));
  }
}
