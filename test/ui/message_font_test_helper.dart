import 'dart:io';

import 'package:stitch_chat/core/settings/message_font_service.dart';

Future<MessageFontService> createTestMessageFontService() async {
  final storage = Directory.systemTemp.createTempSync('stitch_msg_font_');
  final service = MessageFontService();
  await service.initialize(storageDirectory: storage);
  return service;
}
