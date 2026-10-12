import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_chat/data/models/message.dart';
import 'package:stitch_chat/domain/draft_inline_tokens.dart';

void main() {
  group('collectCommittedTagTokens', () {
    test('requires trailing boundary while typing', () {
      final mid = collectCommittedTagTokens('hello #test');
      expect(mid.ordered, isEmpty);

      final done = collectCommittedTagTokens('hello #test ');
      expect(done.ordered, ['test']);
    });

    test('allowTerminalBoundary stages end-of-string tags', () {
      final terminal = collectCommittedTagTokens(
        'hello #test',
        allowTerminalBoundary: true,
      );
      expect(terminal.ordered, ['test']);
    });
  });

  group('autoStageTagsFromContent', () {
    test('stages on boundary and reconciles deletion of inline-tracked tags', () {
      final draft = DraftReplySettings();
      autoStageTagsFromContent(draft, 'see #alpha #beta ');
      expect(draft.tags, ['alpha', 'beta']);
      expect(draft.inlineTrackedTags, {'alpha', 'beta'});

      autoStageTagsFromContent(draft, 'see #alpha ');
      expect(draft.tags, ['alpha']);
      expect(draft.inlineTrackedTags, {'alpha'});
    });

    test('suppressed tags are not re-staged while still in content', () {
      final draft = DraftReplySettings(
        suppressedTags: {'alpha'},
      );
      autoStageTagsFromContent(draft, 'keep #alpha ');
      expect(draft.tags, isEmpty);
      expect(draft.suppressedTags, {'alpha'});
    });
  });

  group('mentions', () {
    test('autocomplete ensure + reconcile on delete', () {
      final draft = DraftReplySettings();
      ensureDraftRecipient(
        draft,
        const DraftRecipient(
          recipientId: 'uid-1',
          kind: RecipientKind.cloudUser,
          userTag: 'alice',
        ),
      );
      expect(draft.mentionTagSet, {'alice'});

      reconcileInlineRecipientsWithContent(draft, 'hi @alice ');
      expect(draft.recipients, hasLength(1));

      reconcileInlineRecipientsWithContent(draft, 'hi ');
      expect(draft.recipients, isEmpty);
    });

    test('clearing composer text drops inline-tracked cloud recipients', () {
      // Documents the send race: TextEditingController.clear() must not run
      // applyDraftContentChange('', …) before send snapshots draft.recipients.
      final draft = DraftReplySettings();
      ensureDraftRecipient(
        draft,
        const DraftRecipient(
          recipientId: 'uid-1',
          kind: RecipientKind.cloudUser,
          userTag: 'alice',
        ),
      );
      expect(draft.recipients, hasLength(1));

      applyDraftContentChange(
        draft,
        '',
        botIdForTag: (_) => null,
      );
      expect(draft.recipients, isEmpty);
      // Cloud mentions are not re-staged from content alone.
      applyDraftContentChange(
        draft,
        'hi @alice ',
        botIdForTag: (_) => null,
      );
      expect(draft.recipients, isEmpty);
    });

    test('auto-stages known local bots when committed', () {
      final draft = DraftReplySettings();
      applyDraftContentChange(
        draft,
        'ping @cursor ',
        botIdForTag: (tag) => tag == 'cursor' ? 'cursor' : null,
      );
      expect(draft.recipients, hasLength(1));
      expect(draft.recipients.single.recipientId, 'cursor');
      expect(draft.tags, isEmpty);
    });
  });

  group('syncReplyParentAuthor', () {
    test('stages parent author on the draft list', () {
      final draft = DraftReplySettings();
      syncReplyParentAuthor(
        draft,
        parentMessageId: 'msg-1',
        authorId: 'alice',
        currentUserId: 'me',
        kind: RecipientKind.cloudUser,
        userTag: 'alice',
      );
      expect(draft.recipients, hasLength(1));
      expect(draft.recipients.single.recipientId, 'alice');
      expect(draft.replyParentStagedRecipientId, 'alice');
      expect(draft.replyParentMessageId, 'msg-1');
    });

    test('skips current user and clears prior staged author', () {
      final draft = DraftReplySettings();
      syncReplyParentAuthor(
        draft,
        parentMessageId: 'msg-1',
        authorId: 'alice',
        currentUserId: 'me',
        kind: RecipientKind.cloudUser,
        userTag: 'alice',
      );
      syncReplyParentAuthor(
        draft,
        parentMessageId: 'msg-2',
        authorId: 'me',
        currentUserId: 'me',
        kind: RecipientKind.cloudUser,
      );
      expect(draft.recipients, isEmpty);
      expect(draft.replyParentStagedRecipientId, isNull);
      expect(draft.replyParentMessageId, 'msg-2');
    });

    test('replaces staged author when parent changes', () {
      final draft = DraftReplySettings();
      syncReplyParentAuthor(
        draft,
        parentMessageId: 'msg-1',
        authorId: 'alice',
        currentUserId: 'me',
        kind: RecipientKind.cloudUser,
        userTag: 'alice',
      );
      syncReplyParentAuthor(
        draft,
        parentMessageId: 'msg-2',
        authorId: 'bob',
        currentUserId: 'me',
        kind: RecipientKind.cloudUser,
        userTag: 'bob',
      );
      expect(draft.recipients.map((r) => r.recipientId), ['bob']);
      expect(draft.replyParentStagedRecipientId, 'bob');
    });

    test('honors user removal until parent message changes', () {
      final draft = DraftReplySettings();
      syncReplyParentAuthor(
        draft,
        parentMessageId: 'msg-1',
        authorId: 'alice',
        currentUserId: 'me',
        kind: RecipientKind.cloudUser,
        userTag: 'alice',
      );
      draft.recipients.clear();
      expect(noteReplyParentRecipientRemoved(draft, 'alice'), isTrue);

      syncReplyParentAuthor(
        draft,
        parentMessageId: 'msg-1',
        authorId: 'alice',
        currentUserId: 'me',
        kind: RecipientKind.cloudUser,
        userTag: 'alice',
      );
      expect(draft.recipients, isEmpty);

      syncReplyParentAuthor(
        draft,
        parentMessageId: 'msg-2',
        authorId: 'alice',
        currentUserId: 'me',
        kind: RecipientKind.cloudUser,
        userTag: 'alice',
      );
      expect(draft.recipients.single.recipientId, 'alice');
    });

    test('keeps reply-parent author when inline @tag is deleted', () {
      final draft = DraftReplySettings();
      syncReplyParentAuthor(
        draft,
        parentMessageId: 'msg-1',
        authorId: 'alice',
        currentUserId: 'me',
        kind: RecipientKind.cloudUser,
        userTag: 'alice',
      );
      ensureDraftRecipient(
        draft,
        const DraftRecipient(
          recipientId: 'alice',
          kind: RecipientKind.cloudUser,
          userTag: 'alice',
        ),
      );
      expect(draft.inlineTrackedRecipientTags, contains('alice'));

      reconcileInlineRecipientsWithContent(draft, 'hi ');
      expect(draft.recipients.single.recipientId, 'alice');
      expect(draft.replyParentStagedRecipientId, 'alice');
    });

    test('keeps inline-tracked author when parent tip moves away', () {
      final draft = DraftReplySettings();
      syncReplyParentAuthor(
        draft,
        parentMessageId: 'msg-1',
        authorId: 'alice',
        currentUserId: 'me',
        kind: RecipientKind.cloudUser,
        userTag: 'alice',
      );
      ensureDraftRecipient(
        draft,
        const DraftRecipient(
          recipientId: 'alice',
          kind: RecipientKind.cloudUser,
          userTag: 'alice',
        ),
      );
      syncReplyParentAuthor(
        draft,
        parentMessageId: 'msg-2',
        authorId: 'bob',
        currentUserId: 'me',
        kind: RecipientKind.cloudUser,
        userTag: 'bob',
      );
      expect(
        draft.recipients.map((r) => r.recipientId).toSet(),
        {'alice', 'bob'},
      );
    });
  });
}
