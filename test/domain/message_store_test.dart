import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_chat/data/models/message.dart';
import 'package:stitch_chat/domain/message_store.dart';

import 'branch_path_service_test.dart' show FakeMessageRepository;

class _CountingMessageRepository extends FakeMessageRepository {
  int getMessageCalls = 0;

  @override
  Future<Message?> getMessage(String id) {
    getMessageCalls++;
    return super.getMessage(id);
  }
}

void main() {
  late _CountingMessageRepository messages;
  late MessageStore store;

  setUp(() {
    messages = _CountingMessageRepository();
    store = MessageStore(messages);
  });

  Message msg(String id) => Message(id: id, role: MessageRole.user, content: id);

  test('peek is null before load', () {
    expect(store.peek('a'), isNull);
  });

  test('load fetches and caches; a second load does not re-fetch', () async {
    await messages.saveMessage(msg('a'));

    final first = await store.load('a');
    final second = await store.load('a');

    expect(first?.id, 'a');
    expect(second?.id, 'a');
    expect(messages.getMessageCalls, 1);
  });

  test('load populates peek', () async {
    await messages.saveMessage(msg('a'));

    await store.load('a');

    expect(store.peek('a')?.id, 'a');
  });

  test('load on a missing id returns null and does not cache', () async {
    final result = await store.load('missing');

    expect(result, isNull);
    expect(store.peek('missing'), isNull);
  });
}
