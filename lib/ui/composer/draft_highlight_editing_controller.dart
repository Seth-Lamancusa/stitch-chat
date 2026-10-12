import 'package:flutter/material.dart';

import '../core/inline_content_tokens.dart';

/// Colors draft `#` / `@` tokens inside a [TextField] via [buildTextSpan].
///
/// Prefer this over a transparent-text + overlay stack — the editable text
/// then scrolls and clips with the field instead of painting outside it.
class DraftHighlightEditingController extends TextEditingController {
  DraftHighlightEditingController({super.text});

  /// Frontend-ish palette: mention blue / tag amber.
  static const mentionColor = Color(0xFF3BA0D8);
  static const tagColor = Color(0xFFC4921A);

  Set<String> _mentions = const {};
  Set<String> _tags = const {};

  /// Update highlight membership. Does not [notifyListeners] — callers should
  /// rebuild the owning [TextField] (e.g. via [Consumer]) so spans refresh.
  void setHighlights({
    required Set<String> mentions,
    required Set<String> tags,
  }) {
    _mentions = mentions;
    _tags = tags;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    final highlighted = InlineContentTokens.buildSpans(
      text: text,
      baseStyle: baseStyle,
      validMentions: _mentions,
      validTags: _tags,
      mentionColor: mentionColor,
      tagColor: tagColor,
    );

    if (!withComposing || !value.isComposingRangeValid) {
      return highlighted;
    }

    // Preserve IME composing underline on top of token colors.
    return TextSpan(
      style: baseStyle,
      children: _applyComposingUnderline(
        highlighted,
        value.composing,
        baseStyle.merge(const TextStyle(decoration: TextDecoration.underline)),
      ),
    );
  }

  /// Walk [span]'s flat text and underline the composing [range].
  static List<InlineSpan> _applyComposingUnderline(
    InlineSpan span,
    TextRange range,
    TextStyle composingStyle,
  ) {
    final out = <InlineSpan>[];
    var cursor = 0;

    void walk(InlineSpan node) {
      if (node is TextSpan) {
        final children = node.children;
        if (children != null && children.isNotEmpty) {
          for (final child in children) {
            walk(child);
          }
          return;
        }
        final piece = node.text ?? '';
        if (piece.isEmpty) return;
        final start = cursor;
        final end = cursor + piece.length;
        cursor = end;

        if (end <= range.start || start >= range.end) {
          out.add(TextSpan(text: piece, style: node.style));
          return;
        }

        if (start < range.start) {
          out.add(
            TextSpan(
              text: piece.substring(0, range.start - start),
              style: node.style,
            ),
          );
        }
        final midStart = range.start > start ? range.start - start : 0;
        final midEnd = range.end < end ? range.end - start : piece.length;
        out.add(
          TextSpan(
            text: piece.substring(midStart, midEnd),
            style: (node.style ?? const TextStyle()).merge(composingStyle),
          ),
        );
        if (end > range.end) {
          out.add(
            TextSpan(
              text: piece.substring(range.end - start),
              style: node.style,
            ),
          );
        }
      }
    }

    walk(span);
    return out;
  }
}
