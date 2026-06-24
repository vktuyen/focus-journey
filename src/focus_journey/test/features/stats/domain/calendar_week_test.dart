// Unit tests for CalendarWeek — pure Mon-Sun calendar-week math keyed off an
// injected date (AC-4, TC-004). No DateTime.now(): every boundary is computed
// from a supplied DateTime. Confirms the week edges are Monday (inclusive) and
// Sunday (inclusive) and the same-week predicate cuts at the Monday boundary.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/stats/domain/calendar_week.dart';

void main() {
  // 2026-06-22 is a Monday; 2026-06-28 is the Sunday that ends that week.
  final monday = DateTime(2026, 6, 22);
  final sunday = DateTime(2026, 6, 28);

  group('CalendarWeek.mondayOf (AC-4)', () {
    test('mondayItself_mapsToItself', () {
      expect(CalendarWeek.mondayOf(monday), monday);
    });

    test('midweekWednesday_mapsBackToMonday', () {
      expect(CalendarWeek.mondayOf(DateTime(2026, 6, 24)), monday);
    });

    test('sundayEndOfWeek_mapsBackToTheSameMonday', () {
      expect(CalendarWeek.mondayOf(sunday), monday);
    });

    test('stripsTimeOfDay_toLocalMidnight', () {
      expect(CalendarWeek.mondayOf(DateTime(2026, 6, 24, 23, 59, 59)), monday);
    });
  });

  group('CalendarWeek.sundayOf (AC-4)', () {
    test('anyDayInWeek_mapsToTheClosingSunday', () {
      expect(CalendarWeek.sundayOf(DateTime(2026, 6, 24)), sunday);
      expect(CalendarWeek.sundayOf(monday), sunday);
      expect(CalendarWeek.sundayOf(sunday), sunday);
    });
  });

  group('CalendarWeek.isSameWeek — boundary is the Monday cut (AC-4)', () {
    test('mondayThroughSunday_areAllTheSameWeek', () {
      for (var i = 0; i < 7; i++) {
        final day = monday.add(Duration(days: i));
        expect(
          CalendarWeek.isSameWeek(day, DateTime(2026, 6, 24)),
          isTrue,
          reason: '$day should be in the same week as the Wednesday',
        );
      }
    });

    test('priorSunday_isADifferentWeek', () {
      final priorSunday = monday.subtract(const Duration(days: 1));
      expect(CalendarWeek.isSameWeek(priorSunday, monday), isFalse);
    });

    test('nextMonday_isADifferentWeek', () {
      final nextMonday = sunday.add(const Duration(days: 1));
      expect(CalendarWeek.isSameWeek(nextMonday, sunday), isFalse);
    });
  });

  // M1 regression: across a local DST transition, fixed-24h Duration-day math
  // would land a computed Monday at 23:00/01:00 instead of midnight, so two
  // same-week days could compare unequal. The component-based mondayOf must
  // return local midnight for every day and agree across the whole week.
  group('CalendarWeek DST-straddle (M1)', () {
    // Weeks containing real Northern-hemisphere DST Sundays. In many locales
    // 2026-03-08 (spring-forward) and 2026-11-01 (fall-back) are DST Sundays;
    // these weeks are Mon 2026-03-02..Sun 2026-03-08 and Mon 2026-10-26..Sun
    // 2026-11-01. The assertions hold in ANY timezone because mondayOf is
    // component-based (DST-safe by construction).
    void assertWholeWeekAgrees(DateTime weekMonday) {
      final expectedMonday = DateTime(
        weekMonday.year,
        weekMonday.month,
        weekMonday.day,
      );
      for (var i = 0; i < 7; i++) {
        final day = DateTime(
          weekMonday.year,
          weekMonday.month,
          weekMonday.day + i,
        );
        // Every day of the week maps to the same Monday at local midnight.
        expect(
          CalendarWeek.mondayOf(day),
          expectedMonday,
          reason: 'mondayOf($day) must equal the week Monday at local midnight',
        );
        expect(CalendarWeek.mondayOf(day).hour, 0);
        // And every pair within the week compares same-week.
        expect(CalendarWeek.isSameWeek(day, expectedMonday), isTrue);
      }
      // The day after Sunday is a new week (boundary still cuts correctly).
      final nextMonday = DateTime(
        weekMonday.year,
        weekMonday.month,
        weekMonday.day + 7,
      );
      expect(CalendarWeek.isSameWeek(nextMonday, expectedMonday), isFalse);
    }

    test('springForwardWeek_allSevenDaysShareOneMidnightMonday', () {
      // Mon 2026-03-02 .. Sun 2026-03-08 (spring-forward Sunday in many locales).
      assertWholeWeekAgrees(DateTime(2026, 3, 2));
    });

    test('fallBackWeek_allSevenDaysShareOneMidnightMonday', () {
      // Mon 2026-10-26 .. Sun 2026-11-01 (fall-back Sunday in many locales).
      assertWholeWeekAgrees(DateTime(2026, 10, 26));
    });
  });
}
