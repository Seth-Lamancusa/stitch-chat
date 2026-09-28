import '../../core/logging/stitch_log.dart';
import '../models/auth_state.dart';
import '../services/auth_api_client.dart';
import '../services/session_vault.dart';
import '../services/stitch_http_client.dart';
import 'auth_repository.dart';

/// Production auth repository: vault + AuthApiClient + optional HTTP 401 hook.
class StitchAuthRepository extends AuthRepository {
  StitchAuthRepository({
    required SessionVault vault,
    required AuthApiClient api,
    StitchHttpClient? httpClient,
  })  : _vault = vault,
        _api = api,
        _http = httpClient {
    _http?.setUnauthorizedHandler(handleUnauthorized);
  }

  final SessionVault _vault;
  final AuthApiClient _api;
  final StitchHttpClient? _http;

  AuthState _state = AuthState.bootstrapping;

  @override
  AuthState get state => _state;

  void _setState(AuthState next) {
    _state = next;
    notifyListeners();
  }

  Future<void> _persistToken(TokenResponse token) async {
    await _vault.writeSessionToken(token.accessToken);
    final expiresAt = token.expiresAt ??
        DateTime.now().toUtc().add(Duration(seconds: token.expiresIn));
    await _vault.writeExpiresAt(expiresAt);
    _http?.cacheToken(token.accessToken);
  }

  Future<AuthState> _hydrate(String bearer) async {
    final session = await _api.getSession(bearer);
    AuthProfile? profile;
    try {
      profile = await _api.getMe(bearer);
    } catch (e, st) {
      StitchLog.warning('auth profile hydrate failed', tag: 'auth', error: e, stackTrace: st);
    }
    final expiresAt = session.expiresAt ?? await _vault.readExpiresAt();
    return AuthState(
      status: AuthStatus.authenticated,
      sessionId: session.sessionId,
      expiresAt: expiresAt,
      actor: session.actor,
      subject: session.subject,
      permissions: session.permissions,
      delegated: session.delegated,
      profile: profile,
    );
  }

  @override
  Future<void> init() async {
    _setState(AuthState.bootstrapping);
    try {
      final token = await _vault.readSessionToken();
      if (token == null || token.isEmpty) {
        _http?.clearCachedToken();
        _setState(AuthState.anonymous);
        return;
      }
      _http?.cacheToken(token);
      final next = await _hydrate(token);
      _setState(next);
    } on AuthApiException catch (e) {
      StitchLog.info('auth init rejected (${e.statusCode})', tag: 'auth');
      await _vault.clearSession();
      _http?.clearCachedToken();
      _setState(AuthState.anonymous);
    } catch (e, st) {
      StitchLog.warning('auth init failed; treating as anonymous', tag: 'auth', error: e, stackTrace: st);
      await _vault.clearSession();
      _http?.clearCachedToken();
      _setState(AuthState.anonymous);
    }
  }

  @override
  Future<void> login({required String identifier, required String password}) async {
    final deviceId = await _vault.deviceId();
    final token = await _api.login(
      identifier: identifier.trim(),
      password: password,
      deviceId: deviceId,
    );
    await _persistToken(token);
    final next = await _hydrate(token.accessToken);
    _setState(next);
  }

  @override
  Future<void> logout() async {
    final token = await _vault.readSessionToken();
    if (token != null && token.isNotEmpty) {
      await _api.logout(token);
    }
    await _vault.clearSession();
    await _vault.clearManagerBackupToken();
    _http?.clearCachedToken();
    _setState(AuthState.anonymous);
  }

  @override
  Future<void> refresh() async {
    final token = await _vault.readSessionToken();
    if (token == null || token.isEmpty) {
      _setState(AuthState.anonymous);
      return;
    }
    final deviceId = await _vault.deviceId();
    final refreshed = await _api.refresh(bearer: token, deviceId: deviceId);
    await _persistToken(refreshed);
    final next = await _hydrate(refreshed.accessToken);
    _setState(next);
  }

  @override
  Future<String?> sessionToken() => _vault.readSessionToken();

  @override
  Future<void> handleUnauthorized() async {
    if (_state.status == AuthStatus.anonymous) return;
    StitchLog.info('auth unauthorized; clearing local session', tag: 'auth');
    await _vault.clearSession();
    _http?.clearCachedToken();
    _setState(AuthState.anonymous);
  }
}
