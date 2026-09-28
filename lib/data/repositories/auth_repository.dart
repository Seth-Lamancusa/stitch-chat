import 'package:flutter/foundation.dart';

import '../models/auth_state.dart';

/// Source of truth for cloud session state. Implementations notify listeners
/// when [state] changes.
abstract class AuthRepository extends ChangeNotifier {
  AuthState get state;

  /// Cold start: read vault, validate via `/auth/session`, hydrate profile.
  Future<void> init();

  Future<void> login({required String identifier, required String password});

  Future<void> logout();

  /// Optional extend-in-place of the current opaque session.
  Future<void> refresh();

  /// Active Bearer for callers that need it (e.g. WS). Prefer [StitchHttpClient].
  Future<String?> sessionToken();

  /// Clear local session without calling logout (used on 401).
  Future<void> handleUnauthorized();
}
