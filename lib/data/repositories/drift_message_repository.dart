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
    final reply = await _replyOutgoingSplit(parentId);
    return OutgoingEdges(
      replyOutgoing: reply.visible,
      hiddenReplyOutgoing: reply.hidden,
      stitchedOutgoing: await _stitchedOutgoing(parentId),
    );
  }

  @override
  Future<IncomingEdges> getIncoming(String childId) async {
    final replyParent = await _replyIncomingSplit(childId);
    return IncomingEdges(
      replyIncoming: [
        if (replyParent != null && !replyParent.hidden) replyParent.message,
      ],
      hiddenReplyIncoming: [
        if (replyParent != null && replyParent.hidden) replyParent.message,
      ],
      stitchedIncoming: await _stitchedIncoming(childId),
    );
  }

  @override
  Future<List<Message>> getAncestorPath(String messageId) async {
    final path = <Message>[];
    var current = await getMessage(messageId);
    while (current != null) {
      path.add(current);
      final parent = await _replyIncomingSplit(current.id);
      current = parent?.message;
    }
    return path.reversed.toList();
  }

  @override
  Future<List<Message>> getThreadRoots() async {
    final rows = await _threadRootsQuery().get();
    return rows.map((row) => _toMessage(row.readTable(_db.messages))).toList();
  }

  @override
  Stream<List<Message>> watchThreadRoots() {
    return _threadRootsQuery().watch().map(
          (rows) => rows.map((row) => _toMessage(row.readTable(_db.messages))).toList(),
        );
  }

  JoinedSelectStatement<HasResultSet, dynamic> _threadRootsQuery() {
    return _db.select(_db.messages).join([
      leftOuterJoin(
        _db.replyEdges,
        _db.replyEdges.childId.equalsExp(_db.messages.id),
      ),
    ])
      ..where(_db.replyEdges.childId.isNull())
      ..orderBy([
        OrderingTerm.desc(_db.messages.createdAt),
        OrderingTerm.asc(_db.messages.id),
      ]);
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
  Future<void> addReplyEdge(
    String parentId,
    String childId, {
    bool hidden = false,
  }) {
    return _db.into(_db.replyEdges).insertOnConflictUpdate(
          ReplyEdgesCompanion.insert(
            parentId: parentId,
            childId: childId,
            hidden: Value(hidden),
          ),
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
  Future<List<RecipientRef>> getRecipients(String messageId) async {
    final rows = await (_db.select(_db.recipientEdges)
          ..where((t) => t.messageId.equals(messageId)))
        .get();
    return rows.map((row) => RecipientRef(recipientId: row.recipientId, kind: row.kind)).toList();
  }

  @override
  Future<void> deleteMessage(String id) {
    return (_db.delete(_db.messages)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<int> rewriteAuthorId({
    required String fromAuthorId,
    required String toAuthorId,
  }) async {
    if (fromAuthorId.isEmpty || fromAuthorId == toAuthorId) return 0;

    return _db.transaction(() async {
      final messageCount = await (_db.update(_db.messages)
            ..where((t) => t.authorId.equals(fromAuthorId)))
          .write(MessagesCompanion(authorId: Value(toAuthorId)));

      await (_db.update(_db.stitchEdges)
            ..where((t) => t.createdByAuthorId.equals(fromAuthorId)))
          .write(StitchEdgesCompanion(createdByAuthorId: Value(toAuthorId)));

      // recipient_id is part of the primary key — raw SQL so we can rename
      // without a delete/reinsert dance. Conflicts with an existing
      // (message_id, toAuthorId) row are ignored (device is single-user).
      await _db.customStatement(
        'UPDATE OR IGNORE recipient_edges '
        'SET recipient_id = ? WHERE recipient_id = ?',
        [toAuthorId, fromAuthorId],
      );
      await (_db.delete(_db.recipientEdges)
            ..where((t) => t.recipientId.equals(fromAuthorId)))
          .go();

      return messageCount;
    });
  }

  Future<({List<Message> visible, List<Message> hidden})> _replyOutgoingSplit(
    String parentId,
  ) async {
    final query = _db.select(_db.messages).join([
      innerJoin(_db.replyEdges, _db.replyEdges.childId.equalsExp(_db.messages.id)),
    ])
      ..where(_db.replyEdges.parentId.equals(parentId))
      ..orderBy([OrderingTerm.asc(_db.messages.createdAt)]);
    final rows = await query.get();
    final visible = <Message>[];
    final hidden = <Message>[];
    for (final row in rows) {
      final message = _toMessage(row.readTable(_db.messages));
      final edge = row.readTable(_db.replyEdges);
      if (edge.hidden) {
        hidden.add(message);
      } else {
        visible.add(message);
      }
    }
    return (visible: visible, hidden: hidden);
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

  Future<({Message message, bool hidden})?> _replyIncomingSplit(String childId) async {
    final query = _db.select(_db.messages).join([
      innerJoin(_db.replyEdges, _db.replyEdges.parentId.equalsExp(_db.messages.id)),
    ])
      ..where(_db.replyEdges.childId.equals(childId));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return (
      message: _toMessage(row.readTable(_db.messages)),
      hidden: row.readTable(_db.replyEdges).hidden,
    );
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
