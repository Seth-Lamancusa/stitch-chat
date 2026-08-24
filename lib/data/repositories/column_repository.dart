/// Column layout + per-column branch-pointer metadata, restored across app
/// restarts. Pure persistence — deciding *which* child to default to at an
/// unvisited fork is `BranchPathService`'s job, not this repository's; this
/// only stores whatever decision was made.
class ColumnMeta {
  final String id;
  final String? anchorMessageId; // null = no messages sent into this column yet
  final double? width; // null = flexible
  final double? scrollOffset; // null = no saved scroll position

  const ColumnMeta({
    required this.id,
    required this.anchorMessageId,
    this.width,
    this.scrollOffset,
  });
}

/// Naming matches [MessageRepository]'s incoming/outgoing vocabulary: for a
/// given message, "visible outgoing" is which child is currently displayed
/// below it in a column, "visible incoming" is which parent its context
/// currently derives from above it. Both directions of the same underlying
/// (parentId, childId) pointer pair, read from opposite ends.
abstract class ColumnRepository {
  Future<ColumnMeta> createColumn({String? anchorMessageId, double? width});

  Future<void> deleteColumn(String id);

  /// All open columns, for restoring layout on launch.
  Future<List<ColumnMeta>> getColumns();

  Future<void> updateColumnWidth(String id, double? width);

  Future<void> updateColumnAnchor(String id, String anchorMessageId);

  /// Fire-and-forget target for debounced scroll persistence — callers
  /// decide the debounce policy, this just does the (atomic, single-row)
  /// write.
  Future<void> updateColumnScrollOffset(String id, double? scrollOffset);

  /// Atomic (parent, child) pointer-pair upsert for [columnId] — this pair
  /// is never updated independently, matching stitch-frontend's
  /// SET_BRANCH_LINK semantics. Used by the outgoing direction (parent fixed,
  /// child changes); see [setVisibleIncoming] for the incoming direction.
  Future<void> setBranchPointer(String columnId, String parentId, String childId);

  /// The currently-displayed outgoing (child) message below [messageId] in
  /// [columnId], if any.
  Future<String?> getVisibleOutgoing(String columnId, String messageId);

  /// The currently-displayed incoming (parent) message above [messageId] in
  /// [columnId], if any.
  Future<String?> getVisibleIncoming(String columnId, String messageId);

  /// Switches [childId]'s visible incoming (parent) pointer to
  /// [newParentId] — the child stays fixed, the parent changes. Unlike
  /// [setBranchPointer] (which upserts on the (columnId, parentId) primary
  /// key), this must delete any existing row for (columnId, childId) first:
  /// the unique key on (columnId, childId) means a child can be the visible
  /// child of only one parent per column, so switching its incoming pointer
  /// can collide with a stale row under the old parent.
  Future<void> setVisibleIncoming(String columnId, String childId, String newParentId);
}
