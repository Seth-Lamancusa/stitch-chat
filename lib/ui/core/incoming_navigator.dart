import 'package:flutter/material.dart';

import 'theme/app_colors.dart';

/// Ported from stitch-frontend's `LinkSwitcher.vue`. Cycles the candidate
/// pool a message exposes coming *into* it — which reply or stitch parent
/// its context currently derives from above it — so it sits inline between
/// messages on screen, the UI placement stitch-frontend uses for this
/// direction. Data-model-wise this is the mirror image of
/// [OutgoingNavigator]: same "pick one candidate from a pool" operation,
/// opposite edge direction. Also serves as origin transparency: the pill
/// flags when a message's upward context came via a stitch or a hidden
/// reply rather than a normal reply, even when there's nothing to cycle
/// through.
///
/// Per the exclusivity rule (column-ui-impl-plan.md §4-5): only renders when
/// a reply-anchored parent is already displayed above the message and the
/// combined pool has more than one candidate, OR the currently active
/// parent is itself a stitch / hidden reply (non-interactive origin flag).
///
/// Pool order matches [IncomingEdges.all]: hidden replies, then non-hidden
/// replies, then stitches.
class IncomingNavigator extends StatelessWidget {
  const IncomingNavigator({
    super.key,
    required this.hiddenCount,
    required this.replyCount,
    required this.stitchCount,
    required this.currentIndex,
    this.loading = false,
    this.onPrev,
    this.onNext,
  });

  /// Hidden-reply parents in the pool (ordered first).
  final int hiddenCount;

  /// Non-hidden reply parents (0 or 1 today, after hidden).
  final int replyCount;

  /// Stitch parents (ordered after replies).
  final int stitchCount;

  /// Position of the currently-active parent within the combined pool, or
  /// -1 if unknown/none.
  final int currentIndex;

  final bool loading;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  int get _total => hiddenCount + replyCount + stitchCount;

  bool get _hasActive => currentIndex >= 0;

  bool get _isCurrentHidden =>
      _hasActive && currentIndex < hiddenCount;

  bool get _isCurrentStitch =>
      _hasActive && currentIndex >= hiddenCount + replyCount;

  bool get _isSwitchable => _total > 1;

  bool get _shouldShow =>
      _isSwitchable ||
      (_hasActive && (_isCurrentStitch || _isCurrentHidden));

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow) return const SizedBox.shrink();

    final canPrev = _isSwitchable && currentIndex > 0;
    final canNext = _isSwitchable && currentIndex < _total - 1;

    final String label;
    final _OriginKind kind;
    if (_isCurrentHidden) {
      kind = _OriginKind.hidden;
      label = hiddenCount > 1
          ? 'Hidden thread (${currentIndex + 1}/$hiddenCount)'
          : 'Hidden thread';
    } else if (_isCurrentStitch) {
      kind = _OriginKind.stitch;
      final indexInStitchGroup = currentIndex - hiddenCount - replyCount + 1;
      label = stitchCount > 1
          ? 'Linked origin ($indexInStitchGroup/$stitchCount)'
          : 'Linked origin';
    } else {
      kind = _OriginKind.reply;
      label = 'Reply origin';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SwitcherArrow(
            icon: Icons.chevron_left,
            enabled: canPrev && !loading,
            onPressed: onPrev,
          ),
          const SizedBox(width: 3),
          _OriginPill(label: label, kind: kind, loading: loading),
          const SizedBox(width: 3),
          _SwitcherArrow(
            icon: Icons.chevron_right,
            enabled: canNext && !loading,
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

enum _OriginKind { reply, hidden, stitch }

class _OriginPill extends StatelessWidget {
  const _OriginPill({
    required this.label,
    required this.kind,
    required this.loading,
  });

  final String label;
  final _OriginKind kind;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final appColors = context.appColors;

    final Color borderColor;
    final IconData? icon;
    final Color? iconColor;
    final bool italic;
    switch (kind) {
      case _OriginKind.stitch:
        borderColor = appColors.stitchGreenBorderIdle;
        icon = Icons.link;
        iconColor = appColors.stitchGreen;
        italic = true;
      case _OriginKind.hidden:
        borderColor = colorScheme.onSurface.withValues(alpha: 0.28);
        icon = Icons.visibility_outlined;
        iconColor = colorScheme.onSurface.withValues(alpha: 0.65);
        italic = true;
      case _OriginKind.reply:
        borderColor = colorScheme.outlineVariant;
        icon = null;
        iconColor = null;
        italic = false;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const Padding(
              padding: EdgeInsets.only(right: 3),
              child: SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            )
          else if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Icon(icon, size: 10, color: iconColor),
            ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              color: colorScheme.onSurface.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitcherArrow extends StatelessWidget {
  const _SwitcherArrow({required this.icon, required this.enabled, this.onPressed});

  final IconData icon;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        child: Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: enabled ? 0.7 : 0.15),
        ),
      ),
    );
  }
}
