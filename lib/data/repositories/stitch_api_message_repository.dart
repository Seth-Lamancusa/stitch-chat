import '../models/cloud_sync_status.dart';
import '../models/message.dart';
import '../models/message_tag.dart';
import '../models/participant_profile.dart';
import 'message_repository.dart';

/// Talks to the Stitch backend's message CRUD API as an alternative
/// `MessageRepository` to `DriftMessageRepository`.
///
/// NOT YET IMPLEMENTED. API integration is pending decisions on the
/// intended sync/reconciliation flow between this store and the local
/// drift one — e.g. whether writes go local-first with background push,
/// how conflicting edits to the same message/branch pointer resolve,
/// whether the tree is fully mirrored locally or lazily fetched, and how
/// offline writes are queued and replayed. Don't build against this class
/// until that's settled; the method bodies below are stubs so the
/// interface shape can be reviewed ahead of time.
class StitchApiMessageRepository implements MessageRepository {
  final String baseUrl;

  StitchApiMessageRepository(this.baseUrl);

  @override
  Future<void> saveMessage(Message message) => _unimplemented();

  @override
  Future<Message?> getMessage(String id) => _unimplemented();

  @override
  Future<OutgoingEdges> getOutgoing(String parentId) => _unimplemented();

  @override
  Future<IncomingEdges> getIncoming(String childId) => _unimplemented();

  @override
  Future<List<Message>> getAncestorPath(String messageId) => _unimplemented();

  @override
  Future<List<Message>> getThreadRoots() => _unimplemented();

  @override
  Stream<List<Message>> watchThreadRoots() => _unimplemented();

  @override
  Stream<List<Message>> watchReplyOutgoing(String parentId) => _unimplemented();

  @override
  Future<void> addReplyEdge(
    String parentId,
    String childId, {
    bool hidden = false,
  }) =>
      _unimplemented();

  @override
  Future<void> addStitchEdge(String fromId, String toId, {String? createdByAuthorId}) =>
      _unimplemented();

  @override
  Future<void> addRecipientEdge(
    String messageId,
    String recipientId,
    RecipientKind kind, {
    bool isCloudBot = false,
    bool isPublic = true,
    bool notify = true,
    String? addedBy,
    DateTime? addedAt,
  }) =>
      _unimplemented();

  @override
  Future<List<RecipientRef>> getRecipients(String messageId) => _unimplemented();

  @override
  Future<void> setMessageTags(String messageId, List<MessageTag> tags) =>
      _unimplemented();

  @override
  Future<List<MessageTag>> getMessageTags(String messageId) => _unimplemented();

  @override
  Future<void> deleteMessage(String id) => _unimplemented();

  @override
  Future<int> rewriteAuthorId({
    required String fromAuthorId,
    required String toAuthorId,
  }) =>
      _unimplemented();

  @override
  Future<String?> resolveGraphMessageId(String cloudOrLocalId) => _unimplemented();

  @override
  Future<Message?> getMessageByCloudId(String cloudMessageId) => _unimplemented();

  @override
  Future<void> updateCloudSync({
    required String localMessageId,
    CloudSyncStatus? syncStatus,
    String? cloudMessageId,
    String? syncError,
  }) =>
      _unimplemented();

  @override
  Future<void> upsertParticipantProfile(ParticipantProfile profile) => _unimplemented();

  @override
  Future<ParticipantProfile?> getParticipantProfile(String uid) => _unimplemented();

  Never _unimplemented() {
    throw UnimplementedError(
      'StitchApiMessageRepository is pending sync/reconciliation design — see class doc comment.',
    );
  }
}
