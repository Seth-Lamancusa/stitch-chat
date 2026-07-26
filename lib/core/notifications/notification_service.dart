import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'app_notification.dart';

export 'app_notification.dart';

const _uuid = Uuid();

/// The single surface every layer of the app routes user-facing errors and
/// status messages through, per the "centralize error handling" principle.
/// ViewModels/repositories call this instead of holding their own ad-hoc
/// error fields, so every error ends up visible the same way.
class NotificationService extends ChangeNotifier {
  final List<AppNotification> _notifications = [];

  List<AppNotification> get toasts => _notifications.where((n) => !n.blocking).toList(growable: false);

  AppNotification? get blocking {
    for (final n in _notifications) {
      if (n.blocking) return n;
    }
    return null;
  }

  void show(
    String message, {
    NotificationSeverity severity = NotificationSeverity.info,
    bool blocking = false,
    Duration duration = const Duration(seconds: 5),
  }) {
    _notifications.add(AppNotification(
      id: _uuid.v4(),
      message: message,
      severity: severity,
      blocking: blocking,
      duration: duration,
    ));
    notifyListeners();
  }

  void showError(String message, {bool blocking = false}) {
    show(message, severity: NotificationSeverity.error, blocking: blocking);
  }

  void showToast(String message, {NotificationSeverity severity = NotificationSeverity.info}) {
    show(message, severity: severity);
  }

  void dismiss(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }
}
