import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/message.dart';
import '../core/adaptive_marker.dart';
import '../core/incoming_navigator.dart';
import '../core/message_card.dart';
import '../core/outgoing_navigator.dart' show OutgoingNavArrow;
import '../core/theme/app_colors.dart';
import 'column_ui_state.dart';
import 'columns_viewmodel.dart';

/// One column: header, message list with navigators/markers, composer.
/// Absorbs the old `ChatView`'s bubble rendering and composer, scoped to a
/// single column instead of the whole app.
class ColumnView extends StatefulWidget {
  const ColumnView({super.key, required this.state});

  final ColumnUiState state;

  @override
  State<ColumnView> createState() => _ColumnViewState();
}

class _ColumnViewState extends State<ColumnView> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send(ColumnsViewModel vm) {
    vm.sendMessage(widget.state.id, _controller.text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ColumnsViewModel>();
    final state = vm.columns.firstWhere((c) => c.id == widget.state.id, orElse: () => widget.state);
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => vm.setActiveColumn(state.id),
      child: ColoredBox(
        color: state.isActive ? colorScheme.onSurface.withValues(alpha: 0.03) : Colors.transparent,
        child: Column(
          children: [
            _Header(state: state, onClose: () => vm.removeColumn(state.id)),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: _MessageList(key: ValueKey(state.id), state: state)),
                  if (state.isActive)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _Composer(onSend: () => _send(vm), controller: _controller, focusNode: _focusNode),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.onClose});

  final ColumnUiState state;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final headerColor = state.isActive
        ? context.appColors.columnHeaderSurfaceSelected
        : context.appColors.columnHeaderSurface;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: headerColor,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 14),
                children: [
                  const TextSpan(
                    text: 'New column ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: '(${state.id.substring(0, 8)})',
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatefulWidget {
  const _MessageList({super.key, required this.state});

  final ColumnUiState state;

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  // Floating-point rounding tolerance only — not a "near bottom" zone.
  static const double _bottomThreshold = 2;
  static const Duration _scrollSaveDebounce = Duration(milliseconds: 400);

  final _scrollController = ScrollController();
  bool _isAtBottom = true;
  bool _restoredInitialOffset = false;
  Timer? _scrollSaveTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollSaveTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isAtBottom && widget.state.rows.length != oldWidget.state.rows.length) {
      _scrollToBottom();
    }
  }

  void _onScroll() {
    _updateIsAtBottom();
    _scheduleScrollSave();
  }

  void _updateIsAtBottom() {
    if (!_scrollController.hasClients) return;
    // reverse: true means pixels: 0 is the bottom (newest message).
    _isAtBottom = _scrollController.position.pixels <= _bottomThreshold;
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  // Debounced rather than written on every scroll-notification frame, so a
  // drag doesn't turn into dozens of writes/sec — only the position at rest
  // (or 400ms after the last movement) hits the DB. `updateColumnScrollOffset`
  // itself is a single-row `write`, which drift executes atomically.
  void _scheduleScrollSave() {
    _scrollSaveTimer?.cancel();
    _scrollSaveTimer = Timer(_scrollSaveDebounce, () {
      if (!mounted || !_scrollController.hasClients) return;
      context.read<ColumnsViewModel>().updateColumnScrollOffset(
            widget.state.id,
            _scrollController.position.pixels,
          );
    });
  }

  // Runs once per column, after the first frame with a non-empty list so
  // `maxScrollExtent` is populated — restores the position persisted from a
  // previous session/load rather than the default 0.
  void _maybeRestoreInitialOffset() {
    if (_restoredInitialOffset || !_scrollController.hasClients) return;
    _restoredInitialOffset = true;
    final offset = widget.state.initialScrollOffset;
    if (offset == null) return;
    _scrollController.jumpTo(offset.clamp(0.0, _scrollController.position.maxScrollExtent));
    _updateIsAtBottom();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ColumnsViewModel>();
    final state = widget.state;

    if (state.rows.isEmpty) {
      return const Align(
        alignment: Alignment(0.0, -0.2),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 30),
          child: Text('No messages yet — send one to start this branch.', textAlign: TextAlign.center),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRestoreInitialOffset());

    return ListView(
      controller: _scrollController,
      // reverse: true so the list is anchored to the newest message (pixels:
      // 0 is the bottom): new messages append without disturbing a user who
      // has scrolled up, and staying pinned at the bottom needs no explicit
      // scroll-to-end handling from layout.
      reverse: true,
      // Reserved unconditionally (not just while active) so selecting or
      // deselecting a column never changes the list's scroll extents.
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 70),
      children: [
        // Children are in reverse visual order: index 0 renders at the
        // bottom (newest), so the bottom marker comes first and the top
        // marker last.
        AdaptiveMarker(
          isTop: false,
          state: state.bottomLoading
              ? MarkerVisualState.loading
              : (state.bottomError != null ? MarkerVisualState.error : state.bottomMarker),
          stitchCount: state.bottomStitchCount,
          errorMessage: state.bottomError,
          onLoadStitches: () => vm.loadStitchBelow(state.id),
          onRetry: () => vm.loadStitchBelow(state.id),
        ),
        for (int i = state.rows.length - 1; i >= 0; i--) ...[
          _MessageRow(
            columnId: state.id,
            row: state.rows[i],
            // Rows are stored top-to-bottom (index 0 is topmost/oldest), but this
            // ListView is `reverse: true` and iterates i downward, so "the row
            // above" is index i - 1, not i + 1.
            showAuthor: i == 0 || _authorKey(state.rows[i].message) != _authorKey(state.rows[i - 1].message),
          ),
          if (i > 0) const SizedBox(height: 8),
        ],
        AdaptiveMarker(
          isTop: true,
          state: state.topLoading ? MarkerVisualState.loading : (state.topError != null ? MarkerVisualState.error : state.topMarker),
          stitchCount: state.topStitchCount,
          errorMessage: state.topError,
          onLoadStitches: () => vm.loadStitchAbove(state.id),
          onRetry: () => vm.loadStitchAbove(state.id),
        ),
      ],
    );
  }
}

String _authorKey(Message message) => message.authorId ?? _MessageRow._defaultAuthorLabel(message.role);

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.columnId, required this.row, required this.showAuthor});

  final String columnId;
  final MessageRowData row;
  final bool showAuthor;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ColumnsViewModel>();
    final isMe = row.message.authorId != null && row.message.authorId == vm.currentUserId;

    // Author label
    final authorLabel = Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        isMe ? 'You' : row.message.authorId ?? _defaultAuthorLabel(row.message.role),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );

    // Message bubble
    Widget bubble = MessageCard(message: row.message, currentUserId: vm.currentUserId);

    // Nav buttons (if outgoing exists)
    Widget? leftNav;
    Widget? rightNav;
    if (row.outgoing != null) {
      final anchorId = row.outgoingAnchorId!;
      final canPrev = row.outgoingCurrentIndex > 0;
      final canNext = row.outgoingCurrentIndex >= 0 && row.outgoingCurrentIndex < row.outgoing!.all.length - 1;
      final prevIsStitch = canPrev && (row.outgoingCurrentIndex - 1) >= row.outgoing!.replyOutgoing.length;
      final nextIsStitch = canNext && (row.outgoingCurrentIndex + 1) >= row.outgoing!.replyOutgoing.length;

      leftNav = OutgoingNavArrow(
        icon: Icons.chevron_left,
        enabled: canPrev,
        loading: false,
        isStitch: prevIsStitch,
        onPressed: () => vm.navigateOutgoing(columnId, anchorId, forward: false),
        tooltip: 'Previous',
      );

      rightNav = OutgoingNavArrow(
        icon: Icons.chevron_right,
        enabled: canNext,
        loading: false,
        isStitch: nextIsStitch,
        onPressed: () => vm.navigateOutgoing(columnId, anchorId, forward: true),
        tooltip: 'Next',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (row.incoming != null)
          IncomingNavigator(
            replyCount: row.incoming!.replyIncoming.length,
            stitchCount: row.incoming!.stitchedIncoming.length,
            currentIndex: row.incomingCurrentIndex,
            onPrev: () => vm.navigateIncoming(columnId, row.message.id, forward: false),
            onNext: () => vm.navigateIncoming(columnId, row.message.id, forward: true),
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Author label row — only for the topmost message of a consecutive
            // same-author run.
            if (showAuthor)
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 2),
                child: authorLabel,
              ),
            // Message bubble row with nav buttons
            IntrinsicHeight(
              child: Row(
                children: [
                  SizedBox(width: 20, child: leftNav != null ? Center(child: leftNav) : null),
                  const SizedBox(width: 6),
                  Expanded(child: bubble),
                  const SizedBox(width: 6),
                  SizedBox(width: 20, child: rightNav != null ? Center(child: rightNav) : null),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _defaultAuthorLabel(MessageRole role) {
    switch (role) {
      case MessageRole.user:
        return 'user';
      case MessageRole.localBot:
        return 'assistant';
      case MessageRole.functionCall:
      case MessageRole.functionResult:
        return 'function';
    }
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend, required this.focusNode});

  final TextEditingController controller;
  final VoidCallback onSend;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.columnHeaderSurfaceSelected,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  hintText: 'Say something...',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: context.appColors.stitchGreen,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              icon: Icon(Icons.arrow_upward, color: colorScheme.onPrimary),
              onPressed: onSend,
            ),
          ),
        ],
      ),
    );
  }
}
