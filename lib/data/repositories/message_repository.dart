import '../models/edges.dart';
import '../models/message.dart';

export '../models/edges.dart' show OutgoingEdges, IncomingEdges;

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

  /// Hidden reply children, then non-hidden replies, then stitch children —
  /// the combined candidate pool an outgoing navigator needs.
  /// Default path walks use only the non-hidden reply list.
  Future<OutgoingEdges> getOutgoing(String parentId);

  /// Hidden reply parent, then non-hidden reply parent (0–1 reply parents
  /// total today), then stitch parents — the combined pool an incoming
  /// navigator needs.
  Future<IncomingEdges> getIncoming(String childId);

  /// Root-to-node ancestry via reply parents, root first.
  Future<List<Message>> getAncestorPath(String messageId);

  /// Absolute thread roots — messages with no reply parent.
  Future<List<Message>> getThreadRoots();

  /// Reactive [getThreadRoots]; updates when messages or reply edges change.
  Stream<List<Message>> watchThreadRoots();

  /// Reply-only, reactive. Stitch edges aren't merged in here: nothing
  /// currently watches a second reactive stream for a code path with no real
  /// second input yet — [getOutgoing] already does the full union for
  /// one-shot reads.
  Stream<List<Message>> watchReplyOutgoing(String parentId);

  /// [hidden] marks the edge for Surgical Loading–style default skip; see
  /// [OutgoingEdges.hiddenReplyOutgoing].
  Future<void> addReplyEdge(
    String parentId,
    String childId, {
    bool hidden = false,
  });

  Future<void> addStitchEdge(String fromId, String toId, {String? createdByAuthorId});

  Future<void> addRecipientEdge(String messageId, String recipientId, RecipientKind kind);

  /// Existing recipient edges on [messageId] — used to inherit a parent
  /// message's addressees onto a reply.
  Future<List<RecipientRef>> getRecipients(String messageId);

  Future<void> deleteMessage(String id);

  /// Rewrites identity stamps from [fromAuthorId] to [toAuthorId] across
  /// message authors, stitch `createdByAuthorId`, and recipient edges.
  /// Returns the number of message rows updated. No-op when the ids are
  /// equal or [fromAuthorId] is empty.
  Future<int> rewriteAuthorId({
    required String fromAuthorId,
    required String toAuthorId,
  });
}
