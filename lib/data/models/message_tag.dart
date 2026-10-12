/// Hashtag metadata on a message — mirrors stitch-backend tag objects.
///
/// Membership is list-authoritative: content may still contain `#foo` after a
/// tag is removed (or lack it after a modal add). Highlights derive from this
/// list, not from scanning content alone.
class MessageTag {
  const MessageTag({
    required this.name,
    this.createdAt,
    this.addedBy,
    this.addedByTag,
  });

  /// Normalized lowercase `^[a-z0-9-]+$`, max 32.
  final String name;

  final DateTime? createdAt;
  final String? addedBy;
  final String? addedByTag;

  MessageTag copyWith({
    DateTime? createdAt,
    String? addedBy,
    String? addedByTag,
  }) {
    return MessageTag(
      name: name,
      createdAt: createdAt ?? this.createdAt,
      addedBy: addedBy ?? this.addedBy,
      addedByTag: addedByTag ?? this.addedByTag,
    );
  }
}
