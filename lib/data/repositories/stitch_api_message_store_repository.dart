import '../models/persisted_message.dart';
import 'message_store_repository.dart';

/// Talks to the Stitch backend's message CRUD API as an alternative
/// [MessageStoreRepository] to [SqliteMessageStoreRepository].
///
/// NOT YET IMPLEMENTED. API integration is pending decisions on the
/// intended sync/reconciliation flow between this store and the local
/// SQLite one — e.g. whether writes go local-first with background push,
/// how conflicting edits to the same message/branch pointer resolve,
/// whether the tree is fully mirrored locally or lazily fetched, and how
/// offline writes are queued and replayed. Don't build against this class
/// until that's settled; the method bodies below are stubs so the
/// interface shape can be reviewed ahead of time.
class StitchApiMessageStoreRepository implements MessageStoreRepository {
  final String baseUrl;

  StitchApiMessageStoreRepository(this.baseUrl);

  @override
  Future<void> saveMessage(PersistedMessage message) => _unimplemented();

  @override
  Future<PersistedMessage?> getMessage(String id) => _unimplemented();

  @override
  Future<List<PersistedMessage>> getChildren(String parentId) => _unimplemented();

  @override
  Future<List<PersistedMessage>> getAncestorPath(String messageId) => _unimplemented();

  @override
  Future<void> setSelectedChild(String parentId, String childId) => _unimplemented();

  @override
  Future<String?> getSelectedChild(String parentId) => _unimplemented();

  @override
  Future<void> deleteMessage(String id) => _unimplemented();

  Never _unimplemented() {
    throw UnimplementedError(
      'StitchApiMessageStoreRepository is pending sync/reconciliation design — see class doc comment.',
    );
  }
}
