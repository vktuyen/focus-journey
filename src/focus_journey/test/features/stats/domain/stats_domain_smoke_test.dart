/// Smoke tests for the local-stats pure domain logic. These prove the seams are
/// expressible/deterministic; the comprehensive case suite is written by
/// `unit-test-writer`. No real timers, no `DateTime.now()` — clock values are
/// passed in directly.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/journey_state.dart';
import 'package:focus_journey/features/stats/domain/app_settings.dart';
import 'package:focus_journey/features/stats/domain/badge.dart';
import 'package:focus_journey/features/stats/domain/badge_catalogue.dart';
import 'package:focus_journey/features/stats/domain/badge_evaluator.dart';
import 'package:focus_journey/features/stats/domain/best_focus_tracker.dart';
import 'package:focus_journey/features/stats/domain/calendar_week.dart';
import 'package:focus_journey/features/stats/domain/daily_stats.dart';
import 'package:focus_journey/features/stats/domain/day_stats.dart';
import 'package:focus_journey/features/stats/domain/earned_badges.dart';
import 'package:focus_journey/features/stats/domain/focus_streak.dart';
import 'package:focus_journey/features/stats/domain/streak_reminder_policy.dart';
import 'package:focus_journey/features/stats/domain/weekly_stats.dart';

void main() {
  group('DailyStatsProjection honesty invariant (AC-2)', () {
    test('projects raw separately and allows raw == journey', () {
      final daily = DailyStatsProjection.project(
        activeTime: const Duration(minutes: 30),
        rawActiveTime: const Duration(minutes: 30),
        distanceKm: 12,
        idleTime: const Duration(minutes: 5),
        bestFocusPeriod: const Duration(minutes: 20),
      );
      expect(daily.rawActiveTime, daily.activeTime);
    });

    test('throws when raw > journey (defect, not rendered)', () {
      expect(
        () => DailyStatsProjection.project(
          activeTime: const Duration(minutes: 10),
          rawActiveTime: const Duration(minutes: 11),
          distanceKm: 0,
          idleTime: Duration.zero,
          bestFocusPeriod: Duration.zero,
        ),
        throwsA(isA<HonestyInvariantViolation>()),
      );
    });
  });

  group('BestFocusTracker (AC-3)', () {
    test('longest raw-active run wins; non-increase breaks the run', () {
      final t = BestFocusTracker();
      t.observe(Duration.zero); // baseline
      t.observe(const Duration(minutes: 1)); // run = 1
      t.observe(const Duration(minutes: 2)); // run = 2
      t.observe(const Duration(minutes: 2)); // no advance -> break
      t.observe(const Duration(minutes: 3)); // new run = 1
      expect(t.bestFocusPeriod, const Duration(minutes: 2));
    });
  });

  group('WeeklyStatsAggregator (AC-4)', () {
    test('sums only the current Mon-Sun week', () {
      final monday = CalendarWeek.mondayOf(DateTime(2026, 6, 24)); // a Wed
      final inWeek = DayStats(
        date: monday,
        activeTime: const Duration(minutes: 40),
        rawActiveTime: const Duration(minutes: 30),
        distanceKmForDay: 10,
        idleTime: const Duration(minutes: 5),
        bestFocusPeriod: const Duration(minutes: 15),
      );
      final priorWeek = DayStats(
        date: monday.subtract(const Duration(days: 1)), // Sunday before
        activeTime: const Duration(minutes: 99),
        rawActiveTime: const Duration(minutes: 99),
        distanceKmForDay: 99,
        idleTime: Duration.zero,
        bestFocusPeriod: const Duration(minutes: 99),
      );
      final weekly = WeeklyStatsAggregator.aggregate(<DayStats>[
        inWeek,
        priorWeek,
      ], DateTime(2026, 6, 24));
      expect(weekly.distanceKm, 10);
      expect(weekly.daysActive, 1);
      expect(weekly.bestFocusPeriod, const Duration(minutes: 15));
    });
  });

  group('FocusStreak locked 25-min rule (AC-16)', () {
    DayStats day(DateTime d, int rawMinutes) => DayStats(
      date: d,
      activeTime: Duration(minutes: rawMinutes),
      rawActiveTime: Duration(minutes: rawMinutes),
      distanceKmForDay: 0,
      idleTime: Duration.zero,
      bestFocusPeriod: Duration.zero,
    );

    test('25 min qualifies, 24 does not; gap breaks the streak', () {
      final today = DateTime(2026, 6, 24);
      final history = <DayStats>[
        day(today, 25),
        day(today.subtract(const Duration(days: 1)), 30),
        day(today.subtract(const Duration(days: 2)), 24), // breaks
        day(today.subtract(const Duration(days: 3)), 60),
      ];
      expect(FocusStreak.currentLength(history, today), 2);
    });
  });

  group('BadgeEvaluator data-driven catalogue (AC-13/AC-18)', () {
    BadgeContext ctx({
      double distance = 0,
      double weekDistance = 0,
      double percent = 0,
      int provinces = 0,
      bool completed = false,
      int streak = 0,
      Duration rawToday = Duration.zero,
      Duration best = Duration.zero,
      double totalHours = 0,
    }) => BadgeContext(
      cumulativeDistanceKm: distance,
      weekDistanceKm: weekDistance,
      percentOfCountry: percent,
      provincesPassed: provinces,
      routeCompleted: completed,
      currentStreakDays: streak,
      todayRawActive: rawToday,
      todayBestFocusPeriod: best,
      totalRawActiveHours: totalHours,
    );

    test('catalogue spans all four families', () {
      final families = BadgeCatalogue.badges.map((b) => b.family).toSet();
      expect(families, BadgeFamily.values.toSet());
    });

    test('crossing a distance threshold earns + persists into the set', () {
      final result = BadgeEvaluator.evaluate(
        catalogue: BadgeCatalogue.badges,
        context: ctx(distance: BadgeThresholds.distanceFirst100Km),
        current: const EarnedBadges.empty(),
        today: DateTime(2026, 6, 24),
      );
      expect(result.newlyEarned, contains('distance_first_100km'));
      expect(result.earned.contains('distance_first_100km'), isTrue);
    });

    test('windowed badge resets on a new week; permanent persists', () {
      final wk1 = DateTime(2026, 6, 24); // week W
      final earnWindowed = BadgeEvaluator.evaluate(
        catalogue: BadgeCatalogue.badges,
        context: ctx(
          weekDistance: BadgeThresholds.weekDistance100Km,
          distance: BadgeThresholds.distanceFirst100Km,
        ),
        current: const EarnedBadges.empty(),
        today: wk1,
      );
      expect(earnWindowed.earned.contains('distance_century_week'), isTrue);
      expect(earnWindowed.earned.contains('distance_first_100km'), isTrue);

      // Next week, no week distance -> windowed resets, permanent stays.
      final wk2 = wk1.add(const Duration(days: 7));
      final afterRollover = BadgeEvaluator.evaluate(
        catalogue: BadgeCatalogue.badges,
        context: ctx(distance: BadgeThresholds.distanceFirst100Km),
        current: earnWindowed.earned,
        today: wk2,
      );
      expect(afterRollover.earned.contains('distance_century_week'), isFalse);
      expect(afterRollover.earned.contains('distance_first_100km'), isTrue);
    });
  });

  group('StreakReminderPolicy gating (AC-12)', () {
    final settings = const AppSettings();

    test('does not fire when today already qualified', () {
      expect(
        StreakReminderPolicy.shouldFire(
          settings: settings,
          now: DateTime(2026, 6, 24, 21),
          reminderTime: defaultStreakReminderTime,
          todayQualified: true,
          alreadyFiredToday: false,
          journeyState: JourneyState.paused,
        ),
        isFalse,
      );
    });

    test('does not fire while actively progressing', () {
      expect(
        StreakReminderPolicy.shouldFire(
          settings: settings,
          now: DateTime(2026, 6, 24, 21),
          reminderTime: defaultStreakReminderTime,
          todayQualified: false,
          alreadyFiredToday: false,
          journeyState: JourneyState.active,
        ),
        isFalse,
      );
    });

    test(
      'fires once when unqualified, idle, past reminder time, master on',
      () {
        expect(
          StreakReminderPolicy.shouldFire(
            settings: settings,
            now: DateTime(2026, 6, 24, 21),
            reminderTime: defaultStreakReminderTime,
            todayQualified: false,
            alreadyFiredToday: false,
            journeyState: JourneyState.idle,
          ),
          isTrue,
        );
      },
    );

    test('master off suppresses the toast', () {
      expect(
        StreakReminderPolicy.shouldFire(
          settings: settings.copyWith(notificationsEnabled: false),
          now: DateTime(2026, 6, 24, 21),
          reminderTime: defaultStreakReminderTime,
          todayQualified: false,
          alreadyFiredToday: false,
          journeyState: JourneyState.idle,
        ),
        isFalse,
      );
    });
  });
}
