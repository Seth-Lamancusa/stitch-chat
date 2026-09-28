import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/auth_state.dart';

/// HTTP failure from auth endpoints with optional server `detail`.
class AuthApiException implements Exception {
  AuthApiException(this.statusCode, this.detail);
  final int statusCode;
  final String detail;

  @override
  String toString() => 'AuthApiException($statusCode: $detail)';
}

/// Parsed mint / refresh body (`access_token`, `expires_in`, …).
class TokenResponse {
  TokenResponse({
    required this.accessToken,
    required this.expiresIn,
    this.sessionId,
    this.expiresAt,
  });

  final String accessToken;
  final int expiresIn;
  final String? sessionId;
  final DateTime? expiresAt;

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 60 * 60 * 24 * 30;
    DateTime? expiresAt;
    final raw = json['expires_at'];
    if (raw is String) expiresAt = DateTime.tryParse(raw);
    return TokenResponse(
      accessToken: json['access_token'] as String,
      expiresIn: expiresIn,
      sessionId: json['session_id'] as String?,
      expiresAt: expiresAt,
    );
  }
}

/// Session DTO from `GET /v1/auth/session`.
class SessionDto {
  SessionDto({
    required this.sessionId,
    required this.actor,
    required this.subject,
    required this.permissions,
    required this.delegated,
    this.expiresAt,
  });

  final String sessionId;
  final AuthPrincipal actor;
  final AuthPrincipal subject;
  final List<String> permissions;
  final bool delegated;
  final DateTime? expiresAt;

  factory SessionDto.fromJson(Map<String, dynamic> json) {
    final sessionId = (json['session_id'] ?? '').toString();
    final actorMap = json['actor'] as Map<String, dynamic>?;
    final subjectMap = json['subject'] as Map<String, dynamic>?;
    final actor = AuthPrincipal.fromJson(actorMap, fallbackId: '');
    final subject = AuthPrincipal.fromJson(
      subjectMap,
      fallbackId: actor.id,
    );
    final permsRaw = json['permissions'];
    final permissions = permsRaw is List
        ? permsRaw.map((e) => e.toString()).toList(growable: false)
        : const <String>[];
    final expiresAt = json['expires_at'] is String
        ? DateTime.tryParse(json['expires_at'] as String)
        : null;
    final delegated = json['delegated'] == true ||
        (actor.id.isNotEmpty && subject.id.isNotEmpty && actor.id != subject.id);
    return SessionDto(
      sessionId: sessionId,
      actor: actor,
      subject: subject,
      permissions: permissions,
      delegated: delegated,
      expiresAt: expiresAt,
    );
  }
}

/// Talks only to `/v1/auth/*` and `/v1/users/me`. Bearer is passed explicitly;
/// persistence stays in [SessionVault].
class AuthApiClient {
  AuthApiClient({
    required this.baseUrl,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> _jsonHeaders({String? bearer}) {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (bearer != null && bearer.isNotEmpty) {
      h['Authorization'] = 'Bearer $bearer';
    }
    return h;
  }

  Future<Map<String, dynamic>> _decodeMap(http.Response response) {
    if (response.body.isEmpty) return Future.value(<String, dynamic>{});
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return Future.value(decoded);
    if (decoded is Map) {
      return Future.value(decoded.map((k, v) => MapEntry(k.toString(), v)));
    }
    return Future.value(<String, dynamic>{});
  }

  String _detail(Map<String, dynamic> body, http.Response response) {
    final d = body['detail'];
    if (d is String && d.isNotEmpty) return d;
    if (response.body.isNotEmpty) return response.body;
    return 'HTTP ${response.statusCode}';
  }

  /// `POST /v1/auth/password/login` — use body `access_token` (ignore cookies).
  Future<TokenResponse> login({
    required String identifier,
    required String password,
    required String deviceId,
  }) async {
    final response = await _http.post(
      _uri('/v1/auth/password/login'),
      headers: _jsonHeaders(),
      body: jsonEncode({
        'identifier': identifier,
        'password': password,
        'device_id': deviceId,
      }),
    );
    final body = await _decodeMap(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthApiException(response.statusCode, _detail(body, response));
    }
    final token = body['access_token'];
    if (token is! String || token.isEmpty) {
      throw AuthApiException(response.statusCode, 'missing_access_token');
    }
    return TokenResponse.fromJson(body);
  }

  Future<SessionDto> getSession(String bearer) async {
    final response = await _http.get(
      _uri('/v1/auth/session'),
      headers: _jsonHeaders(bearer: bearer),
    );
    final body = await _decodeMap(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthApiException(response.statusCode, _detail(body, response));
    }
    return SessionDto.fromJson(body);
  }

  /// Extend session in place; returns the same opaque token string.
  Future<TokenResponse> refresh({
    required String bearer,
    required String deviceId,
  }) async {
    final response = await _http.post(
      _uri('/v1/auth/sessions/refresh'),
      headers: _jsonHeaders(bearer: bearer),
      body: jsonEncode({'device_id': deviceId}),
    );
    final body = await _decodeMap(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthApiException(response.statusCode, _detail(body, response));
    }
    return TokenResponse.fromJson({
      ...body,
      'access_token': body['access_token'] ?? bearer,
    });
  }

  Future<void> logout(String bearer) async {
    try {
      await _http.post(
        _uri('/v1/auth/logout'),
        headers: _jsonHeaders(bearer: bearer),
        body: '{}',
      );
    } catch (_) {
      // Idempotent; vault clear happens regardless.
    }
  }

  Future<AuthProfile> getMe(String bearer) async {
    final response = await _http.get(
      _uri('/v1/users/me'),
      headers: _jsonHeaders(bearer: bearer),
    );
    final body = await _decodeMap(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthApiException(response.statusCode, _detail(body, response));
    }
    return AuthProfile.fromJson(body);
  }

  void close() => _http.close();
}
