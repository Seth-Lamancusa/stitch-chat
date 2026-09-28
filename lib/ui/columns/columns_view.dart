import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/message.dart';
import '../auth/login_screen.dart';
import '../auth/login_viewmodel.dart';
import '../core/settings_modal.dart';
import '../core/stitch_logo_title.dart';
import '../core/theme/app_colors.dart';
import '../core/thread_roots_panel.dart';
import 'column_view.dart';
import 'columns_display_mode.dart';
import 'columns_viewmodel.dart';

/// Top-level multi-column screen: a row of [ColumnView]s with draggable
/// resize handles (port of stitch-flutter's `_ColumnResizer` pattern) and an
/// "Add Column" toolbar action.
class ColumnsView extends StatefulWidget {
  const ColumnsView({super.key});

  /// Default render width when a column has no persisted width.
  static const double defaultColumnWidth = 400;

  @override
  State<ColumnsView> createState() => _ColumnsViewState();
}

class _ColumnsViewState extends State<ColumnsView> {
  bool _threadRootsOpen = false;

  void _setThreadRootsOpen(bool open) {
    if (_threadRootsOpen == open) return;
    setState(() => _threadRootsOpen = open);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ColumnsViewModel>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.appColors.appBarSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(_threadRootsOpen ? Icons.close : Icons.menu),
          tooltip: _threadRootsOpen ? 'Close threads' : 'Thread roots',
          mouseCursor: SystemMouseCursors.click,
          onPressed: () => _setThreadRootsOpen(!_threadRootsOpen),
        ),
        title: const StitchLogoTitle(),
        actions: [
          IconButton(
            icon: Icon(
              vm.displayMode == ColumnsDisplayMode.single
                  ? Icons.view_column
                  : Icons.crop_portrait,
            ),
            tooltip: vm.displayMode == ColumnsDisplayMode.single
                ? 'Multi-column layout'
                : 'Single column layout',
            mouseCursor: SystemMouseCursors.click,
            onPressed: vm.toggleDisplayMode,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add column',
            mouseCursor: SystemMouseCursors.click,
            onPressed: () => vm.addColumn(),
          ),
          Consumer<LoginViewModel>(
            builder: (context, loginVm, _) {
              if (!loginVm.authReady) {
                return const SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              if (loginVm.isAuthenticated) {
                final tag = loginVm.state.profile?.userTag ??
                    loginVm.state.subject?.userTag ??
                    'account';
                return IconButton(
                  icon: const Icon(Icons.account_circle),
                  tooltip: 'Signed in as @$tag — open settings',
                  mouseCursor: SystemMouseCursors.click,
                  onPressed: () => showSettingsModal(context),
                );
              }
              return IconButton(
                icon: const Icon(Icons.login),
                tooltip: 'Sign in to Stitch cloud',
                mouseCursor: SystemMouseCursors.click,
                onPressed: () => showLoginModal(context),
              );
            },
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          vm.columns.isEmpty
              ? const Center(child: Text('No columns yet.'))
              : vm.displayMode == ColumnsDisplayMode.single
                  ? _SingleColumnBody(vm: vm)
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: _buildColumnsWithResizers(vm)),
                    ),
          if (_threadRootsOpen) ...[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _setThreadRootsOpen(false),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.35),
                ),
              ),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              width: ThreadRootsPanel.panelWidth,
              child: StreamBuilder<List<Message>>(
                stream: vm.watchThreadRoots(),
                builder: (context, snapshot) {
                  final roots = snapshot.data ?? const <Message>[];
                  return ThreadRootsPanel(
                    roots: roots,
                    onClose: () => _setThreadRootsOpen(false),
                    onRootTap: vm.onThreadRootPreviewTap,
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildColumnsWithResizers(ColumnsViewModel vm) {
    const defaultColumnWidth = ColumnsView.defaultColumnWidth;
    final children = <Widget>[];
    final columns = vm.columns;
    for (var i = 0; i < columns.length; i++) {
      final state = columns[i];
      // Key the Row's direct child, not only [ColumnView]: without this,
      // removing a column to the left reuses slot 0's element for the next
      // column's SizedBox and disposes the shifted column's state (scroll,
      // composer draft, etc.) even though the inner ColumnView id differs.
      children.add(
        SizedBox(
          key: ValueKey(state.id),
          width: state.width ?? defaultColumnWidth,
          child: ColumnView(state: state),
        ),
      );
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

/// First column only, centered horizontally; cwd picker in the view top-right.
class _SingleColumnBody extends StatelessWidget {
  const _SingleColumnBody({required this.vm});

  final ColumnsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final state = vm.columns.first;
    final width = state.width ?? ColumnsView.defaultColumnWidth;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            key: ValueKey(state.id),
            width: width,
            height: double.infinity,
            child: ColumnView(
              state: state,
              showCwdInHeader: false,
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Material(
            color: context.appColors.columnHeaderSurface.withValues(alpha: 0.92),
            elevation: 1,
            borderRadius: BorderRadius.circular(8),
            child: ColumnCwdIconButton(state: state),
          ),
        ),
      ],
    );
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
