/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

import 'package:equatable/equatable.dart';

import 'calendar_week.dart';
import 'day_stats.dart';

/// The aggregate of a single local calendar week (Mon–Sun) — the weekly view
/// (AC-4). Pure value object produced by [WeeklyStatsAggregator.aggregate].
class WeeklyStats extends Equatable {
  /// Creates a weekly aggregate.
  const WeeklyStats({
    required this.activeTime,
    required this.rawActiveTime,
    required this.distanceKm,
    required this.idleTime,
    required this.daysActive,
    required this.bestFocusPeriod,
  });

  /// The empty week (no in-week history).
  const WeeklyStats.empty()
    : activeTime = Duration.zero,
      rawActiveTime = Duration.zero,
      distanceKm = 0,
      idleTime = Duration.zero,
      daysActive = 0,
      bestFocusPeriod = Duration.zero;

  /// Summed journey time across the week's in-window days.
  final Duration activeTime;

  /// Summed raw active time across the week (always `<= activeTime`).
  final Duration rawActiveTime;

  /// Summed distance (km) across the week.
  final double distanceKm;

  /// Summed idle time across the week.
  final Duration idleTime;

  /// Count of distinct in-week days that recorded any activity (rawActiveTime
  /// or activeTime > 0). Used by the weekly readout.
  final int daysActive;

  /// The single longest raw-active stretch seen on any in-week day (the week's
  /// best focus period — the max of the per-day bests, not a sum).
  final Duration bestFocusPeriod;

  @override
  List<Object?> get props => <Object?>[
    activeTime,
    rawActiveTime,
    distanceKm,
    idleTime,
    daysActive,
    bestFocusPeriod,
  ];
}

/// Pure aggregation of a per-day history into the **current** local calendar
/// week (Mon–Sun), keyed off an injected "today" (AC-4). Stateless,
/// deterministic, framework-free.
abstract final class WeeklyStatsAggregator {
  /// Aggregates the days in [history] that fall in the same Mon–Sun week as
  /// [today], summing the counters and taking the max best-focus-period; the
  /// prior week's days are excluded (AC-4).
  static WeeklyStats aggregate(List<DayStats> history, DateTime today) {
    var active = Duration.zero;
    var raw = Duration.zero;
    var distance = 0.0;
    var idle = Duration.zero;
    var daysActive = 0;
    var best = Duration.zero;

    for (final day in history) {
      if (!CalendarWeek.isSameWeek(day.date, today)) {
        continue;
      }
      active += day.activeTime;
      raw += day.rawActiveTime;
      distance += day.distanceKmForDay;
      idle += day.idleTime;
      if (day.rawActiveTime > Duration.zero || day.activeTime > Duration.zero) {
        daysActive++;
      }
      if (day.bestFocusPeriod > best) {
        best = day.bestFocusPeriod;
      }
    }

    return WeeklyStats(
      activeTime: active,
      rawActiveTime: raw,
      distanceKm: distance,
      idleTime: idle,
      daysActive: daysActive,
      bestFocusPeriod: best,
    );
  }
}
