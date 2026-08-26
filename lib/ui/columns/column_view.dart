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
  final _messageListKey = GlobalKey<_MessageListState>();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send(ColumnsViewModel vm) {
    final content = _controller.text;
    _controller.clear();
    _focusNode.requestFocus();
    _messageListKey.currentState?.sendAndStickToBottom(
      () => vm.sendMessage(widget.state.id, content),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ColumnsViewModel>();
    final state = vm.columns.firstWhere(
      (c) => c.id == widget.state.id,
      orElse: () => widget.state,
    );
    final colorScheme = Theme.of(context).colorScheme;

    Message? replyTarget;
    if (state.replyingToMessageId != null) {
      for (final row in state.rows) {
        if (row.message.id == state.replyingToMessageId) {
          replyTarget = row.message;
          break;
        }
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => vm.setActiveColumn(state.id),
      child: ColoredBox(
        color: state.isActive
            ? colorScheme.onSurface.withValues(alpha: 0.03)
            : Colors.transparent,
        child: Column(
          children: [
            _Header(state: state, onClose: () => vm.removeColumn(state.id)),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _MessageList(key: _messageListKey, state: state),
                  ),
                  if (state.isActive)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _Composer(
                        onSend: () => _send(vm),
                        controller: _controller,
                        focusNode: _focusNode,
                        replyTarget: replyTarget,
                        onCancelReply: () => vm.setReplyTarget(state.id, null),
                      ),
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
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
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

  // Identifies the pinned *slot* in the sliver list passed to
  // `CustomScrollView.center` — not the anchor message itself, which
  // changes across builds as the user navigates forks. Because slivers
  // before this key grow backward (negative offset) and slivers after it
  // grow forward, whichever row currently lands in the center sliver simply
  // never moves on screen when content on either side is replaced by a
  // fork switch — a layout invariant, not something asserted after the fact
  // with `jumpTo` like the old `ListView(reverse: true)` approach required.
  final Key _centerKey = UniqueKey();

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

  /// Runs [action] (a new outgoing message) and, if the user was already
  /// pinned to the bottom, keeps them there. This is deliberately *not* a
  /// generic "row count changed" reaction in [didUpdateWidget]: that would
  /// also fire for [loadStitchAbove]/[loadStitchBelow] (an explicit "load
  /// more" tap, which shouldn't also yank the view) and for branch switches
  /// (already handled, and in the opposite way, by the column's persisted
  /// anchor — see `_centerKey`). Scroll intent lives with the action that
  /// causes it instead of being
  /// inferred after the fact from its side effects.
  void sendAndStickToBottom(void Function() action) {
    final wasAtBottom = _isAtBottom;
    action();
    // `action` (a real repo round trip) only *schedules* the rebuild that
    // lays out the new row — reading `maxScrollExtent` before that frame
    // runs would target the stale, pre-send extent, undershooting by one
    // message. Deferring to a post-frame callback lets `_scrollToBottom`
    // read the extent that actually includes the new row.
    if (wasAtBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _onScroll() {
    _updateIsAtBottom();
    _scheduleScrollSave();
  }

  void _updateIsAtBottom() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    _isAtBottom = (position.maxScrollExtent - position.pixels) <= _bottomThreshold;
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
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
    final position = _scrollController.position;
    // Offsets into the before-anchor sliver are legitimately negative now
    // (`minScrollExtent` is negative for a `center`-based CustomScrollView),
    // unlike the old reversed ListView where 0 was always the lower bound.
    _scrollController.jumpTo(
      offset.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
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
          child: Text(
            'No messages yet — send one to start this branch.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeRestoreInitialOffset(),
    );

    // The persisted anchor (`ColumnsViewModel.anchorOf`) is already exactly
    // the row that must stay visually fixed across a fork switch:
    // `navigateOutgoing`/`navigateIncoming` re-anchor it to `parentId`/
    // `childId` respectively — the one row each swap leaves untouched. It's
    // guaranteed present in `state.rows` because `getFullVisibleBranch`
    // always builds `[...above, anchor, ...below]` from this same id, and
    // `state.rows` is only non-empty when an anchor exists (see the
    // early-return above).
    final anchorId = vm.anchorOf(state.id);
    final anchorIndex = state.rows.indexWhere(
      (r) => r.message.id == anchorId,
    );
    assert(
      anchorIndex != -1,
      'persisted anchor $anchorId missing from derived branch',
    );

    final showAuthorById = <String, bool>{
      for (int i = 0; i < state.rows.length; i++)
        state.rows[i].message.id:
            i == 0 ||
            _authorKey(state.rows[i].message) !=
                _authorKey(state.rows[i - 1].message),
    };

    // Slivers listed before `center` grow backward (negative offset), so
    // this sliver's own child order must have index 0 closest to the
    // anchor (the row immediately above it) and increasing index moving
    // further back in time, ending in the top marker.
    final beforeRows = state.rows.sublist(0, anchorIndex).reversed.toList();
    final centerRow = state.rows[anchorIndex];
    final afterRows = state.rows.sublist(anchorIndex + 1);

    return CustomScrollView(
      controller: _scrollController,
      center: _centerKey,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              for (int i = 0; i < beforeRows.length; i++) ...[
                _MessageRow(
                  key: ValueKey(beforeRows[i].message.id),
                  columnId: state.id,
                  row: beforeRows[i],
                  showAuthor: showAuthorById[beforeRows[i].message.id]!,
                ),
                const SizedBox(height: 4),
              ],
              AdaptiveMarker(
                isTop: true,
                state: state.topLoading
                    ? MarkerVisualState.loading
                    : (state.topError != null
                          ? MarkerVisualState.error
                          : state.topMarker),
                stitchCount: state.topStitchCount,
                errorMessage: state.topError,
                onLoadStitches: () => vm.loadStitchAbove(state.id),
                onRetry: () => vm.loadStitchAbove(state.id),
              ),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          key: _centerKey,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _MessageRow(
              key: ValueKey(centerRow.message.id),
              columnId: state.id,
              row: centerRow,
              showAuthor: showAuthorById[centerRow.message.id]!,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 70),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (afterRows.isNotEmpty) const SizedBox(height: 4),
              for (int i = 0; i < afterRows.length; i++) ...[
                _MessageRow(
                  key: ValueKey(afterRows[i].message.id),
                  columnId: state.id,
                  row: afterRows[i],
                  showAuthor: showAuthorById[afterRows[i].message.id]!,
                ),
                if (i < afterRows.length - 1) const SizedBox(height: 4),
              ],
              AdaptiveMarker(
                isTop: false,
                state: state.bottomLoading
                    ? MarkerVisualState.loading
                    : (state.bottomError != null
                          ? MarkerVisualState.error
                          : state.bottomMarker),
                stitchCount: state.bottomStitchCount,
                errorMessage: state.bottomError,
                onLoadStitches: () => vm.loadStitchBelow(state.id),
                onRetry: () => vm.loadStitchBelow(state.id),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

String _authorKey(Message message) =>
    message.authorId ?? _MessageRow._defaultAuthorLabel(message.role);

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    super.key,
    required this.columnId,
    required this.row,
    required this.showAuthor,
  });

  final String columnId;
  final MessageRowData row;
  final bool showAuthor;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ColumnsViewModel>();
    final isMe =
        row.message.authorId != null &&
        row.message.authorId == vm.currentUserId;

    // Author label
    final authorLabel = Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        isMe
            ? 'You'
            : row.message.authorId ?? _defaultAuthorLabel(row.message.role),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );

    // Message bubble
    Widget bubble = MessageCard(
      message: row.message,
      currentUserId: vm.currentUserId,
      onReply: () => vm.setReplyTarget(columnId, row.message.id),
    );

    // Nav buttons (if outgoing exists)
    Widget? leftNav;
    Widget? rightNav;
    if (row.outgoing != null) {
      final anchorId = row.outgoingAnchorId!;
      final canPrev = row.outgoingCurrentIndex > 0;
      final canNext =
          row.outgoingCurrentIndex >= 0 &&
          row.outgoingCurrentIndex < row.outgoing!.all.length - 1;
      final prevIsStitch =
          canPrev &&
          (row.outgoingCurrentIndex - 1) >= row.outgoing!.replyOutgoing.length;
      final nextIsStitch =
          canNext &&
          (row.outgoingCurrentIndex + 1) >= row.outgoing!.replyOutgoing.length;

      // `anchorId` is the parent row above — the one row a sibling swap
      // leaves untouched, and exactly what `navigateOutgoing` re-anchors the
      // column's persisted anchor to, so the column's `CustomScrollView`
      // picks it up as the scroll anchor with no extra wiring needed here.
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
          // Mirror image of the sibling case: a parent swap rewrites the
          // context *above* this message and leaves the message itself in
          // place, and `navigateIncoming` re-anchors the column's persisted
          // anchor to this message, so it's picked up as the scroll anchor
          // automatically.
          IncomingNavigator(
            replyCount: row.incoming!.replyIncoming.length,
            stitchCount: row.incoming!.stitchedIncoming.length,
            currentIndex: row.incomingCurrentIndex,
            onPrev: () =>
                vm.navigateIncoming(columnId, row.message.id, forward: false),
            onNext: () =>
                vm.navigateIncoming(columnId, row.message.id, forward: true),
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
                  SizedBox(
                    width: 20,
                    child: leftNav != null ? Center(child: leftNav) : null,
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: bubble),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 20,
                    child: rightNav != null ? Center(child: rightNav) : null,
                  ),
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
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.focusNode,
    this.replyTarget,
    this.onCancelReply,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final FocusNode focusNode;

  /// The message [ColumnsViewModel.sendMessage] will reply under if set —
  /// mirrors the column's `replyingToMessageId` state — shown as a
  /// dismissable indicator above the input.
  final Message? replyTarget;
  final VoidCallback? onCancelReply;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.columnHeaderSurfaceSelected,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (replyTarget != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.reply,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Replying to: ${replyTarget!.content}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: onCancelReply,
                    borderRadius: BorderRadius.circular(10),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          Row(
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
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
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
        ],
      ),
    );
  }
}
