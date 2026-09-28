import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'session_vault.dart';

typedef UnauthorizedHandler = Future<void> Function();

/// Thin authenticated HTTP client for `/v1/*` (and future cloud repos).
/// Attaches Bearer from [SessionVault]; on 401 invokes [onUnauthorized] once
/// (single-flight) so the auth repository can clear the vault.
class StitchHttpClient {
  StitchHttpClient({
    required this.baseUrl,
    required SessionVault vault,
    http.Client? httpClient,
    UnauthorizedHandler? onUnauthorized,
  })  : _vault = vault,
        _http = httpClient ?? http.Client(),
        _onUnauthorized = onUnauthorized;

  final String baseUrl;
  final SessionVault _vault;
  final http.Client _http;
  UnauthorizedHandler? _onUnauthorized;

  /// In-memory cache so we do not hit the vault on every request.
  String? _cachedToken;
  Future<void>? _unauthorizedInFlight;

  void setUnauthorizedHandler(UnauthorizedHandler handler) {
    _onUnauthorized = handler;
  }

  void cacheToken(String? token) {
    _cachedToken = token;
  }

  void clearCachedToken() {
    _cachedToken = null;
  }

  Future<String?> _bearer() async {
    if (_cachedToken != null && _cachedToken!.isNotEmpty) return _cachedToken;
    final fromVault = await _vault.readSessionToken();
    _cachedToken = fromVault;
    return fromVault;
  }

  Uri _uri(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Uri.parse(path);
    }
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalized');
  }

  Future<Map<String, String>> _headers({Map<String, String>? extra}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      ...?extra,
    };
    final token = await _bearer();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<void> _handleUnauthorized() async {
    final handler = _onUnauthorized;
    if (handler == null) return;
    if (_unauthorizedInFlight != null) {
      await _unauthorizedInFlight;
      return;
    }
    _unauthorizedInFlight = () async {
      try {
        await handler();
      } finally {
        _unauthorizedInFlight = null;
      }
    }();
    await _unauthorizedInFlight;
  }

  Future<http.Response> get(String path, {Map<String, String>? headers}) async {
    final response = await _http.get(
      _uri(path),
      headers: await _headers(extra: headers),
    );
    if (response.statusCode == 401) await _handleUnauthorized();
    return response;
  }

  Future<http.Response> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final response = await _http.post(
      _uri(path),
      headers: await _headers(extra: headers),
      body: body is String || body == null ? body : jsonEncode(body),
    );
    if (response.statusCode == 401) await _handleUnauthorized();
    return response;
  }

  Future<http.Response> delete(String path, {Map<String, String>? headers}) async {
    final response = await _http.delete(
      _uri(path),
      headers: await _headers(extra: headers),
    );
    if (response.statusCode == 401) await _handleUnauthorized();
    return response;
  }

  void close() => _http.close();
}
