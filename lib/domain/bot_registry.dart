/// Parses `@bot` mentions from message content for local-bot dispatch.
///
/// Stitch addresses bots by tag in messages. Which tags resolve to which
/// bot id — and flags like [BotSpec.requiresCwd] for composer warnings —
/// is derived from the registry the Python bridge exposes on connect.
/// The bridge still enforces `requires_cwd` (via `invoke_skipped`); Dart
/// uses the flag only for UI above the reply box.

class BotSpec {
  const BotSpec({
    required this.id,
    required this.aliases,
    this.requiresCwd = false,
  });

  /// Canonical bot id sent on the wire (e.g. `chatgpt`).
  final String id;

  /// Every tag (without `@`) that resolves to [id], including [id] itself.
  final Set<String> aliases;

  /// When true and the column has no cwd, the composer shows a warning and
  /// the bridge skips adapter dispatch. Not an error.
  final bool requiresCwd;
}

class BotMention {
  const BotMention({required this.botId, required this.raw});

  /// Canonical bot id sent on the wire (e.g. `chatgpt`).
  final String botId;

  /// The matched tag text without `@` (e.g. `chatgpt` or `openai`).
  final String raw;
}

final _mentionPattern = RegExp(r'(?:^|\s)@([A-Za-z0-9_-]+)');

/// Tag -> bot id lookup built from a [BotSpec] list. Unknown tags are
/// ignored (no dispatch); the bridge still validates bot_id.
class BotRegistry {
  BotRegistry(List<BotSpec> bots)
      : _byId = {for (final bot in bots) bot.id: bot},
        _aliasToId = {
          for (final bot in bots)
            for (final alias in bot.aliases) alias.toLowerCase(): bot.id,
        };

  const BotRegistry.empty()
      : _byId = const {},
        _aliasToId = const {};

  factory BotRegistry.fromWire(List<dynamic> bots) {
    return BotRegistry([
      for (final entry in bots.cast<Map<String, dynamic>>())
        BotSpec(
          id: entry['id'] as String,
          aliases: (entry['aliases'] as List).cast<String>().toSet(),
          requiresCwd: entry['requires_cwd'] == true,
        ),
    ]);
  }

  final Map<String, BotSpec> _byId;
  final Map<String, String> _aliasToId;

  bool requiresCwd(String botId) => _byId[botId]?.requiresCwd ?? false;

  /// Returns distinct local bots tagged in [content], in first-seen order.
  List<BotMention> parseMentions(String content) {
    final seen = <String>{};
    final out = <BotMention>[];
    for (final match in _mentionPattern.allMatches(content)) {
      final raw = match.group(1)!;
      final botId = _aliasToId[raw.toLowerCase()];
      if (botId == null) continue;
      if (!seen.add(botId)) continue;
      out.add(BotMention(botId: botId, raw: raw));
    }
    return out;
  }
}
