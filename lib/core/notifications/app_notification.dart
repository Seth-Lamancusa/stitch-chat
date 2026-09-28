enum NotificationSeverity { info, warning, error }

/// A single notification routed through [NotificationService]. `blocking`
/// notifications render as a persistent banner the user must dismiss;
/// non-blocking ones render as a toast that auto-dismisses after [duration].
class AppNotification {
  final String id;
  final String message;
  final NotificationSeverity severity;
  final bool blocking;
  final Duration duration;

  /// Optional headline above [message] (e.g. "New message from bot").
  final String? title;

  /// Optional tap handler for the toast body (not copy/close controls).
  final Future<void> Function()? onTap;

  const AppNotification({
    required this.id,
    required this.message,
    required this.severity,
    this.blocking = false,
    this.duration = const Duration(seconds: 5),
    this.title,
    this.onTap,
  });
}
