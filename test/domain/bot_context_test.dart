import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_chat/data/models/message.dart';
import 'package:stitch_chat/domain/bot_mention.dart';
import 'package:stitch_chat/domain/context_chain.dart';

void main() {
  group('parseBotMentions', () {
    test('finds chatgpt and aliases openai', () {
      expect(parseBotMentions('@chatgpt hi').map((m) => m.botId), ['chatgpt']);
      expect(parseBotMentions('hey @openai').map((m) => m.botId), ['chatgpt']);
    });

    test('dedupes and ignores unknown tags', () {
      final mentions = parseBotMentions('@chatgpt @openai @claude please');
      expect(mentions.map((m) => m.botId), ['chatgpt']);
    });
  });

  group('contextThroughReplyTarget', () {
    Message msg(String id) => Message(
          id: id,
          role: MessageRole.user,
          authorId: 'me',
          content: id,
        );

    test('returns empty when no reply target', () {
      expect(contextThroughReplyTarget([msg('a'), msg('b')]), isEmpty);
    });

    test('includes messages through the reply target only', () {
      final branch = [msg('a'), msg('b'), msg('c')];
      expect(
        contextThroughReplyTarget(branch, replyTargetId: 'b').map((m) => m.id),
        ['a', 'b'],
      );
    });

    test('returns empty when reply target is not on the visible branch', () {
      expect(
        contextThroughReplyTarget([msg('a')], replyTargetId: 'missing'),
        isEmpty,
      );
    });
  });
}
