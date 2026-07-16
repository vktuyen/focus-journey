// route-real-road — the DERIVED journey gate (app-layer / presentation).
//
// There is NO manual Start/Pause control. The journey RUNS whenever there is a
// committed active route and is PAUSED only while the user is authoring/
// re-authoring a route or when there is no route at all — i.e. the flag is
// `hasActiveRoute && !authoring`. These tests pin:
//   - JourneyGateCubit toggles cleanly via start/pause and the authoring hooks;
//   - the gate→ticker wiring (exactly as main.dart wires it): no active route →
//     paused, no accrual; a committed active route → running + accrues; opening
//     a re-authoring flow → paused; closing it (with an active route) → running;
//   - confirming a route (onRouteStarted) opens the gate; RESTORING an active
//     route yields a selection (the runtime's auto-run condition) while no plan
//     yields none (stays paused).
//
// No real timers / wall-clock: a scripted FakeClock + a fake timer factory, and
// tickOnce() is driven directly (mirrors activity_ticker_test.dart).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/activity/data/mock_activity_source.dart';
import 'package:focus_journey/features/journey/domain/clock.dart';
import 'package:focus_journey/features/journey/domain/journey_engine.dart';
import 'package:focus_journey/features/journey/presentation/activity_ticker.dart';
import 'package:focus_journey/features/journey/presentation/journey_cubit.dart';
import 'package:focus_journey/features/journey/presentation/journey_gate_cubit.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/domain/route_planner.dart';
import 'package:focus_journey/features/route/domain/route_plan.dart';
import 'package:focus_journey/features/route/presentation/route_progress_cubit.dart';

import '../../route/map_test_fixtures.dart' as mapfx;
import '../../route/route_test_fixtures.dart';

class FakeClock implements Clock {
  FakeClock(this._now);
  DateTime _now;
  void advance(Duration by) => _now = _now.add(by);
  @override
  DateTime now() => _now;
}

class FakeTimer implements Timer {
  bool wasCancelled = false;
  @override
  void cancel() => wasCancelled = true;
  @override
  bool get isActive => !wasCancelled;
  @override
  int get tick => 0;
}

const double kTol = 1e-6;
final DateTime _noon = DateTime(2026, 7, 15, 12);

void main() {
  group('JourneyGateCubit — flag + authoring hooks', () {
    test('starts PAUSED (false)', () {
      final gate = JourneyGateCubit();
      addTearDown(gate.close);
      expect(gate.state, isFalse);
      expect(gate.isRunning, isFalse);
    });

    test('start / pause / beginAuthoring / endAuthoring emit the flag',
        () async {
      final gate = JourneyGateCubit();
      addTearDown(gate.close);
      final emitted = <bool>[];
      final sub = gate.stream.listen(emitted.add);
      addTearDown(sub.cancel);

      gate.start(); // committed active route → running.
      gate.start(); // idempotent.
      gate.beginAuthoring(); // re-authoring opened → paused.
      gate.beginAuthoring(); // idempotent.
      gate.endAuthoring(); // authoring closed → running again.
      await pumpEventQueue();

      expect(emitted, <bool>[true, false, true]);
    });

    test('start/pause/authoring hooks are safe no-ops after close (S6)', () {
      // A re-authoring `finally { endAuthoring() }` can fire AFTER a
      // mid-authoring runtime teardown (Factory reset closed the cubit).
      final gate = JourneyGateCubit();
      gate.close();
      expect(() {
        gate.start();
        gate.pause();
        gate.beginAuthoring();
        gate.endAuthoring();
      }, returnsNormally);
      expect(gate.isClosed, isTrue);
    });

    test('a re-authoring flow that throws still releases the gate (S1 finally)',
        () async {
      final gate = JourneyGateCubit();
      addTearDown(gate.close);
      gate.start(); // running on the active route.

      // Mirror the entry points' structure: pause on open, and ALWAYS resume in
      // a `finally` — even when building/showing the dialog throws.
      Future<void> reauthor() async {
        gate.beginAuthoring();
        try {
          await Future<void>.error(StateError('dialog build failed'));
        } finally {
          gate.endAuthoring();
        }
      }

      await expectLater(reauthor(), throwsStateError);
      // The gate is NOT stuck paused — it resumed the still-active route.
      expect(gate.isRunning, isTrue);
    });
  });

  group('gate → ticker wiring (mirrors main.dart _JourneyRuntime)', () {
    late FakeClock clock;
    late JourneyEngine engine;
    late JourneyCubit journeyCubit;
    late JourneyGateCubit gate;
    late ActivityTicker ticker;
    late int timersCreated;

    setUp(() {
      clock = FakeClock(_noon);
      final source = MockActivitySource(idleSeconds: 0, screenLocked: false);
      engine = JourneyEngine(
        clock: clock,
        activityPlugin: source,
        kmPerActiveHour: 10, // 6 min ⇒ 1 km.
        maxTickDelta: const Duration(hours: 6),
      );
      journeyCubit = JourneyCubit();
      gate = JourneyGateCubit();
      timersCreated = 0;
      ticker = ActivityTicker(
        engine: engine,
        clock: clock,
        cubit: journeyCubit,
        timerFactory: (_, _) {
          timersCreated++;
          return FakeTimer();
        },
      );
      // The runtime listens to the gate and starts/stops the ticker.
      gate.stream.listen((running) {
        if (running) {
          ticker.start();
        } else {
          ticker.stop();
        }
      });
      addTearDown(() {
        ticker.dispose();
        journeyCubit.close();
        gate.close();
      });
    });

    test('no active route on launch → paused, no timer, no accrual', () async {
      // The runtime does NOT open the gate when there is no committed route.
      await pumpEventQueue();
      expect(gate.isRunning, isFalse);
      expect(ticker.isRunning, isFalse);
      expect(timersCreated, 0);
      clock.advance(const Duration(minutes: 30));
      expect(engine.distanceKm, closeTo(0, kTol));
    });

    test('committed active route on launch → running + accrues', () async {
      // The runtime opens the gate at init because a route was restored.
      gate.start();
      await pumpEventQueue();
      expect(ticker.isRunning, isTrue);
      expect(timersCreated, 1);

      await ticker.tickOnce(); // establishes lastTick (delta 0).
      clock.advance(const Duration(minutes: 6));
      await ticker.tickOnce();
      expect(engine.distanceKm, closeTo(1, kTol));
    });

    test('opening re-authoring pauses; closing it resumes (route stays active)',
        () async {
      gate.start(); // running on the active route.
      await pumpEventQueue();
      expect(ticker.isRunning, isTrue);

      await ticker.tickOnce();
      clock.advance(const Duration(minutes: 6));
      await ticker.tickOnce();
      final frozen = engine.distanceKm;
      expect(frozen, closeTo(1, kTol));

      // Re-authoring opens → paused → the odometer freezes.
      gate.beginAuthoring();
      await pumpEventQueue();
      expect(ticker.isRunning, isFalse);
      clock.advance(const Duration(minutes: 30));
      expect(engine.distanceKm, closeTo(frozen, kTol));

      // Authoring closes (route still active) → running again.
      gate.endAuthoring();
      await pumpEventQueue();
      expect(ticker.isRunning, isTrue);
      expect(timersCreated, 2); // a fresh timer scheduled on resume.
    });
  });

  group('route confirm opens the gate; restore yields the auto-run condition',
      () {
    late final ProvinceChain chain = buildFixtureChain();
    late final ProvinceGeography geography = mapfx.buildFixtureGeography(chain);

    ResolvedRoute resolve(String startId, String endId) => RoutePlanner.resolve(
          fullChain: chain,
          fullGeography: geography,
          start: nodeById(chain, startId),
          end: nodeById(chain, endId),
        );

    test('confirmRoute fires onRouteStarted → gate opens', () async {
      final gate = JourneyGateCubit();
      addTearDown(gate.close);
      final cubit = RouteProgressCubit(
        chain: chain,
        geography: geography,
        repository: RecordingRouteRepository(),
        onRouteStarted: gate.start,
      );
      addTearDown(cubit.close);

      expect(gate.isRunning, isFalse);
      await cubit.confirmRoute(resolve('can_tho', 'da_nang'));
      expect(gate.isRunning, isTrue);
    });

    test('restoring an active route → selection present → runtime auto-runs it',
        () {
      final resolved = resolve('can_tho', 'da_nang');
      final plan = RoutePlan.fromResolved(resolved, routeStartOffsetKm: 0);
      final gate = JourneyGateCubit();
      addTearDown(gate.close);
      final cubit = RouteProgressCubit(
        chain: chain,
        geography: geography,
        repository: RecordingRouteRepository(seedPlan: plan),
        initialPlan: plan,
        onRouteStarted: gate.start,
      );
      addTearDown(cubit.close);

      // The runtime's auto-run condition: a committed route was adopted.
      expect(cubit.state.selection, isNotNull);
      // Simulate the runtime opening the gate on that condition.
      if (cubit.state.selection != null) {
        gate.start();
      }
      expect(gate.isRunning, isTrue);
    });

    test('no restored plan → no selection → stays paused', () {
      final gate = JourneyGateCubit();
      addTearDown(gate.close);
      final cubit = RouteProgressCubit(
        chain: chain,
        geography: geography,
        repository: RecordingRouteRepository(),
        onRouteStarted: gate.start,
      );
      addTearDown(cubit.close);

      expect(cubit.state.selection, isNull);
      if (cubit.state.selection != null) {
        gate.start();
      }
      expect(gate.isRunning, isFalse);
    });
  });

  group('S2 — freeze the journey on arrival', () {
    late final ProvinceChain chain = buildFixtureChain();
    late final ProvinceGeography geography = mapfx.buildFixtureGeography(chain);

    ResolvedRoute resolve(String startId, String endId) => RoutePlanner.resolve(
          fullChain: chain,
          fullGeography: geography,
          start: nodeById(chain, startId),
          end: nodeById(chain, endId),
        );

    test('a route that ticks to completion pauses the gate (ticker stops); a '
        'new route re-opens it', () async {
      final clock = FakeClock(_noon);
      final source = MockActivitySource(idleSeconds: 0, screenLocked: false);
      final engine = JourneyEngine(
        clock: clock,
        activityPlugin: source,
        kmPerActiveHour: 10,
        maxTickDelta: const Duration(hours: 6),
      );
      final journeyCubit = JourneyCubit();
      final gate = JourneyGateCubit();
      final ticker = ActivityTicker(
        engine: engine,
        clock: clock,
        cubit: journeyCubit,
        timerFactory: (_, _) => FakeTimer(),
      );
      // Runtime wiring: gate → ticker, and the route listener that freezes the
      // gate on arrival (mirrors main.dart `_onRouteChanged` S2).
      gate.stream.listen((running) {
        if (running) {
          ticker.start();
        } else {
          ticker.stop();
        }
      });
      final routeCubit = RouteProgressCubit(
        chain: chain,
        geography: geography,
        repository: RecordingRouteRepository(),
        onRouteStarted: gate.start,
      );
      routeCubit.stream.listen((s) {
        if (s.position?.isCompleted ?? false) {
          gate.pause();
        }
      });
      addTearDown(() {
        ticker.dispose();
        journeyCubit.close();
        gate.close();
        routeCubit.close();
      });

      // Confirming a route runs it.
      await routeCubit.confirmRoute(resolve('can_tho', 'da_nang'));
      await pumpEventQueue();
      expect(gate.isRunning, isTrue);
      expect(ticker.isRunning, isTrue);

      // Drive the route to (well past) its destination → completion latches.
      routeCubit.updateFromDistance(100000);
      await pumpEventQueue();
      expect(routeCubit.state.position?.isCompleted, isTrue);
      // The gate froze on arrival — the ticker stopped, so nothing more accrues.
      expect(gate.isRunning, isFalse);
      expect(ticker.isRunning, isFalse);

      // Starting a NEW route re-opens the gate (a fresh route is not completed).
      await routeCubit.confirmRoute(resolve('can_tho', 'ha_giang'));
      await pumpEventQueue();
      expect(routeCubit.state.position?.isCompleted, isFalse);
      expect(gate.isRunning, isTrue);
      expect(ticker.isRunning, isTrue);
    });
  });
}
