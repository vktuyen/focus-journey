// Unit tests for WeeklyStatsAggregator — sums only the current Mon-Sun calendar
// week from the per-day history, excluding the prior week (AC-4, TC-004). Pure,
// deterministic, keyed off an injected "today" — no DateTime.now(). Seeds dated
// entries straddling a Monday boundary and asserts the aggregate plus days-active
// count and the week's best-focus-period (the MAX of per-day bests, not a sum).

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/stats/domain/calendar_week.dart';
import 'package:focus_journey/features/stats/domain/day_stats.dart';
import 'package:focus_journey/features/stats/domain/weekly_stats.dart';

import '../stats_test_fixtures.dart';

const double _tol = 1e-6;

void main() {
  // Week W: Mon 2026-06-22 .. Sun 2026-06-28. "Today" = Wed 2026-06-24.
  final today = DateTime(2026, 6, 24);
  final monday = DateTime(2026, 6, 22);
  final sunday = DateTime(2026, 6, 28);

  group('WeeklyStatsAggregator — empty (AC-4)', () {
    test('emptyHistory_yieldsTheEmptyWeek', () {
      expect(
        WeeklyStatsAggregator.aggregate(const <DayStats>[], today),
        const WeeklyStats.empty(),
      );
    });

    test('onlyPriorWeekDays_yieldZeroForThisWeek', () {
      final history = <DayStats>[
        dayStats(
          monday.subtract(const Duration(days: 1)), // prior Sunday
          rawActiveTime: const Duration(minutes: 99),
          distanceKmForDay: 99,
        ),
      ];
      expect(
        WeeklyStatsAggregator.aggregate(history, today),
        const WeeklyStats.empty(),
      );
    });
  });

  group('WeeklyStatsAggregator — Mon-Sun window straddle (AC-4 / TC-004)', () {
    test('sumsOnlyInWeekDays_andExcludesThePriorWeek', () {
      final history = <DayStats>[
        // In-week: Monday (the inclusive start edge).
        dayStats(
          monday,
          activeTime: const Duration(minutes: 40),
          rawActiveTime: const Duration(minutes: 30),
          distanceKmForDay: 10,
          idleTime: const Duration(minutes: 5),
          bestFocusPeriod: const Duration(minutes: 12),
        ),
        // In-week: Wednesday.
        dayStats(
          today,
          activeTime: const Duration(minutes: 20),
          rawActiveTime: const Duration(minutes: 18),
          distanceKmForDay: 6,
          idleTime: const Duration(minutes: 3),
          bestFocusPeriod: const Duration(minutes: 15),
        ),
        // In-week: Sunday (the inclusive end edge).
        dayStats(
          sunday,
          activeTime: const Duration(minutes: 10),
          rawActiveTime: const Duration(minutes: 10),
          distanceKmForDay: 4,
          bestFocusPeriod: const Duration(minutes: 8),
        ),
        // Prior week — must be excluded entirely.
        dayStats(
          monday.subtract(const Duration(days: 1)),
          activeTime: const Duration(hours: 5),
          rawActiveTime: const Duration(hours: 5),
          distanceKmForDay: 500,
          idleTime: const Duration(hours: 1),
          bestFocusPeriod: const Duration(hours: 2),
        ),
      ];

      final weekly = WeeklyStatsAggregator.aggregate(history, today);

      expect(weekly.activeTime, const Duration(minutes: 70));
      expect(weekly.rawActiveTime, const Duration(minutes: 58));
      expect(weekly.distanceKm, closeTo(20, _tol));
      expect(weekly.idleTime, const Duration(minutes: 8));
      expect(weekly.daysActive, 3);
      // Week best focus = MAX per-day best, not a sum.
      expect(weekly.bestFocusPeriod, const Duration(minutes: 15));
    });

    test('weekEdgesAreInclusive_whenClockIsOnSundayOrMonday', () {
      final history = <DayStats>[
        dayStats(monday, rawActiveTime: const Duration(minutes: 10)),
        dayStats(sunday, rawActiveTime: const Duration(minutes: 10)),
      ];
      // Clock on the Monday edge sees both Mon and Sun (same week).
      expect(WeeklyStatsAggregator.aggregate(history, monday).daysActive, 2);
      // Clock on the Sunday edge also sees both.
      expect(WeeklyStatsAggregator.aggregate(history, sunday).daysActive, 2);
    });
  });

  group('WeeklyStatsAggregator — daysActive counting (AC-4)', () {
    test('aDayWithNoActivity_doesNotCountTowardDaysActive', () {
      final history = <DayStats>[
        dayStats(monday, rawActiveTime: const Duration(minutes: 30)),
        dayStats(today), // zero everything — recorded but inactive
      ];
      final weekly = WeeklyStatsAggregator.aggregate(history, today);
      expect(weekly.daysActive, 1);
    });

    test('aDayWithOnlyJourneyTime_stillCountsAsActive', () {
      final history = <DayStats>[
        dayStats(today, activeTime: const Duration(minutes: 5)),
      ];
      expect(WeeklyStatsAggregator.aggregate(history, today).daysActive, 1);
    });
  });

  group('WeeklyStatsAggregator — determinism (TC-NF1)', () {
    test('sameInputs_yieldIdenticalAggregate', () {
      final history = <DayStats>[
        dayStats(monday, rawActiveTime: const Duration(minutes: 30)),
        dayStats(today, rawActiveTime: const Duration(minutes: 18)),
      ];
      final a = WeeklyStatsAggregator.aggregate(history, today);
      final b = WeeklyStatsAggregator.aggregate(history, today);
      expect(a, b);
    });

    test('keyingOffMondayOf_isConsistentWithCalendarWeek', () {
      // A day in week W aggregated against any other day of W gives the same set.
      final history = <DayStats>[
        dayStats(monday, rawActiveTime: const Duration(minutes: 30)),
        dayStats(sunday, rawActiveTime: const Duration(minutes: 30)),
      ];
      final viaWed = WeeklyStatsAggregator.aggregate(history, today);
      final viaMonday = WeeklyStatsAggregator.aggregate(
        history,
        CalendarWeek.mondayOf(today),
      );
      expect(viaWed, viaMonday);
    });
  });
}
