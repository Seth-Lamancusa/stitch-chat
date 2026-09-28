import 'package:flutter/foundation.dart';

import '../../core/notifications/notification_service.dart';
import '../../data/models/auth_state.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/auth_api_client.dart';

/// UI logic for cloud login / logout. Widgets stay dumb — they bind [state]
/// and call [login] / [logout] / [openLogin] commands.
///
/// Optional [onAuthenticated] runs after a successful login (and after
/// [init] when a vault session restores as authenticated) so callers can
/// promote local message authorship to the cloud subject without this
/// ViewModel depending on [MessageRepository].
class LoginViewModel extends ChangeNotifier {
  LoginViewModel({
    required AuthRepository authRepository,
    required NotificationService notifications,
    Future<void> Function()? onAuthenticated,
  })  : _auth = authRepository,
        _notifications = notifications,
        _onAuthenticated = onAuthenticated {
    _wasAuthenticated = _auth.state.isAuthenticated;
    _auth.addListener(_onAuthChanged);
  }

  final AuthRepository _auth;
  final NotificationService _notifications;
  final Future<void> Function()? _onAuthenticated;

  bool _busy = false;
  String? _formError;
  bool _loginDialogOpen = false;
  bool _wasAuthenticated = false;
  bool _expectingLogout = false;

  AuthState get state => _auth.state;
  bool get busy => _busy;
  String? get formError => _formError;
  bool get isAuthenticated => _auth.state.isAuthenticated;
  bool get authReady => _auth.state.authReady;

  void _onAuthChanged() {
    final nowAuth = _auth.state.isAuthenticated;
    if (_wasAuthenticated && !nowAuth && !_expectingLogout) {
      _notifications.showError('Cloud session expired — please sign in again');
    }
    _wasAuthenticated = nowAuth;
    _expectingLogout = false;
    notifyListeners();
  }

  Future<void> init() async {
    await _auth.init();
    if (_auth.state.isAuthenticated) {
      await _onAuthenticated?.call();
    }
  }

  Future<bool> login({required String identifier, required String password}) async {
    if (_busy) return false;
    _busy = true;
    _formError = null;
    notifyListeners();
    try {
      await _auth.login(identifier: identifier, password: password);
      _wasAuthenticated = true;
      await _onAuthenticated?.call();
      _notifications.showToast('Signed in');
      return true;
    } on AuthApiException catch (e) {
      _formError = _friendlyDetail(e);
      _notifications.showError(_formError!);
      notifyListeners();
      return false;
    } catch (e) {
      _formError = e.toString();
      _notifications.showError(_formError!);
      notifyListeners();
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    if (_busy) return;
    _busy = true;
    _expectingLogout = true;
    notifyListeners();
    try {
      await _auth.logout();
      _wasAuthenticated = false;
      _notifications.showToast('Signed out');
    } catch (e) {
      _expectingLogout = false;
      _notifications.showError('Sign out failed: $e');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void clearFormError() {
    if (_formError == null) return;
    _formError = null;
    notifyListeners();
  }

  void setLoginDialogOpen(bool open) {
    _loginDialogOpen = open;
    if (!open) _formError = null;
    notifyListeners();
  }

  bool get loginDialogOpen => _loginDialogOpen;

  static String _friendlyDetail(AuthApiException e) {
    switch (e.detail) {
      case 'invalid_credentials':
        return 'Invalid tag/email/phone or password';
      case 'multiple_accounts_for_email':
        return 'Multiple accounts for that email — sign in with user tag';
      case 'missing_access_token':
        return 'Login succeeded but no session token returned';
      default:
        if (e.statusCode == 401) return 'Invalid tag/email/phone or password';
        return e.detail;
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
