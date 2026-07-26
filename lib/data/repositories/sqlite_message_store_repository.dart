import 'package:sqlite3/sqlite3.dart';

import '../models/persisted_message.dart';
import '../services/sqlite_database.dart';
import 'message_store_repository.dart';

class SqliteMessageStoreRepository implements MessageStoreRepository {
  Database? _db;

  Future<Database> get _database async => _db ??= await SqliteDatabase.open();

  @override
  Future<void> saveMessage(PersistedMessage message) async {
    final db = await _database;
    db.execute(
      '''
      INSERT INTO messages (id, parent_id, conversation_id, role, content, bot_id, git_commit, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        content = excluded.content,
        bot_id = excluded.bot_id,
        git_commit = excluded.git_commit
      ''',
      [
        message.id,
        message.parentId,
        message.conversationId,
        message.role,
        message.content,
        message.botId,
        message.gitCommit,
        message.createdAt.toIso8601String(),
      ],
    );
  }

  @override
  Future<PersistedMessage?> getMessage(String id) async {
    final db = await _database;
    final rows = db.select('SELECT * FROM messages WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    return _toMessage(rows.first);
  }

  @override
  Future<List<PersistedMessage>> getChildren(String parentId) async {
    final db = await _database;
    final rows = db.select(
      'SELECT * FROM messages WHERE parent_id = ? ORDER BY created_at ASC',
      [parentId],
    );
    return rows.map(_toMessage).toList();
  }

  @override
  Future<List<PersistedMessage>> getAncestorPath(String messageId) async {
    final path = <PersistedMessage>[];
    var current = await getMessage(messageId);
    while (current != null) {
      path.add(current);
      current = current.parentId == null ? null : await getMessage(current.parentId!);
    }
    return path.reversed.toList();
  }

  @override
  Future<void> setSelectedChild(String parentId, String childId) async {
    final db = await _database;
    db.execute(
      'UPDATE messages SET selected_child_id = ? WHERE id = ?',
      [childId, parentId],
    );
  }

  @override
  Future<String?> getSelectedChild(String parentId) async {
    final db = await _database;
    final rows = db.select('SELECT selected_child_id FROM messages WHERE id = ?', [parentId]);
    if (rows.isEmpty) return null;
    return rows.first['selected_child_id'] as String?;
  }

  @override
  Future<void> deleteMessage(String id) async {
    final db = await _database;
    db.execute('DELETE FROM messages WHERE id = ?', [id]);
  }

  PersistedMessage _toMessage(Row row) {
    return PersistedMessage(
      id: row['id'] as String,
      parentId: row['parent_id'] as String?,
      conversationId: row['conversation_id'] as String,
      role: row['role'] as String,
      content: row['content'] as String,
      botId: row['bot_id'] as String?,
      gitCommit: row['git_commit'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
