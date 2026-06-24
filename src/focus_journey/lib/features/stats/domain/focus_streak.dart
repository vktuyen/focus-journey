/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

import 'day_stats.dart';

/// Pure focus-streak counting over the per-day history on the **locked** rule:
/// a day **qualifies iff** its `rawActiveTime >= 25 min` (journey-engine AC-15 /
/// Resolved decision — counted here from stored history, never re-derived from
/// live signals; the threshold is NOT re-opened). Deterministic and
/// framework-free (Determinism NFR / AC-16).
abstract final class FocusStreak {
  /// The locked streak-qualification threshold: a day counts toward the streak
  /// only if its raw active time reaches this. **Fixed constant**, not a tunable
  /// OQ (only the streak *lengths* in the badge catalogue are tunable).
  static const Duration qualifyingRawActive = Duration(minutes: 25);

  /// Whether [day] qualifies under the locked ≥ 25-min raw-active rule.
  static bool qualifies(DayStats day) =>
      day.rawActiveTime >= qualifyingRawActive;

  /// The length (in days) of the **current** consecutive-qualifying-day streak
  /// ending on [today]. Counts back from [today] (or the most recent qualifying
  /// day immediately preceding it) over contiguous local calendar days; a
  /// missing day or a day below the threshold **breaks** the streak (AC-16).
  ///
  /// If [today] itself does not qualify, the streak ending on [today] is the run
  /// of qualifying days ending on [today]-1 (so an unfinished current day does
  /// not zero a streak the user can still extend), consistent with the daily
  /// streak-reminder gating (AC-12). Keyed off the injected [today]; reads only
  /// stored history.
  static int currentLength(List<DayStats> history, DateTime today) {
    final byDate = <DateTime, DayStats>{
      for (final day in history) day.date: day,
    };
    final todayOnly = DateTime(today.year, today.month, today.day);

    // Anchor: start counting from today if it qualifies, otherwise from
    // yesterday (an unfinished today does not break an existing streak).
    // Step by date COMPONENTS, not a fixed-24h Duration: across a local DST
    // transition a `Duration(days: 1)` step would land at 23:00/01:00 and miss
    // the date-only midnight keys in `byDate` (M1, DST-safe).
    var cursor = todayOnly;
    final todayEntry = byDate[todayOnly];
    if (todayEntry == null || !qualifies(todayEntry)) {
      cursor = _previousDay(cursor);
    }

    var length = 0;
    while (true) {
      final entry = byDate[cursor];
      if (entry == null || !qualifies(entry)) {
        break;
      }
      length++;
      cursor = _previousDay(cursor);
    }
    return length;
  }

  /// The local-midnight calendar day before [date], by date components so it is
  /// DST-safe (M1).
  static DateTime _previousDay(DateTime date) =>
      DateTime(date.year, date.month, date.day - 1);

  /// The total count of qualifying days in [history] (used by the
  /// total-raw-hours / cumulative focus-time badges' day counting if needed).
  static int qualifyingDayCount(List<DayStats> history) =>
      history.where(qualifies).length;
}
