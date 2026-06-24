/// Data layer — the ONLY file that imports `launch_at_startup`. Wraps the
/// package behind the domain [StartupController] interface so Cubits/tests never
/// see the package (DI / dependency inversion; AC-10).
///
/// **Privacy (AC-21):** the only capability this exposes is reading/setting the
/// OS "open at login" flag. It reads NO input content, screen, clipboard, files,
/// or network.
library;

import 'package:launch_at_startup/launch_at_startup.dart';

import '../domain/stats_repositories.dart';

/// A [StartupController] backed by the `launch_at_startup` package.
///
/// The package's `setup(...)` (app name + path) must be called once at app
/// startup before use — done in `main.dart` (see the wiring there). On platforms
/// the package does not support, calls may throw; the Cubit treats a read
/// failure as "disabled" so the toggle still renders.
class LaunchAtStartupController implements StartupController {
  /// Creates the controller over the shared package instance.
  const LaunchAtStartupController();

  @override
  Future<bool> isEnabled() => launchAtStartup.isEnabled();

  @override
  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }
  }
}
