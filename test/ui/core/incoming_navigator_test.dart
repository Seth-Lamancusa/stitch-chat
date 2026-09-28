import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_chat/ui/core/incoming_navigator.dart';
import 'package:stitch_chat/ui/core/theme/app_theme.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    );
  }

  testWidgets('shows Hidden thread pill when current parent is hidden', (tester) async {
    await tester.pumpWidget(
      wrap(
        const IncomingNavigator(
          hiddenCount: 1,
          replyCount: 0,
          stitchCount: 0,
          currentIndex: 0,
        ),
      ),
    );

    expect(find.text('Hidden thread'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  testWidgets('shows Linked origin pill when current parent is stitch', (tester) async {
    await tester.pumpWidget(
      wrap(
        const IncomingNavigator(
          hiddenCount: 0,
          replyCount: 1,
          stitchCount: 1,
          currentIndex: 1,
        ),
      ),
    );

    expect(find.text('Linked origin'), findsOneWidget);
    expect(find.byIcon(Icons.link), findsOneWidget);
  });

  testWidgets('hides when only a normal reply parent is active', (tester) async {
    await tester.pumpWidget(
      wrap(
        const IncomingNavigator(
          hiddenCount: 0,
          replyCount: 1,
          stitchCount: 0,
          currentIndex: 0,
        ),
      ),
    );

    expect(find.text('Reply origin'), findsNothing);
    expect(find.text('Hidden thread'), findsNothing);
  });
}
