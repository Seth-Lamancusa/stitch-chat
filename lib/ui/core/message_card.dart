import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/message.dart';

/// A single message, free-floating (no background box), full width of its
/// column. Darkens slightly on hover. Role only distinguishes function
/// call/result (a small chip) from everything else — stitch-frontend has no
/// per-role bubble coloring at all (confirmed against `main`), and
/// collapsing function call/result into indistinguishable bot messages
/// would hide real structure, so this is a deliberately small,
/// non-load-bearing exception to otherwise uniform styling.
///
/// [MessageRole.user] alone doesn't say *which* human sent it — multiple
/// human users share that role (`docs/plans/message-tree-data-model.md`
/// §2: `authorId` is the identity field, `role` only the kind). "Is this
/// me" is an `authorId == currentUserId` comparison, not a role check: the
/// author label is bold only for the current user, plain for every other
/// author (human or bot) — the same visual treatment regardless of role.
class MessageCard extends StatelessWidget {
  final Message message;
  final String currentUserId;
  final VoidCallback? onReply;

  const MessageCard({super.key, required this.message, required this.currentUserId, this.onReply});

  @override
  Widget build(BuildContext context) {
    return _MessageBubble(message: message, currentUserId: currentUserId, onReply: onReply);
  }
}

class _MessageBubble extends StatefulWidget {
  final Message message;
  final String currentUserId;
  final VoidCallback? onReply;

  const _MessageBubble({required this.message, required this.currentUserId, this.onReply});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  final LayerLink _layerLink = LayerLink();
  final OverlayPortalController _menuOverlay = OverlayPortalController();

  bool _hoveringCard = false;
  bool _hoveringMenu = false;

  // The "more actions" popup opens via a full-screen (invisible) modal
  // barrier route so it can catch the dismiss-tap. That barrier sits above
  // everything in the Overlay and intercepts hit-testing for the whole
  // screen, so both the toolbar's and the card's MouseRegions fire onExit
  // the instant the popup opens even though the cursor hasn't moved. This
  // flag forces the hovered look while that popup is open, independent of
  // whatever the MouseRegions think is happening underneath it.
  bool _moreMenuOpen = false;

  // The card's own hit box and the menu's hit box don't perfectly abut —
  // the menu is narrower than the card and offset from its edge — so a
  // cursor moving between them can pass through a sliver of neither for a
  // frame or two. Hiding immediately on every exit made that read as a
  // flicker (hide, then re-show with a fresh fade-in) each time the cursor
  // crossed that gap. Debouncing the hide gives the other region a moment
  // to claim the cursor before the menu actually disappears.
  Timer? _hideTimer;

  void _cancelHide() => _hideTimer?.cancel();

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 120), () {
      if (!_hoveringCard && !_hoveringMenu && !_moreMenuOpen) _menuOverlay.hide();
    });
  }

  void _setMoreMenuOpen(bool open) {
    _moreMenuOpen = open;
    if (open) {
      _cancelHide();
      if (!_menuOverlay.isShowing) _menuOverlay.show();
    } else {
      _scheduleHide();
    }
    setState(() {});
  }

  void _enterCard() {
    _hoveringCard = true;
    _cancelHide();
    if (!_menuOverlay.isShowing) _menuOverlay.show();
    setState(() {});
  }

  void _exitCard() {
    _hoveringCard = false;
    _scheduleHide();
    setState(() {});
  }

  void _enterMenu() {
    _hoveringMenu = true;
    _cancelHide();
    setState(() {});
  }

  void _exitMenu() {
    _hoveringMenu = false;
    _scheduleHide();
    setState(() {});
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final message = widget.message;
    final hovering = _hoveringCard || _hoveringMenu || _moreMenuOpen;

    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _menuOverlay,
        // Rendered on the root Overlay rather than in this widget's own
        // Stack: the message list gives each row an exact, non-overlapping
        // slice of the screen, so a menu that merely overflows its own
        // Stack still lands in a *different* list row's hit-test territory
        // and can't be hovered there. Rendering on the Overlay sidesteps
        // list-row boundaries entirely, and keeps rows tightly packed since
        // nothing needs reserved space for the overflow.
        overlayChildBuilder: (context) {
          // Overlay lays out non-Positioned children with tight
          // full-viewport constraints (same mechanism as StackFit.expand).
          // CompositedTransformFollower doesn't loosen those for its child,
          // so without this Positioned wrapper the menu is forced to fill
          // the screen. left/top are irrelevant to where it actually
          // paints — the follower positions itself via a layer transform
          // tied to the anchors below, ignoring normal layout offset.
          return Positioned(
            left: 0,
            top: 0,
            child: CompositedTransformFollower(
              link: _layerLink,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(-8, -20),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 100),
                builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
                child: MouseRegion(
                  onEnter: (_) => _enterMenu(),
                  onExit: (_) => _exitMenu(),
                  child: _MessageActionMenu(
                    content: message.content,
                    onReply: widget.onReply,
                    onMoreMenuOpenChanged: _setMoreMenuOpen,
                  ),
                ),
              ),
            ),
          );
        },
        child: MouseRegion(
          onEnter: (_) => _enterCard(),
          onExit: (_) => _exitCard(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: hovering ? colorScheme.onSurface.withValues(alpha: 0.05) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.role == MessageRole.functionCall || message.role == MessageRole.functionResult)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      message.role == MessageRole.functionCall ? 'FUNCTION CALL' : 'FUNCTION RESULT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                Text(message.content.isEmpty ? '…' : message.content),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A minimal, non-interactive replacement for [Tooltip]. The real [Tooltip]
/// positions itself via the ambient [Overlay], which requires computing a
/// paint transform up to the root — that computation throws when an
/// ancestor is a [CompositedTransformFollower] (as the action menu's
/// buttons are), because the follower's transform isn't known until after
/// painting. This widget never touches the Overlay: the label is just a
/// [Positioned] sibling of [child] within a local, purely-cosmetic [Stack],
/// so it's exempt from that whole problem — nothing needs to hit-test it.
class _HoverLabel extends StatelessWidget {
  const _HoverLabel({required this.message, required this.visible, required this.child});

  final String message;
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        child,
        if (visible)
          Positioned(
            bottom: 28,
            child: IgnorePointer(
              child: Material(
                elevation: 4,
                color: const Color(0xE6212121),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Hover toolbar for a message, floating over the bottom border of the card
/// and right-aligned.
class _MessageActionMenu extends StatelessWidget {
  const _MessageActionMenu({required this.content, this.onReply, required this.onMoreMenuOpenChanged});

  final String content;
  final VoidCallback? onReply;
  final ValueChanged<bool> onMoreMenuOpenChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(6),
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MessageActionButton(icon: Icons.reply, tooltip: 'Reply', onPressed: onReply),
            _CopyButton(content: content),
            _MoreActionButton(onOpenChanged: onMoreMenuOpenChanged),
          ],
        ),
      ),
    );
  }
}

class _MessageActionButton extends StatefulWidget {
  const _MessageActionButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  State<_MessageActionButton> createState() => _MessageActionButtonState();
}

class _MessageActionButtonState extends State<_MessageActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return _HoverLabel(
      message: widget.tooltip,
      visible: _isHovered,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _isHovered ? onSurface.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: widget.onPressed,
              child: Center(
                child: Icon(widget.icon, size: 14, color: onSurface.withValues(alpha: 0.7)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.content});

  final String content;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _isHovered = false;
  bool _copied = false;

  Future<void> _handleTap() async {
    await Clipboard.setData(ClipboardData(text: widget.content));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return _HoverLabel(
      message: _copied ? 'Copied!' : 'Copy',
      visible: _isHovered,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _isHovered ? onSurface.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: _handleTap,
              child: Center(
                child: Icon(
                  _copied ? Icons.check : Icons.copy,
                  size: 14,
                  color: _copied ? Colors.green : onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Contextual "more actions" menu. Items are placeholders so the dropdown
/// styling can be nailed down before real actions exist.
class _MoreActionButton extends StatefulWidget {
  const _MoreActionButton({required this.onOpenChanged});

  final ValueChanged<bool> onOpenChanged;

  @override
  State<_MoreActionButton> createState() => _MoreActionButtonState();
}

class _MoreActionButtonState extends State<_MoreActionButton> {
  bool _isHovered = false;

  // showMenu (rather than PopupMenuButton) so opening/closing can be
  // observed directly via the returned future — PopupMenuButton exposes
  // onOpened but nothing symmetrical for close, and the parent needs both
  // edges to force the card's hover state while this menu is up.
  Future<void> _openMenu(BuildContext context) async {
    widget.onOpenChanged(true);
    final box = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromRect(
      Rect.fromPoints(topLeft, topLeft.translate(box.size.width, box.size.height)),
      Offset.zero & overlay.size,
    );
    try {
      await showMenu<String>(
        context: context,
        position: position,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        items: const [
          PopupMenuItem(value: 'placeholder-1', child: Text('Placeholder')),
          PopupMenuItem(value: 'placeholder-2', child: Text('Placeholder')),
        ],
      );
    } finally {
      if (mounted) widget.onOpenChanged(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return _HoverLabel(
      message: 'More',
      visible: _isHovered,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _isHovered ? onSurface.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => _openMenu(context),
              child: Center(
                child: Icon(Icons.more_horiz, size: 14, color: onSurface.withValues(alpha: 0.7)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
