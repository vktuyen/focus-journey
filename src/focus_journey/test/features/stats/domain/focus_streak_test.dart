// Unit tests for FocusStreak — consecutive qualifying days on the LOCKED
// rawActiveTime >= 25 min rule (AC-16, TC-016). The 25-min bar is a fixed
// constant (NOT a tunable OQ): a day at exactly 25 min qualifies, 24 does not.
// A sub-threshold day or a calendar gap breaks the streak. Pure, deterministic,
// keyed off an injected "today" — counts from stored history, never live signals.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/stats/domain/day_stats.dart';
import 'package:focus_journey/features/stats/domain/focus_streak.dart';

import '../stats_test_fixtures.dart';

void main() {
  final today = DateTime(2026, 6, 24);

  // A history of N consecutive days ending on [today], each at [rawMinutes].
  List<DayStats> consecutive(int days, int rawMinutes, {DateTime? endingOn}) {
    final end = endingOn ?? today;
    return <DayStats>[
      for (var i = 0; i < days; i++)
        dayStats(
          end.subtract(Duration(days: i)),
          rawActiveTime: Duration(minutes: rawMinutes),
        ),
    ];
  }

  group('FocusStreak.qualifies — locked 25-min bar (AC-16)', () {
    test('exactly25Min_qualifies', () {
      expect(
        FocusStreak.qualifies(
          dayStats(today, rawActiveTime: FocusStreak.qualifyingRawActive),
        ),
        isTrue,
      );
    });

    test('24Min_doesNotQualify', () {
      expect(
        FocusStreak.qualifies(
          dayStats(today, rawActiveTime: const Duration(minutes: 24)),
        ),
        isFalse,
      );
    });

    test('justUnder25Min_doesNotQualify', () {
      expect(
        FocusStreak.qualifies(
          dayStats(
            today,
            rawActiveTime: const Duration(minutes: 24, seconds: 59),
          ),
        ),
        isFalse,
      );
    });

    test('theLockedThresholdIs25Minutes', () {
      expect(FocusStreak.qualifyingRawActive, const Duration(minutes: 25));
    });
  });

  group('FocusStreak.currentLength — consecutive counting (AC-16)', () {
    test('emptyHistory_isZero', () {
      expect(FocusStreak.currentLength(const <DayStats>[], today), 0);
    });

    test('threeQualifyingDaysInARow_endingToday_isThree', () {
      expect(FocusStreak.currentLength(consecutive(3, 30), today), 3);
    });

    test('sevenInARow_isSeven', () {
      expect(FocusStreak.currentLength(consecutive(7, 25), today), 7);
    });

    test('thirtyInARow_isThirty', () {
      expect(FocusStreak.currentLength(consecutive(30, 26), today), 30);
    });
  });

  group('FocusStreak.currentLength — a sub-25 day breaks it (AC-16)', () {
    test('aDayAt24Min_breaksTheStreakAtThatGap', () {
      final history = <DayStats>[
        dayStats(today, rawActiveTime: const Duration(minutes: 25)),
        dayStats(
          today.subtract(const Duration(days: 1)),
          rawActiveTime: const Duration(minutes: 30),
        ),
        // Below the bar — breaks the chain here.
        dayStats(
          today.subtract(const Duration(days: 2)),
          rawActiveTime: const Duration(minutes: 24),
        ),
        dayStats(
          today.subtract(const Duration(days: 3)),
          rawActiveTime: const Duration(minutes: 60),
        ),
      ];
      expect(FocusStreak.currentLength(history, today), 2);
    });

    test('aMissingCalendarDay_breaksTheStreak', () {
      final history = <DayStats>[
        dayStats(today, rawActiveTime: const Duration(minutes: 30)),
        // No entry for today-1 (gap) — streak is just today.
        dayStats(
          today.subtract(const Duration(days: 2)),
          rawActiveTime: const Duration(minutes: 30),
        ),
      ];
      expect(FocusStreak.currentLength(history, today), 1);
    });
  });

  group('FocusStreak.currentLength — unfinished today (AC-12 gating)', () {
    test('todayNotYetQualified_doesNotZeroAnExistingStreakEndingYesterday', () {
      final history = <DayStats>[
        // Today is unfinished / below the bar.
        dayStats(today, rawActiveTime: const Duration(minutes: 5)),
        dayStats(
          today.subtract(const Duration(days: 1)),
          rawActiveTime: const Duration(minutes: 30),
        ),
        dayStats(
          today.subtract(const Duration(days: 2)),
          rawActiveTime: const Duration(minutes: 30),
        ),
      ];
      // The yesterday-anchored streak is preserved (user can still extend today).
      expect(FocusStreak.currentLength(history, today), 2);
    });

    test('noTodayEntryAtAll_countsTheRunEndingYesterday', () {
      final history = <DayStats>[
        dayStats(
          today.subtract(const Duration(days: 1)),
          rawActiveTime: const Duration(minutes: 30),
        ),
        dayStats(
          today.subtract(const Duration(days: 2)),
          rawActiveTime: const Duration(minutes: 30),
        ),
      ];
      expect(FocusStreak.currentLength(history, today), 2);
    });
  });

  group('FocusStreak.qualifyingDayCount (AC-17 day counting)', () {
    test('countsAllQualifyingDaysRegardlessOfContiguity', () {
      final history = <DayStats>[
        dayStats(today, rawActiveTime: const Duration(minutes: 30)),
        dayStats(
          today.subtract(const Duration(days: 1)),
          rawActiveTime: const Duration(minutes: 10), // not qualifying
        ),
        dayStats(
          today.subtract(const Duration(days: 2)),
          rawActiveTime: const Duration(minutes: 25),
        ),
      ];
      expect(FocusStreak.qualifyingDayCount(history), 2);
    });
  });

  group('FocusStreak — determinism (TC-NF1)', () {
    test('sameHistoryAndToday_yieldsSameLength', () {
      final history = consecutive(4, 30);
      expect(
        FocusStreak.currentLength(history, today),
        FocusStreak.currentLength(history, today),
      );
    });
  });
}
