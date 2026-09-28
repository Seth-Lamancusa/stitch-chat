import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_chat/data/services/typing_cue_store.dart';

void main() {
  group('TypingCueStore', () {
    test('same author may type on multiple targets in parallel', () {
      final store = TypingCueStore(ttl: const Duration(hours: 1));
      addTearDown(store.dispose);

      store.apply(
        const TypingCueEvent(
          authorId: 'cursor',
          targetMessageId: 'a',
          typing: true,
        ),
      );
      store.apply(
        const TypingCueEvent(
          authorId: 'cursor',
          targetMessageId: 'b',
          typing: true,
        ),
      );
      expect(store.authorsTypingAt('a'), ['cursor']);
      expect(store.authorsTypingAt('b'), ['cursor']);

      store.apply(
        const TypingCueEvent(
          authorId: 'cursor',
          targetMessageId: 'a',
          typing: false,
        ),
      );
      expect(store.authorsTypingAt('a'), isEmpty);
      expect(store.authorsTypingAt('b'), ['cursor']);
    });

    test('multiple authors on same target', () {
      final store = TypingCueStore(ttl: const Duration(hours: 1));
      addTearDown(store.dispose);

      store.apply(
        const TypingCueEvent(
          authorId: 'cursor',
          targetMessageId: 't',
          typing: true,
        ),
      );
      store.apply(
        const TypingCueEvent(
          authorId: 'chatgpt',
          targetMessageId: 't',
          typing: true,
        ),
      );
      expect(store.authorsTypingAt('t'), ['chatgpt', 'cursor']);
    });

    test('TTL expires stale cues', () {
      var now = DateTime.utc(2026, 1, 1, 12);
      final store = TypingCueStore(
        ttl: const Duration(seconds: 8),
        clock: () => now,
      );
      addTearDown(store.dispose);

      store.apply(
        const TypingCueEvent(
          authorId: 'cursor',
          targetMessageId: 't',
          typing: true,
        ),
      );
      expect(store.authorsTypingAt('t'), ['cursor']);

      now = now.add(const Duration(seconds: 9));
      store.debugSweepExpired();
      expect(store.authorsTypingAt('t'), isEmpty);
    });
  });
}
