import 'package:flutter/material.dart';

import '../../data/models/message.dart';
import '../../data/models/participant_profile.dart';
import '../../domain/bot_registry.dart';

/// Cloud ☁️ and laptop 💻 badges per product rules (see `docs/cloud-sync.md`).
class AuthorIdentityBadges extends StatelessWidget {
  const AuthorIdentityBadges({
    super.key,
    required this.message,
    this.profile,
    this.botRegistry = const BotRegistry.empty(),
  });

  final Message message;
  final ParticipantProfile? profile;
  final BotRegistry botRegistry;

  @override
  Widget build(BuildContext context) {
    final showLaptop = _showLaptop;
    final showCloud = _showCloud;
    if (!showLaptop && !showCloud) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showCloud)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text('☁️', style: TextStyle(fontSize: 12)),
          ),
        if (showLaptop)
          const Padding(
            padding: EdgeInsets.only(left: 2),
            child: Text('💻', style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }

  bool get _showLaptop {
    if (message.role == MessageRole.localBot) return true;
    if (profile?.isBot == true) return true;
    final authorId = message.authorId;
    if (authorId != null && botRegistry.isKnownBot(authorId)) return true;
    return false;
  }

  bool get _showCloud {
    if (message.role == MessageRole.localBot) return false;
    if (profile != null) return true;
    return false;
  }
}

/// ☁️ / 💻 on composer `@` suggestions (`docs/cloud-sync.md`).
class MentionSuggestionBadges extends StatelessWidget {
  const MentionSuggestionBadges.localBridgeBot({super.key})
      : showCloud = false,
        showLaptop = true;

  const MentionSuggestionBadges.cloudUser({super.key, required bool isBot})
      : showCloud = true,
        showLaptop = isBot;

  final bool showCloud;
  final bool showLaptop;

  @override
  Widget build(BuildContext context) {
    if (!showCloud && !showLaptop) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showCloud)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text('☁️', style: TextStyle(fontSize: 12)),
          ),
        if (showLaptop)
          const Padding(
            padding: EdgeInsets.only(left: 2),
            child: Text('💻', style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }
}
