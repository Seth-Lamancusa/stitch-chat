import '../data/models/message.dart';
import '../data/models/participant_profile.dart';

/// Slices a column's visible linear branch into the ancestor prefix for a
/// new send: from the top of the branch through [replyTargetId] inclusive.
/// Messages below the reply target are excluded even if still on screen.
///
/// When [replyTargetId] is null (fresh root send), the prefix is empty —
/// the trigger alone will be the context window once appended.
///
/// The invoke context window is this prefix **plus the trigger message**
/// as the final node (see [contextWindowIncludingTrigger]).
List<Message> contextThroughReplyTarget(
  List<Message> visibleBranch, {
  String? replyTargetId,
}) {
  if (replyTargetId == null) return const [];
  final index = visibleBranch.indexWhere((m) => m.id == replyTargetId);
  if (index < 0) return const [];
  return List<Message>.unmodifiable(visibleBranch.sublist(0, index + 1));
}

/// Full context window for a bot invoke: ancestor prefix through the reply
/// target, then [trigger] as the last message. The trigger is not a
/// separate wire field — it is just the final Stitch node in the list.
List<Message> contextWindowIncludingTrigger(
  List<Message> prefixThroughReplyTarget,
  Message trigger,
) {
  return List<Message>.unmodifiable([
    ...prefixThroughReplyTarget,
    trigger,
  ]);
}

/// Wire shape for one Stitch node inside `user_message.context`.
Map<String, dynamic> messageToContextNode(Message message) {
  return {
    'id': message.id,
    'role': message.role.name,
    'author_id': message.authorId,
    'content': message.content,
  };
}

/// Maps a local ancestor into a Stitch cloud notify `content.context` node.
///
/// Cloud bots receive ancestors in `content.context` and the trigger in
/// `content.messages` — unlike the local bridge, the trigger is not appended
/// here. Prefer [Message.cloudMessageId] when synced so ids align with the
/// cloud graph; unsynced local ids are fine for LLM history.
///
/// Returns null when [message] has empty content (caller should skip).
Map<String, dynamic>? messageToCloudContextNode(
  Message message, {
  ParticipantProfile? profile,
}) {
  final content = message.content.trim();
  if (content.isEmpty) return null;

  final uid = profile?.uid ?? message.authorId ?? '';
  final userTag = profile?.userTag ?? '';
  final displayName = profile?.displayName ??
      (userTag.isNotEmpty
          ? userTag
          : (uid.isNotEmpty ? uid : 'Unknown'));
  final isBot = profile?.isBot ??
      (message.role == MessageRole.localBot ||
          message.role == MessageRole.functionCall ||
          message.role == MessageRole.functionResult ||
          message.role == MessageRole.thinking);

  final id = (message.cloudMessageId != null &&
          message.cloudMessageId!.isNotEmpty)
      ? message.cloudMessageId!
      : message.id;

  return {
    'id': id,
    'content': message.content,
    'public': false,
    'timestamp': (message.createdAt ?? DateTime.now().toUtc()).toIso8601String(),
    'author': {
      'uid': uid,
      'user_tag': userTag,
      'display_name': displayName,
      'is_bot': isBot,
    },
  };
}

/// Builds the cloud notify ancestor list from a visible-branch prefix.
///
/// [profileFor] looks up a cached [ParticipantProfile] by author uid; missing
/// profiles fall back to role heuristics inside [messageToCloudContextNode].
List<Map<String, dynamic>> messagesToCloudContext(
  Iterable<Message> prefixThroughReplyTarget, {
  ParticipantProfile? Function(String authorId)? profileFor,
}) {
  final out = <Map<String, dynamic>>[];
  for (final message in prefixThroughReplyTarget) {
    final authorId = message.authorId;
    final profile =
        authorId != null && authorId.isNotEmpty && profileFor != null
            ? profileFor(authorId)
            : null;
    final node = messageToCloudContextNode(message, profile: profile);
    if (node != null) out.add(node);
  }
  return out;
}
