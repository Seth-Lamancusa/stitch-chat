import '../../core/logging/stitch_log.dart';
import '../repositories/message_repository.dart';
import 'local_identity_service.dart';

/// Promotes message authorship from the device-local identity to the cloud
/// subject once Stitch Cloud auth is active.
///
/// Local-first chat stamps sends with [LocalIdentityService.localUserId].
/// After a successful cloud login (or session restore), any rows still
/// bearing that local id are rewritten to the cloud uid so "is this me"
/// and future sync stay canonical. Idempotent: later logins only touch
/// leftover local stamps (e.g. messages sent while signed out).
class AuthorIdPromotion {
  AuthorIdPromotion._();

  /// Returns the number of message rows rewritten (0 when nothing to do).
  static Future<int> promoteLocalToCloud({
    required LocalIdentityService identity,
    required MessageRepository messages,
  }) async {
    if (!identity.authenticatedOnline) return 0;
    final from = identity.localUserId;
    final to = identity.currentUserId;
    if (from == to) return 0;

    final count = await messages.rewriteAuthorId(
      fromAuthorId: from,
      toAuthorId: to,
    );
    if (count > 0) {
      StitchLog.info(
        'promoted $count message author_id(s) local→cloud ($from → $to)',
        tag: 'auth',
      );
    }
    return count;
  }
}
