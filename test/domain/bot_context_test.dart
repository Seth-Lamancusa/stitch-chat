import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_chat/data/models/cloud_sync_status.dart';
import 'package:stitch_chat/data/models/message.dart';
import 'package:stitch_chat/data/models/participant_profile.dart';
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

    test('fromWire maps requires_cwd', () {
      final fromWire = BotRegistry.fromWire([
        {'id': 'cursor', 'aliases': ['cursor'], 'requires_cwd': true},
        {'id': 'chatgpt', 'aliases': ['chatgpt']},
      ]);
      expect(fromWire.requiresCwd('cursor'), isTrue);
      expect(fromWire.requiresCwd('chatgpt'), isFalse);
    });

    test('dedupes and ignores unknown tags', () {
      final mentions = registry.parseMentions('@chatgpt @openai @claude please');
      expect(mentions.map((m) => m.botId), ['chatgpt']);
    });

    test('empty registry ignores every tag', () {
      expect(const BotRegistry.empty().parseMentions('@chatgpt hi'), isEmpty);
    });

    test('searchTagSuggestions filters by prefix', () {
      expect(registry.searchTagSuggestions('chat'), ['chatgpt']);
      expect(registry.searchTagSuggestions('c'), ['chatgpt', 'cursor']);
      expect(registry.searchTagSuggestions(''), ['chatgpt', 'cursor', 'openai']);
    });

    test('bots lists advertised specs sorted by id', () {
      expect(registry.bots.map((b) => b.id), ['chatgpt', 'cursor']);
      expect(const BotRegistry.empty().bots, isEmpty);
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

  group('messageToCloudContextNode', () {
    test('returns null for empty content', () {
      expect(
        messageToCloudContextNode(
          const Message(
            id: 'a',
            role: MessageRole.user,
            content: '   ',
          ),
        ),
        isNull,
      );
    });

    test('prefers cloudMessageId when synced', () {
      final node = messageToCloudContextNode(
        Message(
          id: 'local-1',
          role: MessageRole.user,
          authorId: 'uid-1',
          content: 'hello',
          createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
          cloudMessageId: 'abcd1234',
          syncStatus: CloudSyncStatus.synced,
        ),
        profile: const ParticipantProfile(
          uid: 'uid-1',
          userTag: 'alice',
          displayName: 'Alice',
        ),
      );
      expect(node, isNotNull);
      expect(node!['id'], 'abcd1234');
      expect(node['content'], 'hello');
      expect(node['public'], isFalse);
      expect(node['timestamp'], '2026-01-02T03:04:05.000Z');
      expect(node['author'], {
        'uid': 'uid-1',
        'user_tag': 'alice',
        'display_name': 'Alice',
        'is_bot': false,
      });
    });

    test('falls back to local id and role-based is_bot', () {
      final node = messageToCloudContextNode(
        const Message(
          id: 'local-bot',
          role: MessageRole.localBot,
          authorId: 'chatgpt',
          content: 'reply',
        ),
      );
      expect(node!['id'], 'local-bot');
      expect(node['author']['is_bot'], isTrue);
      expect(node['author']['uid'], 'chatgpt');
    });
  });

  group('messagesToCloudContext', () {
    test('skips empty nodes and resolves profiles', () {
      final nodes = messagesToCloudContext(
        [
          const Message(
            id: 'a',
            role: MessageRole.user,
            authorId: 'uid-a',
            content: 'one',
          ),
          const Message(
            id: 'b',
            role: MessageRole.user,
            authorId: 'uid-b',
            content: '  ',
          ),
          Message(
            id: 'c',
            role: MessageRole.user,
            authorId: 'uid-c',
            content: 'three',
            cloudMessageId: 'cloud-c',
            syncStatus: CloudSyncStatus.synced,
          ),
        ],
        profileFor: (id) => id == 'uid-a'
            ? const ParticipantProfile(
                uid: 'uid-a',
                userTag: 'alice',
                displayName: 'Alice',
              )
            : null,
      );
      expect(nodes.map((n) => n['id']), ['a', 'cloud-c']);
      expect(nodes.first['author']['user_tag'], 'alice');
    });
  });
}
