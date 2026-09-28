import '../models/auth_state.dart';
import 'auth_repository.dart';

/// Fake auth repository for unit / widget tests.
class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository({AuthState initial = AuthState.anonymous}) : _state = initial;

  AuthState _state;
  String? token;
  bool loginShouldFail = false;
  String? lastLoginIdentifier;
  int initCalls = 0;
  int unauthorizedCalls = 0;

  @override
  AuthState get state => _state;

  void setState(AuthState next) {
    _state = next;
    notifyListeners();
  }

  @override
  Future<void> init() async {
    initCalls++;
    if (token != null && token!.isNotEmpty) {
      _state = AuthState(
        status: AuthStatus.authenticated,
        sessionId: 'sess-test',
        actor: const AuthPrincipal(id: 'actor-1', userTag: 'alice'),
        subject: const AuthPrincipal(id: 'actor-1', userTag: 'alice'),
        permissions: const ['messages.read', 'messages.write'],
        profile: const AuthProfile(uid: 'actor-1', userTag: 'alice', displayName: 'Alice'),
      );
    } else {
      _state = AuthState.anonymous;
    }
    notifyListeners();
  }

  @override
  Future<void> login({required String identifier, required String password}) async {
    lastLoginIdentifier = identifier;
    if (loginShouldFail) {
      throw Exception('invalid_credentials');
    }
    token = 'st_session_test.secret';
    _state = AuthState(
      status: AuthStatus.authenticated,
      sessionId: 'sess-test',
      actor: AuthPrincipal(id: 'actor-1', userTag: identifier),
      subject: AuthPrincipal(id: 'actor-1', userTag: identifier),
      permissions: const ['messages.read', 'messages.write'],
      profile: AuthProfile(uid: 'actor-1', userTag: identifier, displayName: identifier),
    );
    notifyListeners();
  }

  @override
  Future<void> logout() async {
    token = null;
    _state = AuthState.anonymous;
    notifyListeners();
  }

  @override
  Future<void> refresh() async {
    if (token == null) {
      _state = AuthState.anonymous;
      notifyListeners();
      return;
    }
    notifyListeners();
  }

  @override
  Future<String?> sessionToken() async => token;

  @override
  Future<void> handleUnauthorized() async {
    unauthorizedCalls++;
    token = null;
    _state = AuthState.anonymous;
    notifyListeners();
  }
}
