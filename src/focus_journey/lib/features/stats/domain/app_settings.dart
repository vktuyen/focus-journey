/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

import 'package:equatable/equatable.dart';

/// The user-configurable settings (AC-8..AC-12, AC-20): the engine-affecting
/// idle threshold plus the OS-only launch-at-startup and notification toggles,
/// and the onboarding-seen flag. Persisted via the `shared_preferences`/JSON
/// seam; only the idle threshold feeds the engine (AC-9).
///
/// **Privacy:** holds only configuration values + a boolean flag — no raw
/// signals (TC-027).
class AppSettings extends Equatable {
  /// Creates settings.
  const AppSettings({
    this.idleThreshold = defaultIdleThreshold,
    this.launchAtStartup = false,
    this.notificationsEnabled = true,
    this.badgeNotificationsEnabled = true,
    this.streakReminderEnabled = true,
    this.onboardingSeen = false,
  });

  /// The default idle threshold (5 min) — matches the engine's shipped default
  /// (AC-8).
  static const Duration defaultIdleThreshold = Duration(minutes: 5);

  /// The selectable preset idle thresholds (3 / 5 / 10 min); a custom value is
  /// any other [Duration] (AC-8).
  static const List<Duration> idleThresholdPresets = <Duration>[
    Duration(minutes: 3),
    Duration(minutes: 5),
    Duration(minutes: 10),
  ];

  /// The idle threshold applied to the engine's pause decision (AC-8). The
  /// **only** engine-affecting setting (AC-9).
  final Duration idleThreshold;

  /// Whether the app is set to open at OS login (OS-only; AC-10).
  final bool launchAtStartup;

  /// The master notifications toggle (AC-11). With this off, no toast fires.
  final bool notificationsEnabled;

  /// Per-type toggle: badge-earned toasts (AC-12).
  final bool badgeNotificationsEnabled;

  /// Per-type toggle: daily streak-reminder toast (AC-12).
  final bool streakReminderEnabled;

  /// Whether the first-run onboarding has been completed (AC-20). Persisted so
  /// onboarding is not re-shown; re-openable from settings.
  final bool onboardingSeen;

  /// Whether a badge-earned toast may fire (master AND per-type on; AC-11/AC-12).
  bool get canNotifyBadge => notificationsEnabled && badgeNotificationsEnabled;

  /// Whether a streak-reminder toast may fire (master AND per-type on).
  bool get canNotifyStreak => notificationsEnabled && streakReminderEnabled;

  /// Returns a copy with the given fields overridden.
  AppSettings copyWith({
    Duration? idleThreshold,
    bool? launchAtStartup,
    bool? notificationsEnabled,
    bool? badgeNotificationsEnabled,
    bool? streakReminderEnabled,
    bool? onboardingSeen,
  }) {
    return AppSettings(
      idleThreshold: idleThreshold ?? this.idleThreshold,
      launchAtStartup: launchAtStartup ?? this.launchAtStartup,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      badgeNotificationsEnabled:
          badgeNotificationsEnabled ?? this.badgeNotificationsEnabled,
      streakReminderEnabled:
          streakReminderEnabled ?? this.streakReminderEnabled,
      onboardingSeen: onboardingSeen ?? this.onboardingSeen,
    );
  }

  /// Serialises to a JSON-compatible map. The threshold as ms int.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'idleThresholdMs': idleThreshold.inMilliseconds,
    'launchAtStartup': launchAtStartup,
    'notificationsEnabled': notificationsEnabled,
    'badgeNotificationsEnabled': badgeNotificationsEnabled,
    'streakReminderEnabled': streakReminderEnabled,
    'onboardingSeen': onboardingSeen,
  };

  /// Reconstructs from [toJson]'s output, degrading safely — missing/wrong-typed
  /// fields fall back to defaults rather than throwing, since settings are
  /// non-critical and a fresh default is a safe restore.
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final ms = json['idleThresholdMs'];
    return AppSettings(
      idleThreshold: ms is int
          ? Duration(milliseconds: ms)
          : defaultIdleThreshold,
      launchAtStartup: json['launchAtStartup'] == true,
      notificationsEnabled: json['notificationsEnabled'] != false,
      badgeNotificationsEnabled: json['badgeNotificationsEnabled'] != false,
      streakReminderEnabled: json['streakReminderEnabled'] != false,
      onboardingSeen: json['onboardingSeen'] == true,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    idleThreshold,
    launchAtStartup,
    notificationsEnabled,
    badgeNotificationsEnabled,
    streakReminderEnabled,
    onboardingSeen,
  ];
}
