import 'dart:async';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:google_fonts/google_fonts.dart';

/// Global test harness: no native dialogs, no font CDN fetches (both stall CI).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  FileSelectorPlatform.instance = _NoOpFileSelector();
  await testMain();
}

class _NoOpFileSelector extends FileSelectorPlatform {
  @override
  Future<String?> getDirectoryPathWithOptions(
    FileDialogOptions options,
  ) async =>
      null;
}
