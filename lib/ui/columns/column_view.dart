import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/message.dart';
import '../core/adaptive_marker.dart';
import '../core/incoming_navigator.dart';
import '../core/message_card.dart';
import '../core/outgoing_navigator.dart' show OutgoingNavArrow;
import '../core/stitch_colors.dart';
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send(ColumnsViewModel vm) {
    vm.sendMessage(widget.state.id, _controller.text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ColumnsViewModel>();
    final state = vm.columns.firstWhere((c) => c.id == widget.state.id, orElse: () => widget.state);

    return GestureDetector(
      onTap: () => vm.setActiveColumn(state.id),
      child: Container(
        decoration: BoxDecoration(
          color: state.isActive ? Colors.white.withValues(alpha: 0.02) : null,
          border: Border(
            left: BorderSide(
              color: state.isActive ? Colors.green : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Column(
          children: [
            _Header(state: state, onClose: () => vm.removeColumn(state.id)),
            Expanded(child: _MessageList(state: state)),
            if (state.isActive) _Composer(onSend: () => _send(vm), controller: _controller),
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
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: StitchColors.surfaceContainerDark,
        border: Border(bottom: BorderSide(color: StitchColors.borderDark)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Column ${state.id.substring(0, 8)}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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

class _MessageList extends StatelessWidget {
  const _MessageList({required this.state});

  final ColumnUiState state;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ColumnsViewModel>();

    if (state.rows.isEmpty) {
      return const Center(
        child: Text('No messages yet — send one to start this branch.', textAlign: TextAlign.center),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        AdaptiveMarker(
          isTop: true,
          state: state.topLoading ? MarkerVisualState.loading : (state.topError != null ? MarkerVisualState.error : state.topMarker),
          stitchCount: state.topStitchCount,
          errorMessage: state.topError,
          onLoadStitches: () => vm.loadStitchAbove(state.id),
          onRetry: () => vm.loadStitchAbove(state.id),
        ),
        for (int i = 0; i < state.rows.length; i++) ...[
          _MessageRow(columnId: state.id, row: state.rows[i]),
          if (i < state.rows.length - 1) const SizedBox(height: 8),
        ],
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
      ],
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.columnId, required this.row});

  final String columnId;
  final MessageRowData row;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ColumnsViewModel>();
    final colorScheme = Theme.of(context).colorScheme;
    final isMe = row.message.authorId != null && row.message.authorId == vm.currentUserId;

    // Author label
    final authorLabel = Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        isMe ? 'You' : row.message.authorId ?? _defaultAuthorLabel(row.message.role),
        style: TextStyle(
          fontSize: 10,
          fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
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
            // Author label row
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
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'Say something...'),
              onSubmitted: (_) => onSend(),
            ),
          ),
          IconButton(icon: const Icon(Icons.send), onPressed: onSend),
        ],
      ),
    );
  }
}
