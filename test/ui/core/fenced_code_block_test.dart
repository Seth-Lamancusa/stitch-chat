import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_chat/ui/core/fenced_code_block.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String? clipboardText;

  setUp(() {
    clipboardText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText =
            (call.arguments as Map<String, dynamic>)['text'] as String?;
        return null;
      }
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': clipboardText};
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('copy button writes fenced code to the clipboard', (tester) async {
    const code = 'print("hello");\n';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FencedCodeBlock(code: code),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.copy));
    await tester.pump();

    expect(clipboardText, code);
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.byIcon(Icons.copy), findsOneWidget);
  });

  testWidgets('copy button sticks within the visible slice while scrolling',
      (tester) async {
    final code = 'line\n' * 40;
    const scrollKey = Key('outer-scroll');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: SingleChildScrollView(
              key: scrollKey,
              child: Column(
                children: [
                  const SizedBox(height: 150),
                  FencedCodeBlock(code: code),
                  const SizedBox(height: 400),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final viewportTop = tester.getTopLeft(find.byKey(scrollKey)).dy;
    Offset buttonCenter() => tester.getCenter(find.byIcon(Icons.copy));

    final start = buttonCenter();

    await tester.drag(find.byKey(scrollKey), const Offset(0, -200));
    await tester.pump();
    // Let the post-frame sticky update run.
    await tester.pump();

    final mid = buttonCenter();
    // Still on screen near the viewport top — not scrolled off with the
    // block's original top-left corner.
    expect(mid.dy, lessThan(start.dy));
    expect(mid.dy, greaterThan(viewportTop));
    expect(mid.dy, lessThan(viewportTop + 50));
  });
}
