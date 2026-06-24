// Deterministic unit tests for the app-layer ActivityTicker.
//
// Scope: the periodic driver that turns measured elapsed time into engine ticks
// and republishes to the JourneyCubit. Tests inject a scripted FakeClock and a
// fake timer factory, then drive `tickOnce()` directly — no real timers, no
// wall-clock waits. The credited delta MUST be `clock.now() - lastTick` (NOT the
// timer interval); the M-2 error policy must swallow plugin failures without
// crashing, accrue no bogus travel, stay usable, and settle the view to stopped.
//
// Conventions mirror test/features/journey/domain/journey_engine_test.dart.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/activity/data/mock_activity_source.dart';
import 'package:focus_journey/features/activity/domain/activity_plugin_exception.dart';
import 'package:focus_journey/features/journey/domain/clock.dart';
import 'package:focus_journey/features/journey/domain/journey_engine.dart';
import 'package:focus_journey/features/journey/domain/journey_state.dart';
import 'package:focus_journey/features/journey/presentation/activity_ticker.dart';
import 'package:focus_journey/features/journey/presentation/journey_cubit.dart';
import 'package:focus_journey/features/journey/presentation/journey_view_state.dart';

/// A fully scriptable [Clock]: tests set [now] explicitly and advance it
/// between ticks to control the measured delta.
class FakeClock implements Clock {
  FakeClock(this._now);

  DateTime _now;

  void setNow(DateTime value) => _now = value;

  /// Moves the scripted instant forward by [by].
  void advance(Duration by) => _now = _now.add(by);

  @override
  DateTime now() => _now;
}

/// A no-op fake [Timer] that records cancellation, so `start()` can be wired
/// without scheduling anything on the real event loop (we drive `tickOnce`
/// directly). [cancel] flips [wasCancelled] so stop()/dispose() can be asserted.
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
final DateTime _noon = DateTime(2026, 6, 23, 12);

JourneyEngine _engine(MockActivitySource source) {
  return JourneyEngine(
    clock: FakeClock(_noon),
    activityPlugin: source,
    kmPerActiveHour: 10, // 1h ⇒ 10 km.
    maxTickDelta: const Duration(hours: 6), // don't clamp the test deltas.
  );
}

void main() {
  group('ActivityTicker — delta is measured, not the interval (overview)', () {
    test('tickOnce_creditsClockDelta_notTheTimerInterval', () async {
      // Engine sees an active signal; the credited delta must equal the elapsed
      // clock time between ticks, NOT the (deliberately different) interval.
      final clock = FakeClock(_noon);
      final source = MockActivitySource(idleSeconds: 0, screenLocked: false);
      final engine = _engine(source);
      final cubit = JourneyCubit();
      addTearDown(cubit.close);
      final ticker = ActivityTicker(
        engine: engine,
        clock: clock,
        cubit: cubit,
        interval: const Duration(seconds: 1), // intentionally != the delta.
        timerFactory: (_, _) => FakeTimer(),
      );

      // First tick establishes lastTick (delta from start == 0 here since we
      // never called start(); previous defaults to now ⇒ delta 0, no accrual).
      await ticker.tickOnce();
      expect(engine.distanceKm, closeTo(0, kTol));

      // Advance the clock by 6 minutes, then tick: delta = 6min ⇒ 1 km at
      // 10 km/h — proving accrual tracks clock.now()-lastTick, not the 1s interval.
      clock.advance(const Duration(minutes: 6));
      await ticker.tickOnce();

      expect(engine.distanceKm, closeTo(1, kTol));
      expect(engine.activeTimeToday, const Duration(minutes: 6));
      expect(engine.state, JourneyState.active);
    });

    test('tickOnce_consecutiveDeltas_accrueIndependently', () async {
      final clock = FakeClock(_noon);
      final source = MockActivitySource(idleSeconds: 0, screenLocked: false);
      final engine = _engine(source);
      final cubit = JourneyCubit();
      addTearDown(cubit.close);
      final ticker = ActivityTicker(
        engine: engine,
        clock: clock,
        cubit: cubit,
        timerFactory: (_, _) => FakeTimer(),
      );

      await ticker.tickOnce(); // delta 0.
      clock.advance(const Duration(minutes: 3));
      await ticker.tickOnce(); // +3min ⇒ +0.5 km.
      clock.advance(const Duration(minutes: 3));
      await ticker.tickOnce(); // +3min ⇒ +0.5 km.

      expect(engine.activeTimeToday, const Duration(minutes: 6));
      expect(engine.distanceKm, closeTo(1, kTol));
    });
  });

  group('ActivityTicker — republishes the snapshot to the cubit', () {
    test('tickOnce_active_cubitMatchesEngineMovingSnapshot', () async {
      final clock = FakeClock(_noon);
      final source = MockActivitySource(idleSeconds: 0, screenLocked: false);
      final engine = _engine(source);
      final cubit = JourneyCubit();
      addTearDown(cubit.close);
      final ticker = ActivityTicker(
        engine: engine,
        clock: clock,
        cubit: cubit,
        timerFactory: (_, _) => FakeTimer(),
      );

      await ticker.tickOnce(); // establishes lastTick.
      clock.advance(const Duration(minutes: 6));
      await ticker.tickOnce();

      expect(cubit.state.motion, JourneyMotion.moving);
      expect(cubit.state.distanceKm, closeTo(engine.distanceKm, kTol));
      expect(cubit.state.mode, engine.mode);
      expect(cubit.state.hasRealState, isTrue);
    });

    test('tickOnce_paused_cubitSettlesToStoppedWithOverlay', () async {
      final clock = FakeClock(_noon);
      // idle past G=T default (5min) ⇒ engine pauses.
      final source = MockActivitySource(idleSeconds: 400, screenLocked: false);
      final engine = _engine(source);
      final cubit = JourneyCubit();
      addTearDown(cubit.close);
      final ticker = ActivityTicker(
        engine: engine,
        clock: clock,
        cubit: cubit,
        timerFactory: (_, _) => FakeTimer(),
      );

      await ticker.tickOnce();
      clock.advance(const Duration(minutes: 1));
      await ticker.tickOnce();

      expect(engine.state, JourneyState.paused);
      expect(cubit.state.motion, JourneyMotion.stopped);
      expect(cubit.state.showPausedOverlay, isTrue);
    });
  });

  group('ActivityTicker — M-2 plugin-error policy', () {
    test('idleError_tickOnceDoesNotThrow_accruesNoTravel', () async {
      final clock = FakeClock(_noon);
      final source = MockActivitySource(idleSeconds: 0, screenLocked: false);
      final engine = _engine(source);
      final cubit = JourneyCubit();
      addTearDown(cubit.close);
      final logged = <String>[];
      final ticker = ActivityTicker(
        engine: engine,
        clock: clock,
        cubit: cubit,
        timerFactory: (_, _) => FakeTimer(),
        log: logged.add,
      );

      await ticker.tickOnce(); // establish lastTick.
      source.idleError = const ActivityPluginException.unavailable(
        message: 'idle signal unavailable',
      );
      clock.advance(const Duration(minutes: 6));

      // M-2: must NOT throw despite the plugin failing mid-tick.
      await expectLater(ticker.tickOnce(), completes);

      // No bogus travel accrued — the engine simply did not advance.
      expect(engine.distanceKm, closeTo(0, kTol));
      expect(engine.activeTimeToday, Duration.zero);
      // The swallowed error was surfaced as a diagnostic, not rethrown.
      expect(logged, isNotEmpty);
    });

    test('lockError_tickOnceDoesNotThrow_accruesNoTravel', () async {
      final clock = FakeClock(_noon);
      final source = MockActivitySource(idleSeconds: 0, screenLocked: false);
      final engine = _engine(source);
      final cubit = JourneyCubit();
      addTearDown(cubit.close);
      final ticker = ActivityTicker(
        engine: engine,
        clock: clock,
        cubit: cubit,
        timerFactory: (_, _) => FakeTimer(),
      );

      await ticker.tickOnce();
      source.lockError = const ActivityPluginException.denied(
        message: 'lock query denied',
      );
      clock.advance(const Duration(minutes: 6));

      await expectLater(ticker.tickOnce(), completes);

      expect(engine.distanceKm, closeTo(0, kTol));
      expect(engine.activeTimeToday, Duration.zero);
    });

    test('afterPluginError_tickerStaysUsable_andCubitSettlesStopped', () async {
      // M-2: a failed tick keeps the ticker usable; once the signal recovers a
      // subsequent active tick credits normally, and after the failed tick the
      // cubit reflects a stopped (last-real) presentation.
      final clock = FakeClock(_noon);
      final source = MockActivitySource(idleSeconds: 0, screenLocked: false);
      final engine = _engine(source);
      final cubit = JourneyCubit();
      addTearDown(cubit.close);
      final ticker = ActivityTicker(
        engine: engine,
        clock: clock,
        cubit: cubit,
        timerFactory: (_, _) => FakeTimer(),
      );

      await ticker.tickOnce(); // lastTick set; engine still at default paused.

      // Failing tick: no advance.
      source.idleError = const ActivityPluginException.unavailable();
      clock.advance(const Duration(minutes: 6));
      await ticker.tickOnce();
      // The engine never advanced past its initial paused default ⇒ stopped view.
      expect(cubit.state.motion, JourneyMotion.stopped);

      // Signal recovers; the ticker is still usable and credits the next tick.
      source.idleError = null;
      clock.advance(const Duration(minutes: 6));
      await ticker.tickOnce();

      expect(engine.state, JourneyState.active);
      expect(engine.distanceKm, closeTo(1, kTol)); // 6min active ⇒ 1 km.
      expect(cubit.state.motion, JourneyMotion.moving);
    });

    test(
      'pluginError_doesNotResetLastTick_nextDeltaMeasuredFromFailedTick',
      () async {
        // The failed tick still advances lastTick to its own now, so the recovery
        // tick credits only the time since the failure (not the cumulative gap).
        final clock = FakeClock(_noon);
        final source = MockActivitySource(idleSeconds: 0, screenLocked: false);
        final engine = _engine(source);
        final cubit = JourneyCubit();
        addTearDown(cubit.close);
        final ticker = ActivityTicker(
          engine: engine,
          clock: clock,
          cubit: cubit,
          timerFactory: (_, _) => FakeTimer(),
        );

        await ticker.tickOnce();
        source.idleError = const ActivityPluginException.unavailable();
        clock.advance(
          const Duration(minutes: 30),
        ); // big gap during the failure.
        await ticker.tickOnce(); // swallowed; lastTick now = noon+30.

        source.idleError = null;
        clock.advance(
          const Duration(minutes: 6),
        ); // only 6min since the failure.
        await ticker.tickOnce();

        // Credits only the 6min since the failed tick, not the 36min total.
        expect(engine.activeTimeToday, const Duration(minutes: 6));
        expect(engine.distanceKm, closeTo(1, kTol));
      },
    );
  });

  group('ActivityTicker — start/stop/dispose lifecycle', () {
    test('start_isIdempotent_secondCallReusesSameTimer', () {
      final clock = FakeClock(_noon);
      final source = MockActivitySource();
      final engine = _engine(source);
      final cubit = JourneyCubit();
      addTearDown(cubit.close);
      var timersCreated = 0;
      final ticker = ActivityTicker(
        engine: engine,
        clock: clock,
        cubit: cubit,
        timerFactory: (_, _) {
          timersCreated++;
          return FakeTimer();
        },
      );

      ticker.start();
      ticker.start(); // ignored while already running.

      expect(timersCreated, 1);
      expect(ticker.isRunning, isTrue);
      ticker.stop();
    });

    test('stop_cancelsTimer_andClearsRunning', () {
      final clock = FakeClock(_noon);
      final source = MockActivitySource();
      final engine = _engine(source);
      final cubit = JourneyCubit();
      addTearDown(cubit.close);
      late FakeTimer created;
      final ticker = ActivityTicker(
        engine: engine,
        clock: clock,
        cubit: cubit,
        timerFactory: (_, _) {
          created = FakeTimer();
          return created;
        },
      );

      ticker.start();
      ticker.stop();

      expect(created.wasCancelled, isTrue);
      expect(ticker.isRunning, isFalse);
    });

    test('stop_whenNotRunning_isSafeNoop', () {
      final clock = FakeClock(_noon);
      final source = MockActivitySource();
      final engine = _engine(source);
      final cubit = JourneyCubit();
      addTearDown(cubit.close);
      final ticker = ActivityTicker(
        engine: engine,
        clock: clock,
        cubit: cubit,
        timerFactory: (_, _) => FakeTimer(),
      );

      // No start() first — must not throw.
      expect(ticker.stop, returnsNormally);
      expect(ticker.isRunning, isFalse);
    });

    test('dispose_cancelsTimer_andStopsRunning', () {
      final clock = FakeClock(_noon);
      final source = MockActivitySource();
      final engine = _engine(source);
      final cubit = JourneyCubit();
      addTearDown(cubit.close);
      late FakeTimer created;
      final ticker = ActivityTicker(
        engine: engine,
        clock: clock,
        cubit: cubit,
        timerFactory: (_, _) {
          created = FakeTimer();
          return created;
        },
      );

      ticker.start();
      ticker.dispose();

      expect(created.wasCancelled, isTrue);
      expect(ticker.isRunning, isFalse);
    });
  });
}
