import 'package:flutter/foundation.dart';

/// Cloud-session status. Orthogonal to [LocalIdentityService]'s offline uid.
enum AuthStatus {
  bootstrapping,
  anonymous,
  authenticated,
}

/// Principal summary from `GET /v1/auth/session` actor/subject objects.
@immutable
class AuthPrincipal {
  const AuthPrincipal({
    required this.id,
    this.displayName,
    this.userTag,
  });

  final String id;
  final String? displayName;
  final String? userTag;

  factory AuthPrincipal.fromJson(Map<String, dynamic>? json, {required String fallbackId}) {
    if (json == null) {
      return AuthPrincipal(id: fallbackId);
    }
    final id = (json['id'] ?? json['uid'] ?? fallbackId).toString();
    return AuthPrincipal(
      id: id,
      displayName: json['display_name'] as String? ?? json['displayName'] as String?,
      userTag: json['user_tag'] as String? ?? json['userTag'] as String?,
    );
  }
}

/// Subject profile hydrate from `GET /v1/users/me` (UI convenience, not authZ).
@immutable
class AuthProfile {
  const AuthProfile({
    required this.uid,
    this.displayName,
    this.userTag,
    this.email,
  });

  final String uid;
  final String? displayName;
  final String? userTag;
  final String? email;

  factory AuthProfile.fromJson(Map<String, dynamic> json) {
    return AuthProfile(
      uid: (json['uid'] ?? json['_key'] ?? '').toString(),
      displayName: json['display_name'] as String?,
      userTag: json['user_tag'] as String?,
      email: _primaryEmail(json),
    );
  }

  static String? _primaryEmail(Map<String, dynamic> json) {
    final contacts = json['contacts'];
    if (contacts is! List) return null;
    for (final c in contacts) {
      if (c is Map && c['type'] == 'email' && c['value'] is String) {
        final v = (c['value'] as String).trim();
        if (v.isNotEmpty) return v;
      }
    }
    return null;
  }
}

/// Immutable cloud auth snapshot. Replace on change; never mutate in place.
@immutable
class AuthState {
  const AuthState({
    required this.status,
    this.sessionId,
    this.expiresAt,
    this.actor,
    this.subject,
    this.permissions = const [],
    this.delegated = false,
    this.profile,
  });

  final AuthStatus status;
  final String? sessionId;
  final DateTime? expiresAt;
  final AuthPrincipal? actor;
  final AuthPrincipal? subject;
  final List<String> permissions;
  final bool delegated;
  final AuthProfile? profile;

  static const bootstrapping = AuthState(status: AuthStatus.bootstrapping);
  static const anonymous = AuthState(status: AuthStatus.anonymous);

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get authReady => status != AuthStatus.bootstrapping;

  /// Cloud subject uid when authenticated; null when anonymous/bootstrapping.
  String? get cloudUserId => subject?.id ?? profile?.uid;

  AuthState copyWith({
    AuthStatus? status,
    String? sessionId,
    DateTime? expiresAt,
    AuthPrincipal? actor,
    AuthPrincipal? subject,
    List<String>? permissions,
    bool? delegated,
    AuthProfile? profile,
    bool clearSession = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      sessionId: clearSession ? null : (sessionId ?? this.sessionId),
      expiresAt: clearSession ? null : (expiresAt ?? this.expiresAt),
      actor: clearSession ? null : (actor ?? this.actor),
      subject: clearSession ? null : (subject ?? this.subject),
      permissions: clearSession ? const [] : (permissions ?? this.permissions),
      delegated: clearSession ? false : (delegated ?? this.delegated),
      profile: clearSession ? null : (profile ?? this.profile),
    );
  }
}
