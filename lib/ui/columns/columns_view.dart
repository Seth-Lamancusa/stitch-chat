import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/stitch_colors.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stitch'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add column',
            onPressed: vm.columns.isEmpty
                ? null
                : () {
                    final active = vm.columns.firstWhere(
                      (c) => c.isActive,
                      orElse: () => vm.columns.first,
                    );
                    final anchor = vm.anchorOf(active.id);
                    if (anchor != null) {
                      vm.addColumn(anchorMessageId: anchor);
                    }
                  },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: vm.columns.isEmpty
          ? const Center(child: Text('No columns yet.'))
          : Row(children: _buildColumnsWithResizers(vm)),
    );
  }

  List<Widget> _buildColumnsWithResizers(ColumnsViewModel vm) {
    final children = <Widget>[];
    final columns = vm.columns;
    for (var i = 0; i < columns.length; i++) {
      final state = columns[i];
      final columnWidget = ColumnView(state: state);
      children.add(
        state.width != null
            ? SizedBox(width: state.width, child: columnWidget)
            : Expanded(child: columnWidget),
      );
      if (i < columns.length - 1) {
        children.add(_ColumnResizer(
          onDrag: (delta) {
            final current = state.width ?? 400;
            vm.updateColumnWidth(state.id, (current + delta).clamp(240.0, 1200.0));
          },
        ));
      }
    }
    return children;
  }
}

class _ColumnResizer extends StatefulWidget {
  const _ColumnResizer({required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  State<_ColumnResizer> createState() => _ColumnResizerState();
}

class _ColumnResizerState extends State<_ColumnResizer> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onHorizontalDragUpdate: (details) => widget.onDrag(details.delta.dx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 4,
          color: _hovering ? Colors.blueAccent.withValues(alpha: 0.5) : StitchColors.borderDark,
        ),
      ),
    );
  }
}
