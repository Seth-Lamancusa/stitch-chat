import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_desktop/data/models/message.dart';
import 'package:stitch_desktop/data/repositories/drift_message_repository.dart';
import 'package:stitch_desktop/data/services/app_database.dart';

void main() {
  late AppDatabase db;
  late DriftMessageRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftMessageRepository(db);
  });

  tearDown(() => db.close());

  Message msg(String id, {DateTime? createdAt}) => Message(
        id: id,
        role: MessageRole.user,
        content: 'content-$id',
        createdAt: createdAt,
      );

  test('saveMessage + getMessage round-trips all fields', () async {
    final created = DateTime.utc(2026, 1, 1);
    await repo.saveMessage(Message(
      id: 'm1',
      role: MessageRole.localBot,
      authorId: 'bot1',
      content: 'hi',
      gitCommit: 'abc123',
      createdAt: created,
    ));

    final loaded = await repo.getMessage('m1');

    expect(loaded, isNotNull);
    expect(loaded!.role, MessageRole.localBot);
    expect(loaded.authorId, 'bot1');
    expect(loaded.content, 'hi');
    expect(loaded.gitCommit, 'abc123');
    expect(loaded.createdAt, created);
  });

  test('getMessage returns null for an unknown id', () async {
    expect(await repo.getMessage('missing'), isNull);
  });

  test('getOutgoing returns reply children before stitch children, each ordered by createdAt', () async {
    await repo.saveMessage(msg('root', createdAt: DateTime.utc(2026, 1, 1)));
    await repo.saveMessage(msg('r2', createdAt: DateTime.utc(2026, 1, 3)));
    await repo.saveMessage(msg('r1', createdAt: DateTime.utc(2026, 1, 2)));
    await repo.saveMessage(msg('s1', createdAt: DateTime.utc(2026, 1, 4)));

    await repo.addReplyEdge('root', 'r2');
    await repo.addReplyEdge('root', 'r1');
    await repo.addStitchEdge('root', 's1');

    final outgoing = await repo.getOutgoing('root');

    expect(outgoing.replyOutgoing.map((m) => m.id).toList(), ['r1', 'r2']);
    expect(outgoing.stitchedOutgoing.map((m) => m.id).toList(), ['s1']);
    expect(outgoing.all.map((m) => m.id).toList(), ['r1', 'r2', 's1']);
  });

  test('getIncoming returns the reply parent before stitch parents', () async {
    await repo.saveMessage(msg('p1'));
    await repo.saveMessage(msg('sp1'));
    await repo.saveMessage(msg('c1'));

    await repo.addReplyEdge('p1', 'c1');
    await repo.addStitchEdge('sp1', 'c1');

    final incoming = await repo.getIncoming('c1');

    expect(incoming.replyIncoming.map((m) => m.id).toList(), ['p1']);
    expect(incoming.stitchedIncoming.map((m) => m.id).toList(), ['sp1']);
    expect(incoming.all.map((m) => m.id).toList(), ['p1', 'sp1']);
  });

  test('getAncestorPath walks reply parents up to the root, root first', () async {
    await repo.saveMessage(msg('root'));
    await repo.saveMessage(msg('mid'));
    await repo.saveMessage(msg('leaf'));
    await repo.addReplyEdge('root', 'mid');
    await repo.addReplyEdge('mid', 'leaf');

    final path = await repo.getAncestorPath('leaf');

    expect(path.map((m) => m.id).toList(), ['root', 'mid', 'leaf']);
  });

  test('getAncestorPath for a root message with no parent is just itself', () async {
    await repo.saveMessage(msg('root'));

    final path = await repo.getAncestorPath('root');

    expect(path.map((m) => m.id).toList(), ['root']);
  });

  test('a reply edge enforces a single parent per child', () async {
    await repo.saveMessage(msg('p1'));
    await repo.saveMessage(msg('p2'));
    await repo.saveMessage(msg('c1'));

    await repo.addReplyEdge('p1', 'c1');
    await repo.addReplyEdge('p2', 'c1');

    expect((await repo.getIncoming('c1')).replyIncoming, hasLength(1));
    expect((await repo.getIncoming('c1')).replyIncoming.single.id, 'p2');
  });

  test('deleteMessage cascades its reply edges', () async {
    await repo.saveMessage(msg('root'));
    await repo.saveMessage(msg('child'));
    await repo.addReplyEdge('root', 'child');

    await repo.deleteMessage('child');

    expect((await repo.getOutgoing('root')).all, isEmpty);
  });

  test('addRecipientEdge does not throw and is idempotent', () async {
    await repo.saveMessage(msg('m1'));

    await repo.addRecipientEdge('m1', 'local:opencode', RecipientKind.localBot);
    await repo.addRecipientEdge('m1', 'local:opencode', RecipientKind.localBot);

    final rows = await db.select(db.recipientEdges).get();
    expect(rows, hasLength(1));
    expect(rows.single.kind, RecipientKind.localBot);
  });

  test('watchReplyOutgoing emits an updated list when a reply edge is added', () async {
    await repo.saveMessage(msg('root'));
    await repo.saveMessage(msg('child'));

    final idStream = repo.watchReplyOutgoing('root').map((msgs) => msgs.map((m) => m.id).toList());
    final expectation = expectLater(idStream, emitsInOrder([<String>[], ['child']]));

    await repo.addReplyEdge('root', 'child');

    await expectation;
  });
}
