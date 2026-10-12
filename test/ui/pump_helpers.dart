import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Settles UI without [WidgetTester.pumpAndSettle], which never completes
/// while a focused composer caret or other ticker keeps scheduling frames.
Future<void> pumpUiSettle(
  WidgetTester tester, {
  Duration settleTime = const Duration(milliseconds: 400),
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.pump(settleTime);
}

/// Flushes one-shot async work (e.g. dialog folder pick) before settling UI.
Future<void> pumpAsyncWork(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}
