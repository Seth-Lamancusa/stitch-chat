import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_chat/core/logging/stitch_env.dart';

void main() {
  test('apiBaseUrl defaults to production and strips trailing slash', () {
    expect(StitchEnv.forTest({}).apiBaseUrl, 'https://api.stitch.fyi');
    expect(StitchEnv.forTest({}).apiBaseUrl, StitchEnv.defaultApiBaseUrl);
    expect(
      StitchEnv.forTest({'STITCH_API_URL': 'https://api.stitch.fyi/'}).apiBaseUrl,
      'https://api.stitch.fyi',
    );
    expect(
      StitchEnv.forTest({'STITCH_API_URL': '  http://localhost:8081  '}).apiBaseUrl,
      'http://localhost:8081',
    );
  });

  test('mockTypingCues is truthy only for common yes values', () {
    expect(StitchEnv.forTest({}).mockTypingCues, isFalse);
    expect(StitchEnv.forTest({'STITCH_MOCK_TYPING_CUES': '0'}).mockTypingCues, isFalse);
    expect(StitchEnv.forTest({'STITCH_MOCK_TYPING_CUES': '1'}).mockTypingCues, isTrue);
    expect(StitchEnv.forTest({'STITCH_MOCK_TYPING_CUES': 'true'}).mockTypingCues, isTrue);
    expect(StitchEnv.forTest({'STITCH_MOCK_TYPING_CUES': 'YES'}).mockTypingCues, isTrue);
  });

  test('mockHiddenReply is truthy only for common yes values', () {
    expect(StitchEnv.forTest({}).mockHiddenReply, isFalse);
    expect(StitchEnv.forTest({'STITCH_MOCK_HIDDEN_REPLY': '1'}).mockHiddenReply, isTrue);
  });
}
