import '../models/message.dart';

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

/// Persists the conversation tree — as opposed to `ChatRepository`, which
/// only carries a single live WS stream of runtime events.
///
/// Local (drift) and remote (Stitch backend) stores both implement this so
/// the rest of the app can treat them as interchangeable data sources, per
/// the repository pattern. There is deliberately no `setSelectedChild`/
/// `getSelectedChild` here: "which branch is currently shown" is scoped to
/// a column, not global to a message (see `ColumnRepository`) — a message
/// can appear in multiple columns showing different branches below it.
///
/// Naming: "outgoing" and "incoming" describe the two edge directions out of
/// a message, each split further by edge type (reply vs. stitch) — this is
/// the vocabulary the whole navigator/marker UI is built on. The *outgoing*
/// navigator (ported from stitch-frontend's SiblingNavigator) sits beside a
/// message and cycles [getOutgoing]'s pool; the *incoming* navigator (ported
/// from LinkSwitcher) sits inline above a message and cycles [getIncoming]'s
/// pool. Same data-model relationship, opposite direction — the UI placement
/// differs only because of where each reads naturally on screen.
abstract class MessageRepository {
  Future<void> saveMessage(Message message);

  Future<Message?> getMessage(String id);

  /// Reply children first (creation order), then stitch children — the
  /// combined candidate pool an outgoing navigator needs.
  Future<OutgoingEdges> getOutgoing(String parentId);

  /// Reply parent first, then stitch parents — the combined pool an incoming
  /// navigator needs. Reply side has 0-1 elements today (the reply-edge
  /// schema enforces a single reply parent per child).
  Future<IncomingEdges> getIncoming(String childId);

  /// Root-to-node ancestry via reply parents, root first.
  Future<List<Message>> getAncestorPath(String messageId);

  /// Reply-only, reactive. Stitch edges aren't merged in here: nothing
  /// currently watches a second reactive stream for a code path with no real
  /// second input yet — [getOutgoing] already does the full union for
  /// one-shot reads.
  Stream<List<Message>> watchReplyOutgoing(String parentId);

  Future<void> addReplyEdge(String parentId, String childId);

  Future<void> addStitchEdge(String fromId, String toId, {String? createdByAuthorId});

  Future<void> addRecipientEdge(String messageId, String recipientId, RecipientKind kind);

  Future<void> deleteMessage(String id);
}
