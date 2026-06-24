// Deterministic unit tests for the pure JourneyViewState value object.
//
// Scope: the flattened, read-only view snapshot only — no widgets, no Flame, no
// timers, no DateTime.now(). Every value is supplied directly. Tests cover the
// engine-state -> JourneyMotion mapping (AC-2/AC-3), the overlay gating rule
// (AC-13/TC-013), and Equatable equality.
//
// Conventions mirror test/features/journey/domain/journey_engine_test.dart:
// group by behaviour, name tests as <subject>_<condition>_<expected>, cite the
// AC/TC in comments.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/journey_state.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/journey/presentation/journey_view_state.dart';

void main() {
  group('JourneyViewState — initial / pre-state default (AC-13, TC-013)', () {
    test('initial_isStoppedMotorbikeZero_withNoRealState', () {
      const state = JourneyViewState.initial();

      expect(state.motion, JourneyMotion.stopped);
      expect(state.mode, TravelMode.motorbike);
      expect(state.distanceKm, 0);
      expect(state.hasRealState, isFalse);
    });

    test('initial_isParkedButShowsNoPausedOverlay', () {
      // TC-013: the first frame is parked WITHOUT the "Paused — idle" overlay,
      // because no real engine state has been observed yet.
      const state = JourneyViewState.initial();

      expect(state.motion, JourneyMotion.stopped);
      expect(state.showPausedOverlay, isFalse);
    });
  });

  group('JourneyViewState — fromEngine motion mapping (AC-2/AC-3, TC-005)', () {
    test('fromEngine_active_mapsToMoving', () {
      final state = JourneyViewState.fromEngine(
        JourneyState.active,
        TravelMode.car,
        12.5,
      );

      expect(state.motion, JourneyMotion.moving);
    });

    test('fromEngine_idle_mapsToStopped', () {
      // AC-2/AC-3: idle collapses to stopped (idle ≡ paused in the view).
      final state = JourneyViewState.fromEngine(
        JourneyState.idle,
        TravelMode.motorbike,
        3,
      );

      expect(state.motion, JourneyMotion.stopped);
    });

    test('fromEngine_paused_mapsToStopped', () {
      // AC-2/AC-3: paused collapses to stopped — identical view to idle in v1.
      final state = JourneyViewState.fromEngine(
        JourneyState.paused,
        TravelMode.ship,
        7,
      );

      expect(state.motion, JourneyMotion.stopped);
    });
  });

  group('JourneyViewState — fromEngine carries snapshot values', () {
    test('fromEngine_copiesModeAndDistance_andMarksRealState', () {
      final state = JourneyViewState.fromEngine(
        JourneyState.active,
        TravelMode.bicycle,
        42.0,
      );

      expect(state.mode, TravelMode.bicycle);
      expect(state.distanceKm, 42.0);
      expect(state.hasRealState, isTrue);
    });
  });

  group('JourneyViewState — showPausedOverlay gating (AC-13, TC-013)', () {
    test('overlay_isFalse_whenActive', () {
      // Moving real state never shows the paused overlay.
      final state = JourneyViewState.fromEngine(
        JourneyState.active,
        TravelMode.motorbike,
        1,
      );

      expect(state.showPausedOverlay, isFalse);
    });

    test('overlay_isTrue_whenIdleRealState', () {
      // A real idle state is parked AND shows the overlay (AC-2).
      final state = JourneyViewState.fromEngine(
        JourneyState.idle,
        TravelMode.motorbike,
        1,
      );

      expect(state.showPausedOverlay, isTrue);
    });

    test('overlay_isTrue_whenPausedRealState', () {
      // A real paused state is parked AND shows the overlay (AC-3).
      final state = JourneyViewState.fromEngine(
        JourneyState.paused,
        TravelMode.motorbike,
        1,
      );

      expect(state.showPausedOverlay, isTrue);
    });

    test('overlay_isFalse_forInitialStoppedFrame', () {
      // The gate requires hasRealState: a stopped pre-state shows no overlay.
      const state = JourneyViewState.initial();

      expect(state.showPausedOverlay, isFalse);
    });

    test('overlay_isFalse_whenStoppedButNoRealState_explicitConstruction', () {
      // Defensive: stopped + hasRealState=false must gate the overlay off even
      // when constructed directly (the rule is motion==stopped AND hasRealState).
      const state = JourneyViewState(
        motion: JourneyMotion.stopped,
        mode: TravelMode.motorbike,
        distanceKm: 0,
        hasRealState: false,
      );

      expect(state.showPausedOverlay, isFalse);
    });
  });

  group('JourneyViewState — Equatable equality', () {
    test('equalValues_areEqual', () {
      const a = JourneyViewState(
        motion: JourneyMotion.moving,
        mode: TravelMode.car,
        distanceKm: 5.5,
        hasRealState: true,
      );
      const b = JourneyViewState(
        motion: JourneyMotion.moving,
        mode: TravelMode.car,
        distanceKm: 5.5,
        hasRealState: true,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('differingMotion_areNotEqual', () {
      const a = JourneyViewState(
        motion: JourneyMotion.moving,
        mode: TravelMode.car,
        distanceKm: 5.5,
        hasRealState: true,
      );
      const b = JourneyViewState(
        motion: JourneyMotion.stopped,
        mode: TravelMode.car,
        distanceKm: 5.5,
        hasRealState: true,
      );

      expect(a, isNot(equals(b)));
    });

    test('differingDistance_areNotEqual', () {
      const a = JourneyViewState(
        motion: JourneyMotion.moving,
        mode: TravelMode.car,
        distanceKm: 5.5,
        hasRealState: true,
      );
      const b = JourneyViewState(
        motion: JourneyMotion.moving,
        mode: TravelMode.car,
        distanceKm: 6.0,
        hasRealState: true,
      );

      expect(a, isNot(equals(b)));
    });

    test('differingHasRealState_areNotEqual', () {
      // The pre-state initial differs from an otherwise-identical real stopped
      // state precisely on hasRealState (which gates the overlay).
      const initial = JourneyViewState.initial();
      const realStopped = JourneyViewState(
        motion: JourneyMotion.stopped,
        mode: TravelMode.motorbike,
        distanceKm: 0,
        hasRealState: true,
      );

      expect(initial, isNot(equals(realStopped)));
    });
  });
}
