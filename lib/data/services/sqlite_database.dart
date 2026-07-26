import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Opens (and migrates) the local conversation-tree database.
///
/// Local-first per docs/flutter-best-practices.md: this is the store the
/// app reads/writes against by default, with no dependency on the Python
/// server or network being up.
class SqliteDatabase {
  static Database? _instance;

  static Future<Database> open() async {
    if (_instance != null) return _instance!;

    final supportDir = await getApplicationSupportDirectory();
    final dbPath = p.join(supportDir.path, 'stitch.db');
    await Directory(supportDir.path).create(recursive: true);

    final db = sqlite3.open(dbPath);
    _migrate(db);
    _instance = db;
    return db;
  }

  static void _migrate(Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        parent_id TEXT,
        conversation_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        bot_id TEXT,
        git_commit TEXT,
        created_at TEXT NOT NULL,
        selected_child_id TEXT
      )
    ''');
    db.execute('CREATE INDEX IF NOT EXISTS idx_messages_parent_id ON messages(parent_id)');
    db.execute('CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id)');
  }
}
