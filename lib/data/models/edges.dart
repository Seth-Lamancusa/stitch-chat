import 'message.dart';

/// The candidate pool a message's outgoing navigator cycles through: which
/// child (reply or stitch) is currently followed below it.
///
/// Ordering matches [MessageRepository.getOutgoing]: hidden replies,
/// then non-hidden replies, then stitch children. Default path walks use only
/// [replyOutgoing]; navigators and reveal actions use [all].
class OutgoingEdges {
  final List<Message> replyOutgoing;
  final List<Message> hiddenReplyOutgoing;
  final List<Message> stitchedOutgoing;

  const OutgoingEdges({
    this.replyOutgoing = const [],
    this.hiddenReplyOutgoing = const [],
    this.stitchedOutgoing = const [],
  });

  /// Combined pool for sibling/outgoing navigation.
  List<Message> get all => [
        ...hiddenReplyOutgoing,
        ...replyOutgoing,
        ...stitchedOutgoing,
      ];

  bool get isEmpty =>
      replyOutgoing.isEmpty &&
      hiddenReplyOutgoing.isEmpty &&
      stitchedOutgoing.isEmpty;
}

/// The candidate pool a message's incoming navigator cycles through: which
/// parent (reply or stitch) its context is currently derived from.
///
/// Ordering matches [MessageRepository.getIncoming]: hidden reply parents,
/// then non-hidden reply parents, then stitch parents.
class IncomingEdges {
  final List<Message> replyIncoming;
  final List<Message> hiddenReplyIncoming;
  final List<Message> stitchedIncoming;

  const IncomingEdges({
    this.replyIncoming = const [],
    this.hiddenReplyIncoming = const [],
    this.stitchedIncoming = const [],
  });

  /// Combined pool for incoming navigation.
  List<Message> get all => [
        ...hiddenReplyIncoming,
        ...replyIncoming,
        ...stitchedIncoming,
      ];

  bool get isEmpty =>
      replyIncoming.isEmpty &&
      hiddenReplyIncoming.isEmpty &&
      stitchedIncoming.isEmpty;
}
