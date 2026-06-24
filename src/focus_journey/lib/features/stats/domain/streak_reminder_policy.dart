/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

import '../../journey/domain/journey_state.dart';
import 'app_settings.dart';

/// Default time-of-day (local) the daily streak reminder may fire — a **tunable
/// config constant** (pending OQ "notification cadence"). The gating logic keys
/// off "fires once, gated", not this literal (AC-12).
const TimeOfDayHm defaultStreakReminderTime = TimeOfDayHm(20, 0);

/// A minimal hour:minute (24h, local) value object so the policy stays
/// framework-free (no Flutter `TimeOfDay`).
class TimeOfDayHm {
  /// Creates an hour:minute value.
  const TimeOfDayHm(this.hour, this.minute);

  /// Hour of day, 0–23.
  final int hour;

  /// Minute of hour, 0–59.
  final int minute;

  /// Minutes since local midnight.
  int get minutesOfDay => hour * 60 + minute;
}

/// Pure decision for whether the daily streak-reminder toast should fire on a
/// given tick (AC-12). All inputs are injected — no `DateTime.now()`, no OS read
/// — so the gating is deterministic and testable.
///
/// The reminder fires **at most once per day**, **only if** notifications +
/// streak reminders are enabled, **only if** today has not yet qualified for the
/// streak, **only** at/after the configured reminder time, and **not** while a
/// journey is actively progressing (AC-12).
abstract final class StreakReminderPolicy {
  /// Whether to fire the reminder.
  ///
  /// - [settings] — must allow streak reminders ([AppSettings.canNotifyStreak]).
  /// - [now] — the injected current local time (gates on time-of-day).
  /// - [reminderTime] — the configured fire-time (default
  ///   [defaultStreakReminderTime]).
  /// - [todayQualified] — whether today already reached the ≥25-min raw-active
  ///   bar (if so, no nag).
  /// - [alreadyFiredToday] — whether the reminder already fired today (no nag).
  /// - [journeyState] — the engine's current state; the reminder does NOT fire
  ///   while `active` (actively progressing).
  static bool shouldFire({
    required AppSettings settings,
    required DateTime now,
    required TimeOfDayHm reminderTime,
    required bool todayQualified,
    required bool alreadyFiredToday,
    required JourneyState journeyState,
  }) {
    if (!settings.canNotifyStreak) {
      return false;
    }
    if (todayQualified) {
      return false;
    }
    if (alreadyFiredToday) {
      return false;
    }
    if (journeyState == JourneyState.active) {
      return false;
    }
    final nowMinutes = now.hour * 60 + now.minute;
    return nowMinutes >= reminderTime.minutesOfDay;
  }
}
