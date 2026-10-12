/// Cached Stitch cloud identity for badges and author labels.
class ParticipantProfile {
  final String uid;
  final String? userTag;
  final String? displayName;
  final bool isBot;

  const ParticipantProfile({
    required this.uid,
    this.userTag,
    this.displayName,
    this.isBot = false,
  });

  String get label =>
      displayName?.trim().isNotEmpty == true
          ? displayName!.trim()
          : (userTag != null ? '@$userTag' : uid);

  factory ParticipantProfile.fromJson(Map<String, dynamic> json) {
    final author = json['author'];
    if (author is Map<String, dynamic>) {
      return ParticipantProfile.fromJson(author);
    }
    return ParticipantProfile(
      uid: (json['uid'] ?? json['id'] ?? '') as String,
      userTag: json['user_tag'] as String?,
      displayName: json['display_name'] as String?,
      isBot: json['is_bot'] as bool? ?? false,
    );
  }
}
