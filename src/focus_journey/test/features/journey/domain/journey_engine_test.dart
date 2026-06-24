// Deterministic unit tests for the pure, framework-free JourneyEngine.
//
// Scope: the domain core loop only — no real timers, no real waits, no
// DateTime.now() (a scripted FakeClock is injected), no native code, no Flame,
// no UI. Every "time passes" is a value fed to tick(delta) or scripted on the
// injected clock. See tests/cases/journey-engine.md (TC-001..TC-022) and
// specs/journey-engine/acceptance-criteria.md (AC-1..AC-16).
//
// Conventions mirror test/features/activity/* : group by behaviour, name tests
// as <subject>_<condition>_<expected> sentences, cite the AC/TC in comments.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/activity/data/mock_activity_source.dart';
import 'package:focus_journey/features/journey/domain/clock.dart';
import 'package:focus_journey/features/journey/domain/journey_engine.dart';
import 'package:focus_journey/features/journey/domain/journey_progress.dart';
import 'package:focus_journey/features/journey/domain/journey_repository.dart';
import 'package:focus_journey/features/journey/domain/journey_state.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';

/// A fully scriptable [Clock]: tests set [now] explicitly. No wall clock, so
/// the engine's day-boundary logic is deterministic (Determinism NFR / AC-12).
class FakeClock implements Clock {
  FakeClock(this._now);

  DateTime _now;

  /// Advances/sets the scripted "current" instant the engine will read next.
  void setNow(DateTime value) => _now = value;

  @override
  DateTime now() => _now;
}

/// An in-memory [JourneyRepository] for round-trip persistence tests (TC-018,
/// TC-020) — the real shared_preferences impl is the data layer, out of the
/// pure engine. Serialises through toJson/fromJson to also exercise that seam.
class InMemoryJourneyRepository implements JourneyRepository {
  Map<String, dynamic>? _stored;

  @override
  Future<JourneyProgress?> load() async {
    final stored = _stored;
    if (stored == null) {
      return null;
    }
    return JourneyProgress.fromJson(stored);
  }

  @override
  Future<void> save(JourneyProgress progress) async {
    _stored = progress.toJson();
  }
}

/// km tolerance / hours tolerance per the cases' ±1e-6 rule.
const double kTol = 1e-6;

/// A fixed mid-day instant used wherever the calendar date is irrelevant.
final DateTime _noon = DateTime(2026, 6, 23, 12);

/// Builds an engine with small, exact, easy-to-reason-about knobs.
///
/// `kmPerActiveHour = 10` so 1h ⇒ 10 km exactly. `F = 5s`, `G = T = 5min`
/// (the default empty-middle-band config) unless a test overrides them.
JourneyEngine _engine({
  Clock? clock,
  MockActivitySource? plugin,
  double kmPerActiveHour = 10,
  Duration grace = const Duration(minutes: 5),
  Duration threshold = const Duration(minutes: 5),
  Duration activeFloor = const Duration(seconds: 5),
  Duration? maxTickDelta,
  Duration? sleepIdleThreshold,
  TravelMode mode = TravelMode.motorbike,
}) {
  return JourneyEngine(
    clock: clock ?? FakeClock(_noon),
    activityPlugin: plugin ?? MockActivitySource(),
    kmPerActiveHour: kmPerActiveHour,
    grace: grace,
    threshold: threshold,
    activeFloor: activeFloor,
    maxTickDelta: maxTickDelta,
    sleepIdleThreshold: sleepIdleThreshold,
    mode: mode,
  );
}

void main() {
  group('JourneyEngine — construction validation (S-2, fail loud)', () {
    test('nonPositiveKmPerActiveHour_throwsArgumentError', () {
      expect(() => _engine(kmPerActiveHour: 0), throwsArgumentError);
      expect(() => _engine(kmPerActiveHour: -10), throwsArgumentError);
    });

    test('graceGreaterThanThreshold_throwsArgumentError', () {
      expect(
        () => _engine(
          grace: const Duration(minutes: 10),
          threshold: const Duration(minutes: 5),
        ),
        throwsArgumentError,
      );
    });

    test('activeFloorNotBelowGrace_throwsArgumentError', () {
      expect(
        () => _engine(
          activeFloor: const Duration(minutes: 5),
          grace: const Duration(minutes: 5),
        ),
        throwsArgumentError,
      );
    });
  });

  group('JourneyEngine — distance accrual (TC-001, AC-1)', () {
    test('activeTick_oneHour_accruesExactlyKmPerActiveHour', () {
      // A 1h delta exceeds the default maxTickDelta clamp (2*T=10min); raise the
      // clamp so a genuine long active tick credits the full hour.
      final engine = _engine(
        kmPerActiveHour: 10,
        maxTickDelta: const Duration(hours: 6),
      );

      engine.tick(
        const Duration(hours: 1),
        idleSeconds: 0,
        screenLocked: false,
      );

      expect(engine.distanceKm, closeTo(10, kTol));
      expect(engine.state, JourneyState.active);
    });

    test('activeTick_partialHour_accruesProportionalDistance', () {
      // 30 min at 10 km/h ⇒ 5 km exactly. Raise the clamp so the 30min delta is
      // credited in full (default maxTickDelta = 2*T = 10min would clamp it).
      final engine = _engine(
        kmPerActiveHour: 10,
        maxTickDelta: const Duration(hours: 6),
      );

      engine.tick(
        const Duration(minutes: 30),
        idleSeconds: 0,
        screenLocked: false,
      );

      expect(engine.distanceKm, closeTo(5, kTol));
    });
  });

  group('JourneyEngine — journey vs raw separation (TC-002, AC-2)', () {
    test('mixedActiveAndGraceTicks_rawStrictlyBelowJourney_neverConflated', () {
      // G = T = 5min, F = 5s. Active tick: idle 0. Grace tick: idle 60s
      // (5s < 60 <= 300s), unlocked, well under sleep thresholds.
      final engine = _engine();

      engine.tick(
        const Duration(minutes: 1),
        idleSeconds: 0,
        screenLocked: false,
      );
      engine.tick(
        const Duration(minutes: 1),
        idleSeconds: 60,
        screenLocked: false,
      );

      // Journey accrues for both active + grace; raw only for the active tick.
      expect(engine.activeTimeToday, const Duration(minutes: 2));
      expect(engine.rawActiveTime, const Duration(minutes: 1));
      expect(engine.rawActiveTime, lessThan(engine.activeTimeToday));
      // raw equals the summed active-tick deltas exactly.
      expect(engine.rawActiveTime, const Duration(minutes: 1));
    });
  });

  group('JourneyEngine — active tick accounting (TC-003, AC-3)', () {
    test('activeTick_idleBelowFloor_accruesDistanceJourneyRaw_notIdle', () {
      final engine = _engine();

      engine.tick(
        const Duration(minutes: 6),
        idleSeconds: 0,
        screenLocked: false,
      );

      expect(engine.state, JourneyState.active);
      expect(engine.distanceKm, closeTo(1, kTol)); // 6min at 10km/h = 1km.
      expect(engine.activeTimeToday, const Duration(minutes: 6));
      expect(engine.rawActiveTime, const Duration(minutes: 6));
      expect(engine.idleTimeToday, Duration.zero);
    });

    test('activeTick_idleExactlyAtFloor_belongsToActiveBand', () {
      // Boundary: idle == F (5s) is inclusive of the active band.
      final engine = _engine(activeFloor: const Duration(seconds: 5));

      engine.tick(
        const Duration(minutes: 1),
        idleSeconds: 5,
        screenLocked: false,
      );

      expect(engine.state, JourneyState.active);
      expect(engine.rawActiveTime, const Duration(minutes: 1));
      expect(engine.activeTimeToday, const Duration(minutes: 1));
      expect(engine.idleTimeToday, Duration.zero);
    });
  });

  group('JourneyEngine — grace tick accounting (TC-004, AC-4)', () {
    test('graceTick_idleBetweenFandG_accruesDistanceJourney_notRawNotIdle', () {
      final engine = _engine();

      engine.tick(
        const Duration(minutes: 1),
        idleSeconds: 60,
        screenLocked: false,
      );

      expect(engine.state, JourneyState.active); // travelling.
      expect(engine.distanceKm, closeTo(10 / 60, kTol)); // 1min at 10km/h.
      expect(engine.activeTimeToday, const Duration(minutes: 1));
      expect(engine.rawActiveTime, Duration.zero);
      expect(engine.idleTimeToday, Duration.zero);
    });

    test('graceTick_idleExactlyAtG_stillTravels', () {
      // Boundary: idle == G (300s) is still travel (idle > grace is the cut).
      final engine = _engine();

      engine.tick(
        const Duration(minutes: 1),
        idleSeconds: 300,
        screenLocked: false,
      );

      expect(engine.state, JourneyState.active);
      expect(engine.activeTimeToday, const Duration(minutes: 1));
      expect(engine.rawActiveTime, Duration.zero);
    });
  });

  group('JourneyEngine — past grace, idle only (TC-005, AC-5)', () {
    test('idleBand_GbelowT_accruesIdleOnly_noTravel', () {
      // G = 5min, T = 10min ⇒ idle band G < s <= T non-empty. idle = 360s.
      final engine = _engine(threshold: const Duration(minutes: 10));

      engine.tick(
        const Duration(minutes: 1),
        idleSeconds: 360,
        screenLocked: false,
      );

      expect(engine.distanceKm, 0);
      expect(engine.activeTimeToday, Duration.zero);
      expect(engine.rawActiveTime, Duration.zero);
      expect(engine.idleTimeToday, const Duration(minutes: 1));
    });
  });

  group('JourneyEngine — lock overrides grace (TC-006, AC-6)', () {
    test('lockedTick_idleInsideGraceBand_noTravel_idleOnly', () {
      final engine = _engine();

      engine.tick(
        const Duration(minutes: 1),
        idleSeconds: 60,
        screenLocked: true,
      );

      expect(engine.state, JourneyState.paused);
      expect(engine.distanceKm, 0);
      expect(engine.activeTimeToday, Duration.zero);
      expect(engine.rawActiveTime, Duration.zero);
      expect(engine.idleTimeToday, const Duration(minutes: 1));
    });
  });

  group('JourneyEngine — sleep-inferred overrides grace (TC-007, AC-6)', () {
    test('largeIdleInsideGraceDeltaSmall_inferredSleep_noTravel_idleOnly', () {
      // F=5s, G=T=5min ⇒ sleepIdleThreshold = 2*T = 600s. idle = 600s triggers
      // sleep inference even though delta is small.
      final engine = _engine();

      engine.tick(
        const Duration(seconds: 10),
        idleSeconds: 600,
        screenLocked: false,
      );

      expect(engine.state, JourneyState.paused);
      expect(engine.distanceKm, 0);
      expect(engine.activeTimeToday, Duration.zero);
      expect(engine.rawActiveTime, Duration.zero);
      expect(engine.idleTimeToday, const Duration(seconds: 10));
    });

    test('largeDeltaIdleSmall_isActive_creditClampedToMaxTickDelta', () {
      // B-1: a large delta with a SMALL idle reading (idle = 0 = recent input,
      // e.g. a stalled/slow ticker while the user is genuinely active) is NOT
      // sleep — sleep is keyed on the idle signal only. The tick is active; its
      // accrued delta is clamped to maxTickDelta (default 2*T = 10min) so a stall
      // can't over-credit, but real work is credited (up to the clamp), not lost.
      // kmPerActiveHour = 10, maxTickDelta = 10min ⇒ distance = 10 * 10/60.
      final engine = _engine();

      engine.tick(
        const Duration(minutes: 30),
        idleSeconds: 0,
        screenLocked: false,
      );

      expect(engine.state, JourneyState.active);
      expect(engine.distanceKm, closeTo(10 * 10 / 60, kTol));
      expect(engine.activeTimeToday, const Duration(minutes: 10));
      expect(engine.rawActiveTime, const Duration(minutes: 10));
      expect(engine.idleTimeToday, Duration.zero);
    });
  });

  group('JourneyEngine — sleep/wake gap is idle, not travel (TC-008, AC-8)', () {
    test('wasActive_thenLargeGapTick_entireGapIsIdle_noTravelCredit', () {
      final engine = _engine();

      // Active stretch first.
      engine.tick(
        const Duration(minutes: 1),
        idleSeconds: 0,
        screenLocked: false,
      );
      final distAfterActive = engine.distanceKm;
      final journeyAfterActive = engine.activeTimeToday;
      final rawAfterActive = engine.rawActiveTime;

      // Long real-time gap (machine asleep): large delta + large idle reading.
      engine.tick(
        const Duration(hours: 2),
        idleSeconds: 7200,
        screenLocked: false,
      );

      // No travel credit for the gap; the whole gap is idle.
      expect(engine.distanceKm, closeTo(distAfterActive, kTol));
      expect(engine.activeTimeToday, journeyAfterActive);
      expect(engine.rawActiveTime, rawAfterActive);
      expect(engine.idleTimeToday, const Duration(hours: 2));
      expect(engine.state, JourneyState.paused);
    });
  });

  group('JourneyEngine — delta-scaled elapsed (TC-009, AC-7)', () {
    test(
      'oneSixtySecondTick_equalsSixTenSecondTicks_acrossAllAccumulators',
      () {
        final coarse = _engine();
        final fine = _engine();

        coarse.tick(
          const Duration(seconds: 60),
          idleSeconds: 0,
          screenLocked: false,
        );
        for (var i = 0; i < 6; i++) {
          fine.tick(
            const Duration(seconds: 10),
            idleSeconds: 0,
            screenLocked: false,
          );
        }

        expect(fine.distanceKm, closeTo(coarse.distanceKm, kTol));
        expect(fine.activeTimeToday, coarse.activeTimeToday);
        expect(fine.rawActiveTime, coarse.rawActiveTime);
      },
    );
  });

  group(
    'JourneyEngine — empty middle band, default G=T (TC-010, AC-16/AC-5)',
    () {
      test('defaultGequalsT_idleJustAboveG_goesStraightToPaused', () {
        // G = T = 5min (=300s). idle = 301s is > grace and > threshold ⇒ paused,
        // never idle.
        final engine = _engine();

        engine.tick(
          const Duration(minutes: 1),
          idleSeconds: 301,
          screenLocked: false,
        );

        expect(engine.state, JourneyState.paused);
        expect(engine.distanceKm, 0);
        expect(engine.activeTimeToday, Duration.zero);
        expect(engine.rawActiveTime, Duration.zero);
        expect(engine.idleTimeToday, const Duration(minutes: 1));
      });
    },
  );

  group('JourneyEngine — idle vs paused with G<T (TC-011, AC-16)', () {
    test('idleInMiddleBand_isIdleState_pastT_isPausedState_sameAccounting', () {
      // G = 5min (300s), T = 10min (600s). Middle band 300 < s <= 600.
      final idleBand = _engine(threshold: const Duration(minutes: 10));
      final pastT = _engine(threshold: const Duration(minutes: 10));

      idleBand.tick(
        const Duration(minutes: 1),
        idleSeconds: 360,
        screenLocked: false,
      );
      pastT.tick(
        const Duration(minutes: 1),
        idleSeconds: 601,
        screenLocked: false,
      );

      expect(idleBand.state, JourneyState.idle);
      expect(pastT.state, JourneyState.paused);

      // Accounting identical: idle-only, no travel.
      for (final e in [idleBand, pastT]) {
        expect(e.distanceKm, 0);
        expect(e.activeTimeToday, Duration.zero);
        expect(e.rawActiveTime, Duration.zero);
        expect(e.idleTimeToday, const Duration(minutes: 1));
      }
    });

    test('lockedInMiddleBand_isPausedNotIdle', () {
      // Locked yields paused regardless of s being in the middle band.
      final engine = _engine(threshold: const Duration(minutes: 10));

      engine.tick(
        const Duration(minutes: 1),
        idleSeconds: 360,
        screenLocked: true,
      );

      expect(engine.state, JourneyState.paused);
      expect(engine.idleTimeToday, const Duration(minutes: 1));
    });
  });

  group('JourneyEngine — determinism (TC-012, AC-12)', () {
    test('sameScriptedSequence_runTwice_yieldsIdenticalOutputs', () {
      List<Object?> run() {
        final engine = _engine();
        engine.tick(
          const Duration(seconds: 30),
          idleSeconds: 0,
          screenLocked: false,
        );
        engine.tick(
          const Duration(seconds: 30),
          idleSeconds: 60,
          screenLocked: false,
        );
        engine.tick(
          const Duration(seconds: 30),
          idleSeconds: 360,
          screenLocked: false,
        );
        engine.tick(
          const Duration(seconds: 30),
          idleSeconds: 0,
          screenLocked: true,
        );
        return <Object?>[
          engine.distanceKm,
          engine.activeTimeToday,
          engine.rawActiveTime,
          engine.idleTimeToday,
          engine.state,
          engine.mode,
        ];
      }

      expect(run(), run());
    });

    test('outputIndependentOfWallClockValueOnFakeClock', () {
      // Two clocks set to wildly different wall-clock *times* but the SAME
      // local date produce identical outputs — the engine reads no real clock
      // for elapsed time.
      final early = _engine(clock: FakeClock(DateTime(2026, 6, 23, 0, 1)));
      final late = _engine(clock: FakeClock(DateTime(2026, 6, 23, 23, 59)));

      for (final e in [early, late]) {
        e.tick(
          const Duration(seconds: 30),
          idleSeconds: 0,
          screenLocked: false,
        );
      }

      expect(early.distanceKm, late.distanceKm);
      expect(early.activeTimeToday, late.activeTimeToday);
    });
  });

  group('JourneyEngine — mode is cosmetic (TC-013, AC-13)', () {
    test('twoModes_identicalSequence_equalDistanceAndTimes_modePreserved', () {
      final bike = _engine(mode: TravelMode.motorbike);
      final ship = _engine(mode: TravelMode.ship);

      for (final e in [bike, ship]) {
        e.tick(const Duration(minutes: 1), idleSeconds: 0, screenLocked: false);
        e.tick(
          const Duration(minutes: 1),
          idleSeconds: 60,
          screenLocked: false,
        );
      }

      expect(bike.distanceKm, closeTo(ship.distanceKm, kTol));
      expect(bike.activeTimeToday, ship.activeTimeToday);
      expect(bike.rawActiveTime, ship.rawActiveTime);
      expect(bike.mode, TravelMode.motorbike);
      expect(ship.mode, TravelMode.ship);
    });
  });

  group('JourneyEngine — grace stays travel, no rollback (TC-014, AC-14)', () {
    test('graceCreditedThenThresholdCrossed_priorTravelUnchanged', () {
      final engine = _engine();

      // Active then grace ticks accrue distance + journey.
      engine.tick(
        const Duration(minutes: 1),
        idleSeconds: 0,
        screenLocked: false,
      );
      engine.tick(
        const Duration(minutes: 1),
        idleSeconds: 60,
        screenLocked: false,
      );
      final distAfterGrace = engine.distanceKm;
      final journeyAfterGrace = engine.activeTimeToday;
      final rawAfterGrace = engine.rawActiveTime;

      // Threshold-crossing tick (idle past G=T) must not roll back prior grace.
      engine.tick(
        const Duration(minutes: 1),
        idleSeconds: 400,
        screenLocked: false,
      );

      expect(engine.distanceKm, closeTo(distAfterGrace, kTol));
      expect(engine.activeTimeToday, journeyAfterGrace);
      expect(engine.rawActiveTime, rawAfterGrace);
      expect(engine.idleTimeToday, const Duration(minutes: 1));
    });
  });

  group(
    'JourneyEngine — raw is streak metric and <= journey (TC-015, AC-15/AC-2)',
    () {
      test('mixedSequence_rawExcludesGrace_andStaysBelowOrEqualJourney', () {
        final engine = _engine();

        engine.tick(
          const Duration(minutes: 2),
          idleSeconds: 0,
          screenLocked: false,
        );
        engine.tick(
          const Duration(minutes: 3),
          idleSeconds: 60,
          screenLocked: false,
        );
        engine.tick(
          const Duration(minutes: 1),
          idleSeconds: 0,
          screenLocked: false,
        );

        // raw = active deltas only (2 + 1 = 3min); journey = all travel (6min).
        expect(engine.rawActiveTime, const Duration(minutes: 3));
        expect(engine.activeTimeToday, const Duration(minutes: 6));
        expect(engine.rawActiveTime <= engine.activeTimeToday, isTrue);
      });
    },
  );

  group('JourneyEngine — local-midnight reset (TC-016, AC-9)', () {
    test('clockCrossesMidnight_dailyCountersReset_distancePreserved', () {
      final clock = FakeClock(DateTime(2026, 6, 23, 23, 59));
      final engine = _engine(clock: clock);

      engine.tick(
        const Duration(minutes: 2),
        idleSeconds: 0,
        screenLocked: false,
      );
      engine.tick(
        const Duration(minutes: 1),
        idleSeconds: 60,
        screenLocked: false,
      );
      engine.tick(
        const Duration(minutes: 1),
        idleSeconds: 360,
        screenLocked: false,
      );
      final distanceBeforeMidnight = engine.distanceKm;
      expect(distanceBeforeMidnight, greaterThan(0));

      // Cross into the next local day, then tick.
      clock.setNow(DateTime(2026, 6, 24, 0, 0));
      engine.tick(
        const Duration(minutes: 1),
        idleSeconds: 0,
        screenLocked: false,
      );

      // Daily counters reset; the post-midnight active tick is the only accrual.
      expect(engine.activeTimeToday, const Duration(minutes: 1));
      expect(engine.rawActiveTime, const Duration(minutes: 1));
      expect(engine.idleTimeToday, Duration.zero);
      // Cumulative distance preserved across the boundary (carried + new tick).
      expect(
        engine.distanceKm,
        closeTo(distanceBeforeMidnight + 10 / 60, kTol),
      );
      expect(engine.currentDay, DateTime(2026, 6, 24));
    });

    test('midnightResetHappensOnce_notOnEverySubsequentSameDayTick', () {
      final clock = FakeClock(DateTime(2026, 6, 23, 23, 59));
      final engine = _engine(clock: clock);

      engine.tick(
        const Duration(minutes: 5),
        idleSeconds: 0,
        screenLocked: false,
      );

      clock.setNow(DateTime(2026, 6, 24, 0, 0));
      engine.tick(
        const Duration(minutes: 1),
        idleSeconds: 0,
        screenLocked: false,
      );
      // Another same-day tick must accumulate, not re-reset.
      engine.tick(
        const Duration(minutes: 1),
        idleSeconds: 0,
        screenLocked: false,
      );

      expect(engine.activeTimeToday, const Duration(minutes: 2));
      expect(engine.rawActiveTime, const Duration(minutes: 2));
    });
  });

  group('JourneyEngine — restore across midnight (TC-017, AC-10)', () {
    test('storedDateOneDayEarlier_restoreResetsDaily_preservesDistance', () {
      final clock = FakeClock(DateTime(2026, 6, 23, 9));
      final engine = _engine(clock: clock);

      final progress = JourneyProgress(
        distanceKm: 123.5,
        activeTimeToday: const Duration(minutes: 40),
        rawActiveTime: const Duration(minutes: 30),
        idleTimeToday: const Duration(minutes: 20),
        state: JourneyState.active,
        mode: TravelMode.car,
        storedDate: DateTime(2026, 6, 22),
      );

      engine.restore(progress);

      expect(engine.distanceKm, closeTo(123.5, kTol));
      expect(engine.activeTimeToday, Duration.zero);
      expect(engine.rawActiveTime, Duration.zero);
      expect(engine.idleTimeToday, Duration.zero);
      expect(engine.mode, TravelMode.car);
      expect(engine.currentDay, DateTime(2026, 6, 23));
    });

    test(
      'storedDateMultipleDaysEarlier_behavesSameAsOneDayGap_singleReset',
      () {
        final clock = FakeClock(DateTime(2026, 6, 23, 9));
        final engine = _engine(clock: clock);

        final progress = JourneyProgress(
          distanceKm: 500,
          activeTimeToday: const Duration(hours: 3),
          rawActiveTime: const Duration(hours: 2),
          idleTimeToday: const Duration(hours: 1),
          state: JourneyState.active,
          mode: TravelMode.motorbike,
          storedDate: DateTime(2026, 6, 18), // five days earlier.
        );

        engine.restore(progress);

        // Single reset, no per-missed-day reconstruction (distance unchanged).
        expect(engine.distanceKm, closeTo(500, kTol));
        expect(engine.activeTimeToday, Duration.zero);
        expect(engine.rawActiveTime, Duration.zero);
        expect(engine.idleTimeToday, Duration.zero);
      },
    );
  });

  group('JourneyEngine — same-day round-trip (TC-018, AC-11)', () {
    test('saveThenRestoreSameDay_resumesExactly_noDoubleCount', () async {
      final clock = FakeClock(DateTime(2026, 6, 23, 14));
      final source = _engine(clock: clock);
      final repo = InMemoryJourneyRepository();

      source.tick(
        const Duration(minutes: 2),
        idleSeconds: 0,
        screenLocked: false,
      );
      source.tick(
        const Duration(minutes: 1),
        idleSeconds: 60,
        screenLocked: false,
      );
      await source.save(repo);

      final savedDistance = source.distanceKm;
      final savedActive = source.activeTimeToday;
      final savedRaw = source.rawActiveTime;
      final savedIdle = source.idleTimeToday;
      final savedState = source.state;
      final savedMode = source.mode;

      // Fresh engine, same local day.
      final restored = _engine(clock: FakeClock(DateTime(2026, 6, 23, 15)));
      await restored.loadAndRestore(repo);

      expect(restored.distanceKm, closeTo(savedDistance, kTol));
      expect(restored.activeTimeToday, savedActive);
      expect(restored.rawActiveTime, savedRaw);
      expect(restored.idleTimeToday, savedIdle);
      expect(restored.state, savedState);
      expect(restored.mode, savedMode);
      expect(restored.currentDay, DateTime(2026, 6, 23));

      // A subsequent active tick continues from the restored position.
      restored.tick(
        const Duration(minutes: 6),
        idleSeconds: 0,
        screenLocked: false,
      );
      expect(restored.distanceKm, closeTo(savedDistance + 1, kTol));
    });
  });

  group(
    'JourneyEngine — non-positive delta clamped (TC-019, AC-1/AC-7/AC-12)',
    () {
      test('zeroDelta_isIgnored_noAccrual_engineStaysUsable', () {
        final engine = _engine();

        engine.tick(
          const Duration(minutes: 1),
          idleSeconds: 0,
          screenLocked: false,
        );
        final snapshotDistance = engine.distanceKm;

        engine.tick(Duration.zero, idleSeconds: 0, screenLocked: false);

        expect(engine.distanceKm, closeTo(snapshotDistance, kTol));
        expect(engine.activeTimeToday, const Duration(minutes: 1));
        expect(engine.rawActiveTime, const Duration(minutes: 1));
        expect(engine.idleTimeToday, Duration.zero);

        // Still usable for the next positive tick.
        engine.tick(
          const Duration(minutes: 1),
          idleSeconds: 0,
          screenLocked: false,
        );
        expect(engine.activeTimeToday, const Duration(minutes: 2));
      });

      test('negativeDelta_isIgnored_neverDecreasesAccumulators', () {
        final engine = _engine();

        engine.tick(
          const Duration(minutes: 1),
          idleSeconds: 0,
          screenLocked: false,
        );
        final snapshotDistance = engine.distanceKm;
        final snapshotActive = engine.activeTimeToday;

        engine.tick(
          const Duration(seconds: -30),
          idleSeconds: 0,
          screenLocked: false,
        );

        expect(engine.distanceKm, closeTo(snapshotDistance, kTol));
        expect(engine.activeTimeToday, snapshotActive);
        expect(engine.distanceKm, greaterThanOrEqualTo(0));
      });
    },
  );

  group(
    'JourneyEngine — future stored date treated as today (TC-020, AC-10/AC-11)',
    () {
      test(
        'storedDateLaterThanToday_restoreDoesNotReset_resumesNormally',
        () async {
          final clock = FakeClock(DateTime(2026, 6, 23, 9));
          final engine = _engine(clock: clock);

          final progress = JourneyProgress(
            distanceKm: 88.0,
            activeTimeToday: const Duration(minutes: 50),
            rawActiveTime: const Duration(minutes: 35),
            idleTimeToday: const Duration(minutes: 15),
            state: JourneyState.active,
            mode: TravelMode.bicycle,
            storedDate: DateTime(2026, 6, 24), // future relative to clock.
          );

          engine.restore(progress);

          // No reset: daily counters restored as-is.
          expect(engine.distanceKm, closeTo(88.0, kTol));
          expect(engine.activeTimeToday, const Duration(minutes: 50));
          expect(engine.rawActiveTime, const Duration(minutes: 35));
          expect(engine.idleTimeToday, const Duration(minutes: 15));
          expect(engine.mode, TravelMode.bicycle);

          // A same-day tick resumes accruing normally on top of restored values.
          engine.tick(
            const Duration(minutes: 6),
            idleSeconds: 0,
            screenLocked: false,
          );
          expect(engine.distanceKm, closeTo(89.0, kTol));
          expect(engine.activeTimeToday, const Duration(minutes: 56));
        },
      );
    },
  );

  group(
    'JourneyEngine — resume idle/paused to active (TC-021, AC-3/AC-5/AC-14)',
    () {
      test('afterPaused_freshInput_resumesActive_noRetroactiveCredit', () {
        final engine = _engine();

        // Active, then go past grace (paused with G=T default).
        engine.tick(
          const Duration(minutes: 1),
          idleSeconds: 0,
          screenLocked: false,
        );
        engine.tick(
          const Duration(minutes: 1),
          idleSeconds: 400,
          screenLocked: false,
        );
        final frozenDistance = engine.distanceKm;
        final frozenJourney = engine.activeTimeToday;
        final frozenRaw = engine.rawActiveTime;
        final idleAfterPause = engine.idleTimeToday;
        expect(engine.state, JourneyState.paused);

        // Fresh input arrives.
        engine.tick(
          const Duration(minutes: 6),
          idleSeconds: 0,
          screenLocked: false,
        );

        expect(engine.state, JourneyState.active);
        // Resume tick adds exactly one tick's travel; no retroactive idle->travel.
        expect(engine.distanceKm, closeTo(frozenDistance + 1, kTol));
        expect(
          engine.activeTimeToday,
          frozenJourney + const Duration(minutes: 6),
        );
        expect(engine.rawActiveTime, frozenRaw + const Duration(minutes: 6));
        // Idle frozen (didn't grow on the active resume tick).
        expect(engine.idleTimeToday, idleAfterPause);
      });
    },
  );

  group(
    'JourneyEngine — full-day end-to-end invariants (TC-022, multi-AC)',
    () {
      test('mixedDay_allFourTotalsExact_andRawNeverExceedsJourney', () {
        // Round numbers so all totals are exactly assertable.
        // Active: 2 + 2 = 4 min. Grace: 3 min. Idle/paused/locked/sleep:
        // 5 + 5 + 5 + 60 = 75 min idle.
        final engine = _engine();

        engine.tick(
          const Duration(minutes: 2),
          idleSeconds: 0,
          screenLocked: false,
        ); // active
        engine.tick(
          const Duration(minutes: 3),
          idleSeconds: 60,
          screenLocked: false,
        ); // grace
        engine.tick(
          const Duration(minutes: 5),
          idleSeconds: 400,
          screenLocked: false,
        ); // paused (>T)
        engine.tick(
          const Duration(minutes: 5),
          idleSeconds: 0,
          screenLocked: true,
        ); // locked
        engine.tick(
          const Duration(minutes: 60),
          idleSeconds: 7200,
          screenLocked: false,
        ); // sleep gap
        engine.tick(
          const Duration(minutes: 2),
          idleSeconds: 0,
          screenLocked: false,
        ); // active again

        // raw = active deltas only (2 + 2 = 4).
        expect(engine.rawActiveTime, const Duration(minutes: 4));
        // journey = active + grace (4 + 3 = 7).
        expect(engine.activeTimeToday, const Duration(minutes: 7));
        // idle = paused + locked + sleep-gap (5 + 5 + 60 = 70).
        expect(engine.idleTimeToday, const Duration(minutes: 70));
        // distance = kmPerActiveHour * (journey hours) = 10 * 7/60.
        expect(engine.distanceKm, closeTo(10 * 7 / 60, kTol));
        expect(engine.rawActiveTime <= engine.activeTimeToday, isTrue);
      });
    },
  );

  group('JourneyEngine — default-config active travel (B-2, TC-001, AC-1)', () {
    test('activeTick_realisticDelta_defaultMaxTickDelta_accruesExactDistance', () {
      // The existing TC-001 tests RAISE maxTickDelta to 6h, so the real-wiring
      // default (maxTickDelta = 2*T = 10min) was never exercised for accrual.
      // A 45s ticker-sized active tick is well under the 10min clamp, so the
      // FULL delta credits — proving AC-1 holds with the config real wiring uses.
      final engine = _engine(); // kmPerActiveHour = 10, default 10min clamp.
      const delta = Duration(seconds: 45);

      engine.tick(delta, idleSeconds: 0, screenLocked: false);

      // distance = kmPerActiveHour * delta/3600 = 10 * 45/3600 = 0.125 km.
      expect(engine.distanceKm, closeTo(10 * 45 / 3600, kTol));
      expect(engine.activeTimeToday, delta);
      expect(engine.rawActiveTime, delta);
      expect(engine.rawActiveTime, engine.activeTimeToday);
      expect(engine.idleTimeToday, Duration.zero);
      expect(engine.state, JourneyState.active);
    });
  });

  group(
    'JourneyEngine — accrual clamp boundary (flagged by implementer, TC-001/TC-004, AC-1/AC-4/AC-8)',
    () {
      test('travellingTick_deltaEqualsMaxTickDelta_creditsFullDelta', () {
        // (a) Boundary: delta == maxTickDelta is NOT over-sized (clamp is
        // delta > maxTickDelta), so the full delta credits.
        final engine = _engine(maxTickDelta: const Duration(minutes: 10));

        engine.tick(
          const Duration(minutes: 10),
          idleSeconds: 0,
          screenLocked: false,
        );

        // Full 10min credited: distance = 10 * 10/60.
        expect(engine.distanceKm, closeTo(10 * 10 / 60, kTol));
        expect(engine.activeTimeToday, const Duration(minutes: 10));
        expect(engine.rawActiveTime, const Duration(minutes: 10));
        expect(engine.state, JourneyState.active);
      });

      test('activeTick_deltaExceedsMaxTickDelta_creditsExactlyMaxTickDelta', () {
        // (b) Active band, delta > maxTickDelta ⇒ accrual clamped to maxTickDelta
        // across distance, journey AND raw (active band feeds raw too).
        final engine = _engine(maxTickDelta: const Duration(minutes: 10));

        engine.tick(
          const Duration(minutes: 25), // > 10min clamp.
          idleSeconds: 0,
          screenLocked: false,
        );

        // Clamped to 10min, NOT the full 25min.
        expect(engine.distanceKm, closeTo(10 * 10 / 60, kTol));
        expect(engine.activeTimeToday, const Duration(minutes: 10));
        expect(engine.rawActiveTime, const Duration(minutes: 10));
        expect(engine.idleTimeToday, Duration.zero);
        expect(engine.state, JourneyState.active);
      });

      test(
        'graceTick_deltaExceedsMaxTickDelta_clampsDistanceAndJourney_notRaw',
        () {
          // (c) The SAME clamp applies in the GRACE band (F < idle <= G). Grace
          // credits distance + journey but never raw — the clamp must hold there
          // too. F=5s, G=T=5min default; idle=60s is grace. sleepIdleThreshold is
          // 2*T = 600s, so idle=60 is well below it. delta 25min > 10min clamp.
          final engine = _engine(maxTickDelta: const Duration(minutes: 10));

          engine.tick(
            const Duration(minutes: 25),
            idleSeconds: 60,
            screenLocked: false,
          );

          expect(engine.state, JourneyState.active); // travelling.
          // Clamped to 10min for distance + journey.
          expect(engine.distanceKm, closeTo(10 * 10 / 60, kTol));
          expect(engine.activeTimeToday, const Duration(minutes: 10));
          // Grace never feeds raw, clamp or no clamp.
          expect(engine.rawActiveTime, Duration.zero);
          expect(engine.idleTimeToday, Duration.zero);
        },
      );
    },
  );

  group(
    'JourneyEngine — restore × midnight composition (B-3, TC-011/TC-016, AC-9/AC-11)',
    () {
      test(
        'restoreTodayThenAccrueThenCrossMidnight_resetsOnce_distancePreserved',
        () {
          // Composes AC-11 (restore today, no reset) with AC-9 (rollover on the
          // next-day tick) — untested together. Restore a snapshot dated TODAY,
          // accrue more active time same-day, then cross local midnight and tick.
          final clock = FakeClock(DateTime(2026, 6, 23, 23, 50));
          final engine = _engine(clock: clock);

          final progress = JourneyProgress(
            distanceKm: 200.0,
            activeTimeToday: const Duration(minutes: 40),
            rawActiveTime: const Duration(minutes: 30),
            idleTimeToday: const Duration(minutes: 10),
            state: JourneyState.active,
            mode: TravelMode.motorbike,
            storedDate: DateTime(
              2026,
              6,
              23,
            ), // today: restored as-is, no reset.
          );

          engine.restore(progress);
          // Restore kept the daily counters (same day).
          expect(engine.activeTimeToday, const Duration(minutes: 40));
          expect(engine.distanceKm, closeTo(200.0, kTol));

          // Accrue more, still on 2026-06-23 (a 1min active tick = +10/60 km).
          engine.tick(
            const Duration(minutes: 1),
            idleSeconds: 0,
            screenLocked: false,
          );
          final distanceBeforeMidnight = engine.distanceKm;
          expect(distanceBeforeMidnight, closeTo(200.0 + 10 / 60, kTol));
          expect(engine.activeTimeToday, const Duration(minutes: 41));

          // Cross local midnight, then tick: rollover fires exactly once.
          clock.setNow(DateTime(2026, 6, 24, 0, 1));
          engine.tick(
            const Duration(minutes: 2),
            idleSeconds: 0,
            screenLocked: false,
          );

          // Daily counters reset, then only the post-midnight tick accrues.
          expect(engine.activeTimeToday, const Duration(minutes: 2));
          expect(engine.rawActiveTime, const Duration(minutes: 2));
          expect(engine.idleTimeToday, Duration.zero);
          expect(engine.currentDay, DateTime(2026, 6, 24));
          // Cumulative distance preserved across reset (restored + both ticks).
          expect(
            engine.distanceKm,
            closeTo(200.0 + 10 / 60 + 2 * 10 / 60, kTol),
          );

          // A further same-day tick must NOT re-reset (rollover is once).
          engine.tick(
            const Duration(minutes: 1),
            idleSeconds: 0,
            screenLocked: false,
          );
          expect(engine.activeTimeToday, const Duration(minutes: 3));
        },
      );
    },
  );

  group(
    'JourneyEngine — non-positive delta vs rollover ordering (S-6, TC-019/TC-016, AC-7/AC-9)',
    () {
      test('nonPositiveDelta_leavesIdleTimeTodayUntouchedToo', () {
        // The existing TC-019 tests only assert distance/active are untouched. A
        // non-positive delta must also leave idleTimeToday unchanged (the guard
        // returns before ANY accrual). Seed some idle first via a paused tick.
        final engine = _engine();

        engine.tick(
          const Duration(minutes: 1),
          idleSeconds: 400, // past G=T ⇒ paused, accrues idle.
          screenLocked: false,
        );
        final idleBefore = engine.idleTimeToday;
        expect(idleBefore, const Duration(minutes: 1));

        // Zero delta with a paused-looking signal: idle must NOT grow.
        engine.tick(Duration.zero, idleSeconds: 400, screenLocked: false);
        expect(engine.idleTimeToday, idleBefore);

        // Negative delta likewise leaves idle untouched.
        engine.tick(
          const Duration(seconds: -30),
          idleSeconds: 400,
          screenLocked: false,
        );
        expect(engine.idleTimeToday, idleBefore);
      });

      test('nonPositiveDeltaOnLaterDay_stillRollsTheDay_distancePreserved', () {
        // Order-of-operations: the day-boundary check runs BEFORE the
        // non-positive guard, so a delta <= 0 whose clock.now() is on a later day
        // still resets the daily counters (and preserves distance).
        final clock = FakeClock(DateTime(2026, 6, 23, 12));
        final engine = _engine(clock: clock);

        // Accrue active + idle on 2026-06-23.
        engine.tick(
          const Duration(minutes: 6),
          idleSeconds: 0,
          screenLocked: false,
        ); // +1 km, active 6min, raw 6min.
        engine.tick(
          const Duration(minutes: 1),
          idleSeconds: 400,
          screenLocked: false,
        ); // idle 1min.
        final distanceCarried = engine.distanceKm;
        expect(distanceCarried, closeTo(1, kTol));
        expect(engine.activeTimeToday, const Duration(minutes: 6));
        expect(engine.idleTimeToday, const Duration(minutes: 1));

        // Advance the clock to the next day, then fire a NON-POSITIVE tick.
        clock.setNow(DateTime(2026, 6, 24, 0, 0));
        engine.tick(Duration.zero, idleSeconds: 0, screenLocked: false);

        // Rollover ran (counters reset) even though the delta was ignored after.
        expect(engine.activeTimeToday, Duration.zero);
        expect(engine.rawActiveTime, Duration.zero);
        expect(engine.idleTimeToday, Duration.zero);
        expect(engine.currentDay, DateTime(2026, 6, 24));
        // Cumulative distance survives the reset; the zero delta added nothing.
        expect(engine.distanceKm, closeTo(distanceCarried, kTol));
      });
    },
  );

  group(
    'JourneyEngine — DST / exact-midnight rollover robustness (S-4, TC-016, AC-9)',
    () {
      test('clockStepsAcrossSpringForwardGap_rollsDayExactlyOnce', () {
        // Spring-forward: local wall clock jumps 02:00 -> 03:00 on the SAME date,
        // so a tick inside that gap stays on the same calendar day (no reset),
        // and the first tick on the NEXT date resets exactly once. Expressed purely
        // via the injected clock — no real timezone APIs.
        final clock = FakeClock(DateTime(2026, 3, 8, 1, 59));
        final engine = _engine(clock: clock);

        engine.tick(
          const Duration(minutes: 2),
          idleSeconds: 0,
          screenLocked: false,
        );
        expect(engine.activeTimeToday, const Duration(minutes: 2));

        // Step past the spring-forward gap, still 2026-03-08: no reset.
        clock.setNow(DateTime(2026, 3, 8, 3, 0));
        engine.tick(
          const Duration(minutes: 1),
          idleSeconds: 0,
          screenLocked: false,
        );
        expect(engine.currentDay, DateTime(2026, 3, 8));
        expect(engine.activeTimeToday, const Duration(minutes: 3));

        // Next calendar day: exactly one reset.
        clock.setNow(DateTime(2026, 3, 9, 0, 30));
        engine.tick(
          const Duration(minutes: 1),
          idleSeconds: 0,
          screenLocked: false,
        );
        expect(engine.currentDay, DateTime(2026, 3, 9));
        expect(engine.activeTimeToday, const Duration(minutes: 1));
      });

      test('clockStepsAcrossFallBackBoundary_rollsDayExactlyOnce', () {
        // Fall-back: 02:00 repeats. Two ticks at the same wall-clock hour on the
        // same date must NOT double-reset; the next date resets once.
        final clock = FakeClock(DateTime(2026, 11, 1, 1, 30));
        final engine = _engine(clock: clock);

        engine.tick(
          const Duration(minutes: 1),
          idleSeconds: 0,
          screenLocked: false,
        );
        // "Repeat" the 01:30 hour (fall-back) — same date, no reset.
        clock.setNow(DateTime(2026, 11, 1, 1, 30));
        engine.tick(
          const Duration(minutes: 1),
          idleSeconds: 0,
          screenLocked: false,
        );
        expect(engine.currentDay, DateTime(2026, 11, 1));
        expect(engine.activeTimeToday, const Duration(minutes: 2));

        clock.setNow(DateTime(2026, 11, 2, 0, 5));
        engine.tick(
          const Duration(minutes: 1),
          idleSeconds: 0,
          screenLocked: false,
        );
        expect(engine.currentDay, DateTime(2026, 11, 2));
        expect(engine.activeTimeToday, const Duration(minutes: 1));
      });

      test('tickTimestampExactlyMidnight_rollsToNewDay', () {
        // A tick whose clock.now() is exactly 00:00:00.000 of a new day rolls
        // correctly (boundary: isAfter is strict, so 00:00 of the NEXT date is
        // after the previous date-only midnight).
        final clock = FakeClock(DateTime(2026, 6, 23, 23, 59, 59, 500));
        final engine = _engine(clock: clock);

        engine.tick(
          const Duration(minutes: 5),
          idleSeconds: 0,
          screenLocked: false,
        );
        final distanceCarried = engine.distanceKm;
        expect(engine.activeTimeToday, const Duration(minutes: 5));

        clock.setNow(DateTime(2026, 6, 24)); // exactly 00:00:00.000.
        engine.tick(
          const Duration(minutes: 1),
          idleSeconds: 0,
          screenLocked: false,
        );

        expect(engine.currentDay, DateTime(2026, 6, 24));
        expect(engine.activeTimeToday, const Duration(minutes: 1));
        expect(engine.rawActiveTime, const Duration(minutes: 1));
        expect(engine.distanceKm, closeTo(distanceCarried + 10 / 60, kTol));
      });
    },
  );
}
