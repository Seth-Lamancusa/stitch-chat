import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_chat/data/models/message.dart';
import 'package:stitch_chat/data/repositories/fake_auth_repository.dart';
import 'package:stitch_chat/data/services/author_id_promotion.dart';
import 'package:stitch_chat/data/services/local_identity_service.dart';

import '../../domain/branch_path_service_test.dart' show FakeMessageRepository;

void main() {
  group('AuthorIdPromotion', () {
    test('rewrites local-stamped messages after cloud login', () async {
      final identity = LocalIdentityService();
      final auth = FakeAuthRepository();
      identity.bindAuthRepository(auth);

      final dir = await Directory.systemTemp.createTemp('stitch_promote_');
      addTearDown(() => dir.delete(recursive: true));
      await identity.initialize(supportDirectory: dir);

      final local = identity.localUserId;
      final messages = FakeMessageRepository();
      await messages.saveMessage(Message(
        id: 'm1',
        role: MessageRole.user,
        authorId: local,
        content: 'hello',
      ));
      await messages.saveMessage(Message(
        id: 'm2',
        role: MessageRole.localBot,
        authorId: 'cursor',
        content: 'hi',
      ));

      expect(await AuthorIdPromotion.promoteLocalToCloud(
        identity: identity,
        messages: messages,
      ), 0);

      await auth.login(identifier: 'alice', password: 'x');

      final n = await AuthorIdPromotion.promoteLocalToCloud(
        identity: identity,
        messages: messages,
      );
      expect(n, 1);
      expect((await messages.getMessage('m1'))!.authorId, 'actor-1');
      expect((await messages.getMessage('m2'))!.authorId, 'cursor');

      // Idempotent — no leftover local stamps.
      expect(await AuthorIdPromotion.promoteLocalToCloud(
        identity: identity,
        messages: messages,
      ), 0);
    });
  });
}
