import 'package:flutter/material.dart';

/// Mirrors stitch-frontend `mentions_hashtags.js` token rules (simplified).
final _tagToken = RegExp(r'(^|[\s([{])#([A-Za-z0-9-]{1,32})(?![A-Za-z0-9-])');
final _mentionToken =
    RegExp(r'(^|[\s([{])@([A-Za-z0-9-]{2,24})(?![A-Za-z0-9-])(?=[^\w@.]|$)');

class InlineContentTokens {
  static TextSpan buildSpans({
    required String text,
    required TextStyle baseStyle,
    required Set<String> validMentions,
    required Set<String> validTags,
    Color? mentionColor,
    Color? tagColor,
  }) {
    if (text.isEmpty) {
      return TextSpan(text: '', style: baseStyle);
    }

    final matches = <_TokenMatch>[];
    matches.addAll(_collect(text, _tagToken, '#', validTags, _TokenKind.tag));
    matches.addAll(
      _collect(text, _mentionToken, '@', validMentions, _TokenKind.mention),
    );
    matches.sort((a, b) => a.start.compareTo(b.start));

    final children = <InlineSpan>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start < cursor) continue;
      if (match.start > cursor) {
        children.add(TextSpan(text: text.substring(cursor, match.start), style: baseStyle));
      }
      final color = match.kind == _TokenKind.tag ? tagColor : mentionColor;
      children.add(
        TextSpan(
          text: match.raw,
          style: baseStyle.copyWith(
            color: color ?? baseStyle.color?.withValues(alpha: 0.85),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor), style: baseStyle));
    }
    return TextSpan(style: baseStyle, children: children);
  }

  static List<_TokenMatch> _collect(
    String text,
    RegExp pattern,
    String prefix,
    Set<String> valid,
    _TokenKind kind,
  ) {
    if (valid.isEmpty) return const [];
    final out = <_TokenMatch>[];
    for (final match in pattern.allMatches(text)) {
      final lead = match.group(1) ?? '';
      final body = match.group(2)!;
      if (!valid.contains(body.toLowerCase())) continue;
      final token = '$prefix$body';
      final start = match.start + lead.length;
      out.add(_TokenMatch(start, start + token.length, token, kind));
    }
    return out;
  }
}

enum _TokenKind { mention, tag }

class _TokenMatch {
  _TokenMatch(this.start, this.end, this.raw, this.kind);
  final int start;
  final int end;
  final String raw;
  final _TokenKind kind;
}
