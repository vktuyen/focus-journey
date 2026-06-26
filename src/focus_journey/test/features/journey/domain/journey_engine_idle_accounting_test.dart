// Deterministic unit tests for the idle-accounting slice layered onto the pure,
// framework-free JourneyEngine.
//
// Scope: Option B (whole-tick accounting + an Active→Idle/Paused state-change
// stamp), the ordered ActivitySegment record (distance-keyed, contiguous,
// merged, day-split, persisted), the honesty invariant (never over-credit
// active), and NFR-2 robustness (delta <= 0 / future stored date). Every "time
// passes" is a value fed to tick(delta) or scripted on the injected FakeClock —
// no real timers, no wall-clock waits.
//
// Cases: tests/cases/idle-accounting.md TC-100..TC-120.
// ACs: specs/idle-accounting/spec.md AC-1..AC-4, NFR-1/NFR-2.
//
// The existing shipped engine suite (journey_engine_test.dart) MUST keep passing
// unchanged — Option B does not revise the whole-tick rule; this file ADDS the
// new behaviour via new tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/activity/data/mock_activity_source.dart';
import 'package:focus_journey/features/journey/domain/activity_segment.dart';
import 'package:focus_journey/features/journey/domain/clock.dart';
import 'package:focus_journey/features/journey/domain/journey_engine.dart';
import 'package:focus_journey/features/journey/domain/journey_progress.dart';
import 'package:focus_journey/features/journey/domain/journey_repository.dart';
import 'package:focus_journey/features/journey/domain/journey_state.dart';

/// A scriptable [Clock]. Tests set [now] and advance it tick by tick so the
/// engine's day-boundary logic AND the Option B idle stamp are deterministic.
class FakeClock implements Clock {
  FakeClock(this._now);

  DateTime _now;

  void setNow(DateTime value) => _now = value;

  /// Advances the scripted instant by [delta] — used to keep the clock in step
  /// with the deltas fed to tick(), so `idleSince` is stamped at the real onset.
  void advance(Duration delta) => _now = _now.add(delta);

  @override
  DateTime now() => _now;
}

/// An in-memory [JourneyRepository] that round-trips through toJson/fromJson so
/// the persistence seam (incl. the segment record) is exercised end-to-end.
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

const double kTol = 1e-6;

/// km/h chosen so 1 minute of travel = a clean distance; 10 km/h ⇒ 10/60 km/min.
const double _kmPerHour = 10;

/// A clock advanced in lock-step with deltas, so `idleSince` stamps at the real
/// transition instant. [clock] is mutated by the helper [tick] below.
JourneyEngine _engine(
  FakeClock clock, {
  MockActivitySource? plugin,
  Duration grace = const Duration(minutes: 5),
  Duration threshold = const Duration(minutes: 5),
  Duration activeFloor = const Duration(seconds: 5),
  Duration? maxTickDelta,
  Duration? sleepIdleThreshold,
}) {
  return JourneyEngine(
    clock: clock,
    activityPlugin: plugin ?? MockActivitySource(),
    kmPerActiveHour: _kmPerHour,
    grace: grace,
    threshold: threshold,
    activeFloor: activeFloor,
    // Generous clamp so multi-minute scripted ticks credit in full (the clamp
    // is exercised by the existing suite; here we want exact accrual maths).
    maxTickDelta: maxTickDelta ?? const Duration(hours: 6),
    sleepIdleThreshold: sleepIdleThreshold,
  );
}

/// Advances [clock] by [delta] (so the engine's clock.now() reflects the tick's
/// end instant) and feeds the tick. Models a real ticker: the clock and the
/// engine see the same elapsed time, so `idleSince` is stamped honestly.
void tick(
  JourneyEngine engine,
  FakeClock clock,
  Duration delta, {
  required int idleSeconds,
  bool screenLocked = false,
}) {
  clock.advance(delta);
  engine.tick(delta, idleSeconds: idleSeconds, screenLocked: screenLocked);
}

/// Sums every segment's elapsed duration (AC-3 / TC-108).
Duration _sumElapsed(List<ActivitySegment> segments) =>
    segments.fold(Duration.zero, (acc, s) => acc + s.elapsed);

void main() {
  final start = DateTime(2026, 6, 23, 9);

  // -------------------------------------------------------------------------
  // TC-100 — pre-fix repro baseline (Decision (a)). Documented snapshot, NOT a
  // perpetual red test: it records the whole-tick discrepancy the fix drives to
  // 0 in TC-104.
  // -------------------------------------------------------------------------
  group('TC-100 pre-fix repro baseline (AC-2 regression anchor)', () {
    test('wholeTickClassification_idleStartsAtTickBoundary_notMidTickOnset', () {
      // Model the PRE-FIX behaviour: with whole-tick classification, a user who
      // stops strictly INSIDE a tick has their idle counted only from the NEXT
      // tick boundary (the tick is classified by the reading at tick time). The
      // honest "idle from the moment they stopped" (wall-time-since-onset) is
      // therefore LARGER than the whole-tick idleTimeToday by up to one tick.
      const tickLen = Duration(seconds: 10);
      final clock = FakeClock(start);
      final engine = _engine(clock);

      // Active up to a boundary.
      tick(engine, clock, tickLen, idleSeconds: 0);
      // The user actually stops 4s into the NEXT tick (mid-tick onset). But the
      // reading at THIS tick's time is still active-ish (idle < grace), so the
      // whole tick is travel under whole-tick classification — idle does NOT
      // start here. The pre-fix engine only flips to idle on the tick AFTER the
      // reading crosses the band.
      tick(engine, clock, tickLen, idleSeconds: 0); // still active read.
      // Now idle is read past the band — whole tick credits idle from HERE.
      tick(engine, clock, tickLen, idleSeconds: 400);

      // Whole-tick idleTimeToday counts ONE idle tick (10s).
      expect(engine.idleTimeToday, tickLen);

      // The honest onset was ~4s into the second tick, so true idle wall-time at
      // this boundary would be 10 + 6 = 16s. Record the divergence the fix must
      // close (≈ up to one tick). This value is a captured baseline, not an
      // invariant the fixed engine satisfies — TC-104 drives the *displayed vs
      // accounted* divergence to 0.
      const honestIdleAtBoundary = Duration(seconds: 16);
      final divergence = honestIdleAtBoundary - engine.idleTimeToday;
      expect(
        divergence,
        greaterThan(Duration.zero),
        reason: 'pre-fix whole-tick idle lags honest onset by up to one tick',
      );
      expect(
        divergence,
        lessThanOrEqualTo(tickLen + const Duration(seconds: 6)),
      );
    });
  });

  // -------------------------------------------------------------------------
  // AC-1 — idle onset honoured within one tick + honesty (TC-101..TC-103)
  // -------------------------------------------------------------------------
  group('AC-1 idle onset honoured within one tick', () {
    test('TC-101 voluntaryIdle_idleTimeTodayEqualsWallTimeSinceOnset', () {
      const tickLen = Duration(seconds: 10);
      final clock = FakeClock(start);
      final engine = _engine(clock);

      // Active up to T0 (the onset boundary).
      tick(engine, clock, tickLen, idleSeconds: 0);
      // Voluntary idle: 6 ticks past grace ⇒ W = 60s of idle.
      for (var i = 0; i < 6; i++) {
        tick(engine, clock, tickLen, idleSeconds: 400);
      }

      const w = Duration(seconds: 60);
      // idleTimeToday equals W within one tick interval (it is exactly W here
      // because the transition landed on a boundary).
      expect((engine.idleTimeToday - w).abs(), lessThanOrEqualTo(tickLen));
      expect(engine.idleTimeToday, w);
      expect(engine.idleSince, isNotNull);
    });

    test('TC-102 active_neverIncreasesAfterIdleTransition (honesty)', () {
      const tickLen = Duration(seconds: 10);
      final clock = FakeClock(start);
      final engine = _engine(clock);

      tick(engine, clock, tickLen, idleSeconds: 0);
      tick(engine, clock, tickLen, idleSeconds: 0);
      final rawAtT0 = engine.rawActiveTime;
      final journeyAtT0 = engine.activeTimeToday;
      final distAtT0 = engine.distanceKm;

      // Idle/paused ticks only after T0; active accumulators must NEVER grow.
      for (var i = 0; i < 5; i++) {
        tick(engine, clock, tickLen, idleSeconds: 400);
        expect(engine.rawActiveTime, rawAtT0);
        expect(engine.activeTimeToday, journeyAtT0);
        expect(engine.distanceKm, closeTo(distAtT0, kTol));
      }
    });

    test('TC-103 lock_anchorsIdleAtLockInstant_overridesGrace', () {
      const tickLen = Duration(seconds: 10);
      final clock = FakeClock(start);
      // G = 5min so a 60s idle reading is in the grace band (travel) — lock must
      // beat the grace.
      final engine = _engine(clock);

      // Travelling in the grace band.
      tick(engine, clock, tickLen, idleSeconds: 60);
      final distAtLock = engine.distanceKm;
      final journeyAtLock = engine.activeTimeToday;
      final rawAtLock = engine.rawActiveTime;

      // Screen locked mid-grace at Tlock: idle anchored HERE, not next boundary.
      for (var i = 0; i < 3; i++) {
        tick(engine, clock, tickLen, idleSeconds: 60, screenLocked: true);
      }

      expect(engine.state, JourneyState.paused);
      // Idle = wall-time since the lock instant (3 ticks = 30s), within one tick.
      expect(engine.idleTimeToday, const Duration(seconds: 30));
      // Active accumulators frozen at the lock instant (honesty).
      expect(engine.distanceKm, closeTo(distAtLock, kTol));
      expect(engine.activeTimeToday, journeyAtLock);
      expect(engine.rawActiveTime, rawAtLock);
    });

    test('TC-103 sleepVariant_anchorsIdleAtSleepInstant', () {
      const tickLen = Duration(seconds: 10);
      final clock = FakeClock(start);
      // sleepIdleThreshold defaults to 2*T = 600s; a 600s reading triggers sleep
      // inference even inside the grace band.
      final engine = _engine(clock);

      tick(engine, clock, tickLen, idleSeconds: 60); // grace travel.
      final journeyAtSleep = engine.activeTimeToday;

      tick(engine, clock, tickLen, idleSeconds: 600); // sleep-sized reading.
      tick(engine, clock, tickLen, idleSeconds: 600);

      expect(engine.state, JourneyState.paused);
      expect(engine.idleTimeToday, const Duration(seconds: 20));
      expect(engine.activeTimeToday, journeyAtSleep);
    });
  });

  // -------------------------------------------------------------------------
  // Option B idle stamp (idleSince) — onset instant, NOT end-of-tick.
  //
  // After the onset-stamp fix, idleSince is stamped at the START of the first
  // idle tick (clock.now() - delta), the instant the displayed state actually
  // flipped Active→Idle/Paused. The exact invariant follows: for one continuous
  // idle stretch, at EVERY tick boundary clock.now() - idleSince equals the idle
  // wall-time accrued in that stretch. Both onset causes anchor at their
  // triggering tick's start (voluntary s>G crossing, lock/sleep instant).
  // -------------------------------------------------------------------------
  group('Option B idleSince stamped at onset instant (not end-of-tick)', () {
    test('voluntaryOnset_idleSinceEqualsOnsetInstant_startOfFirstIdleTick', () {
      const tickLen = Duration(seconds: 10);
      final clock = FakeClock(start);
      final engine = _engine(clock);

      // One active tick, then the first idle tick (voluntary s > G crossing).
      tick(engine, clock, tickLen, idleSeconds: 0);
      // Capture the clock at the START of the idle tick — this is the onset
      // instant the engine must stamp (clock.now() - delta inside tick()).
      final onsetInstant = clock.now();
      tick(engine, clock, tickLen, idleSeconds: 400);

      // idleSince == onset (start of the first idle tick), NOT the end-of-tick
      // value clock.now(). Pin both: it equals onset and is strictly earlier
      // than the post-tick clock by exactly one tick.
      expect(engine.idleSince, onsetInstant);
      expect(engine.idleSince, clock.now().subtract(tickLen));
      expect(engine.idleSince, isNot(clock.now()));
    });

    test('lockSleepOnset_idleSinceEqualsLockInstant_startOfLockTick', () {
      const tickLen = Duration(seconds: 10);
      final clock = FakeClock(start);
      // G = T = 5min default ⇒ a 60s reading is grace (travel); the lock is what
      // forces idle, overriding grace, so onset is the lock tick's start.
      final engine = _engine(clock);

      tick(engine, clock, tickLen, idleSeconds: 60); // grace travel
      final lockInstant = clock.now(); // start of the lock tick
      tick(engine, clock, tickLen, idleSeconds: 60, screenLocked: true);

      // Forced-idle onset is the lock instant (start of the lock tick), not the
      // end of that tick.
      expect(engine.idleSince, lockInstant);
      expect(engine.idleSince, clock.now().subtract(tickLen));
    });

    test('sleepOnset_idleSinceEqualsSleepInstant_startOfSleepTick', () {
      const tickLen = Duration(seconds: 10);
      final clock = FakeClock(start);
      // sleepIdleThreshold defaults to 2*T = 600s; a 600s reading trips sleep
      // inference even inside the grace band, overriding grace.
      final engine = _engine(clock);

      tick(engine, clock, tickLen, idleSeconds: 60); // grace travel
      final sleepInstant = clock.now(); // start of the sleep tick
      tick(engine, clock, tickLen, idleSeconds: 600); // sleep-sized reading

      expect(engine.idleSince, sleepInstant);
      expect(engine.idleSince, clock.now().subtract(tickLen));
    });

    test(
      'voluntaryStretch_clockNowMinusIdleSinceEqualsIdleAccrued_everyBoundary',
      () {
        const tickLen = Duration(seconds: 10);
        final clock = FakeClock(start);
        final engine = _engine(clock);

        tick(engine, clock, tickLen, idleSeconds: 0); // active

        // A continuous voluntary-idle stretch. The exact invariant must hold at
        // EVERY tick boundary: clock.now() - idleSince == idle wall-time accrued
        // in this stretch (== i*tickLen after i idle ticks). idleSince is frozen
        // at onset, so each idle tick adds tickLen to BOTH clock.now() and
        // idleTimeToday, leaving the difference exactly equal to the accrual.
        for (var i = 1; i <= 6; i++) {
          tick(engine, clock, tickLen, idleSeconds: 400);
          final sinceOnset = clock.now().difference(engine.idleSince!);
          final accrued = tickLen * i;
          expect(sinceOnset, accrued);
          // And the displayed/accounted idle agrees with that wall-time (Option B
          // divergence 0 over a single uninterrupted stretch).
          expect(engine.idleTimeToday, accrued);
        }
      },
    );

    test('lockStretch_clockNowMinusIdleSinceEqualsIdleAccrued_everyBoundary', () {
      const tickLen = Duration(seconds: 10);
      final clock = FakeClock(start);
      final engine = _engine(clock);

      tick(engine, clock, tickLen, idleSeconds: 0); // active

      // Continuous lock/sleep stretch — the invariant must hold for the forced
      // cause too, anchored at the lock instant (start of the first lock tick).
      for (var i = 1; i <= 5; i++) {
        tick(engine, clock, tickLen, idleSeconds: 0, screenLocked: true);
        final sinceOnset = clock.now().difference(engine.idleSince!);
        expect(sinceOnset, tickLen * i);
        expect(engine.idleTimeToday, tickLen * i);
      }
    });

    test('resumeTravel_clearsIdleSince_thenReStampsAtNewOnset', () {
      const tickLen = Duration(seconds: 10);
      final clock = FakeClock(start);
      final engine = _engine(clock);

      tick(engine, clock, tickLen, idleSeconds: 0); // active
      tick(engine, clock, tickLen, idleSeconds: 400); // idle ⇒ idleSince set
      expect(engine.idleSince, isNotNull);

      tick(engine, clock, tickLen, idleSeconds: 0); // travel ⇒ stamp cleared
      expect(engine.idleSince, isNull);

      // A SECOND idle stretch re-stamps at ITS onset (start of this idle tick),
      // not the first stretch's onset.
      final secondOnset = clock.now();
      tick(engine, clock, tickLen, idleSeconds: 400);
      expect(engine.idleSince, secondOnset);
      expect(engine.idleSince, clock.now().subtract(tickLen));
    });
  });

  // -------------------------------------------------------------------------
  // AC-2 — displayed idle counter vs accounting accumulator agree (divergence
  // 0). The displayed counter IS engine.idleTimeToday (Option B anchors both to
  // the same stamped value); we assert exact equality at every boundary.
  // (TC-104..TC-106)
  // -------------------------------------------------------------------------
  group('AC-2 UI idle counter and accounting agree (divergence 0)', () {
    test('TC-104 insideTickTransition_divergence0_atEveryBoundary', () {
      const tickLen = Duration(seconds: 10);
      final clock = FakeClock(start);
      final engine = _engine(clock);

      tick(engine, clock, tickLen, idleSeconds: 0);
      // After i idle ticks the honestly-accounted idle is exactly i*tickLen.
      // Assert the accumulator against that INDEPENDENTLY hand-computed value at
      // every boundary (divergence 0 vs the known scripted timeline), not a
      // tautology of the accumulator against itself.
      for (var i = 0; i < 8; i++) {
        tick(engine, clock, tickLen, idleSeconds: 400);
        final expectedIdle = tickLen * (i + 1);
        expect(engine.idleTimeToday, expectedIdle);
      }
      expect(engine.idleTimeToday, const Duration(seconds: 80));
    });

    test('TC-105 manyTransitions_noCumulativeDrift', () {
      const tickLen = Duration(seconds: 10);
      final clock = FakeClock(start);
      final engine = _engine(clock);

      // Active → idle → resume → idle → … (≥ 4 transitions). Track idle by hand
      // and assert the accumulator never drifts from the hand-counted total.
      var expectedIdle = Duration.zero;
      void step(int idleSeconds) {
        tick(engine, clock, tickLen, idleSeconds: idleSeconds);
        final isIdle = idleSeconds > 300; // past G=T default ⇒ idle/paused.
        if (isIdle) {
          expectedIdle += tickLen;
        }
        // The hand-counted total equals the engine accumulator at every
        // boundary across many active⇄idle transitions — no cumulative drift.
        expect(engine.idleTimeToday, expectedIdle);
      }

      step(0); // active
      step(400); // idle (transition 1)
      step(400);
      step(0); // active (transition 2)
      step(0);
      step(400); // idle (transition 3)
      step(0); // active (transition 4)
      step(400); // idle (transition 5)

      expect(engine.idleTimeToday, expectedIdle);
    });

    test('TC-106 onBoundaryTransition_divergence0', () {
      const tickLen = Duration(seconds: 10);
      final clock = FakeClock(start);
      final engine = _engine(clock);

      // Transition lands exactly on a tick boundary (no sub-tick remainder).
      tick(engine, clock, tickLen, idleSeconds: 0); // active
      tick(engine, clock, tickLen, idleSeconds: 400); // idle from boundary
      tick(engine, clock, tickLen, idleSeconds: 400);

      // Exactly two idle ticks — no double-count, no off-by-one vs TC-104.
      expect(engine.idleTimeToday, const Duration(seconds: 20));
    });
  });

  // -------------------------------------------------------------------------
  // AC-3 — segments reconstruct the route losslessly + contiguously
  // (TC-107, TC-108, TC-114)
  // -------------------------------------------------------------------------
  group('AC-3 segments contiguous, gap-free, lossless', () {
    test('TC-107 segments_coverRunEndToEnd_contiguous_noOverlap', () {
      const tickLen = Duration(seconds: 30);
      final clock = FakeClock(start);
      final engine = _engine(clock);

      tick(engine, clock, tickLen, idleSeconds: 0); // active
      tick(engine, clock, tickLen, idleSeconds: 60); // grace (still active seg)
      tick(engine, clock, tickLen, idleSeconds: 400); // voluntary idle
      tick(engine, clock, tickLen, idleSeconds: 0); // active again

      final segments = engine.segments;
      expect(segments, isNotEmpty);
      // First segment starts at distance 0 (run start).
      expect(segments.first.fromKm, closeTo(0, kTol));
      // Last segment ends at the engine's current distance (run end).
      expect(segments.last.toKm, closeTo(engine.distanceKm, kTol));
      // Pairwise contiguity: seg[i].to == seg[i+1].from.
      for (var i = 0; i < segments.length - 1; i++) {
        expect(segments[i].toKm, closeTo(segments[i + 1].fromKm, kTol));
      }
    });

    test('TC-108 summedSegmentDurations_equalTotalElapsed', () {
      const tickLen = Duration(seconds: 30);
      final clock = FakeClock(start);
      final engine = _engine(clock);

      // 8 ticks of 30s ⇒ E = 240s exactly, mixed classifications.
      const total = Duration(seconds: 240);
      tick(engine, clock, tickLen, idleSeconds: 0);
      tick(engine, clock, tickLen, idleSeconds: 0);
      tick(engine, clock, tickLen, idleSeconds: 60);
      tick(engine, clock, tickLen, idleSeconds: 400);
      tick(engine, clock, tickLen, idleSeconds: 400);
      tick(engine, clock, tickLen, idleSeconds: 0, screenLocked: true);
      tick(engine, clock, tickLen, idleSeconds: 0);
      tick(engine, clock, tickLen, idleSeconds: 0);

      expect(_sumElapsed(engine.segments), total);
    });

    test('TC-114 sharedBoundaryPosition_resolvesToExactlyOneSegment', () {
      const tickLen = Duration(seconds: 30);
      final clock = FakeClock(start);
      final engine = _engine(clock);

      tick(engine, clock, tickLen, idleSeconds: 0); // active 0..D
      tick(engine, clock, tickLen, idleSeconds: 400); // idle at D (from==to==D)

      final segments = engine.segments;
      expect(segments.length, 2);
      final boundary = segments[0].toKm;
      expect(boundary, closeTo(segments[1].fromKm, kTol));

      // Boundary ownership: a position exactly at the shared endpoint belongs to
      // the segment whose half-open [from, to) contains it — here the active
      // segment owns [0, D); the idle segment is the zero-length point at D and
      // the next travel reopens. We pin the convention: query with the rule
      // "owner is the LAST segment whose fromKm <= pos AND (pos < toKm OR it is
      // the final segment)". The boundary D resolves to exactly one segment.
      ActivitySegment? owner;
      var matches = 0;
      for (final s in segments) {
        final isLast = identical(s, segments.last);
        if (s.fromKm <= boundary && (boundary < s.toKm || isLast)) {
          owner = s;
          matches++;
        }
      }
      expect(matches, 1, reason: 'a shared endpoint belongs to exactly one');
      expect(owner, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // AC-4 — segment labels correct + cause-tagged (TC-109, TC-110, TC-111)
  // -------------------------------------------------------------------------
  group('AC-4 segment labels + cause tagging', () {
    test('TC-109 lockSegment_startsAtLockInstant_notNextBoundary', () {
      const tickLen = Duration(seconds: 30);
      final clock = FakeClock(start);
      final engine = _engine(clock);

      tick(engine, clock, tickLen, idleSeconds: 60); // grace travel 0..D
      final distAtLock = engine.distanceKm;
      tick(engine, clock, tickLen, idleSeconds: 60, screenLocked: true); // lock

      final segments = engine.segments;
      // Prior travel segment ended at the lock instant's distance.
      final travel = segments.first;
      expect(travel.classification, SegmentClassification.active);
      expect(travel.toKm, closeTo(distAtLock, kTol));
      // The paused segment begins exactly there (from == lock-instant distance).
      final paused = segments.last;
      expect(paused.classification, SegmentClassification.idle);
      expect(paused.cause, SegmentCause.lockSleep);
      expect(paused.fromKm, closeTo(distAtLock, kTol));
      // No travel segment extends past the lock instant.
      expect(paused.toKm, closeTo(distAtLock, kTol));
    });

    test('TC-110 voluntaryRamp_activeThenIdle_causeVoluntary', () {
      const tickLen = Duration(seconds: 30);
      final clock = FakeClock(start);
      // G = 5min, T = 10min so the voluntary ramp passes active → grace → idle.
      final engine = _engine(clock, threshold: const Duration(minutes: 10));

      tick(engine, clock, tickLen, idleSeconds: 0); // active
      tick(engine, clock, tickLen, idleSeconds: 60); // grace ⇒ still active seg
      tick(engine, clock, tickLen, idleSeconds: 360); // idle band (s > G)

      final segments = engine.segments;
      expect(segments.length, 2);
      // Active+grace merged into ONE active segment (grace-stays-travel).
      expect(segments[0].classification, SegmentClassification.active);
      expect(segments[0].cause, SegmentCause.none);
      expect(segments[0].elapsed, const Duration(seconds: 60));
      // Post-G span is a distinct idle segment, cause = voluntary.
      expect(segments[1].classification, SegmentClassification.idle);
      expect(segments[1].cause, SegmentCause.voluntary);
    });

    test('TC-111 mixedRun_everySegmentMatchesItsBand', () {
      const tickLen = Duration(seconds: 30);
      final clock = FakeClock(start);
      final engine = _engine(clock, threshold: const Duration(minutes: 10));

      // Interleaved: active, grace, voluntary-idle, lock, active.
      tick(engine, clock, tickLen, idleSeconds: 0); // active
      tick(engine, clock, tickLen, idleSeconds: 60); // grace (active seg)
      tick(engine, clock, tickLen, idleSeconds: 360); // voluntary idle
      tick(engine, clock, tickLen, idleSeconds: 0, screenLocked: true); // lock
      tick(engine, clock, tickLen, idleSeconds: 0); // active resume

      final segments = engine.segments;
      expect(
        segments.map((s) => s.classification).toList(),
        <SegmentClassification>[
          SegmentClassification.active, // active + grace merged
          SegmentClassification.idle, // voluntary
          SegmentClassification.idle, // lock
          SegmentClassification.active, // resume
        ],
      );
      expect(segments.map((s) => s.cause).toList(), <SegmentCause>[
        SegmentCause.none,
        SegmentCause.voluntary,
        SegmentCause.lockSleep,
        SegmentCause.none,
      ]);
    });
  });

  // -------------------------------------------------------------------------
  // NFR-1 — aggregate-only consumption (TC-112 unit-assertable subset)
  // -------------------------------------------------------------------------
  group('NFR-1 aggregate-only segments, no new OS signal', () {
    test('TC-112 segments_onlyAggregateFields_engineUsesOnlyIdleAndLock', () {
      const tickLen = Duration(seconds: 30);
      final clock = FakeClock(start);
      final engine = _engine(clock);

      tick(engine, clock, tickLen, idleSeconds: 0);
      tick(engine, clock, tickLen, idleSeconds: 400);

      // Segment record exposes ONLY aggregate fields (asserted via toJson keys).
      for (final s in engine.segments) {
        expect(s.toJson().keys.toSet(), <String>{
          'fromKm',
          'toKm',
          'elapsedMs',
          'classification',
          'cause',
        });
      }
      // tickFromPlugin consumes only getSystemIdleSeconds + isScreenLocked — the
      // MockActivitySource exposes no other methods, so the engine cannot read a
      // new OS signal. (The "no new OS signal / privacy-audit PASS" gate is the
      // privacy-guardian review, per the case note.)
    });
  });

  // -------------------------------------------------------------------------
  // NFR-2 — clock skew / non-positive delta robustness (TC-113, TC-115)
  // -------------------------------------------------------------------------
  group('NFR-2 robustness under clock skew', () {
    test('TC-113 nonPositiveDelta_clampedToZero_noSegmentMutation', () {
      const tickLen = Duration(seconds: 30);
      final clock = FakeClock(start);
      final engine = _engine(clock);

      tick(engine, clock, tickLen, idleSeconds: 0); // open active segment
      tick(engine, clock, tickLen, idleSeconds: 400); // open idle segment
      final segmentsBefore = engine.segments
          .map((s) => s.toJson())
          .toList(growable: false);
      final idleBefore = engine.idleTimeToday;
      final distBefore = engine.distanceKm;
      final activeBefore = engine.activeTimeToday;
      final rawActiveBefore = engine.rawActiveTime;

      // Zero delta then negative delta with an ACTIVE-band reading (idle 0) —
      // a non-positive tick must never accrue, even one that classifies active.
      engine.tick(Duration.zero, idleSeconds: 0, screenLocked: false);
      engine.tick(
        const Duration(seconds: -30),
        idleSeconds: 0,
        screenLocked: false,
      );
      // …and one with an idle-band reading, for symmetry.
      engine.tick(Duration.zero, idleSeconds: 400, screenLocked: false);
      engine.tick(
        const Duration(seconds: -30),
        idleSeconds: 400,
        screenLocked: false,
      );

      expect(
        engine.segments.map((s) => s.toJson()).toList(),
        segmentsBefore,
        reason: 'segment record byte-identical across non-positive ticks',
      );
      expect(engine.idleTimeToday, idleBefore);
      expect(engine.distanceKm, closeTo(distBefore, kTol));
      // S-6: the active accumulators must also be untouched (never decrease, no
      // spurious credit) across the non-positive ticks — including the active-
      // band ones that would otherwise have accrued distance/active/raw time.
      expect(engine.activeTimeToday, activeBefore);
      expect(engine.rawActiveTime, rawActiveBefore);

      // A subsequent positive tick continues the open idle segment correctly.
      final countBefore = engine.segments.length;
      tick(engine, clock, tickLen, idleSeconds: 400);
      expect(engine.segments.length, countBefore); // merged into open idle seg
      expect(engine.idleTimeToday, idleBefore + tickLen);
    });

    test(
      'TC-115 futureStoredDate_restoresSegmentsIntact_noSpuriousSplit',
      () async {
        const tickLen = Duration(seconds: 30);
        final clock = FakeClock(start);
        final source = _engine(clock);
        final repo = InMemoryJourneyRepository();

        tick(source, clock, tickLen, idleSeconds: 0);
        tick(source, clock, tickLen, idleSeconds: 400);
        await source.save(repo);
        final savedSegments = source.segments;

        // Restore on an engine whose clock is BEFORE the stored date (clock skew
        // moved "today" backwards). The stored date is treated as today: counters
        // and segments restore intact.
        final progress = await repo.load();
        // Forge a future stored date relative to a clock that is earlier.
        final future = JourneyProgress(
          distanceKm: progress!.distanceKm,
          activeTimeToday: progress.activeTimeToday,
          rawActiveTime: progress.rawActiveTime,
          idleTimeToday: progress.idleTimeToday,
          state: progress.state,
          mode: progress.mode,
          storedDate: DateTime(2026, 6, 24), // later than the clock's 06-23.
          segments: progress.segments,
        );
        final restored = _engine(FakeClock(DateTime(2026, 6, 23, 9)));
        restored.restore(future);

        expect(restored.segments, savedSegments);
        expect(restored.idleTimeToday, source.idleTimeToday);
      },
    );

    test(
      'TC-115 pastStoredDate_dailyResetDropsSegments_preservesDistance',
      () async {
        const tickLen = Duration(seconds: 30);
        final clock = FakeClock(start);
        final source = _engine(clock);
        final repo = InMemoryJourneyRepository();

        tick(source, clock, tickLen, idleSeconds: 0); // active ⇒ distance + seg
        tick(source, clock, tickLen, idleSeconds: 400); // voluntary idle ⇒ seg
        await source.save(repo);
        final savedDistance = source.distanceKm;
        expect(source.segments, isNotEmpty);

        // Restore on an engine whose clock is the NEXT local day (the stored blob
        // is dated 06-23, "today" is 06-24): the documented daily-reset branch.
        final progress = await repo.load();
        final restored = _engine(FakeClock(DateTime(2026, 6, 24, 9)));
        restored.restore(progress!);

        // Daily reset: counters zeroed and the previous day's segment record
        // dropped (each day's segments belong to that day) — segments == [].
        expect(restored.segments, isEmpty);
        expect(restored.idleTimeToday, Duration.zero);
        expect(restored.activeTimeToday, Duration.zero);
        expect(restored.rawActiveTime, Duration.zero);
        // Cumulative distance is preserved across the day boundary (AC-10).
        expect(restored.distanceKm, closeTo(savedDistance, kTol));
      },
    );
  });

  // -------------------------------------------------------------------------
  // Decision-protecting cases (TC-116..TC-120)
  // -------------------------------------------------------------------------
  group('Decision (d) grace-stays-travel (TC-116)', () {
    test('graceSegment_unchanged_afterCrossingIntoIdle', () {
      const tickLen = Duration(seconds: 30);
      final clock = FakeClock(start);
      final engine = _engine(clock, threshold: const Duration(minutes: 10));

      tick(engine, clock, tickLen, idleSeconds: 0); // active
      tick(engine, clock, tickLen, idleSeconds: 60); // grace ⇒ active seg
      final graceSegment = engine.segments.first;
      final distAfterGrace = engine.distanceKm;
      final journeyAfterGrace = engine.activeTimeToday;

      // Cross s > G into idle without returning to input.
      tick(engine, clock, tickLen, idleSeconds: 360);

      // The earlier active(+grace) segment is unchanged (no retro-conversion).
      expect(engine.segments.first, graceSegment);
      expect(engine.distanceKm, closeTo(distAfterGrace, kTol));
      expect(engine.activeTimeToday, journeyAfterGrace);
      // Only the post-G span is a NEW idle segment.
      expect(engine.segments.last.classification, SegmentClassification.idle);
      expect(engine.segments.last.cause, SegmentCause.voluntary);
    });
  });

  group('Decision (c) midnight split (TC-117)', () {
    test('openSegmentSplitsAtLocalMidnight_contiguous_distancePreserved', () {
      const tickLen = Duration(minutes: 1);
      final clock = FakeClock(DateTime(2026, 6, 23, 23, 59));
      final engine = _engine(clock);

      // Open an active segment late on day N.
      engine.tick(tickLen, idleSeconds: 0, screenLocked: false);
      final distBeforeMidnight = engine.distanceKm;
      final dayNSegment = engine.segments.last;
      expect(engine.segments.length, 1);

      // Cross local midnight, then tick (same active classification).
      clock.setNow(DateTime(2026, 6, 24, 0, 0));
      engine.tick(tickLen, idleSeconds: 0, screenLocked: false);

      final segments = engine.segments;
      // Split: the day-N segment is closed, a new day-N+1 segment opened.
      expect(segments.length, 2);
      expect(segments[0], dayNSegment); // day-N portion frozen.
      // Contiguity preserved across the split.
      expect(segments[0].toKm, closeTo(segments[1].fromKm, kTol));
      // Daily idle reset (TC-016); cumulative distance preserved + new tick.
      expect(engine.idleTimeToday, Duration.zero);
      expect(
        engine.distanceKm,
        closeTo(distBeforeMidnight + _kmPerHour / 60, kTol),
      );
      expect(engine.currentDay, DateTime(2026, 6, 24));
    });
  });

  group('Decision (c) growth bound by merge (TC-118)', () {
    test('manyIdenticalTicks_mergeIntoOneSegment_changeOpensNew', () {
      const tickLen = Duration(seconds: 10);
      final clock = FakeClock(start);
      final engine = _engine(clock);

      // 100 identical active ticks ⇒ ONE merged segment, not 100.
      for (var i = 0; i < 100; i++) {
        tick(engine, clock, tickLen, idleSeconds: 0);
      }
      expect(engine.segments.length, 1);

      // 100 identical voluntary-idle ticks ⇒ ONE more segment (change opens it).
      for (var i = 0; i < 100; i++) {
        tick(engine, clock, tickLen, idleSeconds: 400);
      }
      expect(engine.segments.length, 2);

      // Segment count is O(classification changes), not O(tick count).
      expect(engine.segments[0].classification, SegmentClassification.active);
      expect(engine.segments[1].classification, SegmentClassification.idle);
    });
  });

  group('Decision (c) persistence across restart (TC-119)', () {
    test('segmentRecord_savesAndRestores_resumesContiguously', () async {
      const tickLen = Duration(seconds: 30);
      final clock = FakeClock(DateTime(2026, 6, 23, 14));
      final source = _engine(clock);
      final repo = InMemoryJourneyRepository();

      tick(source, clock, tickLen, idleSeconds: 0); // active
      tick(source, clock, tickLen, idleSeconds: 400); // idle
      await source.save(repo);
      final savedSegments = source.segments;

      // Fresh engine, same local day.
      final restored = _engine(FakeClock(DateTime(2026, 6, 23, 15)));
      await restored.loadAndRestore(repo);

      expect(restored.segments, savedSegments);

      // Next active tick continues contiguously from the restored last segment.
      final restoredLastTo = restored.segments.last.toKm;
      tick(restored, clock, tickLen, idleSeconds: 0);
      // A new active segment opens (last was idle) starting at restored.last.to.
      final newSeg = restored.segments.last;
      expect(newSeg.classification, SegmentClassification.active);
      expect(newSeg.fromKm, closeTo(restoredLastTo, kTol));
      // No duplicate / reset of prior segments.
      expect(restored.segments.length, savedSegments.length + 1);
    });
  });

  group('TC-120 mixed full-day end-to-end (AC-1..AC-4)', () {
    test('mixedDay_allInvariantsHoldTogether', () {
      const tickLen = Duration(minutes: 1);
      // 9 one-minute steps total (8 before journeyDayN + 1 crossing step), so
      // start at 23:51 ⇒ the final step lands exactly on 00:00 of 06-24.
      final clock = FakeClock(DateTime(2026, 6, 23, 23, 51));
      final engine = _engine(clock, threshold: const Duration(minutes: 10));

      // Helper that advances the clock with the tick.
      void step(int idleSeconds, {bool locked = false}) {
        clock.setNow(clock.now().add(tickLen));
        engine.tick(tickLen, idleSeconds: idleSeconds, screenLocked: locked);
      }

      // Day N: active(2) → grace(1) → voluntary idle(2) → lock(2) → resume(1).
      step(0);
      step(0); // active 2min
      step(60); // grace 1min (merges into active seg)
      step(360); // voluntary idle
      step(360); // voluntary idle (2min total)
      step(0, locked: true);
      step(0, locked: true); // lock 2min
      step(0); // resume active 1min — now ~23:59
      final journeyDayN = engine.activeTimeToday;
      expect(journeyDayN, greaterThan(Duration.zero));

      // Day N accrued exactly 4 idle minutes (2 voluntary-idle + 2 lock ticks)
      // before the crossing — hand-counted from the scripted timeline above.
      expect(engine.idleTimeToday, const Duration(minutes: 4));

      // Cross midnight into day N+1, then one active minute.
      step(0); // this tick crosses into 06-24 (resets daily, splits segment).

      // (AC-2) displayed idle == accounting accumulator, divergence 0: after the
      // rollover the daily idle counter resets and this crossing tick is active,
      // so the honestly-accounted day-N+1 idle is exactly zero — asserted
      // against that independently computed value, not the accumulator itself.
      expect(engine.idleTimeToday, Duration.zero);
      // (AC-1) active never over-credited: rawActiveTime <= activeTimeToday.
      expect(engine.rawActiveTime <= engine.activeTimeToday, isTrue);
      // (AC-3) segments contiguous + gap-free over the whole run.
      final segments = engine.segments;
      for (var i = 0; i < segments.length - 1; i++) {
        expect(segments[i].toKm, closeTo(segments[i + 1].fromKm, kTol));
      }
      expect(segments.first.fromKm, closeTo(0, kTol));
      expect(segments.last.toKm, closeTo(engine.distanceKm, kTol));
      // (AC-4) the lock segment is cause = lockSleep, voluntary is voluntary.
      expect(
        segments.any(
          (s) =>
              s.classification == SegmentClassification.idle &&
              s.cause == SegmentCause.lockSleep,
        ),
        isTrue,
      );
      expect(
        segments.any(
          (s) =>
              s.classification == SegmentClassification.idle &&
              s.cause == SegmentCause.voluntary,
        ),
        isTrue,
      );
      // Day rolled over.
      expect(engine.currentDay, DateTime(2026, 6, 24));
    });
  });
}
