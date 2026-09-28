import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stitch_chat/data/models/auth_state.dart';
import 'package:stitch_chat/data/repositories/fake_auth_repository.dart';
import 'package:stitch_chat/data/repositories/stitch_auth_repository.dart';
import 'package:stitch_chat/data/services/auth_api_client.dart';
import 'package:stitch_chat/data/services/session_vault.dart';
import 'package:stitch_chat/data/services/stitch_http_client.dart';

void main() {
  group('InMemorySessionVault', () {
    test('persists token and clears session without wiping device id', () async {
      final vault = InMemorySessionVault();
      final device = await vault.deviceId();
      await vault.writeSessionToken('st_session_a.secret');
      await vault.writeExpiresAt(DateTime.utc(2030, 1, 1));

      expect(await vault.readSessionToken(), 'st_session_a.secret');
      expect(await vault.readExpiresAt(), DateTime.utc(2030, 1, 1));

      await vault.clearSession();
      expect(await vault.readSessionToken(), isNull);
      expect(await vault.readExpiresAt(), isNull);
      expect(await vault.deviceId(), device);
    });
  });

  group('FakeAuthRepository', () {
    test('login and logout flip AuthState', () async {
      final repo = FakeAuthRepository();
      expect(repo.state.status, AuthStatus.anonymous);

      await repo.login(identifier: 'alice', password: 'x');
      expect(repo.state.isAuthenticated, isTrue);
      expect(repo.state.cloudUserId, 'actor-1');
      expect(repo.lastLoginIdentifier, 'alice');

      await repo.logout();
      expect(repo.state.status, AuthStatus.anonymous);
      expect(await repo.sessionToken(), isNull);
    });

    test('handleUnauthorized clears session', () async {
      final repo = FakeAuthRepository();
      await repo.login(identifier: 'alice', password: 'x');
      await repo.handleUnauthorized();
      expect(repo.unauthorizedCalls, 1);
      expect(repo.state.isAuthenticated, isFalse);
    });
  });

  group('StitchHttpClient', () {
    test('attaches Bearer and invokes unauthorized handler on 401', () async {
      final vault = InMemorySessionVault();
      await vault.writeSessionToken('st_session_live.secret');

      var unauthorized = 0;
      final mock = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer st_session_live.secret');
        return http.Response('{"detail":"invalid_session"}', 401);
      });

      final client = StitchHttpClient(
        baseUrl: 'http://example.test',
        vault: vault,
        httpClient: mock,
        onUnauthorized: () async {
          unauthorized++;
          await vault.clearSession();
        },
      );

      final response = await client.get('/v1/users/me');
      expect(response.statusCode, 401);
      expect(unauthorized, 1);
      expect(await vault.readSessionToken(), isNull);
    });
  });

  group('StitchAuthRepository', () {
    test('login hydrates session and profile', () async {
      final vault = InMemorySessionVault();
      final mock = MockClient((request) async {
        if (request.url.path == '/v1/auth/password/login') {
          return http.Response(
            jsonEncode({
              'access_token': 'st_session_new.secret',
              'token_type': 'Bearer',
              'expires_in': 3600,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/v1/auth/session') {
          expect(request.headers['Authorization'], 'Bearer st_session_new.secret');
          return http.Response(
            jsonEncode({
              'session_id': 'sess-1',
              'actor': {'id': 'u1', 'user_tag': 'alice', 'display_name': 'Alice'},
              'subject': {'id': 'u1', 'user_tag': 'alice', 'display_name': 'Alice'},
              'permissions': ['messages.read', 'messages.write'],
              'delegated': false,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/v1/users/me') {
          return http.Response(
            jsonEncode({
              'uid': 'u1',
              'user_tag': 'alice',
              'display_name': 'Alice',
              'contacts': [
                {'type': 'email', 'value': 'a@example.com', 'verified': true},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      });

      final api = AuthApiClient(baseUrl: 'http://example.test', httpClient: mock);
      final httpClient = StitchHttpClient(
        baseUrl: 'http://example.test',
        vault: vault,
        httpClient: mock,
      );
      final repo = StitchAuthRepository(vault: vault, api: api, httpClient: httpClient);

      await repo.login(identifier: 'alice', password: 'secret');

      expect(repo.state.isAuthenticated, isTrue);
      expect(repo.state.subject?.userTag, 'alice');
      expect(repo.state.profile?.email, 'a@example.com');
      expect(await vault.readSessionToken(), 'st_session_new.secret');
      expect(repo.state.permissions, contains('messages.write'));
    });

    test('init with invalid vault token becomes anonymous', () async {
      final vault = InMemorySessionVault();
      await vault.writeSessionToken('st_session_dead.secret');

      final mock = MockClient((request) async {
        expect(request.url.path, '/v1/auth/session');
        return http.Response('{"detail":"invalid_session"}', 401);
      });

      final api = AuthApiClient(baseUrl: 'http://example.test', httpClient: mock);
      final repo = StitchAuthRepository(vault: vault, api: api);

      await repo.init();

      expect(repo.state.status, AuthStatus.anonymous);
      expect(await vault.readSessionToken(), isNull);
    });
  });

  group('AuthState', () {
    test('cloudUserId prefers subject then profile', () {
      const withSubject = AuthState(
        status: AuthStatus.authenticated,
        subject: AuthPrincipal(id: 's1'),
        profile: AuthProfile(uid: 'p1'),
      );
      expect(withSubject.cloudUserId, 's1');

      const profileOnly = AuthState(
        status: AuthStatus.authenticated,
        profile: AuthProfile(uid: 'p1'),
      );
      expect(profileOnly.cloudUserId, 'p1');
    });
  });
}
