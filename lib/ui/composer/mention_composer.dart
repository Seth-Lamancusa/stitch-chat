import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/models/message.dart';
import '../../data/services/cloud_user_directory.dart';
import '../columns/columns_viewmodel.dart';
import '../core/author_identity_badges.dart';
import 'draft_highlight_editing_controller.dart';

enum _MentionKind { localBot, cloudUser }

class _MentionSuggestion {
  const _MentionSuggestion({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.recipientId,
    this.cloudIsBot = false,
  });

  final String tag;
  final String title;
  final String subtitle;
  final _MentionKind kind;
  final String recipientId;
  final bool cloudIsBot;
}

/// `@` mention autocomplete + draft `#`/`@` highlighting.
///
/// List membership lives on [ColumnsViewModel] draft settings (SSoT). Token
/// colors are applied via [DraftHighlightEditingController.buildTextSpan] —
/// same contract as stitch-frontend ReplyBox.
class MentionComposer extends StatefulWidget {
  const MentionComposer({
    super.key,
    required this.columnId,
    required this.controller,
    required this.focusNode,
    required this.style,
    required this.decoration,
  });

  final String columnId;
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle? style;
  final InputDecoration decoration;

  @override
  State<MentionComposer> createState() => _MentionComposerState();
}

class _MentionComposerState extends State<MentionComposer> {
  final LayerLink _layerLink = LayerLink();
  final OverlayPortalController _menuOverlay = OverlayPortalController();
  final Object _tapRegionGroup = Object();
  final ScrollController _menuScrollController = ScrollController();

  Timer? _debounce;
  List<_MentionSuggestion> _suggestions = const [];
  bool _cloudLoading = false;
  int _anchorStart = -1;
  bool _menuDismissed = false;
  int _selectedIndex = 0;

  static const double _suggestionRowExtent = 52;

  KeyEventResult Function(FocusNode, KeyEvent)? _priorFocusOnKeyEvent;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    // Attach on the field's FocusNode so Tab is handled before focus traversal.
    _priorFocusOnKeyEvent = widget.focusNode.onKeyEvent;
    widget.focusNode.onKeyEvent = _onFocusKeyEvent;
  }

  @override
  void didUpdateWidget(covariant MentionComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) return;
    oldWidget.focusNode.onKeyEvent = _priorFocusOnKeyEvent;
    _priorFocusOnKeyEvent = widget.focusNode.onKeyEvent;
    widget.focusNode.onKeyEvent = _onFocusKeyEvent;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _menuScrollController.dispose();
    widget.controller.removeListener(_onTextChanged);
    if (widget.focusNode.onKeyEvent == _onFocusKeyEvent) {
      widget.focusNode.onKeyEvent = _priorFocusOnKeyEvent;
    }
    super.dispose();
  }

  KeyEventResult _onFocusKeyEvent(FocusNode node, KeyEvent event) {
    final result = _onComposerKeyEvent(node, event);
    if (result != KeyEventResult.ignored) return result;
    return _priorFocusOnKeyEvent?.call(node, event) ?? KeyEventResult.ignored;
  }

  void _setSuggestions(List<_MentionSuggestion> next) {
    _suggestions = next;
    _selectedIndex = next.isEmpty ? 0 : _selectedIndex.clamp(0, next.length - 1);
  }

  void _moveSelection(int delta) {
    if (_suggestions.isEmpty) return;
    setState(() {
      _selectedIndex =
          (_selectedIndex + delta).clamp(0, _suggestions.length - 1);
    });
    _scrollSelectedIntoView();
  }

  void _scrollSelectedIntoView() {
    if (!_menuScrollController.hasClients) return;
    final target = _selectedIndex * _suggestionRowExtent;
    final viewTop = _menuScrollController.offset;
    final viewBottom = viewTop + _menuScrollController.position.viewportDimension;
    if (target < viewTop) {
      _menuScrollController.jumpTo(target);
    } else if (target + _suggestionRowExtent > viewBottom) {
      _menuScrollController.jumpTo(
        math.max(0, target + _suggestionRowExtent - _menuScrollController.position.viewportDimension),
      );
    }
  }

  KeyEventResult _onComposerKeyEvent(FocusNode node, KeyEvent event) {
    if (!_shouldShowMenu || _suggestions.isEmpty) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveSelection(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveSelection(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab &&
        !HardwareKeyboard.instance.isShiftPressed) {
      final index = _selectedIndex.clamp(0, _suggestions.length - 1);
      _insertMention(_suggestions[index]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      setState(() => _menuDismissed = true);
      _syncMenuOverlay();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool get _shouldShowMenu =>
      !_menuDismissed &&
      _anchorStart >= 0 &&
      (_cloudLoading || _suggestions.isNotEmpty);

  void _dismissMenuFromOutsideTap() {
    if (!_shouldShowMenu) return;
    setState(() => _menuDismissed = true);
    _syncMenuOverlay();
  }

  void _syncMenuOverlay() {
    if (!mounted) return;
    if (_shouldShowMenu) {
      if (!_menuOverlay.isShowing) _menuOverlay.show();
    } else if (_menuOverlay.isShowing) {
      _menuOverlay.hide();
    }
  }

  ({int anchorStart, String query})? _activeMentionAtCursor() {
    final text = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) return null;

    final before = text.substring(0, cursor);
    final at = before.lastIndexOf('@');
    if (at < 0) return null;

    if (at > 0) {
      final prev = before[at - 1];
      if (prev != ' ' && prev != '\n' && prev != '(' && prev != '[' && prev != '{') {
        return null;
      }
    }

    final fragment = before.substring(at + 1);
    if (fragment.contains(' ') || fragment.contains('\n')) return null;

    return (anchorStart: at, query: fragment);
  }

  List<_MentionSuggestion> _localSuggestions(ColumnsViewModel vm, String query) {
    final registry = vm.botRegistry;
    final tags = registry.searchTagSuggestions(query);
    return [
      for (final tag in tags)
        _MentionSuggestion(
          tag: tag,
          title: tag,
          subtitle: registry.botIdForTag(tag) ?? tag,
          kind: _MentionKind.localBot,
          recipientId: registry.botIdForTag(tag) ?? tag,
        ),
    ];
  }

  Future<void> _refreshCloudSuggestions(ColumnsViewModel vm, String query) async {
    if (!vm.cloudFeaturesEnabled || query.isEmpty) {
      if (!mounted) return;
      setState(() => _cloudLoading = false);
      _syncMenuOverlay();
      return;
    }

    final directory = context.read<CloudUserDirectory>();
    setState(() => _cloudLoading = true);
    _syncMenuOverlay();

    final results = await directory.search(query);
    if (!mounted) return;

    final active = _activeMentionAtCursor();
    if (active == null || active.query != query) return;

    final localTags = vm.botRegistry
        .searchTagSuggestions(query)
        .map((t) => t.toLowerCase())
        .toSet();

    final cloud = <_MentionSuggestion>[
      for (final user in results)
        if (user.userTag != null && user.userTag!.isNotEmpty)
          if (!localTags.contains(user.userTag!.toLowerCase()))
            _MentionSuggestion(
              tag: user.userTag!,
              title: user.displayName ?? user.userTag!,
              subtitle: '@${user.userTag}',
              kind: _MentionKind.cloudUser,
              recipientId: user.uid,
              cloudIsBot: user.isBot,
            ),
    ];

    setState(() {
      _cloudLoading = false;
      _setSuggestions([..._localSuggestions(vm, query), ...cloud]);
    });
    _syncMenuOverlay();
  }

  void _onTextChanged() {
    final vm = context.read<ColumnsViewModel>();
    final active = _activeMentionAtCursor();
    if (active == null) {
      _debounce?.cancel();
      setState(() {
        _setSuggestions(const []);
        _anchorStart = -1;
        _cloudLoading = false;
      });
      _syncMenuOverlay();
      return;
    }

    _anchorStart = active.anchorStart;
    _debounce?.cancel();

    final local = _localSuggestions(vm, active.query);
    setState(() {
      _menuDismissed = false;
      _selectedIndex = 0;
      _setSuggestions(local);
      _cloudLoading = false;
    });
    _syncMenuOverlay();

    _debounce = Timer(const Duration(milliseconds: 200), () {
      _refreshCloudSuggestions(vm, active.query);
    });
  }

  Future<void> _insertMention(_MentionSuggestion suggestion) async {
    final tag = suggestion.tag;
    if (tag.isEmpty) return;
    final text = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset;
    final start = _anchorStart >= 0 ? _anchorStart : cursor;
    final end = cursor;
    final next = '${text.substring(0, start)}@$tag ${text.substring(end)}';
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + tag.length + 2),
    );

    final vm = context.read<ColumnsViewModel>();
    if (suggestion.kind == _MentionKind.cloudUser) {
      final directory = context.read<CloudUserDirectory>();
      final profile = await directory.findByUserTag(tag);
      if (!mounted) return;
      vm.ensureComposerMention(
        columnId: widget.columnId,
        recipientId: profile?.uid ?? suggestion.recipientId,
        kind: RecipientKind.cloudUser,
        userTag: tag,
        isCloudBot: profile?.isBot ?? suggestion.cloudIsBot,
        profile: profile,
      );
    } else {
      vm.ensureComposerMention(
        columnId: widget.columnId,
        recipientId: suggestion.recipientId,
        kind: RecipientKind.localBot,
        userTag: tag,
      );
    }

    setState(() {
      _setSuggestions(const []);
      _anchorStart = -1;
      _cloudLoading = false;
      _selectedIndex = 0;
    });
    _syncMenuOverlay();
  }

  Widget _menuShell(BuildContext context, {required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      color: colorScheme.surface,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: child,
      ),
    );
  }

  Widget _suggestionRow(_MentionSuggestion suggestion, {required bool selected}) {
    final colorScheme = Theme.of(context).colorScheme;
    final badges = switch (suggestion.kind) {
      _MentionKind.localBot => const MentionSuggestionBadges.localBridgeBot(),
      _MentionKind.cloudUser =>
        MentionSuggestionBadges.cloudUser(isBot: suggestion.cloudIsBot),
    };

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () => _insertMention(suggestion),
        onHover: (hovering) {
          if (!hovering) return;
          final index = _suggestions.indexOf(suggestion);
          if (index < 0 || index == _selectedIndex) return;
          setState(() => _selectedIndex = index);
        },
        child: ColoredBox(
          color: selected
              ? colorScheme.primaryContainer.withValues(alpha: 0.45)
              : Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suggestion.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        suggestion.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                badges,
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _menuOverlay,
        overlayChildBuilder: (context) {
          if (!_shouldShowMenu) return const SizedBox.shrink();

          return Positioned(
            left: 0,
            top: 0,
            child: CompositedTransformFollower(
              link: _layerLink,
              targetAnchor: Alignment.topLeft,
              followerAnchor: Alignment.bottomLeft,
              offset: const Offset(0, -6),
              showWhenUnlinked: false,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 100),
                builder: (context, opacity, child) =>
                    Opacity(opacity: opacity, child: child),
                child: TapRegion(
                  groupId: _tapRegionGroup,
                  child: _menuShell(
                    context,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320, maxHeight: 220),
                      child: _cloudLoading && _suggestions.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: _menuScrollController,
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: _suggestions.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              color: Theme.of(context).colorScheme.outlineVariant,
                            ),
                            itemBuilder: (context, index) =>
                                _suggestionRow(
                                  _suggestions[index],
                                  selected: index == _selectedIndex,
                                ),
                          ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        child: TapRegion(
          groupId: _tapRegionGroup,
          onTapOutside: (_) => _dismissMenuFromOutsideTap(),
          child: Consumer<ColumnsViewModel>(
            builder: (context, vm, _) {
              final controller = widget.controller;
              if (controller is DraftHighlightEditingController) {
                controller.setHighlights(
                  mentions: vm.draftHighlightMentions(widget.columnId),
                  tags: vm.draftHighlightTags(widget.columnId),
                );
              }
              return TextField(
                controller: controller,
                focusNode: widget.focusNode,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                minLines: 1,
                maxLines: 8,
                style: (widget.style ?? const TextStyle()).copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.4,
                ),
                cursorColor: Theme.of(context).colorScheme.primary,
                decoration: widget.decoration,
              );
            },
          ),
        ),
      ),
    );
  }
}
