import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_chat/data/models/message.dart';
import 'package:stitch_chat/data/services/mock_typing_cue.dart';

void main() {
  group('MockTypingCue', () {
    test('authorsOf parses comma list and ignores empty marker', () {
      expect(
        MockTypingCue.authorsOf(
          '[[mockTyping:cursor,chatgpt]]\nhello',
        ),
        ['cursor', 'chatgpt'],
      );
      expect(MockTypingCue.authorsOf('[[mockTyping:]]\nhello'), isEmpty);
      expect(MockTypingCue.authorsOf('plain'), isEmpty);
    });

    test('strip removes only the leading marker', () {
      expect(
        MockTypingCue.strip('[[mockTyping:cursor]]\nLeaf text'),
        'Leaf text',
      );
      expect(MockTypingCue.strip('no marker'), 'no marker');
    });

    test('embed + forDisplay round-trip', () {
      final embedded = MockTypingCue.embed(const ['claude'], 'Leaf text');
      final message = Message(
        id: 'm',
        role: MessageRole.user,
        content: embedded,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      expect(MockTypingCue.authorsOf(message.content), ['claude']);
      expect(MockTypingCue.forDisplay(message).content, 'Leaf text');
    });
  });
}
