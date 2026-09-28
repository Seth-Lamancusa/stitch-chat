/// Stable ids for the stitch-sibling UX fixture.
///
/// Graph (matches the "main reply already visible, stitch sibling not yet
/// crossed" case):
///
/// ```
/// T  user trigger
/// ├── A1  localBot (reply)          ← visible branch
/// └── S1  thinking (stitch from T)  ← sibling, not auto-followed
///     └── S2  functionCall (reply)
///         └── S3  functionResult (reply)
/// ```
class MockStitchSibling {
  MockStitchSibling._();

  static const fixtureTriggerId = 'stitch-sib-trigger';
  static const fixtureReplyId = 'stitch-sib-reply';
  static const fixtureSideRootId = 'stitch-sib-side-root';
  static const fixtureSideMidId = 'stitch-sib-side-mid';
  static const fixtureSideLeafId = 'stitch-sib-side-leaf';

  static const Set<String> fixtureIds = {
    fixtureTriggerId,
    fixtureReplyId,
    fixtureSideRootId,
    fixtureSideMidId,
    fixtureSideLeafId,
  };
}
