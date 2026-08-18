import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/message.dart';
import 'migrations.dart';

part 'app_database.g.dart';

/// A message node in the conversation tree. Topology is not stored here —
/// see [ReplyEdges]/[StitchEdges]. `isStreaming` from the domain [Message]
/// model is deliberately absent: it's live-chat-only UI state, never
/// persisted.
@DataClassName('MessageRow')
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get role => textEnum<MessageRole>()();
  TextColumn get authorId => text().nullable()();
  TextColumn get content => text()();
  TextColumn get gitCommit => text().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Structural, single-parent-per-child by construction. The primary key on
/// [childId] alone is the "unique index on childId" the data model doc
/// describes as an application-level constraint, not a schema shape:
/// multi-parent replies fold in later by widening this to a composite
/// `(parentId, childId)` key, with no other model/rendering changes.
class ReplyEdges extends Table {
  @ReferenceName('replyEdgesAsParent')
  TextColumn get parentId => text().references(Messages, #id, onDelete: KeyAction.cascade)();
  @ReferenceName('replyEdgesAsChild')
  TextColumn get childId => text().references(Messages, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {childId};
}

/// Semantic, many-to-many, may be cyclic — no write-time validation, matching
/// stitch-backend's `createLink`.
class StitchEdges extends Table {
  @ReferenceName('stitchEdgesAsFrom')
  TextColumn get fromId => text().references(Messages, #id, onDelete: KeyAction.cascade)();
  @ReferenceName('stitchEdgesAsTo')
  TextColumn get toId => text().references(Messages, #id, onDelete: KeyAction.cascade)();
  TextColumn get createdByAuthorId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {fromId, toId};
}

/// A message can address multiple recipients; `kind` only says which
/// dispatch path handles this recipient, not delivery outcome.
class RecipientEdges extends Table {
  TextColumn get messageId => text().references(Messages, #id, onDelete: KeyAction.cascade)();
  TextColumn get recipientId => text()();
  TextColumn get kind => textEnum<RecipientKind>()();

  @override
  Set<Column> get primaryKey => {messageId, recipientId};
}

/// A column in the multi-column layout. No `title` column yet — added by
/// the column-UI plan when it's actually needed.
@DataClassName('ColumnRow')
class Columns extends Table {
  TextColumn get id => text()();
  // Nullable: a freshly-added column with no messages yet has no anchor
  // until the first message is sent into it.
  TextColumn get anchorMessageId => text().references(Messages, #id).nullable()();
  RealColumn get width => real().nullable()(); // null = flexible

  @override
  Set<Column> get primaryKey => {id};
}

/// One row = one atomic (parent, child) branch-pointer pair for a column —
/// the concrete SQL realization of the data model doc's abstract
/// `visibleParent`/`visibleChild` maps. The primary key enforces "at most
/// one visible child per parent per column"; the unique key on
/// (columnId, childId) enforces "each column renders one linear path" (a
/// child can't be the visible-child of two different parents in the same
/// column) — both DB-level invariants, not just lookup indexes.
class ColumnBranchPointers extends Table {
  TextColumn get columnId => text().references(Columns, #id, onDelete: KeyAction.cascade)();
  @ReferenceName('branchPointersAsParent')
  TextColumn get parentId => text().references(Messages, #id, onDelete: KeyAction.cascade)();
  @ReferenceName('branchPointersAsChild')
  TextColumn get childId => text().references(Messages, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {columnId, parentId};

  @override
  List<Set<Column>> get uniqueKeys => [
        {columnId, childId},
      ];
}

@DriftDatabase(tables: [
  Messages,
  ReplyEdges,
  StitchEdges,
  RecipientEdges,
  Columns,
  ColumnBranchPointers,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For unit tests: pass e.g. `NativeDatabase.memory()`.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) => runMigrations(m, this, from, to),
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final supportDir = await getApplicationSupportDirectory();
      await Directory(supportDir.path).create(recursive: true);
      final dbFile = File(p.join(supportDir.path, 'stitch.db'));
      return NativeDatabase.createInBackground(dbFile);
    });
  }
}
