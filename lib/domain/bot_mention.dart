/// Parses `@bot` mentions from message content for local-bot dispatch.
///
/// Stitch addresses bots by tag in the trigger message. Unknown tags are
/// ignored here (no dispatch); the bridge still validates bot_id.

class BotMention {
  const BotMention({required this.botId, required this.raw});

  /// Canonical bot id sent on the wire (e.g. `chatgpt`).
  final String botId;

  /// The matched tag text without `@` (e.g. `chatgpt` or `openai`).
  final String raw;
}

const _aliases = <String, String>{
  'chatgpt': 'chatgpt',
  'openai': 'chatgpt',
};

final _mentionPattern = RegExp(r'(?:^|\s)@([A-Za-z0-9_-]+)');

/// Returns distinct local bots tagged in [content], in first-seen order.
List<BotMention> parseBotMentions(String content) {
  final seen = <String>{};
  final out = <BotMention>[];
  for (final match in _mentionPattern.allMatches(content)) {
    final raw = match.group(1)!;
    final botId = _aliases[raw.toLowerCase()];
    if (botId == null) continue;
    if (!seen.add(botId)) continue;
    out.add(BotMention(botId: botId, raw: raw));
  }
  return out;
}
