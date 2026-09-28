import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/logging/stitch_log.dart';
import '../../data/models/message.dart';
import '../../data/services/mock_typing_cue.dart';
import '../../domain/branch_path_service.dart' show Direction;
import '../core/adaptive_marker.dart';
import '../core/incoming_navigator.dart';
import '../core/message_card.dart';
import '../core/outgoing_navigator.dart' show OutgoingNavArrow;
import '../core/theme/app_colors.dart';
import 'column_ui_state.dart';
import 'columns_viewmodel.dart';

/// Vertical gap between consecutive message rows in the list. Shared by
/// every row-to-row boundary — including the center-anchored sliver's
/// boundary with its neighbors, which (due to `CustomScrollView.center`
/// reversing growth direction on the `beforeRows` side) can't reuse the
/// plain inter-row `SizedBox` and instead needs this same value applied
/// as `SliverPadding` inset. Keep every boundary below wired to this one
/// constant rather than a repeated literal.
const double _kMessageRowGap = 2.0;

/// Native folder dialog used by the column cwd editor. Tests replace this
/// so they can return a path without opening a platform dialog.
@visibleForTesting
Future<String?> Function({String? initialDirectory})?
debugColumnDirectoryPicker;

Future<String?> _pickColumnDirectory({String? initialDirectory}) {
  final override = debugColumnDirectoryPicker;
  if (override != null) {
    return override(initialDirectory: initialDirectory);
  }
  return getDirectoryPath(
    initialDirectory: initialDirectory,
    confirmButtonText: 'Select folder',
  );
}

/// One column: header, message list with navigators/markers, composer.
/// Absorbs the old `ChatView`'s bubble rendering and composer, scoped to a
/// single column instead of the whole app.
/// Opens the column cwd dialog and persists the result via [ColumnsViewModel].
Future<void> editColumnCwd(BuildContext context, ColumnUiState state) async {
  final vm = context.read<ColumnsViewModel>();
  final next = await showDialog<String?>(
    context: context,
    builder: (dialogContext) => _CwdPickerDialog(initialPath: state.cwd ?? ''),
  );
  if (next == null) return;
  await vm.updateColumnCwd(state.id, next);
}

/// Folder icon for the column working directory ("environment" picker).
class ColumnCwdIconButton extends StatelessWidget {
  const ColumnCwdIconButton({super.key, required this.state});

  final ColumnUiState state;

  @override
  Widget build(BuildContext context) {
    final cwd = state.cwd;
    final hasCwd = cwd != null && cwd.isNotEmpty;
    return IconButton(
      tooltip: hasCwd ? cwd : 'Set column cwd',
      icon: Icon(
        hasCwd ? Icons.folder : Icons.folder_outlined,
        size: 18,
      ),
      onPressed: () => editColumnCwd(context, state),
    );
  }
}

class ColumnView extends StatefulWidget {
  const ColumnView({
    super.key,
    required this.state,
    this.showCwdInHeader = true,
  });

  final ColumnUiState state;

  /// When false, cwd is expected elsewhere (e.g. single-column overlay).
  final bool showCwdInHeader;

  @override
  State<ColumnView> createState() => _ColumnViewState();
}

class _ColumnViewState extends State<ColumnView> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  bool _wasComposerActive = false;
  String? _wasReplyingToMessageId;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onDraftChanged);
  }

  /// Runs after the current pointer gesture finishes. A single post-frame
  /// callback is too early for message-body taps: [SelectionArea] claims
  /// focus on pointer-up and would steal the caret we just placed.
  void _scheduleComposerFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    });
  }

  /// Activate this column and focus the composer — used for column chrome
  /// taps and message-body taps (message markdown is a [SelectionArea], so
  /// those taps never reach the outer [GestureDetector]).
  void _activateColumn(ColumnsViewModel vm, String columnId) {
    vm.setActiveColumn(columnId);
    _scheduleComposerFocus();
  }

  /// Focus the reply field when the composer appears (column activated or
  /// created) or when an explicit reply target is set on an already-active
  /// column — covers Reply, new column, and click-to-activate without
  /// touching [ColumnsViewModel].
  void _focusComposerWhenShown(ColumnUiState state) {
    if (!state.isActive) {
      _wasComposerActive = false;
      return;
    }
    final composerAppeared = !_wasComposerActive;
    final replyTargetPinned = state.replyingToMessageId != null &&
        state.replyingToMessageId != _wasReplyingToMessageId;
    if (composerAppeared || replyTargetPinned) {
      _scheduleComposerFocus();
    }
    _wasComposerActive = true;
    _wasReplyingToMessageId = state.replyingToMessageId;
  }

  @override
  void dispose() {
    _controller.removeListener(_onDraftChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onDraftChanged() {
    if (!mounted) return;
    context.read<ColumnsViewModel>().onComposerDraftChanged(
          widget.state.id,
          _controller.text,
        );
  }

  void _send(ColumnsViewModel vm) {
    final content = _controller.text;
    vm.retainAuthPromptsAcrossSend(widget.state.id);
    _controller.clear();
    _focusNode.requestFocus();
    vm.sendMessage(widget.state.id, content);
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

    _focusComposerWhenShown(state);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _activateColumn(vm, state.id),
      child: ColoredBox(
        color: state.isActive
            ? colorScheme.onSurface.withValues(alpha: 0.03)
            : Colors.transparent,
        child: Column(
          children: [
            _Header(
              state: state,
              showCwdInHeader: widget.showCwdInHeader,
              onClose: () => vm.removeColumn(state.id),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _MessageList(
                      state: state,
                      onColumnBodyTap: () => _activateColumn(vm, state.id),
                    ),
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
                        cwdWarningBotIds: state.cwdWarningBotIds,
                        cwdWarningPhase: state.cwdWarningPhase,
                        authPrompts: state.authPrompts,
                        onSignIn: vm.beginBotAuth,
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
  const _Header({
    required this.state,
    required this.onClose,
    this.showCwdInHeader = true,
  });

  final ColumnUiState state;
  final VoidCallback onClose;
  final bool showCwdInHeader;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final headerColor = state.isActive
        ? context.appColors.columnHeaderSurfaceSelected
        : context.appColors.columnHeaderSurface;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: headerColor,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
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
          ),
          if (showCwdInHeader) ColumnCwdIconButton(state: state),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// Column cwd editor. The path is chosen with the platform folder dialog
/// and shown read-only; empty string means clear.
class _CwdPickerDialog extends StatefulWidget {
  const _CwdPickerDialog({required this.initialPath});

  final String initialPath;

  @override
  State<_CwdPickerDialog> createState() => _CwdPickerDialogState();
}

class _CwdPickerDialogState extends State<_CwdPickerDialog> {
  late String _path = widget.initialPath;
  bool _picking = false;
  String? _error;

  Future<void> _pick() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    String? picked;
    Object? failure;
    StackTrace? stack;
    try {
      final initial = _path.trim();
      picked = await _pickColumnDirectory(
        initialDirectory: initial.isEmpty ? null : initial,
      );
    } catch (error, trace) {
      failure = error;
      stack = trace;
    }
    if (!mounted) return;
    if (failure != null) {
      StitchLog.warning(
        'column cwd folder picker failed',
        tag: 'dart.column',
        error: failure,
        stackTrace: stack,
      );
    }
    setState(() {
      _picking = false;
      _error = failure == null ? null : 'Could not open the folder picker';
      if (picked != null) _path = picked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasPath = _path.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('Column cwd'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              hasPath ? _path : 'No folder selected',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: hasPath
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _picking ? null : _pick,
                icon: const Icon(Icons.folder_open),
                label: Text(hasPath ? 'Change folder' : 'Choose folder'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: colorScheme.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (hasPath)
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('Clear'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_path),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Scroll controller that can arm a one-shot pin-preservation correction
/// consumed during the next [ScrollPosition.applyContentDimensions].
///
/// Used by [_MessageListState.navigatePreservingPin] so relocating
/// `CustomScrollView.center` onto a message doesn't flash for a frame the
/// way a post-layout [ScrollPosition.jumpTo] would.
class _PinPreservingScrollController extends ScrollController {
  double? _targetPixels;
  bool _alignToMinScrollExtent = false;

  /// Arm a correction consumed on the next [ScrollPosition.applyContentDimensions].
  ///
  /// Pass [targetPixels] for an explicit offset (persisted restore, fork pin).
  /// Pass [alignToMinScrollExtent] when the anchor is the first visible row so
  /// the before-[center] block (top marker) sits flush with the viewport top;
  /// the exact [ScrollPosition.minScrollExtent] is only known once sliver
  /// heights are measured during that same layout pass — still before paint,
  /// not a post-frame [jumpTo].
  void armPinPreservation({
    double? targetPixels,
    bool alignToMinScrollExtent = false,
  }) {
    assert(targetPixels == null || !alignToMinScrollExtent);
    _targetPixels = targetPixels;
    _alignToMinScrollExtent = alignToMinScrollExtent;
  }

  ({double? targetPixels, bool alignToMinScrollExtent}) takeArmedCorrection() {
    final correction = (
      targetPixels: _targetPixels,
      alignToMinScrollExtent: _alignToMinScrollExtent,
    );
    _targetPixels = null;
    _alignToMinScrollExtent = false;
    return correction;
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _PinPreservingScrollPosition(
      physics: physics,
      context: context,
      oldPosition: oldPosition,
      takeArmedCorrection: takeArmedCorrection,
    );
  }
}

class _PinPreservingScrollPosition extends ScrollPositionWithSingleContext {
  _PinPreservingScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    required this.takeArmedCorrection,
  });

  final ({double? targetPixels, bool alignToMinScrollExtent})
      Function() takeArmedCorrection;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    // Run the normal extent update first so extents reflect this layout
    // pass. Returning false below tells [RenderViewport] to re-layout with
    // the corrected offset before paint — the RetainableScrollPosition
    // pattern.
    final applied = super.applyContentDimensions(
      minScrollExtent,
      maxScrollExtent,
    );
    final correction = takeArmedCorrection();
    final target = correction.alignToMinScrollExtent
        ? minScrollExtent
        : correction.targetPixels;
    if (target == null) return applied;

    final clamped = target.clamp(minScrollExtent, maxScrollExtent);
    if ((clamped - pixels).abs() < 0.5) return applied;

    correctPixels(clamped);
    return false;
  }
}

class _MessageList extends StatefulWidget {
  const _MessageList({
    super.key,
    required this.state,
    required this.onColumnBodyTap,
  });

  final ColumnUiState state;
  final VoidCallback onColumnBodyTap;

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  static const Duration _scrollSaveDebounce = Duration(milliseconds: 400);

  // How close to an edge (in pixels) triggers an auto-load of the next
  // batch — per `docs/plans/message-loading-plan.md` §7's intersection-
  // observer-style margin.
  static const double _loadMoreMargin = 200;

  final _scrollController = _PinPreservingScrollController();
  bool _initialScrollCorrectionArmed = false;
  Timer? _scrollSaveTimer;

  // Identifies the pinned *slot* in the sliver list passed to
  // `CustomScrollView.center` — not the anchor message itself, which
  // changes across builds as the user navigates forks. Because slivers
  // before this key grow backward (negative offset) and slivers after it
  // grow forward, whichever row currently lands in the center sliver simply
  // never moves on screen when content on either side is replaced by a
  // fork switch — provided that row was already the center. Relocating
  // which message occupies this slot (first outgoing/incoming switch)
  // still needs a one-shot scroll correction; see [navigatePreservingPin].
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

  /// Sibling/parent navigator entry point: run [action] (which re-anchors the
  /// column onto [pinMessageId] and rebuilds the branch), then correct the
  /// scroll offset if that re-anchor moved [pinMessageId] on screen.
  ///
  /// `CustomScrollView.center` keeps a *slot* fixed, not a message. When the
  /// pin is already the center row, [action] only swaps content around it and
  /// no correction is needed. When the center was still some other row (the
  /// typical first outgoing switch, center = leaf), [action] puts
  /// [pinMessageId] into that slot and the pin's screen Y would change. We
  /// precompute the target [ScrollPosition.pixels] from the pin's and
  /// viewport's global Y *before* [action], arm it afterward, and let the
  /// next [ScrollPosition.applyContentDimensions] `correctPixels` + return
  /// false so the viewport re-lays out before paint (no post-frame flash).
  Future<void> navigatePreservingPin({
    required String pinMessageId,
    required Future<void> Function() action,
  }) {
    return _navigatePreservingPin(
      pinMessageId: pinMessageId,
      action: action,
    );
  }

  Future<void> _navigatePreservingPin({
    required String pinMessageId,
    required Future<void> Function() action,
  }) async {
    // Measure before [action] while size access is legal. After the pin
    // becomes the center sliver (anchor 0, AxisDirection.down), its top
    // paints at `viewportTop - pixels`, so this target puts it back at
    // [yBefore]. Applied during layout via [correctPixels] — not a
    // post-frame [jumpTo] — so there's no one-frame flash.
    final yBefore = _messageTopY(pinMessageId);
    final viewportTop = _viewportTopY();

    await action();
    if (!mounted || yBefore == null || viewportTop == null) return;

    // Arm *after* [action] returns: [notifyListeners] has only marked the
    // tree dirty — the rebuild/layout that consumes this correction hasn't
    // run yet. Arming before the await would risk an intervening frame
    // (during the async nav) consuming the pending correction against the
    // still-old branch.
    _scrollController.armPinPreservation(
      targetPixels: viewportTop - yBefore,
    );
    await WidgetsBinding.instance.endOfFrame;
  }

  /// Top edge of the scrollable viewport in global coordinates.
  double? _viewportTopY() {
    if (!_scrollController.hasClients) return null;
    final box = _scrollController.position.context.notificationContext
        ?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero).dy;
  }

  /// Top edge of the row for [messageId] in global coordinates, or null if
  /// that row isn't laid out under this list yet.
  double? _messageTopY(String messageId) {
    final key = ValueKey<String>(messageId);
    Element? match;
    void visitor(Element element) {
      if (match != null) return;
      if (element.widget.key == key) {
        match = element;
        return;
      }
      element.visitChildren(visitor);
    }

    context.visitChildElements(visitor);
    final box = match?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero).dy;
  }

  void _onScroll() {
    _scheduleScrollSave();
    _maybeTriggerLoadMore();
  }

  // Scroll-proximity auto-trigger for a `waiting` marker: fires
  // `extendAbove`/`extendBelow` once the viewport comes within
  // `_loadMoreMargin` of an edge that has more to load. Re-entrancy is
  // guarded by `topLoading`/`bottomLoading`, which `ColumnsViewModel`
  // flips synchronously before its first await — so a scroll frame arriving
  // before the triggered load completes just sees loading == true and
  // skips.
  void _maybeTriggerLoadMore() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final state = widget.state;
    final vm = context.read<ColumnsViewModel>();
    if (state.topMarker == MarkerVisualState.waiting &&
        !state.topLoading &&
        position.pixels - position.minScrollExtent <= _loadMoreMargin) {
      vm.extendAbove(state.id);
    }
    if (state.bottomMarker == MarkerVisualState.waiting &&
        !state.bottomLoading &&
        position.maxScrollExtent - position.pixels <= _loadMoreMargin) {
      vm.extendBelow(state.id);
    }
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

  /// One-shot scroll target consumed during the next
  /// [ScrollPosition.applyContentDimensions] — same path as
  /// [navigatePreservingPin], not a post-frame [jumpTo].
  ///
  /// When the anchor is the first visible row, offset `0` pins the anchor
  /// message to the viewport top and hides the top [AdaptiveMarker] in the
  /// before-[center] sliver; [alignToMinScrollExtent] uses the laid-out
  /// [ScrollPosition.minScrollExtent] during the same layout pass.
  void _armInitialScrollCorrectionIfNeeded({
    required int anchorIndex,
    required ColumnUiState state,
  }) {
    if (_initialScrollCorrectionArmed) return;
    _initialScrollCorrectionArmed = true;

    final persisted = state.initialScrollOffset;
    if (persisted != null) {
      _scrollController.armPinPreservation(targetPixels: persisted);
    } else if (anchorIndex == 0) {
      _scrollController.armPinPreservation(alignToMinScrollExtent: true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeTriggerLoadMore();
    });
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

    // The persisted anchor (`ColumnsViewModel.anchorOf`) is already exactly
    // the row that must stay visually fixed across a fork switch:
    // `navigateOutgoing`/`navigateIncoming` re-anchor it to `parentId`/
    // `childId` respectively — the one row each swap leaves untouched. It's
    // guaranteed present in `state.rows` because `materializedTrajectory`
    // always builds `[...above, anchor, ...below]` from this same id, and
    // `state.rows` is only non-empty when an anchor exists (see the
    // early-return above).
    final anchorId = vm.anchorOf(state.id);
    var anchorIndex = state.rows.indexWhere(
      (r) => r.message.id == anchorId,
    );
    // If anchor isn't on this branch (stale id / mid-update), pin to the tip.
    if (anchorIndex == -1) {
      anchorIndex = state.rows.length - 1;
    }

    final showAuthorById = <String, bool>{
      for (int i = 0; i < state.rows.length; i++)
        state.rows[i].message.id:
            i == 0 ||
            _authorKey(state.rows[i].message) !=
                _authorKey(state.rows[i - 1].message),
    };

    // Slivers listed before `center` grow backward (negative offset). The
    // before-column is laid out top→bottom inside a single box whose bottom
    // edge sits on the center, so chronological order (oldest first) puts
    // the row immediately above the anchor last in that column.
    final centerRow = state.rows[anchorIndex];
    final afterRows = state.rows.sublist(anchorIndex + 1);

    final centerGapAbove = anchorIndex > 0 ? _kMessageRowGap : 0.0;
    final centerGapBelow = afterRows.isNotEmpty ? _kMessageRowGap : 0.0;

    _armInitialScrollCorrectionIfNeeded(
      anchorIndex: anchorIndex,
      state: state,
    );

    // Eager columns inside SliverToBoxAdapters — not SliverList. A list
    // sliver only lays out the cache window and *estimates* the rest from
    // average child height; tall fenced code blocks make that estimate
    // wildly wrong, so the scrollbar jumps as they enter/leave view. The
    // branch window is already bounded, so measuring every row is cheap,
    // and `center` still pins the anchor across fork switches.
    final beforeChildren = <Widget>[
      AdaptiveMarker(
        isTop: true,
        state: state.topLoading
            ? MarkerVisualState.loading
            : (state.topError != null
                  ? MarkerVisualState.error
                  : state.topMarker),
        stitchCount: state.topStitchCount,
        hiddenCount: state.topHiddenCount,
        errorMessage: state.topError,
        onLoadStitches: () => vm.revealStitch(
          state.id,
          state.rows.first.message.id,
          Direction.incoming,
        ),
        onRevealHidden: () => vm.loadHiddenAbove(state.id),
        onRetry: () => vm.extendAbove(state.id),
      ),
      // Chronological order: oldest at the top of this box. The box sits
      // above `center`, so its last child is the row immediately above
      // the anchor.
      for (int i = 0; i < anchorIndex; i++) ...[
        const SizedBox(height: _kMessageRowGap),
        _MessageRow(
          key: ValueKey(state.rows[i].message.id),
          columnId: state.id,
          row: state.rows[i],
          showAuthor: showAuthorById[state.rows[i].message.id]!,
          onColumnBodyTap: widget.onColumnBodyTap,
        ),
      ],
    ];

    final afterChildren = <Widget>[
      for (int i = 0; i < afterRows.length; i++) ...[
        if (i == 0 && centerGapBelow > 0)
          const SizedBox(height: _kMessageRowGap),
        _MessageRow(
          key: ValueKey(afterRows[i].message.id),
          columnId: state.id,
          row: afterRows[i],
          showAuthor: showAuthorById[afterRows[i].message.id]!,
          onColumnBodyTap: widget.onColumnBodyTap,
        ),
        if (i < afterRows.length - 1) const SizedBox(height: _kMessageRowGap),
      ],
      AdaptiveMarker(
        isTop: false,
        state: state.bottomLoading
            ? MarkerVisualState.loading
            : (state.bottomError != null
                  ? MarkerVisualState.error
                  : state.bottomMarker),
        stitchCount: state.bottomStitchCount,
        hiddenCount: state.bottomHiddenCount,
        errorMessage: state.bottomError,
        onLoadStitches: () => vm.revealStitch(
          state.id,
          state.rows.last.message.id,
          Direction.outgoing,
        ),
        onRevealHidden: () => vm.loadHiddenBelow(state.id),
        onRetry: () => vm.extendBelow(state.id),
      ),
    ];

    return CustomScrollView(
      controller: _scrollController,
      center: _centerKey,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, centerGapAbove),
          sliver: SliverToBoxAdapter(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: beforeChildren,
            ),
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
              onColumnBodyTap: widget.onColumnBodyTap,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 70),
          sliver: SliverToBoxAdapter(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: afterChildren,
            ),
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
    required this.onColumnBodyTap,
  });

  final String columnId;
  final MessageRowData row;
  final bool showAuthor;
  final VoidCallback onColumnBodyTap;

  Future<void> _navigateOutgoing(
    BuildContext context,
    String anchorId, {
    required bool forward,
  }) {
    final list = context.findAncestorStateOfType<_MessageListState>();
    final nav = context.read<ColumnsViewModel>().navigateOutgoing;
    if (list == null) {
      return nav(columnId, anchorId, forward: forward);
    }
    return list.navigatePreservingPin(
      pinMessageId: anchorId,
      action: () => nav(columnId, anchorId, forward: forward),
    );
  }

  Future<void> _navigateIncoming(
    BuildContext context, {
    required bool forward,
  }) {
    final list = context.findAncestorStateOfType<_MessageListState>();
    final nav = context.read<ColumnsViewModel>().navigateIncoming;
    if (list == null) {
      return nav(columnId, row.message.id, forward: forward);
    }
    return list.navigatePreservingPin(
      pinMessageId: row.message.id,
      action: () => nav(columnId, row.message.id, forward: forward),
    );
  }

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

    // Message bubble — strip mock-typing markers from displayed content;
    // when STITCH_MOCK_TYPING_CUES is on, those markers also feed typingAuthors.
    Widget bubble = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerUp: (_) => onColumnBodyTap(),
      child: MessageCard(
        message: MockTypingCue.forDisplay(row.message),
        currentUserId: vm.currentUserId,
        onReply: () => vm.setReplyTarget(columnId, row.message.id),
        typingAuthors: vm.typingAuthorsFor(row.message),
      ),
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
      // Stitch candidates follow hidden + non-hidden replies in `.all`.
      final stitchStart = row.outgoing!.hiddenReplyOutgoing.length +
          row.outgoing!.replyOutgoing.length;
      final prevIsStitch =
          canPrev && (row.outgoingCurrentIndex - 1) >= stitchStart;
      final nextIsStitch =
          canNext && (row.outgoingCurrentIndex + 1) >= stitchStart;

      // `anchorId` is the parent row above — the one row a sibling swap
      // leaves untouched, and exactly what `navigateOutgoing` re-anchors the
      // column's persisted anchor to, so the column's `CustomScrollView`
      // picks it up as the scroll anchor with no extra wiring needed here.
      leftNav = OutgoingNavArrow(
        icon: Icons.chevron_left,
        enabled: canPrev,
        loading: false,
        isStitch: prevIsStitch,
        onPressed: () => _navigateOutgoing(context, anchorId, forward: false),
        tooltip: 'Previous',
      );

      rightNav = OutgoingNavArrow(
        icon: Icons.chevron_right,
        enabled: canNext,
        loading: false,
        isStitch: nextIsStitch,
        onPressed: () => _navigateOutgoing(context, anchorId, forward: true),
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
            hiddenCount: row.incoming!.hiddenReplyIncoming.length,
            replyCount: row.incoming!.replyIncoming.length,
            stitchCount: row.incoming!.stitchedIncoming.length,
            currentIndex: row.incomingCurrentIndex,
            onPrev: () => _navigateIncoming(context, forward: false),
            onNext: () => _navigateIncoming(context, forward: true),
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Author label row — only for the topmost message of a consecutive
            // same-author run.
            if (showAuthor)
              Padding(
                padding: const EdgeInsets.only(left: 22, right: 22),
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
                  const SizedBox(width: 2),
                  Expanded(child: bubble),
                  const SizedBox(width: 2),
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
      case MessageRole.thinking:
        return 'thinking';
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
    this.cwdWarningBotIds = const [],
    this.cwdWarningPhase = CwdWarningPhase.none,
    this.authPrompts = const [],
    this.onSignIn,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final FocusNode focusNode;

  /// The message [ColumnsViewModel.sendMessage] will reply under if set —
  /// mirrors the column's `replyingToMessageId` state — shown as a
  /// dismissable indicator above the input.
  final Message? replyTarget;
  final VoidCallback? onCancelReply;
  final List<String> cwdWarningBotIds;
  final CwdWarningPhase cwdWarningPhase;
  final List<BotAuthPrompt> authPrompts;
  final void Function(String botId)? onSignIn;

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
          _AuthPromptBanner(
            prompts: authPrompts,
            onSignIn: onSignIn,
          ),
          _CwdWarningBanner(
            botIds: cwdWarningBotIds,
            phase: cwdWarningPhase,
          ),
          if (replyTarget != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.reply,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        children: [
                          const TextSpan(text: 'Replying to '),
                          TextSpan(text: replyTarget!.content),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  // Ctrl+Shift+V ("paste plain") — used by dictation tools
                  // like Vibe Typer. Flutter only binds Ctrl+V / Shift+Insert.
                  child: Shortcuts(
                    shortcuts: const <ShortcutActivator, Intent>{
                      SingleActivator(
                        LogicalKeyboardKey.keyV,
                        control: true,
                        shift: true,
                      ): PasteTextIntent(SelectionChangedCause.keyboard),
                    },
                    // Own FocusNode stays on TextField only — sharing it with
                    // this Focus wrapper reparents the node onto itself
                    // ("Tried to make a child into a parent of itself").
                    child: Focus(
                      onKeyEvent: (node, event) {
                        if (event is! KeyDownEvent) {
                          return KeyEventResult.ignored;
                        }
                        final key = event.logicalKey;
                        final isEnter = key == LogicalKeyboardKey.enter ||
                            key == LogicalKeyboardKey.numpadEnter;
                        if (isEnter &&
                            !HardwareKeyboard.instance.isShiftPressed) {
                          onSend();
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.send,
                        minLines: 1,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          hintText: 'Say something…',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
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

/// Sign-in prompt for bots that advertise `requires_auth`. Stays until the
/// bridge reports `authenticated`.
class _AuthPromptBanner extends StatelessWidget {
  const _AuthPromptBanner({
    required this.prompts,
    this.onSignIn,
  });

  final List<BotAuthPrompt> prompts;
  final void Function(String botId)? onSignIn;

  @override
  Widget build(BuildContext context) {
    if (prompts.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final prompt in prompts)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: _AuthPromptBody(prompt: prompt)),
                  if (prompt.state == 'unauthenticated')
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: TextButton(
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        onPressed: onSignIn == null ? null : () => onSignIn!(prompt.botId),
                        child: const Text('Sign in'),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AuthPromptBody extends StatelessWidget {
  const _AuthPromptBody({required this.prompt});

  final BotAuthPrompt prompt;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final style = TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant);
    final tag = '@${prompt.botId}';
    switch (prompt.state) {
      case 'pending':
        return Text('Signing in to $tag…', style: style);
      case 'unavailable':
        return Text(
          prompt.detail ?? 'This bot is not available in this build.',
          style: style,
        );
      default:
        return Text('Sign in to $tag to get a reply.', style: style);
    }
  }
}

/// Keeps the last warning copy visible while opacity animates out.
class _CwdWarningBanner extends StatefulWidget {
  const _CwdWarningBanner({
    required this.botIds,
    required this.phase,
  });

  final List<String> botIds;
  final CwdWarningPhase phase;

  @override
  State<_CwdWarningBanner> createState() => _CwdWarningBannerState();
}

class _CwdWarningBannerState extends State<_CwdWarningBanner> {
  List<String> _botIds = const [];
  CwdWarningPhase _phase = CwdWarningPhase.none;
  double _opacity = 0;

  @override
  void didUpdateWidget(covariant _CwdWarningBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.phase != CwdWarningPhase.none && widget.botIds.isNotEmpty) {
      setState(() {
        _botIds = widget.botIds;
        _phase = widget.phase;
        _opacity = 1;
      });
    } else if (widget.phase == CwdWarningPhase.none && _opacity > 0) {
      setState(() => _opacity = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == CwdWarningPhase.none && _opacity == 0) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 400),
      onEnd: () {
        if (_opacity == 0 && mounted) {
          setState(() {
            _phase = CwdWarningPhase.none;
            _botIds = const [];
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_outlined,
              size: 14,
              color: colorScheme.tertiary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _cwdWarningText(_botIds, _phase),
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _cwdWarningText(List<String> botIds, CwdWarningPhase phase) {
    final tags = botIds.map((id) => '@$id').join(', ');
    final plural = botIds.length > 1;
    return switch (phase) {
      CwdWarningPhase.advisory =>
        '$tags won\'t respond unless you set a cwd on this column.',
      CwdWarningPhase.sent => plural
          ? '$tags aren\'t going to respond.'
          : '$tags isn\'t going to respond.',
      CwdWarningPhase.none => '',
    };
  }
}
