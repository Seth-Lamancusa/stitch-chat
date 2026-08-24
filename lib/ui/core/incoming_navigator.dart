import 'package:flutter/material.dart';

import 'theme/app_colors.dart';

/// Ported from stitch-frontend's `LinkSwitcher.vue`. Cycles the candidate
/// pool a message exposes coming *into* it — which reply or stitch parent
/// its context currently derives from above it — so it sits inline between
/// messages on screen, the UI placement stitch-frontend uses for this
/// direction. Data-model-wise this is the mirror image of
/// [OutgoingNavigator]: same "pick one candidate from a pool" operation,
/// opposite edge direction. Also serves as origin transparency: the pill
/// flags when a message's upward context came via a stitch rather than a
/// reply, even when there's nothing to cycle through.
///
/// Per the exclusivity rule (column-ui-impl-plan.md §4-5): only renders when
/// a reply-anchored parent is already displayed above the message and the
/// combined pool has more than one candidate, OR the currently active
/// parent is itself a stitch (non-interactive "Linked origin" flag, single
/// candidate).
class IncomingNavigator extends StatelessWidget {
  const IncomingNavigator({
    super.key,
    required this.replyCount,
    required this.stitchCount,
    required this.currentIndex,
    this.loading = false,
    this.onPrev,
    this.onNext,
  });

  /// Number of reply candidates in the pool (0 or 1, ordered first).
  final int replyCount;

  /// Number of stitch candidates in the pool (ordered after reply).
  final int stitchCount;

  /// Position of the currently-active parent within the combined pool
  /// (reply first, then stitch), or -1 if unknown/none.
  final int currentIndex;

  final bool loading;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  int get _total => replyCount + stitchCount;

  bool get _hasActive => currentIndex >= 0;

  bool get _isCurrentStitch => _hasActive && currentIndex >= replyCount;

  bool get _isSwitchable => _total > 1;

  bool get _shouldShow => _isSwitchable || (_hasActive && _isCurrentStitch);

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow) return const SizedBox.shrink();

    final canPrev = _isSwitchable && currentIndex > 0;
    final canNext = _isSwitchable && currentIndex < _total - 1;

    String label;
    if (_isCurrentStitch) {
      final indexInStitchGroup = currentIndex - replyCount + 1;
      label = stitchCount > 1 ? 'Linked origin ($indexInStitchGroup/$stitchCount)' : 'Linked origin';
    } else {
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
          _OriginPill(label: label, isStitch: _isCurrentStitch, loading: loading),
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

class _OriginPill extends StatelessWidget {
  const _OriginPill({required this.label, required this.isStitch, required this.loading});

  final String label;
  final bool isStitch;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final appColors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isStitch ? appColors.stitchGreenBorderIdle : colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const Padding(
              padding: EdgeInsets.only(right: 3),
              child: SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5)),
            )
          else if (isStitch)
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Icon(Icons.link, size: 10, color: appColors.stitchGreen),
            ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontStyle: isStitch ? FontStyle.italic : FontStyle.normal,
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
