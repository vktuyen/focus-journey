// Unit tests for DailyStatsProjection + the honesty invariant (AC-1, AC-2,
// TC-001/TC-002). The projection is a pure function of a fixed engine snapshot:
// it surfaces the four headline numbers, carries raw active time as its OWN
// labelled field, and NEVER renders raw > journey. A raw>journey input is a
// DEFECT: project() throws HonestyInvariantViolation rather than emit it.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/stats/domain/daily_stats.dart';

const double _tol = 1e-6;

void main() {
  group('DailyStatsProjection.project — four headline numbers (AC-1)', () {
    test('surfacesActiveRawDistanceIdleAndBestFocus_fromTheSnapshot', () {
      final daily = DailyStatsProjection.project(
        activeTime: const Duration(minutes: 45),
        rawActiveTime: const Duration(minutes: 38),
        distanceKm: 7.5,
        idleTime: const Duration(minutes: 12),
        bestFocusPeriod: const Duration(minutes: 22),
      );

      expect(daily.activeTime, const Duration(minutes: 45));
      expect(daily.rawActiveTime, const Duration(minutes: 38));
      expect(daily.distanceKm, closeTo(7.5, _tol));
      expect(daily.idleTime, const Duration(minutes: 12));
      expect(daily.bestFocusPeriod, const Duration(minutes: 22));
    });

    test('zeroSnapshot_projectsAllZeros', () {
      final daily = DailyStatsProjection.project(
        activeTime: Duration.zero,
        rawActiveTime: Duration.zero,
        distanceKm: 0,
        idleTime: Duration.zero,
        bestFocusPeriod: Duration.zero,
      );
      expect(daily.activeTime, Duration.zero);
      expect(daily.rawActiveTime, Duration.zero);
      expect(daily.distanceKm, 0);
    });
  });

  group('DailyStatsProjection.project — honesty invariant (AC-2)', () {
    test('rawIsCarriedAsItsOwnFieldDistinctFromActive', () {
      // Grace consumed: journey (active) > raw. The two are separate values.
      final daily = DailyStatsProjection.project(
        activeTime: const Duration(minutes: 30),
        rawActiveTime: const Duration(minutes: 25),
        distanceKm: 4,
        idleTime: Duration.zero,
        bestFocusPeriod: const Duration(minutes: 10),
      );
      expect(daily.rawActiveTime, isNot(daily.activeTime));
      expect(daily.rawActiveTime < daily.activeTime, isTrue);
    });

    test('rawEqualToJourney_zeroGrace_isAllowedAndShownEqual', () {
      final daily = DailyStatsProjection.project(
        activeTime: const Duration(minutes: 30),
        rawActiveTime: const Duration(minutes: 30),
        distanceKm: 4,
        idleTime: Duration.zero,
        bestFocusPeriod: const Duration(minutes: 10),
      );
      expect(daily.rawActiveTime, daily.activeTime);
    });

    test(
      'rawGreaterThanJourney_throwsHonestyInvariantViolation_notRendered',
      () {
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
      },
    );

    test('honestyViolation_carriesTheOffendingValuesForDiagnostics', () {
      try {
        DailyStatsProjection.project(
          activeTime: const Duration(minutes: 10),
          rawActiveTime: const Duration(minutes: 11),
          distanceKm: 0,
          idleTime: Duration.zero,
          bestFocusPeriod: Duration.zero,
        );
        fail('expected HonestyInvariantViolation');
      } on HonestyInvariantViolation catch (e) {
        expect(e.rawActiveTime, const Duration(minutes: 11));
        expect(e.activeTime, const Duration(minutes: 10));
        expect(e.toString(), contains('AC-2'));
      }
    });
  });

  group('DailyStats — value equality (cheap field-by-field testing)', () {
    test('sameFields_areEqual', () {
      final a = DailyStatsProjection.project(
        activeTime: const Duration(minutes: 5),
        rawActiveTime: const Duration(minutes: 5),
        distanceKm: 1,
        idleTime: Duration.zero,
        bestFocusPeriod: Duration.zero,
      );
      final b = DailyStatsProjection.project(
        activeTime: const Duration(minutes: 5),
        rawActiveTime: const Duration(minutes: 5),
        distanceKm: 1,
        idleTime: Duration.zero,
        bestFocusPeriod: Duration.zero,
      );
      expect(a, b);
    });
  });

  group('DailyStatsProjection — determinism (TC-NF1)', () {
    test('sameSnapshot_yieldsIdenticalProjection', () {
      DailyStats run() => DailyStatsProjection.project(
        activeTime: const Duration(minutes: 33),
        rawActiveTime: const Duration(minutes: 30),
        distanceKm: 9.25,
        idleTime: const Duration(minutes: 2),
        bestFocusPeriod: const Duration(minutes: 14),
      );
      expect(run(), run());
    });
  });
}
