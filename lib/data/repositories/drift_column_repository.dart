import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../services/app_database.dart';
import 'column_repository.dart';

class DriftColumnRepository implements ColumnRepository {
  DriftColumnRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  @override
  Future<ColumnMeta> createColumn({String? anchorMessageId, double? width}) async {
    final id = _uuid.v4();
    await _db.into(_db.columns).insert(
          ColumnsCompanion.insert(
            id: id,
            anchorMessageId: Value(anchorMessageId),
            width: Value(width),
          ),
        );
    return ColumnMeta(id: id, anchorMessageId: anchorMessageId, width: width);
  }

  @override
  Future<void> deleteColumn(String id) {
    return (_db.delete(_db.columns)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<List<ColumnMeta>> getColumns() async {
    final rows = await _db.select(_db.columns).get();
    return rows.map(_toColumnMeta).toList();
  }

  @override
  Future<void> updateColumnWidth(String id, double? width) {
    return (_db.update(_db.columns)..where((t) => t.id.equals(id)))
        .write(ColumnsCompanion(width: Value(width)));
  }

  @override
  Future<void> updateColumnAnchor(String id, String anchorMessageId) {
    return (_db.update(_db.columns)..where((t) => t.id.equals(id)))
        .write(ColumnsCompanion(anchorMessageId: Value(anchorMessageId)));
  }

  @override
  Future<void> setBranchPointer(String columnId, String parentId, String childId) {
    // childId is unique per column, but the upsert below only resolves
    // conflicts on (columnId, parentId) — if childId is currently visible
    // under a different parent, that row must be cleared first or the
    // insert violates the (columnId, childId) unique constraint.
    return _db.transaction(() async {
      await (_db.delete(_db.columnBranchPointers)
            ..where((t) => t.columnId.equals(columnId) & t.childId.equals(childId)))
          .go();
      await _db.into(_db.columnBranchPointers).insertOnConflictUpdate(
            ColumnBranchPointersCompanion.insert(
              columnId: columnId,
              parentId: parentId,
              childId: childId,
            ),
          );
    });
  }

  @override
  Future<String?> getVisibleOutgoing(String columnId, String messageId) async {
    final row = await (_db.select(_db.columnBranchPointers)
          ..where((t) => t.columnId.equals(columnId) & t.parentId.equals(messageId)))
        .getSingleOrNull();
    return row?.childId;
  }

  @override
  Future<String?> getVisibleIncoming(String columnId, String messageId) async {
    final row = await (_db.select(_db.columnBranchPointers)
          ..where((t) => t.columnId.equals(columnId) & t.childId.equals(messageId)))
        .getSingleOrNull();
    return row?.parentId;
  }

  @override
  Future<void> setVisibleIncoming(String columnId, String childId, String newParentId) {
    return _db.transaction(() async {
      await (_db.delete(_db.columnBranchPointers)
            ..where((t) => t.columnId.equals(columnId) & t.childId.equals(childId)))
          .go();
      await _db.into(_db.columnBranchPointers).insert(
            ColumnBranchPointersCompanion.insert(
              columnId: columnId,
              parentId: newParentId,
              childId: childId,
            ),
          );
    });
  }

  ColumnMeta _toColumnMeta(ColumnRow row) {
    return ColumnMeta(id: row.id, anchorMessageId: row.anchorMessageId, width: row.width);
  }
}
