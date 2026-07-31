import 'package:flutter/material.dart';

import 'stitch_colors.dart';

enum MarkerVisualState { waiting, loading, end, error }

/// Ported from stitch-frontend's `AdaptiveMarker.vue`. Sentinel at the top
/// or bottom of a column's message list. Presentational only — state is
/// computed by the caller from a `BranchWindow`/boundary query, not derived
/// here (mirrors stitch-frontend's split between `ThreadView.vue`'s
/// `topMarkerState`/`bottomMarkerState` and this widget).
///
/// Per the exclusivity rule (column-ui-impl-plan.md §4-5), the "Load
/// stitches (N)" button here is the *only* place unloaded stitch neighbors
/// get surfaced — it only ever applies at a true reply dead-end, exactly
/// when neither [OutgoingNavigator] nor [IncomingNavigator] could have
/// shown that count instead.
class AdaptiveMarker extends StatelessWidget {
  const AdaptiveMarker({
    super.key,
    required this.isTop,
    required this.state,
    this.stitchCount = 0,
    this.errorMessage,
    this.onLoadStitches,
    this.onRetry,
  });

  final bool isTop;
  final MarkerVisualState state;
  final int stitchCount;
  final String? errorMessage;
  final VoidCallback? onLoadStitches;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isTop ? 12 : 8),
      child: Center(child: _content(context)),
    );
  }

  Widget _content(BuildContext context) {
    switch (state) {
      case MarkerVisualState.waiting:
        return _TextRow(
          opacity: 0.5,
          leading: const _DividerDots(),
          text: isTop ? 'Scroll up for more' : 'Scroll down for more',
        );
      case MarkerVisualState.loading:
        return _TextRow(
          leading: const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          text: isTop ? 'Loading earlier messages…' : 'Loading more messages…',
        );
      case MarkerVisualState.end:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TextRow(
              opacity: 0.6,
              leading: const _DividerDots(),
              text: isTop ? 'Beginning of thread' : 'End of thread',
            ),
            if (stitchCount > 0) ...[
              const SizedBox(height: 8),
              _StitchLoadButton(count: stitchCount, onPressed: onLoadStitches),
            ],
          ],
        );
      case MarkerVisualState.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TextRow(
              leading: const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber),
              text: errorMessage ?? 'Something went wrong loading messages.',
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        );
    }
  }
}

class _TextRow extends StatelessWidget {
  const _TextRow({required this.leading, required this.text, this.opacity = 1});

  final Widget leading;
  final String text;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _DividerDots extends StatelessWidget {
  const _DividerDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _StitchLoadButton extends StatelessWidget {
  const _StitchLoadButton({required this.count, this.onPressed});

  final int count;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StitchColors.surfaceContainerDark,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: StitchColors.stitchGreenBorderIdle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link, size: 14, color: StitchColors.stitchGreen),
              const SizedBox(width: 6),
              Text(
                'Load $count stitch${count == 1 ? '' : 'es'}',
                style: TextStyle(fontSize: 12, color: StitchColors.stitchGreen),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
