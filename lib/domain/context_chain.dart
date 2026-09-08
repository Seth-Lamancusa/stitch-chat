import '../data/models/message.dart';

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
