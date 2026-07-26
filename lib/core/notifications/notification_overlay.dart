import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'notification_service.dart';

/// Wraps the app content and renders whatever [NotificationService] is
/// currently holding: at most one blocking banner above the content, plus a
/// stack of auto-dismissing toasts in the corner.
class NotificationOverlay extends StatelessWidget {
  final Widget child;
  const NotificationOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<NotificationService>();
    final blocking = service.blocking;
    final toasts = service.toasts;

    return Stack(
      children: [
        Column(
          children: [
            if (blocking != null)
              _BlockingBanner(notification: blocking, onDismiss: () => service.dismiss(blocking.id)),
            Expanded(child: child),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final toast in toasts)
                _ToastCard(
                  key: ValueKey(toast.id),
                  notification: toast,
                  onDismiss: () => service.dismiss(toast.id),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

Color _containerColor(ColorScheme colors, NotificationSeverity severity) {
  return switch (severity) {
    NotificationSeverity.error => colors.errorContainer,
    NotificationSeverity.warning => colors.tertiaryContainer,
    NotificationSeverity.info => colors.surfaceContainerHighest,
  };
}

// The "on" color for each container above — required for text/icon contrast,
// since the containers aren't all the same lightness.
Color _onContainerColor(ColorScheme colors, NotificationSeverity severity) {
  return switch (severity) {
    NotificationSeverity.error => colors.onErrorContainer,
    NotificationSeverity.warning => colors.onTertiaryContainer,
    NotificationSeverity.info => colors.onSurfaceVariant,
  };
}

IconData _severityIcon(NotificationSeverity severity) {
  return switch (severity) {
    NotificationSeverity.error => Icons.error_outline,
    NotificationSeverity.warning => Icons.warning_amber_outlined,
    NotificationSeverity.info => Icons.info_outline,
  };
}

class _BlockingBanner extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onDismiss;
  const _BlockingBanner({required this.notification, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final onColor = _onContainerColor(colors, notification.severity);
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(color: onColor);

    return Material(
      color: _containerColor(colors, notification.severity),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(_severityIcon(notification.severity), color: onColor, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Text(notification.message, style: textStyle)),
              _CopyButton(text: notification.message, color: onColor),
              IconButton(icon: Icon(Icons.close, color: onColor), onPressed: onDismiss),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToastCard extends StatefulWidget {
  final AppNotification notification;
  final VoidCallback onDismiss;
  const _ToastCard({super.key, required this.notification, required this.onDismiss});

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard> with TickerProviderStateMixin {
  late final AnimationController _progress;
  late final AnimationController _visibility;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this, duration: widget.notification.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _dismiss();
      })
      ..forward();
    _visibility = AnimationController(vsync: this, duration: const Duration(milliseconds: 220))..forward();
  }

  Future<void> _dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    _progress.stop();
    await _visibility.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    _progress.dispose();
    _visibility.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final onColor = _onContainerColor(colors, widget.notification.severity);
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(color: onColor);
    final curve = CurvedAnimation(parent: _visibility, curve: Curves.easeOut, reverseCurve: Curves.easeIn);

    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: curve.drive(Tween(begin: const Offset(0.2, 0), end: Offset.zero)),
        child: Container(
          width: 320,
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: _containerColor(colors, widget.notification.severity),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Row(
                  children: [
                    Icon(_severityIcon(widget.notification.severity), size: 20, color: onColor),
                    const SizedBox(width: 8),
                    Expanded(child: Text(widget.notification.message, style: textStyle)),
                    _CopyButton(text: widget.notification.message, color: onColor),
                    IconButton(
                      icon: Icon(Icons.close, size: 20, color: onColor),
                      onPressed: _dismiss,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _progress,
                builder: (context, _) => LinearProgressIndicator(
                  value: 1 - _progress.value,
                  minHeight: 3,
                  backgroundColor: onColor.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(onColor.withValues(alpha: 0.6)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  final String text;
  final Color color;
  const _CopyButton({required this.text, required this.color});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(_copied ? Icons.check : Icons.copy, size: 20, color: widget.color),
      tooltip: 'Copy message',
      onPressed: _copy,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }
}
