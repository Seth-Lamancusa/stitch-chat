import 'package:flutter/material.dart';

/// Ported from stitch-frontend's `SiblingNavigator.vue`. Cycles the pool of
/// candidates the *parent above this message* could show in this slot —
/// i.e. this message's siblings. Matching the Vue source (mounted on the
/// child, with the parent id passed in only to look up the pool), this
/// widget wraps the child bubble currently occupying the slot, not the
/// parent: prev/next arrows flank *this* message so switching them swaps
/// which sibling is displayed here. Data-model-wise this is the mirror
/// image of [IncomingNavigator]: same "pick one candidate from a pool"
/// operation, opposite edge direction.
///
/// Per the exclusivity rule (column-ui-impl-plan.md §4-5): this only ever
/// renders when a reply-anchored message is already displayed with a parent
/// row above it and the combined pool has more than one candidate. A
/// message with zero reply parents but some stitch parents shows nothing
/// here — that boundary is [AdaptiveMarker]'s job, not this widget's.
class OutgoingNavigator extends StatelessWidget {
  const OutgoingNavigator({
    super.key,
    required this.replyCount,
    required this.stitchCount,
    required this.currentIndex,
    required this.child,
    this.loading = false,
    this.onPrev,
    this.onNext,
  });

  /// Number of reply candidates in the pool (ordered first).
  final int replyCount;

  /// Number of stitch candidates in the pool (ordered after reply).
  final int stitchCount;

  /// Position of the currently-displayed child within the combined pool
  /// (reply candidates first, then stitch), or -1 if unknown/unset.
  final int currentIndex;

  final bool loading;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final Widget child;

  int get _total => replyCount + stitchCount;

  bool _isStitchAt(int index) => index >= replyCount;

  @override
  Widget build(BuildContext context) {
    if (_total <= 1) return child;

    final canPrev = currentIndex > 0;
    final canNext = currentIndex >= 0 && currentIndex < _total - 1;
    final prevIsStitch = canPrev && _isStitchAt(currentIndex - 1);
    final nextIsStitch = canNext && _isStitchAt(currentIndex + 1);

    return IntrinsicHeight(
      child: Row(
        children: [
          _NavArrow(
            icon: Icons.chevron_left,
            enabled: canPrev,
            loading: loading,
            isStitch: prevIsStitch,
            onPressed: onPrev,
            tooltip: 'Previous',
          ),
          const SizedBox(width: 4),
          Expanded(child: child),
          const SizedBox(width: 4),
          _NavArrow(
            icon: Icons.chevron_right,
            enabled: canNext,
            loading: loading,
            isStitch: nextIsStitch,
            onPressed: onNext,
            tooltip: 'Next',
          ),
        ],
      ),
    );
  }
}

class OutgoingNavArrow extends StatefulWidget {
  const OutgoingNavArrow({
    super.key,
    required this.icon,
    required this.enabled,
    required this.loading,
    required this.isStitch,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final bool loading;
  final bool isStitch;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  State<OutgoingNavArrow> createState() => _OutgoingNavArrowState();
}

class _NavArrow extends OutgoingNavArrow {
  const _NavArrow({
    required super.icon,
    required super.enabled,
    required super.loading,
    required super.isStitch,
    required super.tooltip,
    super.onPressed,
  });
}

class _OutgoingNavArrowState extends State<OutgoingNavArrow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _getBackgroundColor();
    final iconColor = _getIconColor();

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
          width: 20,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.enabled ? widget.onPressed : null,
              child: widget.loading
                  ? const Center(
                      child: SizedBox(
                        width: 8,
                        height: 8,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                    )
                  : Center(
                      child: Icon(widget.icon, size: 14, color: iconColor),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    if (!widget.enabled) {
      return Colors.transparent;
    }

    if (widget.isStitch) {
      if (_isHovered) {
        return Color.fromARGB(140, 76, 175, 80); // rgba(76, 175, 80, 0.55)
      }
      return Color.fromARGB(89, 76, 175, 80); // rgba(76, 175, 80, 0.35)
    }

    if (_isHovered) {
      return Colors.white.withValues(alpha: 0.08);
    }
    return Colors.transparent;
  }

  Color _getIconColor() {
    if (!widget.enabled) {
      return Colors.white.withValues(alpha: 0.3);
    }

    if (widget.isStitch) {
      return Colors.white;
    }

    if (_isHovered) {
      return Colors.white.withValues(alpha: 0.8);
    }

    return Colors.white.withValues(alpha: 0.5);
  }
}
