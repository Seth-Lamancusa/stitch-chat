import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stitch_chat/data/services/cloud_message_api.dart';
import 'package:stitch_chat/data/services/session_vault.dart';
import 'package:stitch_chat/data/services/stitch_http_client.dart';

void main() {
  group('CloudMessageApi.createMessage', () {
    test('includes context on POST body when non-empty', () async {
      Map<String, dynamic>? posted;
      final client = MockClient((request) async {
        posted = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode([
            {
              'success': true,
              'message': {'id': 'msgcloud1'},
            },
          ]),
          200,
        );
      });

      final vault = InMemorySessionVault()..sessionToken = 'test-token';
      final api = CloudMessageApi(
        StitchHttpClient(
          baseUrl: 'http://example.test',
          vault: vault,
          httpClient: client,
        ),
      );

      final result = await api.createMessage(
        content: 'hi @gpt',
        parentCloudMessageId: 'parent1',
        cloudRecipients: const [
          CloudRecipientInput(uid: 'bot-uid'),
        ],
        tags: const ['t'],
        context: const [
          {
            'id': 'anc1',
            'content': 'earlier',
            'public': false,
            'timestamp': '2026-01-01T00:00:00.000Z',
            'author': {
              'uid': 'u1',
              'user_tag': 'alice',
              'display_name': 'Alice',
              'is_bot': false,
            },
          },
        ],
      );

      expect(result.success, isTrue);
      expect(result.cloudMessageId, 'msgcloud1');
      final body = posted;
      expect(body, isNotNull);
      expect(body!['parent_id'], 'parent1');
      expect(body['context'], isA<List>());
      expect((body['context'] as List).single['id'], 'anc1');
      expect(body['tags'], ['t']);
    });

    test('omits context key when ancestor list is empty', () async {
      Map<String, dynamic>? posted;
      final client = MockClient((request) async {
        posted = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode([
            {
              'success': true,
              'message': {'id': 'msgcloud2'},
            },
          ]),
          200,
        );
      });

      final vault = InMemorySessionVault()..sessionToken = 'test-token';
      final api = CloudMessageApi(
        StitchHttpClient(
          baseUrl: 'http://example.test',
          vault: vault,
          httpClient: client,
        ),
      );

      await api.createMessage(
        content: 'root',
        cloudRecipients: const [
          CloudRecipientInput(uid: 'bot-uid'),
        ],
      );

      expect(posted!.containsKey('context'), isFalse);
    });
  });
}
