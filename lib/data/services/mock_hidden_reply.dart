/// Stable ids for the hidden-reply UX fixture.
///
/// Race graph (sibling nav after main reply is visible):
/// ```
/// T  user trigger
/// ├── A1  localBot (reply)                 ← visible branch (pinned)
/// └── S1  thinking (hidden reply from T)
///     └── S2 … S3
/// ```
///
/// Reveal-only graph (AdaptiveMarker button; no non-hidden reply under R):
/// ```
/// R  user trigger
/// └── H1  thinking (hidden reply)
///     └── H2 … H3
/// ```
class MockHiddenReply {
  MockHiddenReply._();

  static const fixtureTriggerId = 'hidden-reply-trigger';
  static const fixtureReplyId = 'hidden-reply-main';
  static const fixtureSideRootId = 'hidden-reply-side-root';
  static const fixtureSideMidId = 'hidden-reply-side-mid';
  static const fixtureSideLeafId = 'hidden-reply-side-leaf';

  static const fixtureRevealTriggerId = 'hidden-reply-reveal-trigger';
  static const fixtureRevealSideRootId = 'hidden-reply-reveal-side-root';
  static const fixtureRevealSideMidId = 'hidden-reply-reveal-side-mid';
  static const fixtureRevealSideLeafId = 'hidden-reply-reveal-side-leaf';

  static const Set<String> fixtureIds = {
    fixtureTriggerId,
    fixtureReplyId,
    fixtureSideRootId,
    fixtureSideMidId,
    fixtureSideLeafId,
    fixtureRevealTriggerId,
    fixtureRevealSideRootId,
    fixtureRevealSideMidId,
    fixtureRevealSideLeafId,
  };
}
