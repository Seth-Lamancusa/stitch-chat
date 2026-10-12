import '../data/models/message.dart';
import '../data/models/participant_profile.dart';
import '../domain/bot_registry.dart';

class AuthorBadgeFlags {
  const AuthorBadgeFlags({this.showCloud = false, this.showLaptop = false});

  final bool showCloud;
  final bool showLaptop;

  static AuthorBadgeFlags resolve({
    required Message message,
    ParticipantProfile? profile,
    BotRegistry registry = const BotRegistry.empty(),
  }) {
    if (message.role == MessageRole.localBot) {
      return const AuthorBadgeFlags(showLaptop: true);
    }
    if (profile != null) {
      return AuthorBadgeFlags(showCloud: true, showLaptop: profile.isBot);
    }
    final authorId = message.authorId;
    if (authorId != null && registry.isKnownBot(authorId)) {
      return const AuthorBadgeFlags(showLaptop: true);
    }
    return const AuthorBadgeFlags();
  }
}
