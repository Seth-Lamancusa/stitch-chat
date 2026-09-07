import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_chat/core/logging/stitch_log_level.dart';

void main() {
  test('StitchLogLevel.parse accepts common aliases', () {
    expect(StitchLogLevel.parse('debug'), StitchLogLevel.debug);
    expect(StitchLogLevel.parse('WARN'), StitchLogLevel.warning);
    expect(StitchLogLevel.parse('warning'), StitchLogLevel.warning);
    expect(StitchLogLevel.parse(null), StitchLogLevel.info);
    expect(StitchLogLevel.parse(null, fallback: StitchLogLevel.debug), StitchLogLevel.debug);
    expect(StitchLogLevel.parse('nope'), StitchLogLevel.info);
  });

  test('allows filters by severity threshold', () {
    expect(StitchLogLevel.info.allows(StitchLogLevel.debug), isFalse);
    expect(StitchLogLevel.info.allows(StitchLogLevel.info), isTrue);
    expect(StitchLogLevel.info.allows(StitchLogLevel.error), isTrue);
    expect(StitchLogLevel.trace.allows(StitchLogLevel.debug), isTrue);
  });
}
