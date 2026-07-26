import '../models/persisted_message.dart';

/// Persists the conversation tree — as opposed to [ChatRepository], which
/// only carries a single live WS stream of runtime events.
///
/// Local (SQLite) and remote (Stitch backend) stores both implement this
/// so the rest of the app can treat them as interchangeable data sources,
/// per the repository pattern.
abstract class MessageStoreRepository {
  Future<void> saveMessage(PersistedMessage message);

  Future<PersistedMessage?> getMessage(String id);

  /// Children of [parentId], in reply order.
  Future<List<PersistedMessage>> getChildren(String parentId);

  /// Root-to-node ancestry, root first. Mirrors stitch-frontend's
  /// getAncestorPath primitive.
  Future<List<PersistedMessage>> getAncestorPath(String messageId);

  /// Records which child is currently the "selected" branch under
  /// [parentId] — the branch_child pointer pattern from stitch-frontend's
  /// SiblingNavigator, letting the visible thread be reconstructed by
  /// walking these pointers rather than storing a separate path list.
  Future<void> setSelectedChild(String parentId, String childId);

  Future<String?> getSelectedChild(String parentId);

  Future<void> deleteMessage(String id);
}
