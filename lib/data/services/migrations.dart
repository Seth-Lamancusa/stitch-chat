import 'package:drift/drift.dart';

import 'app_database.dart';

/// One-off schema migrations, keyed by the schema version they upgrade
/// *into*. Bump [AppDatabase.schemaVersion] and add an entry here rather
/// than hand-rolling `onUpgrade` logic inline — keeps the growing list of
/// ad-hoc migrations in one place instead of piling up in the database
/// class itself.
typedef Migration = Future<void> Function(Migrator m, AppDatabase db);

final Map<int, Migration> migrations = {
  2: (m, db) async {
    // anchorMessageId became nullable (a freshly-added column has no
    // anchor until its first message is sent into it). Columns/
    // ColumnBranchPointers are layout-only, so it's safe to drop and
    // recreate rather than hand-write an ALTER.
    await m.deleteTable(db.columnBranchPointers.actualTableName);
    await m.deleteTable(db.columns.actualTableName);
    await m.createTable(db.columns);
    await m.createTable(db.columnBranchPointers);
  },
};

Future<void> runMigrations(Migrator m, AppDatabase db, int from, int to) async {
  for (var version = from + 1; version <= to; version++) {
    final migration = migrations[version];
    if (migration != null) await migration(m, db);
  }
}
