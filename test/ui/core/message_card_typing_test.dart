import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_chat/data/models/message.dart';
import 'package:stitch_chat/ui/core/message_card.dart';

void main() {
  testWidgets('typing overlay does not add a list row under the card', (
    tester,
  ) async {
    final message = Message(
      id: 'm1',
      role: MessageRole.user,
      authorId: 'me',
      content: 'hello',
      createdAt: DateTime.utc(2026, 1, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              MessageCard(
                message: message,
                currentUserId: 'me',
                typingAuthors: const ['cursor'],
              ),
            ],
          ),
        ),
      ),
    );
    // Typing chrome uses a repeating opacity pulse — pump frames instead of
    // settle, which never completes while that ticker is running.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Still a single list child — typing is OverlayPortal chrome, not a row.
    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.childrenDelegate.estimatedChildCount, 1);
    expect(find.text('@cursor is typing'), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('clearing typing authors does not throw', (tester) async {
    final message = Message(
      id: 'm-clear',
      role: MessageRole.user,
      authorId: 'me',
      content: 'hello',
      createdAt: DateTime.utc(2026, 1, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageCard(
            message: message,
            currentUserId: 'me',
            typingAuthors: const ['cursor'],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('@cursor is typing'), findsOneWidget);

    // Cue retarget/clear: authors go empty while overlay may still be showing.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageCard(
            message: message,
            currentUserId: 'me',
            typingAuthors: const [],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('@cursor is typing'), findsNothing);
  });

  testWidgets('hover menu replaces typing chrome', (tester) async {
    final message = Message(
      id: 'm2',
      role: MessageRole.user,
      authorId: 'me',
      content: 'world',
      createdAt: DateTime.utc(2026, 1, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageCard(
            message: message,
            currentUserId: 'me',
            typingAuthors: const ['cursor'],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('@cursor is typing'), findsOneWidget);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.text('world')));
    // Menu fade-in is finite; settle is safe once typing chrome is gone.
    await tester.pumpAndSettle();

    // Hover replaces typing chrome with the action menu.
    expect(find.text('@cursor is typing'), findsNothing);
    expect(find.byIcon(Icons.reply), findsOneWidget);
  });

  testWidgets('multi-author typing uses the same right-anchored chrome slot', (
    tester,
  ) async {
    final message = Message(
      id: 'm3',
      role: MessageRole.user,
      authorId: 'me',
      content: 'mid',
      createdAt: DateTime.utc(2026, 1, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageCard(
            message: message,
            currentUserId: 'me',
            typingAuthors: const ['chatgpt', 'cursor'],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('@chatgpt, @cursor are typing'), findsOneWidget);
  });
}
