import '../models/message.dart';

/// Dev-only typing-cue fixture marker embedded in message content.
///
/// Format (first line): `[[mockTyping:author1,author2]]`
///
/// Production cues stay ephemeral ([TypingCueStore]). This marker is the
/// deliberate exception for visual UI work: the cue "persists" because it
/// lives on the message row. [StitchEnv.mockTypingCues] gates whether the
/// UI honors the marker as typing chrome; [strip] always removes it from
/// rendered text so leftover seed data stays readable if the flag is off.
class MockTypingCue {
  MockTypingCue._();

  static const fixtureRootId = 'typing-fx-root';
  static const fixtureMidId = 'typing-fx-mid';
  static const fixtureContId = 'typing-fx-cont';
  static const fixtureLeafId = 'typing-fx-leaf';

  static const Set<String> fixtureIds = {
    fixtureRootId,
    fixtureMidId,
    fixtureContId,
    fixtureLeafId,
  };

  static final RegExp _marker = RegExp(r'^\[\[mockTyping:([^\]]*)\]\]\r?\n?');

  /// Authors listed on a mock-typing marker, or empty if none.
  static List<String> authorsOf(String content) {
    final match = _marker.firstMatch(content);
    if (match == null) return const [];
    return [
      for (final part in match.group(1)!.split(','))
        if (part.trim().isNotEmpty) part.trim(),
    ];
  }

  /// Content with the leading mock-typing marker removed (no-op if absent).
  static String strip(String content) => content.replaceFirst(_marker, '');

  /// Prefix [body] with a mock-typing marker for [authors].
  static String embed(List<String> authors, String body) {
    assert(authors.isNotEmpty);
    return '[[mockTyping:${authors.join(',')}]]\n$body';
  }

  /// Message suitable for display — same identity, marker stripped from content.
  static Message forDisplay(Message message) {
    final stripped = strip(message.content);
    if (identical(stripped, message.content) || stripped == message.content) {
      return message;
    }
    return message.copyWith(content: stripped);
  }
}
