import '../data/models/message.dart';

/// Slices a column's visible linear branch into the context window for a
/// bot invocation: from the top of the branch through [replyTargetId]
/// inclusive. Messages below the reply target are excluded even if still
/// on screen.
///
/// When [replyTargetId] is null (fresh root send), context is empty — the
/// trigger message alone is the prompt.
List<Message> contextThroughReplyTarget(
  List<Message> visibleBranch, {
  String? replyTargetId,
}) {
  if (replyTargetId == null) return const [];
  final index = visibleBranch.indexWhere((m) => m.id == replyTargetId);
  if (index < 0) return const [];
  return List<Message>.unmodifiable(visibleBranch.sublist(0, index + 1));
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
