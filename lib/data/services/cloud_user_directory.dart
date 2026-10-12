import 'dart:convert';

import '../../core/logging/stitch_log.dart';
import '../models/participant_profile.dart';
import 'stitch_http_client.dart';

/// Debounced cloud user search for @mention autocomplete (authenticated only).
class CloudUserDirectory {
  CloudUserDirectory(this._http);

  final StitchHttpClient _http;

  Future<List<ParticipantProfile>> search(String query, {int limit = 15}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final response = await _http.get(
      '/v1/users/search?query=${Uri.encodeQueryComponent(trimmed)}&limit=$limit',
    );
    if (response.statusCode != 200) {
      StitchLog.warning(
        'cloud user search failed status=${response.statusCode}',
        tag: 'cloud.users',
      );
      return const [];
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final users = body['users'];
    if (users is! List) return const [];

    return [
      for (final raw in users)
        if (raw is Map<String, dynamic>)
          ParticipantProfile(
            uid: (raw['uid'] ?? raw['id'] ?? raw['_key'] ?? '') as String,
            userTag: raw['user_tag'] as String?,
            displayName: raw['display_name'] as String?,
            isBot: raw['is_bot'] as bool? ?? false,
          ),
    ].where((p) => p.uid.isNotEmpty).toList(growable: false);
  }

  /// Exact tag match for send-time resolution of `@tag` tokens.
  Future<ParticipantProfile?> findByUserTag(String tag) async {
    final clean = tag.replaceFirst(RegExp(r'^@'), '').trim();
    if (clean.isEmpty) return null;
    final results = await search(clean, limit: 15);
    for (final user in results) {
      if (user.userTag?.toLowerCase() == clean.toLowerCase()) return user;
    }
    return null;
  }
}
