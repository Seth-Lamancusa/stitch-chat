import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_chat/data/models/message.dart';
import 'package:stitch_chat/data/services/bot_bridge_service.dart';
import 'package:stitch_chat/data/services/stitch_ws_client.dart';
import 'package:stitch_chat/data/services/typing_cue_store.dart';

void main() {
  group('messageRoleFromWire', () {
    test('maps known roles', () {
      expect(messageRoleFromWire('thinking'), MessageRole.thinking);
      expect(messageRoleFromWire('functionCall'), MessageRole.functionCall);
      expect(messageRoleFromWire('functionResult'), MessageRole.functionResult);
      expect(messageRoleFromWire('localBot'), MessageRole.localBot);
      expect(messageRoleFromWire(null), MessageRole.localBot);
    });
  });

  group('BotBridgeService multi-part', () {
    late BotBridgeService bridge;

    setUp(() {
      bridge = BotBridgeService(StitchWsClient(Uri.parse('ws://127.0.0.1:9')));
    });

    tearDown(() async {
      // Avoid closing the unused WS controller if already closed.
    });

    test('non-final parts call onPart; is_final completes via invoke_root_id', () async {
      final parts = <BotBridgePart>[];
      final replyFuture = bridge.invokeDriven(
        botId: 'cursor',
        triggerMessageId: 'trig-1',
        onPart: parts.add,
        drive: (emit) async {
          emit({
            'type': 'message_end',
            'message_id': 'srv-think',
            'parent_message_id': 'trig-1',
            'invoke_root_id': 'trig-1',
            'bot_id': 'cursor',
            'role': 'thinking',
            'content': 'hmm',
            'is_final': false,
            'hidden': true,
          });
          emit({
            'type': 'message_end',
            'message_id': 'srv-a1',
            'parent_message_id': 'trig-1',
            'invoke_root_id': 'trig-1',
            'bot_id': 'cursor',
            'role': 'localBot',
            'content': 'hello',
            'is_final': false,
          });
          // Chained parent is prior part — correlation uses invoke_root_id.
          emit({
            'type': 'message_end',
            'message_id': 'srv-a2',
            'parent_message_id': 'srv-a1',
            'invoke_root_id': 'trig-1',
            'bot_id': 'cursor',
            'role': 'localBot',
            'content': 'world',
            'is_final': true,
            'usage': {'total_tokens': 3},
          });
        },
      );

      final reply = await replyFuture;
      expect(parts.map((p) => p.messageId).toList(), ['srv-think', 'srv-a1', 'srv-a2']);
      expect(parts[0].role, MessageRole.thinking);
      expect(parts[0].isFinal, isFalse);
      expect(parts[0].hidden, isTrue);
      expect(parts[1].hidden, isFalse);
      expect(parts[2].parentMessageId, 'srv-a1');
      expect(parts[2].isFinal, isTrue);
      expect(reply.messageId, 'srv-a2');
      expect(reply.usage?['total_tokens'], 3);
    });

    test('legacy message_end without is_final completes', () async {
      final parts = <BotBridgePart>[];
      final reply = await bridge.invokeDriven(
        botId: 'chatgpt',
        triggerMessageId: 'trig-2',
        onPart: parts.add,
        drive: (emit) async {
          emit({
            'type': 'message_end',
            'message_id': 'srv-one',
            'parent_message_id': 'trig-2',
            'bot_id': 'chatgpt',
            'role': 'localBot',
            'content': 'hi',
          });
        },
      );
      expect(parts, hasLength(1));
      expect(parts.single.isFinal, isTrue);
      expect(reply.content, 'hi');
    });

    test('cue envelopes stream without a pending invoke', () async {
      final events = <TypingCueEvent>[];
      final sub = bridge.cues.listen(events.add);
      addTearDown(sub.cancel);

      bridge.debugEmitEnvelope({
        'type': 'cue',
        'author_id': 'cursor',
        'target_message_id': 'trig-9',
        'typing': true,
      });
      bridge.debugEmitEnvelope({
        'type': 'cue',
        'author_id': 'cursor',
        'target_message_id': 'trig-9',
        'typing': false,
      });

      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(2));
      expect(events[0].typing, isTrue);
      expect(events[0].authorId, 'cursor');
      expect(events[0].targetMessageId, 'trig-9');
      expect(events[1].typing, isFalse);
    });
  });
}
