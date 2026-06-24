// Deterministic scene-behaviour tests for the journey-view Flame scene.
//
// Drives JourneyGame ONLY via applyState(...) + update(dt) — no real OS, no real
// timers, no wall-clock waits (tests/cases/journey-view.md conventions). Each
// test maps to a TC id. The companion unit tests for the cubit / view-state /
// ticker (TC-005 mapping, M-2) already live under presentation/ and are NOT
// duplicated here. These pump the SCENE directly.
//
// Covers: TC-001, TC-004, TC-006, TC-007, TC-008, TC-012, TC-013, TC-017,
// TC-018, TC-019 (motion-suppression half), TC-024.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';

import 'journey_game_test_harness.dart';

/// Float tolerance for "equal"/"unchanged" scroll comparisons (per conventions).
const double kEps = 1e-6;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'TC-001 active → road/lanes/side-objects/vehicle advance monotonically',
    () {
      test('active_pumps_advanceOffsetMonotonically_andRunVehicle', () {
        final game = buildMotionGame();
        driveActive(game, mode: TravelMode.car);

        final offsets = pumpOffsets(game, frames: 120);

        // Offset advances monotonically (non-decreasing, strictly after ease).
        for (int i = 1; i < offsets.length; i++) {
          expect(
            offsets[i],
            greaterThanOrEqualTo(offsets[i - 1] - kEps),
            reason: 'offset must never go backwards (frame $i)',
          );
        }
        // Net forward motion occurred.
        expect(offsets.last, greaterThan(offsets.first));
        // Vehicle reads as running and the scene is moving at cruise after ease.
        expect(game.isVehicleRunning, isTrue);
        expect(game.scrollVelocity, closeTo(game.cruiseSpeed, kEps));
        // Side objects came alive (parallax stream) and stayed bounded.
        expect(game.liveSideObjectCount, greaterThan(0));
        expect(
          game.liveSideObjectCount,
          lessThanOrEqualTo(game.sideObjectCapacity),
        );
      });
    },
  );

  group('TC-004 scene never moves while last state is idle/paused', () {
    test('stopped_longPumpSequence_zeroNetMotion', () {
      final game = buildMotionGame();
      // Last-emitted state is stopped (idle/paused collapse to this).
      driveStopped(game);

      final offsets = pumpOffsets(game, frames: 600); // long stopped stretch

      // It starts at rest (never moved) so EVERY offset is exactly the initial.
      for (final o in offsets) {
        expect(o, closeTo(offsets.first, kEps));
      }
      expect(game.isStopped, isTrue);
      expect(game.scrollVelocity, 0);
      expect(game.liveSideObjectCount, 0, reason: 'no spawning while frozen');
    });

    test('stoppedAfterNeverActive_offsetStaysZero', () {
      final game = buildMotionGame();
      driveStopped(game);
      pump(game, frames: 300);
      expect(game.roadScrollOffset, 0);
    });
  });

  group('TC-006 / TC-024 bounded ease — no jank, shrinking deltas to zero', () {
    test('activeToStopped_decelDeltasShrinkMonotonically_toExactlyZero', () {
      final game = buildMotionGame(easeDuration: 0.35, cruiseSpeed: 320);
      driveActive(game);
      // Reach steady cruise.
      pump(game, frames: 120);
      final steadyDelta = () {
        final a = game.roadScrollOffset;
        game.update(kFrameDt);
        return game.roadScrollOffset - a;
      }();
      expect(steadyDelta, closeTo(game.cruiseSpeed * kFrameDt, 1e-3));

      // Toggle to stopped and record the deceleration ramp deltas.
      driveStopped(game);
      final deltas = <double>[];
      double prev = game.roadScrollOffset;
      double accumulatedDt = 0;
      int frames = 0;
      while (!game.isStopped && frames < 1000) {
        game.update(kFrameDt);
        accumulatedDt += kFrameDt;
        final d = game.roadScrollOffset - prev;
        deltas.add(d);
        prev = game.roadScrollOffset;
        frames++;
      }

      // (a) ramp is bounded ≤ ~0.5s of accumulated dt.
      expect(accumulatedDt, lessThanOrEqualTo(0.5 + kFrameDt));
      // (b) post-ramp motion is exactly zero.
      expect(game.isStopped, isTrue);
      expect(game.scrollVelocity, 0);
      final afterStopOffset = game.roadScrollOffset;
      pump(game, frames: 30);
      expect(game.roadScrollOffset, closeTo(afterStopOffset, kEps));
      // (c) per-frame deltas shrink monotonically and never spike above steady.
      for (int i = 1; i < deltas.length; i++) {
        expect(
          deltas[i],
          lessThanOrEqualTo(deltas[i - 1] + kEps),
          reason: 'decel delta must not increase (frame $i): $deltas',
        );
      }
      for (final d in deltas) {
        expect(
          d,
          lessThanOrEqualTo(steadyDelta + kEps),
          reason: 'no single-frame jump larger than steady advance (no jank)',
        );
        expect(d, greaterThanOrEqualTo(-kEps), reason: 'never moves backwards');
      }
    });

    test('stoppedToActive_accelFromRest_isSymmetricBoundedRamp', () {
      final game = buildMotionGame(easeDuration: 0.35, cruiseSpeed: 320);
      driveStopped(game);
      pump(game, frames: 5);
      expect(game.scrollVelocity, 0);

      driveActive(game);
      final deltas = <double>[];
      double prev = game.roadScrollOffset;
      double accumulatedDt = 0;
      int frames = 0;
      while (game.isSettling && frames < 1000) {
        game.update(kFrameDt);
        accumulatedDt += kFrameDt;
        deltas.add(game.roadScrollOffset - prev);
        prev = game.roadScrollOffset;
        frames++;
      }
      // Bounded accelerate-from-rest ramp ≤ ~0.5s.
      expect(accumulatedDt, lessThanOrEqualTo(0.5 + kFrameDt));
      // Deltas grow monotonically up to the steady advance (symmetric ramp).
      for (int i = 1; i < deltas.length; i++) {
        expect(deltas[i], greaterThanOrEqualTo(deltas[i - 1] - kEps));
      }
      expect(game.scrollVelocity, closeTo(game.cruiseSpeed, kEps));
    });
  });

  group('TC-007 binary speed — constant while active, zero while stopped', () {
    // The scene takes only `moving`; distanceKm never reaches it, so we assert
    // that two active runs produce IDENTICAL per-frame advance, and a stopped
    // run produces zero. (Guards against scroll speed wired to engine numbers.)
    List<double> activeAdvances() {
      final game = buildMotionGame();
      driveActive(game);
      pump(game, frames: 120); // past ease → steady cruise
      final advances = <double>[];
      double prev = game.roadScrollOffset;
      for (int i = 0; i < 60; i++) {
        game.update(kFrameDt);
        advances.add(game.roadScrollOffset - prev);
        prev = game.roadScrollOffset;
      }
      return advances;
    }

    test('twoActiveRuns_haveIdenticalPerFrameAdvance', () {
      final a = activeAdvances();
      final b = activeAdvances();
      expect(a.length, b.length);
      for (int i = 0; i < a.length; i++) {
        expect(a[i], closeTo(b[i], kEps));
      }
      // And each frame's advance equals the single shared cruise step.
      for (final d in a) {
        expect(d, closeTo(320 * kFrameDt, 1e-3));
      }
    });

    test('stopped_advanceIsExactlyZero', () {
      final game = buildMotionGame();
      driveStopped(game);
      pump(game, frames: 30);
      final before = game.roadScrollOffset;
      game.update(kFrameDt);
      expect(game.roadScrollOffset - before, closeTo(0, kEps));
    });
  });

  group('TC-008 vehicle sprite reflects mode; same speed across skins', () {
    test('mode_selectsMatchingVehicleAsset_andSwapOnNewMode', () {
      final game = buildMotionGame();
      for (final mode in TravelMode.values) {
        driveActive(game, mode: mode);
        expect(game.currentMode, mode);
        // The selected asset path must be the skin path for that mode.
        expect(game.currentVehicleAsset, isNotEmpty);
        // walk vs car must differ (sanity: sprite swaps).
      }
      driveActive(game, mode: TravelMode.walk);
      final walkAsset = game.currentVehicleAsset;
      driveActive(game, mode: TravelMode.car);
      final carAsset = game.currentVehicleAsset;
      expect(walkAsset, isNot(equals(carAsset)));
    });

    test('scrollAdvanceIdenticalAcrossModes_cosmeticOnly', () {
      List<double> advancesFor(TravelMode mode) {
        final game = buildMotionGame();
        driveActive(game, mode: mode);
        pump(game, frames: 120);
        final out = <double>[];
        double prev = game.roadScrollOffset;
        for (int i = 0; i < 30; i++) {
          game.update(kFrameDt);
          out.add(game.roadScrollOffset - prev);
          prev = game.roadScrollOffset;
        }
        return out;
      }

      final walk = advancesFor(TravelMode.walk);
      final bike = advancesFor(TravelMode.bicycle);
      final car = advancesFor(TravelMode.car);
      for (int i = 0; i < walk.length; i++) {
        expect(walk[i], closeTo(bike[i], kEps));
        expect(walk[i], closeTo(car[i], kEps));
      }
    });
  });

  group('TC-012 day/night tint cosmetic — motion identical across clocks', () {
    test('tintDiffersByTimeOfDay_butScrollAdvanceIdentical', () {
      List<double> advancesAtHour(double hour) {
        final game = buildMotionGame();
        game.applyState(
          moving: true,
          mode: TravelMode.motorbike,
          reduceMotion: false,
          timeOfDayHours: hour,
        );
        pump(game, frames: 120);
        final out = <double>[];
        double prev = game.roadScrollOffset;
        for (int i = 0; i < 30; i++) {
          game.update(kFrameDt);
          out.add(game.roadScrollOffset - prev);
          prev = game.roadScrollOffset;
        }
        return out;
      }

      final dayGame = buildMotionGame();
      dayGame.applyState(
        moving: true,
        mode: TravelMode.motorbike,
        reduceMotion: false,
        timeOfDayHours: 12, // noon
      );
      final nightGame = buildMotionGame();
      nightGame.applyState(
        moving: true,
        mode: TravelMode.motorbike,
        reduceMotion: false,
        timeOfDayHours: 0, // midnight
      );
      // (a) tint differs by injected time-of-day.
      expect(dayGame.currentTint, isNot(equals(nightGame.currentTint)));

      // (b) motion identical across day vs night.
      final day = advancesAtHour(12);
      final night = advancesAtHour(0);
      for (int i = 0; i < day.length; i++) {
        expect(day[i], closeTo(night[i], kEps));
      }
    });

    test('tintIsStateIndependent_sameTintWhenActiveOrStopped', () {
      final active = buildMotionGame();
      active.applyState(
        moving: true,
        mode: TravelMode.motorbike,
        reduceMotion: false,
        timeOfDayHours: 21,
      );
      final stopped = buildMotionGame();
      stopped.applyState(
        moving: false,
        mode: TravelMode.motorbike,
        reduceMotion: false,
        timeOfDayHours: 21,
      );
      // Tint is ambient (function of hour only), not bound to motion state.
      expect(active.currentTint, equals(stopped.currentTint));
    });
  });

  group('TC-013 first-frame / pre-state + stopped → parked, zero motion', () {
    test('beforeAnyApplyState_hasNotReceivedState_andDoesNotMove', () {
      final game = buildMotionGame();
      expect(game.hasReceivedState, isFalse);
      final offsets = pumpOffsets(game, frames: 120);
      for (final o in offsets) {
        expect(o, closeTo(0, kEps));
      }
      expect(game.isStopped, isTrue);
      expect(game.isVehicleRunning, isFalse);
    });

    test('afterStoppedEmit_hasReceivedState_butStillNoMotion', () {
      final game = buildMotionGame();
      driveStopped(game);
      expect(game.hasReceivedState, isTrue);
      final offsets = pumpOffsets(game, frames: 120);
      for (final o in offsets) {
        expect(o, closeTo(0, kEps));
      }
    });
  });

  group('TC-017 bounded side-object pool — live count plateaus', () {
    test('longActiveSession_liveCountStaysBoundedByCapacity', () {
      final game = buildMotionGame(sideObjectCapacity: 24);
      driveActive(game);
      int maxSeen = 0;
      // Pump a very long active session (~30s at 60fps).
      for (int i = 0; i < 1800; i++) {
        game.update(kFrameDt);
        if (game.liveSideObjectCount > maxSeen) {
          maxSeen = game.liveSideObjectCount;
        }
        expect(
          game.liveSideObjectCount,
          lessThanOrEqualTo(game.sideObjectCapacity),
          reason: 'pool must never exceed capacity (frame $i)',
        );
      }
      // It must reach a non-trivial steady population (recycling, not zero).
      expect(maxSeen, greaterThan(0));
      // And it plateaus — the final count is also within capacity.
      expect(
        game.liveSideObjectCount,
        lessThanOrEqualTo(game.sideObjectCapacity),
      );
    });
  });

  group(
    'TC-018 suspend when not visible — pauseEngine stops motion advance',
    () {
      test('pausedEngine_doesNotAdvanceOffset_resumeRestores', () {
        final game = buildMotionGame();
        driveActive(game);
        pump(game, frames: 60);
        final atPause = game.roadScrollOffset;

        game.pauseEngine();
        for (int i = 0; i < 120; i++) {
          game.update(kFrameDt);
        }
        // While paused (off-screen) the scene does no per-frame motion work.
        expect(game.roadScrollOffset, closeTo(atPause, kEps));

        game.resumeEngine();
        final beforeResume = game.roadScrollOffset;
        pump(game, frames: 10);
        // Resumes per current state (still active) → motion continues.
        expect(game.roadScrollOffset, greaterThan(beforeResume));
      });
    },
  );

  group('TC-019 reduce-motion suppresses scroll, still distinguishes state', () {
    // The scene half: with reduceMotion true the offset never advances even when
    // moving. The screen's textual indicator half is covered in the screen test.
    test('reduceMotionActive_offsetDoesNotScroll', () {
      final game = buildMotionGame();
      game.applyState(
        moving: true,
        mode: TravelMode.motorbike,
        reduceMotion: true,
        timeOfDayHours: 12,
      );
      final offsets = pumpOffsets(game, frames: 120);
      for (final o in offsets) {
        expect(o, closeTo(0, kEps), reason: 'reduce-motion suppresses scroll');
      }
      expect(game.reduceMotion, isTrue);
      // Vehicle bob is frozen (velocity 0) but the scene still "knows" moving was
      // requested — state is conveyed by the screen overlay/indicator, not motion.
      expect(game.scrollVelocity, 0);
    });

    test('reduceMotionOff_scrollsNormally', () {
      final game = buildMotionGame();
      driveActive(game, reduceMotion: false);
      pump(game, frames: 60);
      expect(game.roadScrollOffset, greaterThan(0));
    });
  });
}
