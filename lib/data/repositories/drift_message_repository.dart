import 'package:drift/drift.dart';

import '../models/message.dart';
import '../services/app_database.dart';
import 'message_repository.dart';

class DriftMessageRepository implements MessageRepository {
  DriftMessageRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> saveMessage(Message message) {
    return _db.into(_db.messages).insertOnConflictUpdate(
          MessagesCompanion.insert(
            id: message.id,
            role: message.role,
            authorId: Value(message.authorId),
            content: message.content,
            gitCommit: Value(message.gitCommit),
            createdAt: Value(message.createdAt),
          ),
        );
  }

  @override
  Future<Message?> getMessage(String id) async {
    final row = await (_db.select(_db.messages)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toMessage(row);
  }

  @override
  Future<OutgoingEdges> getOutgoing(String parentId) async {
    return OutgoingEdges(
      replyOutgoing: await _replyOutgoing(parentId),
      stitchedOutgoing: await _stitchedOutgoing(parentId),
    );
  }

  @override
  Future<IncomingEdges> getIncoming(String childId) async {
    final replyParent = await _replyIncoming(childId);
    return IncomingEdges(
      replyIncoming: [?replyParent],
      stitchedIncoming: await _stitchedIncoming(childId),
    );
  }

  @override
  Future<List<Message>> getAncestorPath(String messageId) async {
    final path = <Message>[];
    var current = await getMessage(messageId);
    while (current != null) {
      path.add(current);
      final parent = await _replyIncoming(current.id);
      current = parent;
    }
    return path.reversed.toList();
  }

  @override
  Stream<List<Message>> watchReplyOutgoing(String parentId) {
    final query = _db.select(_db.messages).join([
      innerJoin(_db.replyEdges, _db.replyEdges.childId.equalsExp(_db.messages.id)),
    ])
      ..where(_db.replyEdges.parentId.equals(parentId))
      ..orderBy([OrderingTerm.asc(_db.messages.createdAt)]);

    return query.watch().map(
          (rows) => rows.map((row) => _toMessage(row.readTable(_db.messages))).toList(),
        );
  }

  @override
  Future<void> addReplyEdge(String parentId, String childId) {
    return _db.into(_db.replyEdges).insertOnConflictUpdate(
          ReplyEdgesCompanion.insert(parentId: parentId, childId: childId),
        );
  }

  @override
  Future<void> addStitchEdge(String fromId, String toId, {String? createdByAuthorId}) {
    return _db.into(_db.stitchEdges).insertOnConflictUpdate(
          StitchEdgesCompanion.insert(
            fromId: fromId,
            toId: toId,
            createdByAuthorId: Value(createdByAuthorId),
            createdAt: DateTime.now().toUtc(),
          ),
        );
  }

  @override
  Future<void> addRecipientEdge(String messageId, String recipientId, RecipientKind kind) {
    return _db.into(_db.recipientEdges).insertOnConflictUpdate(
          RecipientEdgesCompanion.insert(
            messageId: messageId,
            recipientId: recipientId,
            kind: kind,
          ),
        );
  }

  @override
  Future<void> deleteMessage(String id) {
    return (_db.delete(_db.messages)..where((t) => t.id.equals(id))).go();
  }

  Future<List<Message>> _replyOutgoing(String parentId) async {
    final query = _db.select(_db.messages).join([
      innerJoin(_db.replyEdges, _db.replyEdges.childId.equalsExp(_db.messages.id)),
    ])
      ..where(_db.replyEdges.parentId.equals(parentId))
      ..orderBy([OrderingTerm.asc(_db.messages.createdAt)]);
    final rows = await query.get();
    return rows.map((row) => _toMessage(row.readTable(_db.messages))).toList();
  }

  Future<List<Message>> _stitchedOutgoing(String parentId) async {
    final query = _db.select(_db.messages).join([
      innerJoin(_db.stitchEdges, _db.stitchEdges.toId.equalsExp(_db.messages.id)),
    ])
      ..where(_db.stitchEdges.fromId.equals(parentId))
      ..orderBy([OrderingTerm.asc(_db.stitchEdges.createdAt)]);
    final rows = await query.get();
    return rows.map((row) => _toMessage(row.readTable(_db.messages))).toList();
  }

  Future<Message?> _replyIncoming(String childId) async {
    final query = _db.select(_db.messages).join([
      innerJoin(_db.replyEdges, _db.replyEdges.parentId.equalsExp(_db.messages.id)),
    ])
      ..where(_db.replyEdges.childId.equals(childId));
    final row = await query.getSingleOrNull();
    return row == null ? null : _toMessage(row.readTable(_db.messages));
  }

  Future<List<Message>> _stitchedIncoming(String childId) async {
    final query = _db.select(_db.messages).join([
      innerJoin(_db.stitchEdges, _db.stitchEdges.fromId.equalsExp(_db.messages.id)),
    ])
      ..where(_db.stitchEdges.toId.equals(childId))
      ..orderBy([OrderingTerm.asc(_db.stitchEdges.createdAt)]);
    final rows = await query.get();
    return rows.map((row) => _toMessage(row.readTable(_db.messages))).toList();
  }

  Message _toMessage(MessageRow row) {
    return Message(
      id: row.id,
      role: row.role,
      authorId: row.authorId,
      content: row.content,
      gitCommit: row.gitCommit,
      createdAt: row.createdAt,
    );
  }
}
