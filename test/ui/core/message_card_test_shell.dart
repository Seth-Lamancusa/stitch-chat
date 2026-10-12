import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stitch_chat/core/settings/message_font_service.dart';
import 'package:stitch_chat/ui/core/message_card.dart';

import '../message_font_test_helper.dart';

/// [MessageCard] reads [MessageFontService] from context.
class MessageCardTestShell {
  MessageCardTestShell._();

  static MessageFontService? _fonts;

  static Future<MessageFontService> fonts() async {
    return _fonts ??= await createTestMessageFontService();
  }

  static Future<void> pump(
    WidgetTester tester, {
    required Widget body,
  }) async {
    MessageCard.debugDisableTypingPulse = true;
    final messageFonts = await fonts();
    await tester.pumpWidget(
      ChangeNotifierProvider<MessageFontService>.value(
        value: messageFonts,
        child: MaterialApp(home: Scaffold(body: body)),
      ),
    );
  }
}
