import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_chat/data/models/message.dart';
import 'package:stitch_chat/domain/bot_registry.dart';
import 'package:stitch_chat/domain/context_chain.dart';

void main() {
  group('BotRegistry.parseMentions', () {
    final registry = BotRegistry([
      const BotSpec(id: 'chatgpt', aliases: {'chatgpt', 'openai'}),
      const BotSpec(id: 'cursor', aliases: {'cursor'}, requiresCwd: true),
    ]);

    test('finds chatgpt and aliases openai', () {
      expect(registry.parseMentions('@chatgpt hi').map((m) => m.botId), ['chatgpt']);
      expect(registry.parseMentions('hey @openai').map((m) => m.botId), ['chatgpt']);
    });

    test('finds cursor', () {
      expect(registry.parseMentions('@cursor fix it').map((m) => m.botId), ['cursor']);
    });

    test('requiresCwd is registry-driven for composer warnings', () {
      expect(registry.requiresCwd('cursor'), isTrue);
      expect(registry.requiresCwd('chatgpt'), isFalse);
    });

    test('fromWire maps requires_cwd and requires_auth', () {
      final fromWire = BotRegistry.fromWire([
        {
          'id': 'cursor',
          'aliases': ['cursor'],
          'requires_cwd': true,
          'requires_auth': true,
        },
        {'id': 'chatgpt', 'aliases': ['chatgpt']},
      ]);
      expect(fromWire.requiresCwd('cursor'), isTrue);
      expect(fromWire.requiresAuth('cursor'), isTrue);
      expect(fromWire.requiresCwd('chatgpt'), isFalse);
      expect(fromWire.requiresAuth('chatgpt'), isFalse);
    });

    test('dedupes and ignores unknown tags', () {
      final mentions = registry.parseMentions('@chatgpt @openai @claude please');
      expect(mentions.map((m) => m.botId), ['chatgpt']);
    });

    test('empty registry ignores every tag', () {
      expect(const BotRegistry.empty().parseMentions('@chatgpt hi'), isEmpty);
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

  group('contextWindowIncludingTrigger', () {
    Message msg(String id) => Message(
          id: id,
          role: MessageRole.user,
          authorId: 'me',
          content: id,
        );

    test('appends trigger as the final node', () {
      final window = contextWindowIncludingTrigger([msg('a'), msg('b')], msg('t'));
      expect(window.map((m) => m.id), ['a', 'b', 't']);
    });

    test('trigger-only window when prefix is empty', () {
      final window = contextWindowIncludingTrigger(const [], msg('t'));
      expect(window.map((m) => m.id), ['t']);
    });
  });
}
