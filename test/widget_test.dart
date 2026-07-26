import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:stitch_desktop/core/notifications/notification_overlay.dart';
import 'package:stitch_desktop/core/notifications/notification_service.dart';
import 'package:stitch_desktop/data/models/chat_message.dart';
import 'package:stitch_desktop/data/repositories/chat_repository.dart';
import 'package:stitch_desktop/ui/chat/chat_view.dart';
import 'package:stitch_desktop/ui/chat/chat_viewmodel.dart';

class FakeChatRepository implements ChatRepository {
  final _controller = StreamController<ChatEvent>.broadcast();

  @override
  Stream<ChatEvent> get events => _controller.stream;

  @override
  Future<void> connect() async {}

  @override
  ChatMessage sendMessage(String content, {String? parentId}) {
    return ChatMessage(id: 'fake-id', parentId: parentId, role: 'user', content: content);
  }
}

Widget _buildApp(ChatViewModel viewModel, NotificationService notifications) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<NotificationService>.value(value: notifications),
      ChangeNotifierProvider<ChatViewModel>.value(value: viewModel),
    ],
    child: const MaterialApp(home: NotificationOverlay(child: ChatView())),
  );
}

void main() {
  testWidgets('sending a message renders it in the list', (tester) async {
    final viewModel = ChatViewModel(FakeChatRepository(), NotificationService());

    await tester.pumpWidget(_buildApp(viewModel, NotificationService()));

    await tester.enterText(find.byType(TextField), 'Hello, world!');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.text('Hello, world!'), findsOneWidget);
  });

  testWidgets('test blocking error button shows a dismissible banner', (tester) async {
    final notifications = NotificationService();
    final viewModel = ChatViewModel(FakeChatRepository(), notifications);

    await tester.pumpWidget(_buildApp(viewModel, notifications));

    await tester.tap(find.text('Test blocking error'));
    await tester.pump();

    expect(find.text('Something went badly wrong (test blocking error)'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(find.text('Something went badly wrong (test blocking error)'), findsNothing);
  });

  testWidgets('test toast button shows a toast that can be dismissed early', (tester) async {
    final notifications = NotificationService();
    final viewModel = ChatViewModel(FakeChatRepository(), notifications);

    await tester.pumpWidget(_buildApp(viewModel, notifications));

    await tester.tap(find.text('Test toast'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250)); // let entrance animation settle

    expect(find.text('Heads up — this is a toast (test)'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Heads up — this is a toast (test)'), findsNothing);
  });
}
