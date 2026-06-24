// Unit tests for BadgeEvaluator + the data-driven BadgeCatalogue (AC-13..AC-18,
// TC-013..TC-018). Keys off catalogue STRUCTURE + threshold-CROSSING, never the
// literal numbers (the per-badge thresholds are a pending OQ), so re-tuning the
// catalogue does not churn these tests. The locked rules — the four families,
// permanent-vs-windowed reset, raw-not-journey for focus-time — are asserted
// structurally. Pure, deterministic, keyed off an injected "today".

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/stats/domain/badge.dart';
import 'package:focus_journey/features/stats/domain/badge_catalogue.dart';
import 'package:focus_journey/features/stats/domain/badge_evaluator.dart';
import 'package:focus_journey/features/stats/domain/earned_badges.dart';

/// A terse [BadgeContext] builder so each test drives only the field it crosses.
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

void main() {
  final today = DateTime(2026, 6, 24); // a Wednesday in week W

  group('BadgeCatalogue — data-driven structure (AC-13)', () {
    test('spansAllFourFamilies', () {
      final families = BadgeCatalogue.badges.map((b) => b.family).toSet();
      expect(families, BadgeFamily.values.toSet());
    });

    test('everyFamilyHasAtLeastOneEarnableBadge', () {
      for (final family in BadgeFamily.values) {
        expect(
          BadgeCatalogue.badges.where((b) => b.family == family),
          isNotEmpty,
          reason: 'family $family must have at least one badge',
        );
      }
    });

    test('badgeIdsAreUnique_soEarnedStateNeverCollides', () {
      final ids = BadgeCatalogue.badges.map((b) => b.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('catalogueContainsBothPermanentAndWindowedScopes', () {
      final scopes = BadgeCatalogue.badges.map((b) => b.scope).toSet();
      expect(scopes, contains(BadgeScope.permanent));
      expect(scopes, contains(BadgeScope.weekly));
    });
  });

  group(
    'BadgeEvaluator — each family unlocks at its threshold (AC-13..AC-17)',
    () {
      // For each family, pick the lowest-threshold representative badge and drive
      // the relevant context field across it via the catalogue's own constant —
      // keying off the threshold crossing, not the literal number.

      test(
        'distanceFamily_unlocksWhenCumulativeDistanceCrossesAMark (AC-14)',
        () {
          final result = BadgeEvaluator.evaluate(
            catalogue: BadgeCatalogue.badges,
            context: ctx(distance: BadgeThresholds.distanceFirst100Km),
            current: const EarnedBadges.empty(),
            today: today,
          );
          expect(result.newlyEarned, contains('distance_first_100km'));
          expect(result.earned.contains('distance_first_100km'), isTrue);
        },
      );

      test('journeyProgressFamily_unlocksWhenPercentCrossesAMark (AC-15)', () {
        final result = BadgeEvaluator.evaluate(
          catalogue: BadgeCatalogue.badges,
          context: ctx(percent: BadgeThresholds.halfwayPercent),
          current: const EarnedBadges.empty(),
          today: today,
        );
        expect(result.earned.contains('journey_halfway'), isTrue);
      });

      test('journeyProgressFamily_unlocksWhenProvincesCrossed (AC-15)', () {
        final result = BadgeEvaluator.evaluate(
          catalogue: BadgeCatalogue.badges,
          context: ctx(provinces: BadgeThresholds.crossedProvinces),
          current: const EarnedBadges.empty(),
          today: today,
        );
        expect(result.earned.contains('journey_crossed_provinces'), isTrue);
      });

      test('journeyProgressFamily_unlocksOnRouteComplete (AC-15)', () {
        final result = BadgeEvaluator.evaluate(
          catalogue: BadgeCatalogue.badges,
          context: ctx(completed: true),
          current: const EarnedBadges.empty(),
          today: today,
        );
        expect(result.earned.contains('journey_route_complete'), isTrue);
      });

      test('focusStreakFamily_unlocksWhenStreakLengthCrossesAMark (AC-16)', () {
        final result = BadgeEvaluator.evaluate(
          catalogue: BadgeCatalogue.badges,
          context: ctx(streak: BadgeThresholds.streakShort),
          current: const EarnedBadges.empty(),
          today: today,
        );
        expect(result.earned.contains('streak_3_days'), isTrue);
      });

      test('focusTimeFamily_unlocksOnRawActiveDailyGoal (AC-17)', () {
        final result = BadgeEvaluator.evaluate(
          catalogue: BadgeCatalogue.badges,
          context: ctx(rawToday: BadgeThresholds.dailyRawActiveGoal),
          current: const EarnedBadges.empty(),
          today: today,
        );
        expect(result.earned.contains('focus_daily_goal'), isTrue);
      });
    },
  );

  group('BadgeEvaluator — below threshold stays locked (AC-13)', () {
    test('justBelowAMark_doesNotEarn', () {
      final result = BadgeEvaluator.evaluate(
        catalogue: BadgeCatalogue.badges,
        context: ctx(distance: BadgeThresholds.distanceFirst100Km - 0.01),
        current: const EarnedBadges.empty(),
        today: today,
      );
      expect(result.earned.contains('distance_first_100km'), isFalse);
      expect(result.newlyEarned, isEmpty);
    });
  });

  group('BadgeEvaluator — focus-time keyed on RAW, never journey (AC-17)', () {
    test('journeyInflatedButRawBelowGoal_doesNotEarnTheDailyGoalBadge', () {
      // The daily-goal predicate reads todayRawActive only; an inflated journey
      // time is not even present in the context, so the badge cannot leak in on
      // grace-inflated time. Raw just below the goal stays locked.
      final result = BadgeEvaluator.evaluate(
        catalogue: BadgeCatalogue.badges,
        context: ctx(
          rawToday:
              BadgeThresholds.dailyRawActiveGoal - const Duration(seconds: 1),
        ),
        current: const EarnedBadges.empty(),
        today: today,
      );
      expect(result.earned.contains('focus_daily_goal'), isFalse);
    });
  });

  group(
    'BadgeEvaluator — permanent persists, newlyEarned only once (AC-13)',
    () {
      test('anAlreadyEarnedBadge_isNotReportedAsNewlyEarnedAgain', () {
        final first = BadgeEvaluator.evaluate(
          catalogue: BadgeCatalogue.badges,
          context: ctx(distance: BadgeThresholds.distanceFirst100Km),
          current: const EarnedBadges.empty(),
          today: today,
        );
        expect(first.newlyEarned, contains('distance_first_100km'));

        final second = BadgeEvaluator.evaluate(
          catalogue: BadgeCatalogue.badges,
          context: ctx(distance: BadgeThresholds.distance500Km),
          current: first.earned,
          today: today,
        );
        // The already-earned 100 km badge is not re-announced.
        expect(second.newlyEarned, isNot(contains('distance_first_100km')));
        // It is still earned, and the new 500 km badge joins it.
        expect(second.earned.contains('distance_first_100km'), isTrue);
        expect(second.newlyEarned, contains('distance_500km'));
      });

      test('permanentBadge_survivesAWeekRollover (AC-18)', () {
        final earned = BadgeEvaluator.evaluate(
          catalogue: BadgeCatalogue.badges,
          context: ctx(distance: BadgeThresholds.distanceFirst100Km),
          current: const EarnedBadges.empty(),
          today: today,
        ).earned;

        final nextWeek = today.add(const Duration(days: 7));
        final afterRollover = BadgeEvaluator.evaluate(
          catalogue: BadgeCatalogue.badges,
          context: ctx(),
          current: earned,
          today: nextWeek,
        );
        expect(afterRollover.earned.contains('distance_first_100km'), isTrue);
      });
    },
  );

  group(
    'BadgeEvaluator — windowed badge resets at the week boundary (AC-18)',
    () {
      test('windowedBadge_resetsToLockedInTheNewWeek_andIsReEarnable', () {
        final wk1 = today;
        // Earn a windowed badge (and a permanent one to prove permanence).
        final earned = BadgeEvaluator.evaluate(
          catalogue: BadgeCatalogue.badges,
          context: ctx(
            weekDistance: BadgeThresholds.weekDistance100Km,
            distance: BadgeThresholds.distanceFirst100Km,
          ),
          current: const EarnedBadges.empty(),
          today: wk1,
        ).earned;
        expect(earned.contains('distance_century_week'), isTrue);

        // New week, no week distance: the windowed badge resets.
        final wk2 = wk1.add(const Duration(days: 7));
        final afterReset = BadgeEvaluator.evaluate(
          catalogue: BadgeCatalogue.badges,
          context: ctx(distance: BadgeThresholds.distanceFirst100Km),
          current: earned,
          today: wk2,
        );
        expect(afterReset.earned.contains('distance_century_week'), isFalse);
        expect(afterReset.earned.contains('distance_first_100km'), isTrue);

        // Re-earnable in the new week when the mark is crossed again.
        final reEarned = BadgeEvaluator.evaluate(
          catalogue: BadgeCatalogue.badges,
          context: ctx(
            weekDistance: BadgeThresholds.weekDistance100Km,
            distance: BadgeThresholds.distanceFirst100Km,
          ),
          current: afterReset.earned,
          today: wk2,
        );
        expect(reEarned.earned.contains('distance_century_week'), isTrue);
        expect(reEarned.newlyEarned, contains('distance_century_week'));
      });

      test('windowedBadge_staysEarnedWithinTheSameWeek', () {
        final earned = BadgeEvaluator.evaluate(
          catalogue: BadgeCatalogue.badges,
          context: ctx(weekDistance: BadgeThresholds.weekDistance100Km),
          current: const EarnedBadges.empty(),
          today: today,
        ).earned;

        // Same week, later day, no fresh week distance reported on this tick.
        final laterSameWeek = BadgeEvaluator.evaluate(
          catalogue: BadgeCatalogue.badges,
          context: ctx(),
          current: earned,
          today: today.add(const Duration(days: 2)),
        );
        expect(laterSameWeek.earned.contains('distance_century_week'), isTrue);
      });
    },
  );

  group('BadgeEvaluator — works with a custom test catalogue (AC-13)', () {
    test('aDataDrivenTestCatalogue_evaluatesByPredicate_notHardcodedIds', () {
      final testCatalogue = <BadgeDefinition>[
        BadgeDefinition(
          id: 'test_distance',
          title: 'Test distance',
          description: 'cross 1km',
          family: BadgeFamily.distance,
          scope: BadgeScope.permanent,
          isEarned: (c) => c.cumulativeDistanceKm >= 1,
        ),
        BadgeDefinition(
          id: 'test_week',
          title: 'Test week',
          description: 'cross 1 week km',
          family: BadgeFamily.distance,
          scope: BadgeScope.weekly,
          isEarned: (c) => c.weekDistanceKm >= 1,
        ),
      ];
      final result = BadgeEvaluator.evaluate(
        catalogue: testCatalogue,
        context: ctx(distance: 1, weekDistance: 1),
        current: const EarnedBadges.empty(),
        today: today,
      );
      expect(
        result.earned.earnedIds,
        containsAll(<String>['test_distance', 'test_week']),
      );
    });
  });

  // M2: daily-scope badges read TODAY's metrics — they must reset at the local
  // midnight boundary and be re-earnable the next day, while permanent/weekly
  // scopes keep their existing semantics.
  group('BadgeEvaluator — daily badge resets next day (M2 / AC-17/AC-18)', () {
    test('catalogueContainsADailyScope', () {
      final scopes = BadgeCatalogue.badges.map((b) => b.scope).toSet();
      expect(scopes, contains(BadgeScope.daily));
    });

    test('focusDailyGoalAndDeepStretch_areDailyScope', () {
      final byId = {for (final b in BadgeCatalogue.badges) b.id: b};
      expect(byId['focus_daily_goal']!.scope, BadgeScope.daily);
      expect(byId['focus_deep_stretch']!.scope, BadgeScope.daily);
    });

    test('dailyBadge_resetsToLockedTheNextDay_andIsReEarnable', () {
      final dayD = today;
      // Earn the daily goal on day D (plus a permanent + a weekly to prove the
      // day rollover does NOT touch those).
      final earned = BadgeEvaluator.evaluate(
        catalogue: BadgeCatalogue.badges,
        context: ctx(
          rawToday: BadgeThresholds.dailyRawActiveGoal,
          distance: BadgeThresholds.distanceFirst100Km,
          weekDistance: BadgeThresholds.weekDistance100Km,
        ),
        current: const EarnedBadges.empty(),
        today: dayD,
      ).earned;
      expect(earned.contains('focus_daily_goal'), isTrue);
      expect(earned.contains('distance_century_week'), isTrue);
      expect(earned.contains('distance_first_100km'), isTrue);

      // Next local day (still the SAME week): the daily badge resets, while the
      // weekly + permanent badges persist.
      final dayDPlus1 = DateTime(today.year, today.month, today.day + 1);
      final afterDay = BadgeEvaluator.evaluate(
        catalogue: BadgeCatalogue.badges,
        context: ctx(distance: BadgeThresholds.distanceFirst100Km),
        current: earned,
        today: dayDPlus1,
      );
      expect(
        afterDay.earned.contains('focus_daily_goal'),
        isFalse,
        reason: 'daily badge must reset at the next local day',
      );
      expect(
        afterDay.earned.contains('distance_century_week'),
        isTrue,
        reason: 'weekly badge must survive a mere day rollover (same week)',
      );
      expect(afterDay.earned.contains('distance_first_100km'), isTrue);

      // Re-earnable the next day when today's metric crosses again.
      final reEarned = BadgeEvaluator.evaluate(
        catalogue: BadgeCatalogue.badges,
        context: ctx(rawToday: BadgeThresholds.dailyRawActiveGoal),
        current: afterDay.earned,
        today: dayDPlus1,
      );
      expect(reEarned.earned.contains('focus_daily_goal'), isTrue);
      expect(reEarned.newlyEarned, contains('focus_daily_goal'));
    });

    test('dailyBadge_staysEarnedWithinTheSameDay', () {
      final earned = BadgeEvaluator.evaluate(
        catalogue: BadgeCatalogue.badges,
        context: ctx(rawToday: BadgeThresholds.dailyRawActiveGoal),
        current: const EarnedBadges.empty(),
        today: today,
      ).earned;

      // Same day, later (raw not reported on this tick) — stays earned.
      final laterSameDay = BadgeEvaluator.evaluate(
        catalogue: BadgeCatalogue.badges,
        context: ctx(),
        current: earned,
        today: today,
      );
      expect(laterSameDay.earned.contains('focus_daily_goal'), isTrue);
    });
  });

  group('BadgeEvaluator — determinism (TC-NF1)', () {
    test('sameInputs_yieldIdenticalEvaluation', () {
      final c = ctx(distance: BadgeThresholds.distanceFirst100Km, streak: 3);
      final a = BadgeEvaluator.evaluate(
        catalogue: BadgeCatalogue.badges,
        context: c,
        current: const EarnedBadges.empty(),
        today: today,
      );
      final b = BadgeEvaluator.evaluate(
        catalogue: BadgeCatalogue.badges,
        context: c,
        current: const EarnedBadges.empty(),
        today: today,
      );
      expect(a.earned, b.earned);
      expect(a.newlyEarned, b.newlyEarned);
    });
  });
}
