/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

import 'package:equatable/equatable.dart';

import '../../journey/domain/travel_mode.dart';

/// Sentinel for [AppSettings.copyWith]'s nullable [AppSettings.vehiclePreference]
/// argument, so a caller can DISTINGUISH "leave the preference unchanged"
/// (the default) from "explicitly clear it to null (no preference)". A plain
/// `TravelMode?` parameter could not tell those two apart.
const Object _vehiclePreferenceUnset = Object();

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
    this.vehiclePreference,
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

  /// The user's chosen **cosmetic** vehicle skin override (vehicle-picker
  /// AC-3/AC-4, ADR-0007). `null` = "no preference" → the displayed mode follows
  /// the engine-derived cosmetic mode.
  ///
  /// **COSMETIC-ONLY (ADR-0007 firewall).** This is a view/settings-layer
  /// preference: it overrides only the *displayed* vehicle/cockpit, composed at
  /// the presentation seam (`vehiclePreference ?? engineMode` above
  /// `JourneyViewState`). The `JourneyEngine` neither reads nor depends on it,
  /// and it must **never** feed accrual or speed — not now, not after
  /// `journey-energy-model` (AC-8/AC-9/AC-10). It carries no journey truth.
  final TravelMode? vehiclePreference;

  /// Whether a badge-earned toast may fire (master AND per-type on; AC-11/AC-12).
  bool get canNotifyBadge => notificationsEnabled && badgeNotificationsEnabled;

  /// Whether a streak-reminder toast may fire (master AND per-type on).
  bool get canNotifyStreak => notificationsEnabled && streakReminderEnabled;

  /// Returns a copy with the given fields overridden.
  ///
  /// [vehiclePreference] uses a sentinel so callers can both SET it (pass a
  /// `TravelMode`) and CLEAR it to "no preference" (pass an explicit `null`),
  /// distinct from leaving it unchanged (omit the argument).
  AppSettings copyWith({
    Duration? idleThreshold,
    bool? launchAtStartup,
    bool? notificationsEnabled,
    bool? badgeNotificationsEnabled,
    bool? streakReminderEnabled,
    bool? onboardingSeen,
    Object? vehiclePreference = _vehiclePreferenceUnset,
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
      vehiclePreference: identical(vehiclePreference, _vehiclePreferenceUnset)
          ? this.vehiclePreference
          : vehiclePreference as TravelMode?,
    );
  }

  /// Serialises to a JSON-compatible map. The threshold as ms int; the cosmetic
  /// vehicle preference as the enum `.name` (omitted entirely when null = "no
  /// preference", so a fresh store has no key to misparse — AC-7).
  Map<String, dynamic> toJson() => <String, dynamic>{
    'idleThresholdMs': idleThreshold.inMilliseconds,
    'launchAtStartup': launchAtStartup,
    'notificationsEnabled': notificationsEnabled,
    'badgeNotificationsEnabled': badgeNotificationsEnabled,
    'streakReminderEnabled': streakReminderEnabled,
    'onboardingSeen': onboardingSeen,
    if (vehiclePreference != null)
      'vehiclePreference': vehiclePreference!.name,
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
      vehiclePreference: _vehiclePreferenceFromJson(json['vehiclePreference']),
    );
  }

  /// Parses the stored cosmetic vehicle preference by enum `name`, degrading
  /// safely (AC-7): absent (`null`), wrong-typed, or an unknown name → `null`
  /// ("no preference"), never a throw.
  static TravelMode? _vehiclePreferenceFromJson(Object? raw) {
    if (raw is! String) {
      return null;
    }
    for (final TravelMode mode in TravelMode.values) {
      if (mode.name == raw) {
        return mode;
      }
    }
    return null;
  }

  @override
  List<Object?> get props => <Object?>[
    idleThreshold,
    launchAtStartup,
    notificationsEnabled,
    badgeNotificationsEnabled,
    streakReminderEnabled,
    onboardingSeen,
    vehiclePreference,
  ];
}
