import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persists the message body font size, following [ThemeService]'s
/// single-scalar file convention.
///
/// Material body text is ~14; the default here is intentionally larger so
/// chat is comfortable on desktop without hunting for a control first.
class MessageFontService extends ChangeNotifier {
  static const _fileName = 'message_font_size.txt';

  /// Material-ish body baseline used when converting size ↔ text scale.
  static const double baselineSize = 14;

  static const double minSize = 14;
  static const double maxSize = 28;
  static const double defaultSize = 15;

  double? _fontSize;
  Directory? _storageDirectory;

  double get fontSize {
    final value = _fontSize;
    if (value == null) {
      throw StateError(
        'MessageFontService.initialize() must complete before fontSize is read',
      );
    }
    return value;
  }

  /// Scale factor relative to [baselineSize] for wrapping message content.
  double get textScale => fontSize / baselineSize;

  /// [storageDirectory] avoids [getApplicationSupportDirectory] in widget tests.
  Future<void> initialize({Directory? storageDirectory}) async {
    if (storageDirectory != null) {
      _storageDirectory = storageDirectory;
    }
    final file = await _file();
    if (await file.exists()) {
      final parsed = double.tryParse((await file.readAsString()).trim());
      if (parsed != null) {
        _fontSize = parsed.clamp(minSize, maxSize);
        return;
      }
    }
    _fontSize = defaultSize;
  }

  Future<void> setFontSize(double value) async {
    final clamped = value.clamp(minSize, maxSize);
    if (clamped == _fontSize) return;
    _fontSize = clamped;
    notifyListeners();
    final file = await _file();
    await file.writeAsString(clamped.round().toString());
  }

  Future<File> _file() async {
    final dir =
        _storageDirectory ?? await getApplicationSupportDirectory();
    return File(p.join(dir.path, _fileName));
  }
}
