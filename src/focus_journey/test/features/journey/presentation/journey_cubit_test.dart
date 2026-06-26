// Deterministic unit tests for the JourneyCubit mapping layer.
//
// Scope: the Cubit only maps an already-decided engine snapshot
// (state/mode/distanceKm) onto a JourneyViewState — it performs NO activity
// decision and reads NO OS signal. Tests drive a real (pure) JourneyEngine with
// a scripted FakeClock + deterministic MockActivitySource, then assert the
// emitted view state. Uses bloc_test (already a dev dependency).
//
// Conventions mirror test/features/journey/domain/journey_engine_test.dart.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/activity/data/mock_activity_source.dart';
import 'package:focus_journey/features/journey/domain/clock.dart';
import 'package:focus_journey/features/journey/domain/journey_engine.dart';
import 'package:focus_journey/features/journey/domain/journey_state.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/journey/presentation/journey_cubit.dart';
import 'package:focus_journey/features/journey/presentation/journey_view_state.dart';

/// A fully scriptable [Clock]: tests set [now] explicitly (mirrors the domain
/// test's FakeClock so the presentation tests stay equally deterministic).
class FakeClock implements Clock {
  FakeClock(this._now);

  DateTime _now;

  void setNow(DateTime value) => _now = value;

  @override
  DateTime now() => _now;
}

final DateTime _noon = DateTime(2026, 6, 23, 12);

/// Builds an engine with small, exact knobs (kmPerActiveHour = 10 ⇒ 1h = 10km).
JourneyEngine _engine({
  MockActivitySource? plugin,
  TravelMode mode = TravelMode.motorbike,
}) {
  return JourneyEngine(
    clock: FakeClock(_noon),
    activityPlugin: plugin ?? MockActivitySource(),
    kmPerActiveHour: 10,
    maxTickDelta: const Duration(hours: 6),
    mode: mode,
  );
}

void main() {
  group('JourneyCubit — initial state (AC-13)', () {
    test('newCubit_startsAtInitialParkedNoOverlay', () {
      final cubit = JourneyCubit();
      addTearDown(cubit.close);

      expect(cubit.state, const JourneyViewState.initial());
      expect(cubit.state.showPausedOverlay, isFalse);
    });
  });

  group('JourneyCubit — updateFromEngine motion mapping (TC-005/TC-021)', () {
    blocTest<JourneyCubit, JourneyViewState>(
      'activeEngine_emitsMovingViewWithDistanceAndMode',
      build: JourneyCubit.new,
      act: (cubit) {
        final engine = _engine(mode: TravelMode.car);
        // 6 min active at 10 km/h ⇒ 1 km, state active.
        engine.tick(
          const Duration(minutes: 6),
          idleSeconds: 0,
          screenLocked: false,
        );
        cubit.updateFromEngine(engine);
      },
      expect: () => <JourneyViewState>[
        const JourneyViewState(
          motion: JourneyMotion.moving,
          mode: TravelMode.car,
          distanceKm: 1,
          hasRealState: true,
        ),
      ],
    );

    blocTest<JourneyCubit, JourneyViewState>(
      'pausedEngine_emitsStoppedViewWithOverlay',
      build: JourneyCubit.new,
      act: (cubit) {
        final engine = _engine();
        // idle 400s past G=T (default 5min) ⇒ paused, no travel.
        engine.tick(
          const Duration(minutes: 1),
          idleSeconds: 400,
          screenLocked: false,
        );
        cubit.updateFromEngine(engine);
      },
      verify: (cubit) {
        expect(cubit.state.motion, JourneyMotion.stopped);
        expect(cubit.state.hasRealState, isTrue);
        expect(cubit.state.showPausedOverlay, isTrue);
        expect(cubit.state.distanceKm, 0);
      },
    );

    blocTest<JourneyCubit, JourneyViewState>(
      'idleEngine_emitsStoppedViewWithOverlay',
      build: JourneyCubit.new,
      act: (cubit) {
        // G=5min, T=10min ⇒ non-empty idle band; idle 360s ⇒ idle state.
        final engine = JourneyEngine(
          clock: FakeClock(_noon),
          activityPlugin: MockActivitySource(),
          kmPerActiveHour: 10,
          threshold: const Duration(minutes: 10),
        );
        engine.tick(
          const Duration(minutes: 1),
          idleSeconds: 360,
          screenLocked: false,
        );
        expect(engine.state, JourneyState.idle); // guard the setup.
        cubit.updateFromEngine(engine);
      },
      verify: (cubit) {
        expect(cubit.state.motion, JourneyMotion.stopped);
        expect(cubit.state.showPausedOverlay, isTrue);
      },
    );
  });

  group('JourneyCubit — resume mapping (TC-021)', () {
    blocTest<JourneyCubit, JourneyViewState>(
      'pausedThenActive_emitsStoppedThenMoving',
      build: JourneyCubit.new,
      act: (cubit) {
        final engine = _engine();
        // Past grace ⇒ paused.
        engine.tick(
          const Duration(minutes: 1),
          idleSeconds: 400,
          screenLocked: false,
        );
        cubit.updateFromEngine(engine);
        // Fresh input ⇒ resumes active.
        engine.tick(
          const Duration(minutes: 6),
          idleSeconds: 0,
          screenLocked: false,
        );
        cubit.updateFromEngine(engine);
      },
      expect: () => <Matcher>[
        isA<JourneyViewState>().having(
          (s) => s.motion,
          'motion',
          JourneyMotion.stopped,
        ),
        isA<JourneyViewState>().having(
          (s) => s.motion,
          'motion',
          JourneyMotion.moving,
        ),
      ],
    );
  });

  group('JourneyCubit — idle counter reconciliation (idle-accounting AC-2)', () {
    test('emittedIdleTimeToday_equalsEngineAccumulator_divergence0', () {
      final cubit = JourneyCubit();
      addTearDown(cubit.close);
      // G = T = 5min default; idle 400s ⇒ paused, accrues idle.
      final engine = _engine();

      engine.tick(
        const Duration(minutes: 1),
        idleSeconds: 400,
        screenLocked: false,
      );
      cubit.updateFromEngine(engine);

      // The displayed counter is the engine accumulator read verbatim — exact
      // equality (no tolerance), so UI and accounting agree with divergence 0.
      expect(cubit.state.idleTimeToday, engine.idleTimeToday);
      expect(cubit.state.idleTimeToday, const Duration(minutes: 1));

      // A second idle tick: the displayed value tracks the accumulator exactly.
      engine.tick(
        const Duration(minutes: 1),
        idleSeconds: 400,
        screenLocked: false,
      );
      cubit.updateFromEngine(engine);
      expect(cubit.state.idleTimeToday, engine.idleTimeToday);
      expect(cubit.state.idleTimeToday, const Duration(minutes: 2));
    });
  });

  group('JourneyCubit — equality skips redundant emits', () {
    blocTest<JourneyCubit, JourneyViewState>(
      'twoIdenticalSnapshots_emitOnlyOnce',
      build: JourneyCubit.new,
      act: (cubit) {
        final engine = _engine();
        engine.tick(
          const Duration(minutes: 6),
          idleSeconds: 0,
          screenLocked: false,
        );
        // Same engine snapshot pushed twice: Equatable suppresses the second.
        cubit.updateFromEngine(engine);
        cubit.updateFromEngine(engine);
      },
      expect: () => <JourneyViewState>[
        const JourneyViewState(
          motion: JourneyMotion.moving,
          mode: TravelMode.motorbike,
          distanceKm: 1,
          hasRealState: true,
        ),
      ],
    );
  });
}
