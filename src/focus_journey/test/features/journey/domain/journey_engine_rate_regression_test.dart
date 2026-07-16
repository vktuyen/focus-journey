// province-chain-2026 — accrual-mechanism regression guard (AC-10 / BR-6 /
// ADR-0007 firewall).
//
// Traceability (one test <-> one case; PC + AC ids in each description):
//   PC-923 (AC-10) replaying the SAME active/idle input trace against
//                  JourneyEngine with two different injected kmPerActiveHour
//                  values scales distance EXACTLY by the rate ratio, while
//                  raw-active-time stats/streak and the active/idle time totals
//                  are rate-independent (the mechanism is unchanged — only the
//                  injected config differs).
//   PC-924 (AC-10) the geometry/config rebuild introduces no new active/idle
//                  decision: the per-tick classification (state sequence) and the
//                  distance-vs-raw-active-time split are byte-identical across
//                  two very different rates.
//
// Pure engine test: scripted FakeClock + deterministic MockActivitySource, no
// real timers, no DateTime.now(), no native code (mirrors journey_engine_test).

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/activity/data/mock_activity_source.dart';
import 'package:focus_journey/features/journey/domain/clock.dart';
import 'package:focus_journey/features/journey/domain/journey_engine.dart';
import 'package:focus_journey/features/journey/domain/journey_state.dart';

class _FakeClock implements Clock {
  _FakeClock(this._now);
  DateTime _now;
  void setNow(DateTime v) => _now = v;
  @override
  DateTime now() => _now;
}

/// One scripted tick of the replayed trace.
class _Tick {
  const _Tick(this.idleSeconds, {this.screenLocked = false});
  final int idleSeconds;
  final bool screenLocked;
}

const double _tol = 1e-9;

void main() {
  // G = 2min, T = 5min, F = 5s: a config with a non-empty idle band so the trace
  // exercises active / grace / idle / paused / locked classifications.
  final grace = const Duration(minutes: 2);
  final threshold = const Duration(minutes: 5);
  final activeFloor = const Duration(seconds: 5);
  final delta = const Duration(minutes: 5);
  // maxTickDelta >= delta so no rate-independent clamping muddies the ratio.
  final maxTickDelta = const Duration(minutes: 30);

  // Same input trace replayed against both engines.
  const trace = <_Tick>[
    _Tick(0), // active (idle <= F)
    _Tick(2), // active
    _Tick(60), // grace (F < idle <= G) — travel, no raw-active
    _Tick(180), // idle (G < idle <= T) — no distance
    _Tick(600), // paused (idle > T)
    _Tick(0, screenLocked: true), // paused (locked overrides)
    _Tick(0), // active again
  ];

  JourneyEngine engineWithRate(double kmPerActiveHour) => JourneyEngine(
    clock: _FakeClock(DateTime(2026, 6, 23, 12)),
    activityPlugin: MockActivitySource(),
    kmPerActiveHour: kmPerActiveHour,
    grace: grace,
    threshold: threshold,
    activeFloor: activeFloor,
    maxTickDelta: maxTickDelta,
  );

  void replay(JourneyEngine engine, {List<JourneyState>? recordStates}) {
    for (final t in trace) {
      engine.tick(delta, idleSeconds: t.idleSeconds, screenLocked: t.screenLocked);
      recordStates?.add(engine.state);
    }
  }

  group('accrual mechanism is rate-only config (AC-10 / PC-923)', () {
    test('PC-923 distanceScalesByRateRatio_statsAreRateIndependent', () {
      const rateLow = 100.0;
      const rateHigh = 400.0; // 4x
      final low = engineWithRate(rateLow);
      final high = engineWithRate(rateHigh);
      replay(low);
      replay(high);

      // Distance scales EXACTLY by the injected rate ratio.
      expect(low.distanceKm, greaterThan(0));
      expect(
        high.distanceKm,
        closeTo(low.distanceKm * (rateHigh / rateLow), _tol),
        reason: 'distance must scale linearly with kmPerActiveHour',
      );

      // Raw-active-time (streak-qualifying) is rate-independent.
      expect(high.rawActiveTime, low.rawActiveTime);
      expect(low.rawActiveTime, greaterThan(Duration.zero));
      // Journey time (incl. grace) and idle time are rate-independent too.
      expect(high.activeTimeToday, low.activeTimeToday);
      expect(high.idleTimeToday, low.idleTimeToday);
      expect(high.state, low.state);
      // rawActiveTime <= activeTimeToday (grace excluded) — invariant preserved.
      expect(low.rawActiveTime, lessThan(low.activeTimeToday));
    });
  });

  group('classification + distance/stats firewall untouched (AC-10 / PC-924)', () {
    test('PC-924 perTickStateSequence_isByteIdenticalAcrossRates', () {
      final statesLow = <JourneyState>[];
      final statesHigh = <JourneyState>[];
      replay(engineWithRate(1.0), recordStates: statesLow);
      replay(engineWithRate(12345.6), recordStates: statesHigh);
      // The active/idle classification is independent of the injected rate.
      expect(statesHigh, statesLow);
      // And it produced every band we intended to exercise.
      expect(statesLow, contains(JourneyState.active));
      expect(statesLow, contains(JourneyState.idle));
      expect(statesLow, contains(JourneyState.paused));
    });

    test('PC-924 segmentRecordShapeAndClassifications_areRateIndependent', () {
      final low = engineWithRate(50.0);
      final high = engineWithRate(500.0);
      replay(low);
      replay(high);
      // Same number of segments, same classification/cause sequence — only the
      // distance-keyed extents differ (they scale with the rate).
      expect(high.segments.length, low.segments.length);
      for (var i = 0; i < low.segments.length; i++) {
        expect(high.segments[i].classification, low.segments[i].classification);
        expect(high.segments[i].cause, low.segments[i].cause);
      }
    });
  });
}
