import '../data/models/participant_profile.dart';
import 'bot_registry.dart';

final _mentionToken = RegExp(r'(?:^|\s)@([A-Za-z0-9_-]{2,24})(?=[^\w@.]|$)');

/// Resolves `@tag` tokens to local bots or cloud users.
class CloudMentionParser {
  CloudMentionParser({
    required BotRegistry localBots,
    required Future<ParticipantProfile?> Function(String tag) resolveCloudTag,
  })  : _localBots = localBots,
        _resolveCloudTag = resolveCloudTag;

  final BotRegistry _localBots;
  final Future<ParticipantProfile?> Function(String tag) _resolveCloudTag;

  Future<ResolvedMentions> resolve(String content) async {
    final local = _localBots.parseMentions(content);
    final localTags = {for (final m in local) m.raw.toLowerCase()};

    final cloud = <ParticipantProfile>[];
    for (final match in _mentionToken.allMatches(content)) {
      final raw = match.group(1)!;
      if (localTags.contains(raw.toLowerCase())) continue;
      final profile = await _resolveCloudTag(raw);
      if (profile != null) cloud.add(profile);
    }

    return ResolvedMentions(localMentions: local, cloudUsers: cloud);
  }
}

class ResolvedMentions {
  const ResolvedMentions({
    required this.localMentions,
    required this.cloudUsers,
  });

  final List<BotMention> localMentions;
  final List<ParticipantProfile> cloudUsers;
}
