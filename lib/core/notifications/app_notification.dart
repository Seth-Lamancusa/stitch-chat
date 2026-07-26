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

  const AppNotification({
    required this.id,
    required this.message,
    required this.severity,
    this.blocking = false,
    this.duration = const Duration(seconds: 5),
  });
}
