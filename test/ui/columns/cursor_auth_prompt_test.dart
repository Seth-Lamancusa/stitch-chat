import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_chat/data/repositories/auth_repository.dart';
import 'package:stitch_chat/data/services/bot_bridge_service.dart';
import 'package:stitch_chat/data/services/local_identity_service.dart';
import 'package:stitch_chat/data/services/stitch_ws_client.dart';
import 'package:stitch_chat/domain/bot_registry.dart';
import 'package:stitch_chat/domain/branch_path_service.dart';
import 'package:stitch_chat/domain/message_store.dart';
import 'package:stitch_chat/ui/columns/columns_viewmodel.dart';

import '../../domain/branch_path_service_test.dart' show FakeColumnRepository, FakeMessageRepository;

class _FakeIdentityService implements LocalIdentityService {
  @override
  String get currentUserId => 'me';

  @override
  String get localUserId => 'me';

  @override
  bool get authenticatedOnline => false;

  @override
  void bindAuthRepository(AuthRepository auth) {}

  @override
  Future<void> initialize({Directory? supportDirectory}) async {}

  @override
  void dispose() {}
}

void main() {
  test('held cursor invoke replays after sign-in', () async {
    final messages = FakeMessageRepository();
    final columns = FakeColumnRepository();
    final store = MessageStore(messages);
    final branchPath = BranchPathService(messages, columns, store);
    final bridge = BotBridgeService(StitchWsClient(Uri.parse('ws://127.0.0.1:9')));
    addTearDown(bridge.close);
    bridge.debugConnect(
      registry: BotRegistry([
        const BotSpec(id: 'cursor', aliases: {'cursor'}, requiresAuth: true),
      ]),
    );
    bridge.debugEmitEnvelope({
      'type': 'auth_state',
      'bot_id': 'cursor',
      'state': 'unauthenticated',
    });

    var signedIn = false;
    bridge.debugOnSend = (envelope) {
      if (envelope['type'] != 'user_message') return;
      final trigger = envelope['message_id'] as String;
      if (!signedIn) {
        bridge.debugEmitEnvelope({
          'type': 'invoke_skipped',
          'parent_message_id': trigger,
          'bot_id': 'cursor',
          'reason': 'requires_auth',
        });
      } else {
        bridge.debugEmitEnvelope({
          'type': 'message_end',
          'message_id': 'srv-replay',
          'parent_message_id': trigger,
          'invoke_root_id': trigger,
          'bot_id': 'cursor',
          'role': 'localBot',
          'content': 'after login',
          'is_final': true,
        });
      }
    };

    final vm = ColumnsViewModel(
      messages,
      columns,
      branchPath,
      store,
      _FakeIdentityService(),
      botBridge: bridge,
    );
    addTearDown(vm.dispose);

    await columns.createColumn();
    await vm.initialize();
    await vm.onComposerDraftChanged('col-0', '@cursor hello');
    expect(vm.columns.first.authPrompts.single.botId, 'cursor');
    expect(vm.columns.first.authPrompts.single.state, 'unauthenticated');

    vm.retainAuthPromptsAcrossSend('col-0');
    await vm.onComposerDraftChanged('col-0', '');
    expect(vm.columns.first.authPrompts.single.botId, 'cursor');

    await vm.sendMessage('col-0', '@cursor hello');
    expect(vm.columns.first.authPrompts, isNotEmpty);

    signedIn = true;
    bridge.debugEmitEnvelope({
      'type': 'auth_state',
      'bot_id': 'cursor',
      'state': 'authenticated',
    });
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect((await messages.getMessage('srv-replay'))?.content, 'after login');
    expect(vm.columns.first.authPrompts, isEmpty);
  });
}
