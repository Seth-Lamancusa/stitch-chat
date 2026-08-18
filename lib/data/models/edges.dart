import 'message.dart';

/// The candidate pool a message's outgoing navigator cycles through: which
/// child (reply or stitch) is currently followed below it. Reply-first
/// ordering matches [MessageRepository.getOutgoing].
class OutgoingEdges {
  final List<Message> replyOutgoing;
  final List<Message> stitchedOutgoing;

  const OutgoingEdges({this.replyOutgoing = const [], this.stitchedOutgoing = const []});

  /// The combined pool a sibling/outgoing navigator needs: reply candidates
  /// first, then stitch candidates.
  List<Message> get all => [...replyOutgoing, ...stitchedOutgoing];

  bool get isEmpty => replyOutgoing.isEmpty && stitchedOutgoing.isEmpty;
}

/// The candidate pool a message's incoming navigator cycles through: which
/// parent (reply or stitch) its context is currently derived from. Reply-first
/// ordering matches [MessageRepository.getIncoming].
class IncomingEdges {
  final List<Message> replyIncoming;
  final List<Message> stitchedIncoming;

  const IncomingEdges({this.replyIncoming = const [], this.stitchedIncoming = const []});

  /// The combined pool an incoming navigator needs: the reply parent (0-1
  /// elements today) first, then stitch parents.
  List<Message> get all => [...replyIncoming, ...stitchedIncoming];

  bool get isEmpty => replyIncoming.isEmpty && stitchedIncoming.isEmpty;
}
