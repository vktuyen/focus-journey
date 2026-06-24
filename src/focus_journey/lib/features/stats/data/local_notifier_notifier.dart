/// Data layer — the ONLY file that imports `local_notifier`. Wraps the package
/// behind the domain [Notifier] interface so the notification logic / tests
/// never see the package (DI; AC-11/AC-12).
///
/// **Privacy (AC-21 / NF No network):** delivers ONLY local OS toasts. There is
/// no network, no push, no remote endpoint — `local_notifier` shows a native
/// desktop notification and nothing leaves the machine.
library;

import 'package:local_notifier/local_notifier.dart';

import '../domain/stats_repositories.dart';

/// A [Notifier] backed by the `local_notifier` package (local OS toasts only).
///
/// The package's `localNotifier.setup(appName: ...)` must be called once at app
/// startup before use — done in `main.dart`.
class LocalNotifierNotifier implements Notifier {
  /// Creates the notifier.
  const LocalNotifierNotifier();

  @override
  Future<void> showBadgeEarned({
    required String title,
    required String description,
  }) async {
    final notification = LocalNotification(title: title, body: description);
    await notification.show();
  }

  @override
  Future<void> showStreakReminder({
    required String title,
    required String body,
  }) async {
    final notification = LocalNotification(title: title, body: body);
    await notification.show();
  }
}
