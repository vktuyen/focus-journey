// Screen-level widget tests for the journey screen's Flutter overlays + the
// Bloc↔scene wiring (the parts that are plain Flutter, not Flame rendering).
//
// Covers:
//   TC-002 / TC-003 — idle and paused both show the "Paused — idle" overlay and
//                     are indistinguishable in the view (idle ≡ paused, v1).
//   TC-013 (overlay half) — the pre-state first frame is parked WITHOUT the
//                     overlay; a real stopped state shows it.
//   TC-019 (indicator half) — under reduce-motion a non-scrolling textual
//                     indicator conveys active vs stopped, and the overlay still
//                     shows when stopped.
//   TC-020 / TC-027 — the overlay is real text in the semantics tree (not a
//                     sprite); active vs stopped is discoverable via semantics.
//   TC-010 (runtime half) — pumping the screen through a state sequence never
//                     writes to the cubit's state (no write originates here).
//
// A scriptable cubit emits arbitrary JourneyViewStates so we drive the screen
// deterministically without a real engine/OS. The embedded GameWidget triggers
// Flame's asset load (including the intentionally-missing ship.png); its orphan
// "Unable to load asset" rejection is drained via tester.takeException so it
// does not mask real failures.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/clock.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/journey/presentation/journey_cubit.dart';
import 'package:focus_journey/features/journey/presentation/journey_screen.dart';
import 'package:focus_journey/features/journey/presentation/journey_view_state.dart';

/// A cubit whose state we drive directly (scriptable fake — no engine, no OS).
class ScriptableJourneyCubit extends JourneyCubit {
  void push(JourneyViewState state) => emit(state);
}

/// Pushes [state] and pumps twice: the first frame flushes the Cubit stream's
/// microtask (so BlocBuilder schedules a rebuild), the second renders it. A
/// single pump is not enough because Cubit notifications arrive asynchronously.
/// (No wall-clock waits — these are zero-duration frame pumps.)
Future<void> _push(
  WidgetTester tester,
  ScriptableJourneyCubit cubit,
  JourneyViewState state,
) async {
  cubit.push(state);
  await tester.pump();
  await tester.pump();
  final ex = tester.takeException();
  if (ex != null && !ex.toString().contains('Unable to load asset')) {
    throw ex as Object;
  }
}

/// Fixed-noon clock so the cosmetic tint is deterministic (never drives motion).
class FixedClock implements Clock {
  const FixedClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

JourneyViewState _moving({TravelMode mode = TravelMode.motorbike}) =>
    JourneyViewState(
      motion: JourneyMotion.moving,
      mode: mode,
      distanceKm: 12.3,
      hasRealState: true,
    );

JourneyViewState _stopped({TravelMode mode = TravelMode.motorbike}) =>
    JourneyViewState(
      motion: JourneyMotion.stopped,
      mode: mode,
      distanceKm: 12.3,
      hasRealState: true,
    );

Future<ScriptableJourneyCubit> _pumpScreen(
  WidgetTester tester, {
  bool reduceMotion = false,
}) async {
  final cubit = ScriptableJourneyCubit();
  addTearDown(cubit.close);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: MaterialApp(
        home: BlocProvider<JourneyCubit>.value(
          value: cubit,
          child: JourneyScreen(clock: FixedClock(DateTime(2026, 6, 23, 12))),
        ),
      ),
    ),
  );
  await tester.pump();
  // Drain Flame's expected orphan missing-asset rejection (ship.png).
  final ex = tester.takeException();
  if (ex != null && !ex.toString().contains('Unable to load asset')) {
    throw ex as Object;
  }
  return cubit;
}

void main() {
  group('TC-013 (overlay half) first frame parked, no overlay', () {
    testWidgets('initialState_showsNoPausedOverlay', (tester) async {
      await _pumpScreen(tester);
      // The initial cubit state has hasRealState == false.
      expect(find.text(kPausedOverlayText), findsNothing);
    });
  });

  group('TC-002 / TC-003 idle and paused both show overlay (idle ≡ paused)', () {
    testWidgets('stoppedRealState_showsPausedOverlayText', (tester) async {
      final cubit = await _pumpScreen(tester);
      await _push(tester, cubit, _stopped());
      expect(find.text(kPausedOverlayText), findsOneWidget);
    });

    testWidgets('idleAndPaused_produceIdenticalOverlayPresentation', (
      tester,
    ) async {
      // The view collapses idle and paused to JourneyMotion.stopped, so both
      // inputs yield the same widget tree (AC-3 — no visual distinction in v1).
      final cubit = await _pumpScreen(tester);

      await _push(tester, cubit, _stopped()); // represents idle
      final idleOverlay = find.text(kPausedOverlayText).evaluate().length;

      // Re-emit a DIFFERENT stopped state (changed distance) so Equatable does
      // not suppress the rebuild, then confirm the same overlay presentation.
      await _push(
        tester,
        cubit,
        const JourneyViewState(
          motion: JourneyMotion.stopped,
          mode: TravelMode.motorbike,
          distanceKm: 99,
          hasRealState: true,
        ),
      ); // represents paused
      final pausedOverlay = find.text(kPausedOverlayText).evaluate().length;

      expect(idleOverlay, 1);
      expect(pausedOverlay, 1);
      expect(idleOverlay, pausedOverlay);
    });

    testWidgets('activeState_hidesPausedOverlay', (tester) async {
      final cubit = await _pumpScreen(tester);
      await _push(tester, cubit, _moving());
      expect(find.text(kPausedOverlayText), findsNothing);
    });
  });

  group('TC-020 / TC-027 overlay is real text in the semantics tree', () {
    testWidgets('stopped_exposesPausedIdleAsSemanticsText', (tester) async {
      final semantics = tester.ensureSemantics();
      final cubit = await _pumpScreen(tester);
      await _push(tester, cubit, _stopped());

      // The overlay is a real Text node (not baked into a sprite) and is
      // exposed to assistive tech via a Semantics label. A RegExp matcher is
      // used because the explicit Semantics(label:) and the child Text merge
      // into one node whose label may repeat the string.
      expect(find.text(kPausedOverlayText), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(kPausedOverlayText))),
        findsOneWidget,
        reason: 'overlay must be discoverable by a screen reader',
      );
      semantics.dispose();
    });

    testWidgets('activeVsStopped_areDistinguishableViaSemantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final cubit = await _pumpScreen(tester);

      final overlayLabel = RegExp(RegExp.escape(kPausedOverlayText));
      await _push(tester, cubit, _moving());
      final activeHasOverlay = find
          .bySemanticsLabel(overlayLabel)
          .evaluate()
          .isNotEmpty;

      await _push(tester, cubit, _stopped());
      final stoppedHasOverlay = find
          .bySemanticsLabel(overlayLabel)
          .evaluate()
          .isNotEmpty;

      // The semantics tree changes between active and stopped — assistive tech
      // can tell the journey state without seeing the animation.
      expect(activeHasOverlay, isFalse);
      expect(stoppedHasOverlay, isTrue);
      semantics.dispose();
    });
  });

  group('TC-019 (indicator half) reduce-motion conveys state textually', () {
    testWidgets('reduceMotionActive_showsTravellingIndicator', (tester) async {
      final cubit = await _pumpScreen(tester, reduceMotion: true);
      await _push(tester, cubit, _moving());
      // A non-scrolling textual indicator conveys "Travelling" when active.
      expect(find.text('Travelling'), findsOneWidget);
      expect(find.text('Stopped'), findsNothing);
    });

    testWidgets('reduceMotionStopped_showsStoppedIndicator_andOverlay', (
      tester,
    ) async {
      final cubit = await _pumpScreen(tester, reduceMotion: true);
      await _push(tester, cubit, _stopped());
      expect(find.text('Stopped'), findsOneWidget);
      // The "Paused — idle" overlay still shows when stopped under reduce-motion.
      expect(find.text(kPausedOverlayText), findsOneWidget);
    });

    testWidgets('reduceMotionOff_showsNoIndicator', (tester) async {
      final cubit = await _pumpScreen(tester, reduceMotion: false);
      await _push(tester, cubit, _moving());
      expect(find.text('Travelling'), findsNothing);
      expect(find.text('Stopped'), findsNothing);
    });
  });

  group('TC-010 (runtime half) screen writes no journey state', () {
    testWidgets('drivingScreenThroughStates_neverMutatesCubitFromScreen', (
      tester,
    ) async {
      final cubit = await _pumpScreen(tester);
      // The screen is a pure consumer: only THIS test (the driver) calls push.
      // After a full active→stopped→active sequence the cubit state is exactly
      // what the driver last pushed — the screen originated no write.
      await _push(tester, cubit, _moving(mode: TravelMode.car));
      await _push(tester, cubit, _stopped(mode: TravelMode.car));
      final last = _moving(mode: TravelMode.bicycle);
      await _push(tester, cubit, last);

      expect(
        cubit.state,
        equals(last),
        reason: 'screen must not emit/mutate state on its own',
      );
    });
  });
}
