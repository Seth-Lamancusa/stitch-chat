import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/settings_modal.dart';
import '../core/theme/app_colors.dart';
import 'column_view.dart';
import 'columns_viewmodel.dart';

/// Top-level multi-column screen: a row of [ColumnView]s with draggable
/// resize handles (port of stitch-flutter's `_ColumnResizer` pattern) and an
/// "Add Column" toolbar action.
class ColumnsView extends StatelessWidget {
  const ColumnsView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ColumnsViewModel>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.appColors.appBarSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Builder(
          builder: (context) {
            // Native pixel dimensions of assets/images/stitch_logo.png.
            const logoAspectRatio = 917 / 516;
            const logoHeight = 28.0;
            const logoWidth = logoHeight * logoAspectRatio;
            // Oval backdrop sized proportionally to the rendered logo so it
            // hugs the artwork instead of forming a circle.
            const glowWidth = logoWidth * 2;
            const glowHeight = logoHeight * 1.6;
            const ringThickness = 1.0;
            const earthBrown = Color(0xFF4A3222);
            const foliageGreen = Color(0xFF1F3D2B);

            return SizedBox(
              width: glowWidth,
              height: glowHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // BoxShape.circle inscribes a circle bounded by the
                  // shorter side of the box, so it wouldn't fill a
                  // non-square box. ClipOval instead fits an ellipse to
                  // the full bounding box, giving a true oval. Two nested
                  // ClipOvals (green, then brown inset by ringThickness)
                  // produce a brown fill with a thin green ring.
                  ClipOval(
                    child: Container(
                      width: glowWidth,
                      height: glowHeight,
                      color: foliageGreen,
                    ),
                  ),
                  ClipOval(
                    child: Container(
                      width: glowWidth - ringThickness * 2,
                      height: glowHeight - ringThickness * 2,
                      color: earthBrown,
                    ),
                  ),
                  Image.asset(
                    'assets/images/stitch_logo.png',
                    height: logoHeight,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add column',
            mouseCursor: SystemMouseCursors.click,
            onPressed: () => vm.addColumn(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            mouseCursor: SystemMouseCursors.click,
            onPressed: () => showSettingsModal(context),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: colorScheme.outline),
        ),
      ),
      body: vm.columns.isEmpty
          ? const Center(child: Text('No columns yet.'))
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: _buildColumnsWithResizers(vm)),
            ),
    );
  }

  /// New columns stack onto the right of the existing ones at
  /// [defaultColumnWidth] rather than resizing the whole row to fit the
  /// screen — the row scrolls horizontally instead. `state.width == null`
  /// (never explicitly resized) also renders at this default; it's a
  /// render-time fallback only, not written back to the column's persisted
  /// width.
  static const double defaultColumnWidth = 400;

  List<Widget> _buildColumnsWithResizers(ColumnsViewModel vm) {
    final children = <Widget>[];
    final columns = vm.columns;
    for (var i = 0; i < columns.length; i++) {
      final state = columns[i];
      final columnWidget = ColumnView(key: ValueKey(state.id), state: state);
      children.add(SizedBox(width: state.width ?? defaultColumnWidth, child: columnWidget));
      children.add(_ColumnResizer(
        getStartWidth: () => state.width ?? defaultColumnWidth,
        onResize: (startWidth, offset) {
          vm.updateColumnWidth(state.id, (startWidth + offset).clamp(240.0, 1200.0));
        },
      ));
    }
    return children;
  }
}

class _ColumnResizer extends StatefulWidget {
  const _ColumnResizer({required this.getStartWidth, required this.onResize});

  /// Returns the column's current width at the moment a drag begins.
  final double Function() getStartWidth;

  /// Called with the width recorded at drag-start and the cumulative
  /// horizontal offset of the pointer since then, so the reported width is
  /// always an absolute function of pointer position rather than an
  /// accumulation of per-frame deltas (which could drift from the cursor).
  final void Function(double startWidth, double offset) onResize;

  @override
  State<_ColumnResizer> createState() => _ColumnResizerState();
}

class _ColumnResizerState extends State<_ColumnResizer> {
  bool _hovering = false;
  double _startWidth = 0;
  double _startGlobalX = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onHorizontalDragStart: (details) {
          _startWidth = widget.getStartWidth();
          _startGlobalX = details.globalPosition.dx;
        },
        onHorizontalDragUpdate: (details) =>
            widget.onResize(_startWidth, details.globalPosition.dx - _startGlobalX),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 3,
          color: _hovering ? Colors.blueAccent.withValues(alpha: 0.5) : colorScheme.outlineVariant,
        ),
      ),
    );
  }
}
