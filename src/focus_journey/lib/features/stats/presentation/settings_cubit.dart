/// Presentation layer. The Cubit for the settings screen: idle threshold
/// (engine-affecting), launch-at-startup (OS), and notification toggles.
///
/// SEPARATION / PRIVACY INVARIANT (AC-9/TC-009/TC-026): the **only**
/// engine-affecting setting is the idle threshold, applied via the injected
/// [_applyIdleThreshold] seam (the app wires this to the engine's threshold knob
/// — see `main.dart`). Launch-at-startup and notifications are OS-only and feed
/// the engine **nothing**. This Cubit reads no OS signal directly; it talks to
/// the OS only through the injected [StartupController] interface (AC-10).
///
/// A Cubit (not an event-Bloc) so tests drive it directly against fakes.
library;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/app_settings.dart';
import '../domain/stats_repositories.dart';

/// The seam the settings Cubit uses to apply the chosen idle threshold to the
/// engine's pause decision on the next tick (AC-8). Injected by the app so the
/// Cubit never references the engine — a fake records the applied value in
/// tests, with no engine code change.
typedef ApplyIdleThreshold = void Function(Duration threshold);

/// Emits [AppSettings] snapshots for the settings screen.
class SettingsCubit extends Cubit<AppSettings> {
  /// Creates the cubit with injected dependencies. [initialSettings] is the
  /// restored value (loaded at startup; AC-9), or the defaults.
  SettingsCubit({
    required SettingsRepository repository,
    required StartupController startupController,
    required ApplyIdleThreshold applyIdleThreshold,
    void Function(AppSettings settings)? onSettingsChanged,
    AppSettings? initialSettings,
  }) : _repository = repository,
       _startupController = startupController,
       _applyIdleThreshold = applyIdleThreshold,
       _onSettingsChanged = onSettingsChanged,
       super(initialSettings ?? const AppSettings()) {
    // Apply the restored threshold to the engine immediately so a restart
    // re-applies the persisted value (AC-9).
    _applyIdleThreshold(state.idleThreshold);
  }

  final SettingsRepository _repository;
  final StartupController _startupController;
  final ApplyIdleThreshold _applyIdleThreshold;
  final void Function(AppSettings settings)? _onSettingsChanged;

  /// Reads the **actual** OS open-at-login state and reconciles the toggle to it
  /// (AC-10). Call when the settings screen opens. A read failure (unsupported
  /// platform) leaves the persisted value unchanged.
  Future<void> syncLaunchAtStartupFromOs() async {
    try {
      final osEnabled = await _startupController.isEnabled();
      if (osEnabled != state.launchAtStartup) {
        await _persist(state.copyWith(launchAtStartup: osEnabled));
      }
    } catch (_) {
      // Unsupported platform / read failure: keep the persisted value.
    }
  }

  /// Changes the idle threshold, persists it, and applies it to the engine so
  /// the next tick classifies idle using the new value (AC-8).
  Future<void> setIdleThreshold(Duration threshold) async {
    _applyIdleThreshold(threshold);
    await _persist(state.copyWith(idleThreshold: threshold));
  }

  /// Flips launch-at-startup: writes the **real** OS state via the controller
  /// then persists the toggle (AC-10).
  Future<void> setLaunchAtStartup(bool enabled) async {
    await _startupController.setEnabled(enabled);
    await _persist(state.copyWith(launchAtStartup: enabled));
  }

  /// Toggles the master notifications switch (AC-11).
  Future<void> setNotificationsEnabled(bool enabled) =>
      _persist(state.copyWith(notificationsEnabled: enabled));

  /// Toggles the per-type badge-earned notifications (AC-12).
  Future<void> setBadgeNotificationsEnabled(bool enabled) =>
      _persist(state.copyWith(badgeNotificationsEnabled: enabled));

  /// Toggles the per-type streak-reminder notifications (AC-12).
  Future<void> setStreakReminderEnabled(bool enabled) =>
      _persist(state.copyWith(streakReminderEnabled: enabled));

  /// Marks the first-run onboarding as completed so it is not re-shown (AC-20).
  Future<void> markOnboardingSeen() =>
      _persist(state.copyWith(onboardingSeen: true));

  Future<void> _persist(AppSettings next) async {
    emit(next);
    _onSettingsChanged?.call(next);
    await _repository.save(next);
  }
}
