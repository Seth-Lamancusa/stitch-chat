import '../data/models/message.dart';

/// Product rules for cloud notify (mirror toggle off). See `docs/cloud-sync.md`.
class CloudSendGuard {
  /// When this send addresses cloud bots, replies must hang off synced nodes.
  static String? blockReasonForCloudBotReply({
    required String? parentLocalId,
    required Message? parentMessage,
    required bool addressesCloudBot,
  }) {
    if (!addressesCloudBot) return null;
    if (parentLocalId == null) return null;
    if (parentMessage == null) {
      return 'Reply parent not found.';
    }
    if (!parentMessage.isSyncedOnCloud) {
      return 'Reply to a message that is synced to Stitch cloud before notifying cloud bots.';
    }
    return null;
  }

  static bool addressesCloudBot(Iterable<RecipientRef> recipients) {
    for (final r in recipients) {
      if (r.kind == RecipientKind.cloudUser && r.isCloudBot) return true;
    }
    return false;
  }

  static List<RecipientRef> cloudNotifyRecipients(Iterable<RecipientRef> recipients) {
    return [
      for (final r in recipients)
        if (r.kind == RecipientKind.cloudUser && r.notify) r,
    ];
  }
}
