// TC-215 / AC-10 (runtime half): cosmetic-only — the journey-pov cockpit
// perturbs NO engine number.
//
// The cockpit is a pure VIEW driven solely off the engine's cosmetic `mode`
// (car/motorbike). It accrues no distance, reads no OS signal, decides no
// active-vs-idle. So for IDENTICAL injected ticks the engine's exposed
// counters (`distanceKm`, `activeTimeToday`, `rawActiveTime`, `idleTimeToday`)
// must be EXACTLY equal whether the cosmetic mode is a cockpit mode (`car`) or
// the no-cockpit baseline (`walk`) — compared with EXACT equality (engine
// truth, not rendered floats), not ±epsilon (tests/cases/journey-pov.md
// "Engine counters byte-for-byte unchanged").
//
// The STATIC half of AC-10 (the engine holds no cockpit / scene-render
// reference) lives in cockpit_separation_static_test.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/activity/data/mock_activity_source.dart';
import 'package:focus_journey/features/journey/domain/clock.dart';
import 'package:focus_journey/features/journey/domain/journey_engine.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';

class _FakeClock implements Clock {
  _FakeClock(this._now);
  DateTime _now;
  void setNow(DateTime v) => _now = v;
  @override
  DateTime now() => _now;
}

JourneyEngine _engine(TravelMode mode, _FakeClock clock) => JourneyEngine(
  clock: clock,
  activityPlugin: MockActivitySource(),
  kmPerActiveHour: 10,
  mode: mode,
);

/// A scripted activity tick: how long elapsed + the idle reading at tick time.
typedef _Tick = ({Duration delta, int idleSeconds, bool screenLocked});

const List<_Tick> _ticks = <_Tick>[
  // active (idle below floor) → accrues distance
  (delta: Duration(minutes: 1), idleSeconds: 0, screenLocked: false),
  (delta: Duration(minutes: 2), idleSeconds: 2, screenLocked: false),
  // grace (idle within grace) → still travels
  (delta: Duration(minutes: 3), idleSeconds: 120, screenLocked: false),
  // paused (idle past threshold) → no distance
  (delta: Duration(minutes: 5), idleSeconds: 600, screenLocked: false),
  // screen locked → paused
  (delta: Duration(minutes: 1), idleSeconds: 0, screenLocked: true),
  // active again
  (delta: Duration(minutes: 4), idleSeconds: 1, screenLocked: false),
];

void main() {
  test(
    'TC-215 engine counters are byte-for-byte identical for car vs walk (AC-10)',
    () {
      final start = DateTime(2026, 6, 25, 9);
      final carClock = _FakeClock(start);
      final walkClock = _FakeClock(start);
      final car = _engine(TravelMode.car, carClock); // cockpit mode
      final walk = _engine(TravelMode.walk, walkClock); // no-cockpit baseline

      // Drive BOTH engines with the SAME tick sequence at the SAME instants.
      DateTime t = start;
      for (final tick in _ticks) {
        t = t.add(tick.delta);
        carClock.setNow(t);
        walkClock.setNow(t);
        car.tick(
          tick.delta,
          idleSeconds: tick.idleSeconds,
          screenLocked: tick.screenLocked,
        );
        walk.tick(
          tick.delta,
          idleSeconds: tick.idleSeconds,
          screenLocked: tick.screenLocked,
        );

        // After EVERY tick the counters must be EXACTLY equal (not ±epsilon).
        expect(
          car.distanceKm,
          walk.distanceKm,
          reason: 'distanceKm must not depend on the cosmetic cockpit mode',
        );
        expect(car.activeTimeToday, walk.activeTimeToday);
        expect(car.rawActiveTime, walk.rawActiveTime);
        expect(car.idleTimeToday, walk.idleTimeToday);
        expect(car.state, walk.state);
      }

      // Sanity: the sequence actually moved the engine (otherwise the equality
      // is vacuous). Distance accrued and exact-equals between the two runs.
      expect(car.distanceKm, greaterThan(0));
      expect(car.distanceKm, walk.distanceKm);
    },
  );

  test('TC-215 motorbike (cockpit) equals walk (no cockpit) too (AC-10)', () {
    final start = DateTime(2026, 6, 25, 9);
    final mClock = _FakeClock(start);
    final wClock = _FakeClock(start);
    final moto = _engine(TravelMode.motorbike, mClock);
    final walk = _engine(TravelMode.walk, wClock);

    DateTime t = start;
    for (final tick in _ticks) {
      t = t.add(tick.delta);
      mClock.setNow(t);
      wClock.setNow(t);
      moto.tick(
        tick.delta,
        idleSeconds: tick.idleSeconds,
        screenLocked: tick.screenLocked,
      );
      walk.tick(
        tick.delta,
        idleSeconds: tick.idleSeconds,
        screenLocked: tick.screenLocked,
      );
    }
    expect(moto.distanceKm, walk.distanceKm);
    expect(moto.activeTimeToday, walk.activeTimeToday);
    expect(moto.rawActiveTime, walk.rawActiveTime);
    expect(moto.idleTimeToday, walk.idleTimeToday);
    expect(moto.distanceKm, greaterThan(0));
  });
}
