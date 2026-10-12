import '../data/models/message.dart';

/// Draft `#` / `@` list membership — ports stitch-frontend ReplyBox rules.
///
/// Content is never rewritten when lists change. Highlights and send payloads
/// derive from [DraftReplySettings.tags] / [DraftReplySettings.recipients].

final tagTokenPattern =
    RegExp(r'(^|[\s([{])#([A-Za-z0-9-]{1,32})(?![A-Za-z0-9-])');
final mentionTokenPattern = RegExp(
  r'(^|[\s([{])@([A-Za-z0-9-]{2,24})(?![A-Za-z0-9-])(?=[^\w@.]|$)',
);
final _boundaryPattern = RegExp(r'''[\s.,!?;:)\]}'"`]''');

const maxDraftTags = 20;

/// One draft addressee (local bot or cloud user).
class DraftRecipient {
  const DraftRecipient({
    required this.recipientId,
    required this.kind,
    this.userTag,
    this.isCloudBot = false,
    this.notify = true,
    this.isPublic = true,
  });

  final String recipientId;
  final RecipientKind kind;
  final String? userTag;
  final bool isCloudBot;
  final bool notify;
  final bool isPublic;

  String? get normalizedTag {
    final tag = userTag?.trim().toLowerCase();
    if (tag == null || tag.isEmpty) return null;
    return tag;
  }
}

class DraftReplySettings {
  DraftReplySettings({
    List<String>? tags,
    List<DraftRecipient>? recipients,
    Set<String>? inlineTrackedTags,
    Set<String>? suppressedTags,
    Set<String>? inlineTrackedRecipientTags,
    this.replyParentMessageId,
    this.replyParentStagedRecipientId,
    this.replyParentRecipientSuppressed = false,
  })  : tags = List<String>.from(tags ?? const []),
        recipients = List<DraftRecipient>.from(recipients ?? const []),
        inlineTrackedTags = {...?inlineTrackedTags},
        suppressedTags = {...?suppressedTags},
        inlineTrackedRecipientTags = {...?inlineTrackedRecipientTags};

  List<String> tags;
  List<DraftRecipient> recipients;
  Set<String> inlineTrackedTags;
  Set<String> suppressedTags;

  /// Lowercase `@` tags added via autocomplete (or local-bot auto-stage) that
  /// should drop from [recipients] when the token disappears from content.
  Set<String> inlineTrackedRecipientTags;

  /// Effective reply parent whose author was auto-staged onto [recipients]
  /// (explicit [replyingToMessageId] or column tip). Null when no parent.
  String? replyParentMessageId;

  /// Author id currently present on [recipients] because of [replyParentMessageId].
  String? replyParentStagedRecipientId;

  /// User removed the auto-staged reply-parent author; do not re-add until
  /// [replyParentMessageId] changes.
  bool replyParentRecipientSuppressed;

  Set<String> get tagSet => tags.map((t) => t.toLowerCase()).toSet();

  Set<String> get mentionTagSet => {
        for (final r in recipients)
          if (r.normalizedTag != null) r.normalizedTag!,
      };

  void clear() {
    tags.clear();
    recipients.clear();
    inlineTrackedTags.clear();
    suppressedTags.clear();
    inlineTrackedRecipientTags.clear();
    replyParentMessageId = null;
    replyParentStagedRecipientId = null;
    replyParentRecipientSuppressed = false;
  }

  DraftReplySettings copy() => DraftReplySettings(
        tags: tags,
        recipients: recipients,
        inlineTrackedTags: inlineTrackedTags,
        suppressedTags: suppressedTags,
        inlineTrackedRecipientTags: inlineTrackedRecipientTags,
        replyParentMessageId: replyParentMessageId,
        replyParentStagedRecipientId: replyParentStagedRecipientId,
        replyParentRecipientSuppressed: replyParentRecipientSuppressed,
      );
}

String? normalizeTagName(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim().toLowerCase();
  if (trimmed.isEmpty || trimmed.length > 32) return null;
  if (!RegExp(r'^[a-z0-9-]+$').hasMatch(trimmed)) return null;
  return trimmed;
}

List<String> normalizeTagList(Iterable<String> tags) {
  final out = <String>[];
  final seen = <String>{};
  for (final tag in tags) {
    final n = normalizeTagName(tag);
    if (n == null || !seen.add(n)) continue;
    out.add(n);
    if (out.length >= maxDraftTags) break;
  }
  return out;
}

/// Committed `#tags` in [text]. Without [allowTerminalBoundary], requires a
/// trailing boundary char (space/punct) so mid-growth `#te` does not stage.
({List<String> ordered, Set<String> set}) collectCommittedTagTokens(
  String text, {
  bool allowTerminalBoundary = false,
}) {
  final ordered = <String>[];
  final set = <String>{};
  for (final match in tagTokenPattern.allMatches(text)) {
    final body = match.group(2)!;
    final normalized = body.toLowerCase();
    if (normalized.isEmpty) continue;
    final lead = match.group(1) ?? '';
    final tokenStart = match.start + lead.length;
    final tokenEnd = tokenStart + 1 + body.length;
    final nextChar = tokenEnd < text.length ? text[tokenEnd] : null;
    final hasBoundary = nextChar != null
        ? _boundaryPattern.hasMatch(nextChar)
        : allowTerminalBoundary;
    if (!hasBoundary || set.contains(normalized)) continue;
    set.add(normalized);
    ordered.add(normalized);
  }
  return (ordered: ordered, set: set);
}

Set<String> collectCommittedMentionTokens(String text) {
  final set = <String>{};
  for (final match in mentionTokenPattern.allMatches(text)) {
    final normalized = match.group(2)!.toLowerCase();
    if (normalized.isNotEmpty) set.add(normalized);
  }
  return set;
}

/// Auto-stage `#tags` from content and reconcile inline-tracked removals.
void autoStageTagsFromContent(
  DraftReplySettings draft,
  String text, {
  bool allowTerminalBoundary = false,
}) {
  final collected =
      collectCommittedTagTokens(text, allowTerminalBoundary: allowTerminalBoundary);
  final presentSet = collected.set;

  draft.suppressedTags.removeWhere((tag) => !presentSet.contains(tag));

  final withoutSuppressed = draft.tags
      .where((tag) => !draft.suppressedTags.contains(tag))
      .toList();
  if (withoutSuppressed.length != draft.tags.length) {
    draft.tags = normalizeTagList(withoutSuppressed);
    draft.inlineTrackedTags
        .removeWhere((tag) => draft.suppressedTags.contains(tag));
  }

  if (collected.ordered.isNotEmpty) {
    final staged = List<String>.from(draft.tags);
    var changed = false;
    for (final tag in collected.ordered) {
      if (draft.suppressedTags.contains(tag)) continue;
      if (staged.contains(tag)) continue;
      if (staged.length >= maxDraftTags) break;
      staged.add(tag);
      draft.inlineTrackedTags.add(tag);
      changed = true;
    }
    if (changed) {
      draft.tags = normalizeTagList(staged);
      draft.inlineTrackedTags
          .removeWhere((tag) => !draft.tags.contains(tag));
    }
  }

  _reconcileInlineTags(draft, presentSet);
}

void _reconcileInlineTags(DraftReplySettings draft, Set<String> activeTokenSet) {
  if (draft.inlineTrackedTags.isEmpty) return;
  final toRemove = draft.inlineTrackedTags
      .where((tag) => !activeTokenSet.contains(tag))
      .toSet();
  if (toRemove.isEmpty) return;
  draft.inlineTrackedTags.removeAll(toRemove);
  draft.tags = draft.tags.where((tag) => !toRemove.contains(tag)).toList();
}

/// Drop inline-tracked recipients whose `@tag` left the content.
void reconcileInlineRecipientsWithContent(
  DraftReplySettings draft,
  String text,
) {
  if (draft.inlineTrackedRecipientTags.isEmpty) return;
  final active = collectCommittedMentionTokens(text);
  final toRemove = draft.inlineTrackedRecipientTags
      .where((tag) => !active.contains(tag))
      .toSet();
  if (toRemove.isEmpty) return;
  draft.inlineTrackedRecipientTags.removeAll(toRemove);
  draft.recipients = draft.recipients.where((r) {
    // Reply-parent auto-stage is not content-tied; keep it even if the same
    // `@tag` was also inline-tracked and later deleted from the draft text.
    if (r.recipientId == draft.replyParentStagedRecipientId) return true;
    return r.normalizedTag == null || !toRemove.contains(r.normalizedTag);
  }).toList();
}

/// Stage (or clear) the reply parent's author on the draft recipient list.
///
/// Call whenever the effective reply parent changes — explicit reply target
/// or implied column tip. Skips the current user. Honors user removal via
/// [noteReplyParentRecipientRemoved] until [parentMessageId] changes.
void syncReplyParentAuthor(
  DraftReplySettings draft, {
  required String? parentMessageId,
  required String? authorId,
  required String currentUserId,
  required RecipientKind kind,
  String? userTag,
  bool isCloudBot = false,
}) {
  if (draft.replyParentMessageId != parentMessageId) {
    _clearReplyParentStagedRecipient(draft);
    draft.replyParentMessageId = parentMessageId;
    draft.replyParentRecipientSuppressed = false;
  }

  if (parentMessageId == null) {
    _clearReplyParentStagedRecipient(draft);
    return;
  }

  if (draft.replyParentRecipientSuppressed) return;

  final stageable = authorId != null && authorId != currentUserId;
  if (!stageable) {
    _clearReplyParentStagedRecipient(draft);
    return;
  }

  if (draft.replyParentStagedRecipientId != null &&
      draft.replyParentStagedRecipientId != authorId) {
    _clearReplyParentStagedRecipient(draft);
  }

  ensureDraftRecipient(
    draft,
    DraftRecipient(
      recipientId: authorId,
      kind: kind,
      userTag: userTag,
      isCloudBot: isCloudBot,
    ),
    trackInline: false,
  );
  draft.replyParentStagedRecipientId = authorId;
}

void _clearReplyParentStagedRecipient(DraftReplySettings draft) {
  final id = draft.replyParentStagedRecipientId;
  if (id == null) return;
  final index = draft.recipients.indexWhere((r) => r.recipientId == id);
  if (index >= 0) {
    final tag = draft.recipients[index].normalizedTag;
    final keptByInline =
        tag != null && draft.inlineTrackedRecipientTags.contains(tag);
    if (!keptByInline) {
      draft.recipients.removeAt(index);
    }
  }
  draft.replyParentStagedRecipientId = null;
}

/// Mark reply-parent auto-stage as user-removed. Returns true when [recipientId]
/// was the staged reply-parent author.
bool noteReplyParentRecipientRemoved(
  DraftReplySettings draft,
  String recipientId,
) {
  if (draft.replyParentStagedRecipientId != recipientId) return false;
  draft.replyParentStagedRecipientId = null;
  draft.replyParentRecipientSuppressed = true;
  return true;
}

/// Ensure [recipient] is in the draft list; track for content reconcile.
void ensureDraftRecipient(
  DraftReplySettings draft,
  DraftRecipient recipient, {
  bool trackInline = true,
}) {
  final tag = recipient.normalizedTag;
  final existingIndex = draft.recipients.indexWhere((r) {
    if (r.recipientId == recipient.recipientId) return true;
    final rt = r.normalizedTag;
    return tag != null && rt != null && rt == tag;
  });
  if (existingIndex >= 0) {
    draft.recipients[existingIndex] = recipient;
  } else {
    draft.recipients.add(recipient);
  }
  if (trackInline && tag != null) {
    draft.inlineTrackedRecipientTags.add(tag);
  }
}

/// Auto-stage known local-bot `@tags` when committed in content.
void autoStageLocalBotMentions(
  DraftReplySettings draft,
  String text,
  String? Function(String tag) botIdForTag,
) {
  for (final tag in collectCommittedMentionTokens(text)) {
    final botId = botIdForTag(tag);
    if (botId == null) continue;
    final already = draft.recipients.any(
      (r) =>
          r.kind == RecipientKind.localBot &&
          (r.recipientId == botId || r.normalizedTag == tag),
    );
    if (already) continue;
    ensureDraftRecipient(
      draft,
      DraftRecipient(
        recipientId: botId,
        kind: RecipientKind.localBot,
        userTag: tag,
      ),
    );
  }
  reconcileInlineRecipientsWithContent(draft, text);
}

/// Full per-keystroke update (tags + local bots + recipient reconcile).
void applyDraftContentChange(
  DraftReplySettings draft,
  String text, {
  required String? Function(String tag) botIdForTag,
  bool allowTerminalBoundary = false,
}) {
  autoStageTagsFromContent(
    draft,
    text,
    allowTerminalBoundary: allowTerminalBoundary,
  );
  autoStageLocalBotMentions(draft, text, botIdForTag);
  reconcileInlineRecipientsWithContent(draft, text);
}
