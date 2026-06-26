// Deterministic scene tests for journey-scene-v2 (the scene-level half).
//
// Drives JourneyGame ONLY via applyState(...) + update(dt) — no real OS, no real
// timers, no wall-clock waits (tests/cases/journey-scene-v2.md conventions).
// The per-surface visibility legs (AC-3/AC-4/AC-5) live in the app_shell + the
// integration tests against MockWindowVisibilityController; this file covers the
// pure scene math: AC-1 decoupling, AC-6 winding road, AC-7 even spacing, AC-8
// richer scenery, AC-9 reduce-motion override, AC-10 idle parks.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_assets.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_game.dart';
import 'package:focus_journey/features/journey/presentation/game/scene_motion.dart';
import 'package:focus_journey/features/journey/presentation/game/side_object_pool.dart';

import 'journey_game_test_harness.dart';

const double kEps = 1e-6;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TC-001 rendered scroll rate is ~0.33x of the v1 baseline (AC-1)', () {
    test('production_default_isV2PlaybackRate_withinBand', () {
      // The PRODUCTION game (no explicit cruiseSpeed) renders at the v2 rate.
      final game = JourneyGame();
      game.onGameResize(kTestViewport);
      driveActive(game);
      // Reach steady cruise (past the ease).
      pump(game, frames: 120);

      // Measure rendered scroll delta per injected second over a known window.
      const int frames = 600; // 10 injected seconds at 60fps
      final double before = game.roadScrollOffset;
      pump(game, frames: frames);
      final double elapsed = frames * kFrameDt;
      final double ratePerSec = (game.roadScrollOffset - before) / elapsed;

      // Factor against the pinned v1 baseline.
      final double factor = ratePerSec / kV1CruiseSpeed;
      expect(
        factor,
        inInclusiveRange(0.30, 0.36),
        reason:
            'rendered rate must be ~0.33x of v1 ($kV1CruiseSpeed px/s); '
            'got factor $factor (rate $ratePerSec px/s)',
      );
      // And it equals the pinned constant exactly at steady cruise.
      expect(game.renderedCruiseSpeed, closeTo(kV2CruiseSpeed, kEps));
    });

    test('v2_isAboutThreeTimesSlowerThanV1_sameElapsed', () {
      JourneyGame mk(double speed) {
        final g = JourneyGame(cruiseSpeed: speed);
        g.onGameResize(kTestViewport);
        driveActive(g);
        pump(g, frames: 120); // reach cruise
        return g;
      }

      final v1 = mk(kV1CruiseSpeed);
      final v2 = mk(kV2CruiseSpeed);
      double advance(JourneyGame g) {
        final a = g.roadScrollOffset;
        pump(g, frames: 300);
        return g.roadScrollOffset - a;
      }

      final dv1 = advance(v1);
      final dv2 = advance(v2);
      // v2 covers ~0.33x the distance v1 does over the same injected time.
      expect(dv2 / dv1, inInclusiveRange(0.30, 0.36));
    });
  });

  group(
    'TC-002/AC-2 scroll rate is one-way — pinned constants are render-only',
    () {
      test('v1_and_v2_cruiseConstants_areRenderLayerOnly', () {
        // kV1CruiseSpeed / kV2CruiseSpeed live in scene_motion (presentation).
        // The engine has no reference to them (verified by the separation static
        // test); here we assert the factor relationship is exactly as pinned.
        expect(
          kV2CruiseSpeed,
          closeTo(kV1CruiseSpeed * kV2PlaybackFactor, kEps),
        );
        expect(kV2PlaybackFactor, closeTo(0.33, kEps));
      });
    },
  );

  group('TC-007 the road visibly curves; lanes/objects follow (AC-6)', () {
    test('centreLineOffset_isNonConstantOverDepth_andBendsBothWays', () {
      final game = buildMotionGame(cruiseSpeed: kV2CruiseSpeed);
      driveActive(game);
      // Sample the centre-line at several depths and across a long scroll cycle.
      final Set<double> nearOffsets = <double>{};
      double minOffset = double.infinity;
      double maxOffset = -double.infinity;
      // Long enough that the meander crosses both signs (the integrated heading
      // sweeps past pi, so the bounded sine swings negative as well).
      for (int step = 0; step < 2000; step++) {
        pump(game, frames: 6);
        final double near = game.centreLineOffsetAt(1.0);
        nearOffsets.add(double.parse(near.toStringAsFixed(2)));
        if (near < minOffset) minOffset = near;
        if (near > maxOffset) maxOffset = near;
      }
      // Non-constant over the scroll phase (rejects dead-straight).
      expect(nearOffsets.length, greaterThan(5));
      // Bends BOTH left (negative) and right (positive).
      expect(minOffset, lessThan(-1.0), reason: 'curves left somewhere');
      expect(maxOffset, greaterThan(1.0), reason: 'curves right somewhere');
    });

    test('horizon_offset_isTiny_trapezoidReadPreserved', () {
      final game = buildMotionGame(cruiseSpeed: kV2CruiseSpeed);
      driveActive(game);
      pump(game, frames: 200);
      // At the horizon (t→0) the curve offset tucks to ~0 so the trapezoid
      // narrowing read is preserved; near the camera it is large.
      final double atHorizon = game.centreLineOffsetAt(0.0).abs();
      final double atNear = game.centreLineOffsetAt(1.0).abs();
      expect(atHorizon, lessThan(0.001));
      // The near offset is meaningfully larger than the horizon offset.
      expect(atNear, greaterThan(atHorizon));
    });

    test('curveFrozen_whenStopped', () {
      final game = buildMotionGame(cruiseSpeed: kV2CruiseSpeed);
      driveStopped(game);
      pump(game, frames: 100);
      final double a = game.centreLineOffsetAt(1.0);
      pump(game, frames: 100);
      final double b = game.centreLineOffsetAt(1.0);
      // Stopped → scroll frozen → curve phase frozen.
      expect(b, closeTo(a, kEps));
    });
  });

  group('TC-008 even spacing along the curve, variance <= 20% of mean (AC-7)', () {
    // Computes consecutive arc-length gaps between rendered centre-line points
    // (each `(world, lateral)`), measured ALONG the curve — the longitudinal
    // world delta combined with the lateral centre-line delta, i.e. the true
    // 2D path length the road follows between two objects, not screen-space.
    List<double> arcGaps(List<({double world, double lateral})> pts) {
      final List<double> gaps = <double>[];
      for (int i = 1; i < pts.length; i++) {
        final double dWorld = pts[i].world - pts[i - 1].world;
        final double dLat = pts[i].lateral - pts[i - 1].lateral;
        gaps.add(math.sqrt(dWorld * dWorld + dLat * dLat));
      }
      return gaps;
    }

    test('renderedArcLengthGaps_alongTheCurve_betweenLiveObjects_withinBound', () {
      // S1: measure the REAL spacing of consecutive LIVE objects as rendered
      // along the curving centre-line — NOT the fixed spawn cadence. Each
      // object's centre-line point combines its longitudinal world position with
      // the road's lateral bend there (RoadGeometry.lateralAt scaled by the
      // near-camera curve amplitude), so the arc-length gap absorbs the curve.
      // A sharp enough bend between two objects would push a gap past ±20% and
      // FAIL this — so it is a genuine guard, not the always-true cadence.
      //
      // A large pool keeps many objects live at once across a full cycle.
      final game = buildMotionGame(
        cruiseSpeed: kV2CruiseSpeed,
        sideObjectCapacity: 64,
      );
      driveActive(game);
      pump(game, frames: 120); // reach steady cruise, fill the pool.

      // Sample many frames across a long scroll cycle (the curve meanders, so
      // assert the bound holds at every sampled phase, including sharp bends).
      double worstRatio = 0;
      int framesChecked = 0;
      for (int frame = 0; frame < 600; frame++) {
        pump(game, frames: 3);
        final pts = game.liveCentreLinePoints;
        if (pts.length < 6) {
          continue; // need enough live objects for a meaningful measure
        }
        final List<double> gaps = arcGaps(pts);
        final double mean = gaps.reduce((a, b) => a + b) / gaps.length;
        expect(mean, greaterThan(0));
        for (final g in gaps) {
          final double ratio = (g - mean).abs() / mean;
          if (ratio > worstRatio) worstRatio = ratio;
          expect(
            (g - mean).abs(),
            lessThanOrEqualTo(0.20 * mean + kEps),
            reason:
                'arc-length spacing along the curve must be <= 20% of mean '
                '($mean) at frame ${frame * 3}; gap $g in $gaps '
                '(worst ratio so far $worstRatio)',
          );
        }
        framesChecked++;
      }
      // Guard: we actually exercised the spacing path on many frames, and the
      // lateral curve term genuinely contributed (worstRatio > 0 ⇒ the bend
      // perturbs the gap, so this is not the always-zero spawn-cadence check).
      expect(
        framesChecked,
        greaterThan(50),
        reason: 'too few frames had enough live objects to measure spacing',
      );
      expect(
        worstRatio,
        greaterThan(0),
        reason:
            'the curve must perturb the arc-length gap (else this degenerates '
            'to the vacuous spawn-cadence check)',
      );
    });

    test('spawnCadence_isArcLengthAware_documentsTheEvenSource', () {
      // journey-dynamic-curve AC-6: the spawn cadence is now ARC-LENGTH-aware
      // (equal arc-length increments along the curving centre-line), not equal
      // longitudinal distance. So the LONGITUDINAL gaps between spawns are no
      // longer all exactly spawnEveryWorldPx — where the road leans, the
      // longitudinal step shrinks so the ARC-LENGTH step stays constant. This
      // documents that: longitudinal gaps cluster just below the arc target
      // (arc length ≥ longitudinal distance), and their mean is close to (and
      // never exceeds) the arc target. The behavioural even-arc-length guard is
      // the rendered-arc-length test above (over liveCentreLinePoints).
      final game = buildMotionGame(
        cruiseSpeed: kV2CruiseSpeed,
        sideObjectCapacity: 64,
      );
      driveActive(game);
      final List<double> spawnDistances = <double>[];
      double lastSeenMax = -1;
      for (int i = 0; i < 4000; i++) {
        game.update(kFrameDt);
        final live = game.liveSpawnDistances;
        if (live.isNotEmpty && live.last > lastSeenMax) {
          for (final d in live) {
            if (d > lastSeenMax) spawnDistances.add(d);
          }
          lastSeenMax = live.last;
        }
      }
      spawnDistances.sort();
      expect(spawnDistances.length, greaterThan(10));
      final List<double> gaps = <double>[];
      for (int i = 1; i < spawnDistances.length; i++) {
        gaps.add(spawnDistances[i] - spawnDistances[i - 1]);
      }
      final double mean = gaps.reduce((a, b) => a + b) / gaps.length;
      // Longitudinal mean gap is at-or-below the arc target (since arc ≥
      // longitudinal), and close to it (the bend is gentle relative to 220px).
      expect(mean, lessThanOrEqualTo(game.spawnEveryWorldPx + kEps));
      expect(mean, closeTo(game.spawnEveryWorldPx, 12.0));
    });
  });

  group('TC-009 richer scenery families are surfaced (AC-8, spec #11)', () {
    // The scenery families spec #11 names, mapped to their SideObjectKind
    // representatives. The mountain/hills bands are far-background parallax
    // layers (not pooled side objects); they are asserted separately below via
    // the asset manifest.
    const Map<String, List<SideObjectKind>> families =
        <String, List<SideObjectKind>>{
          'forest': <SideObjectKind>[
            SideObjectKind.pine,
            SideObjectKind.treeRound,
            SideObjectKind.treeTall,
            SideObjectKind.sapling,
            SideObjectKind.palm,
          ],
          'countryside': <SideObjectKind>[
            SideObjectKind.bush,
            SideObjectKind.bushAlt,
            SideObjectKind.fence,
            SideObjectKind.fenceIron,
          ],
          'city': <SideObjectKind>[
            SideObjectKind.houseGable,
            SideObjectKind.houseSmall,
            SideObjectKind.houseGableAlt,
            SideObjectKind.houseSmallAlt,
          ],
          'people': <SideObjectKind>[
            SideObjectKind.person,
            SideObjectKind.personWave,
            SideObjectKind.personWoman,
            SideObjectKind.personWomanWave,
          ],
        };

    test('everyNamedFamily_andAllKinds_areReachableOverAScrollCycle', () {
      final game = buildMotionGame(
        cruiseSpeed: kV2CruiseSpeed,
        sideObjectCapacity: 64,
      );
      driveActive(game);
      final Set<SideObjectKind> seen = <SideObjectKind>{};
      for (int i = 0; i < 6000; i++) {
        game.update(kFrameDt);
        seen.addAll(game.liveSideObjectKinds);
      }

      // Every named family has at least one representative surfaced.
      families.forEach((String family, List<SideObjectKind> kinds) {
        expect(
          kinds.any(seen.contains),
          isTrue,
          reason: 'no "$family" scenery surfaced over a cycle; saw $seen',
        );
      });

      // The spawn cadence is (s*11) % 21 and gcd(11,21)==1, so it cycles through
      // every kind — assert ALL SideObjectKinds are reachable (no kind is
      // dead/unreachable). The P1 dead-weight fix grew the enum 16 -> 21 with 5
      // net-new variety kinds and switched the stride 7 -> 11 (gcd(7,21)==7 would
      // have stranded all but 3 kinds).
      expect(
        seen,
        containsAll(SideObjectKind.values),
        reason:
            'every SideObjectKind must be reachable; missing '
            '${SideObjectKind.values.toSet().difference(seen)}',
      );
    });

    test('mountainAndHills_backgroundBands_areDeclaredScenery', () {
      // The mountain/hills bands are drawn as far-background parallax layers
      // (paintFarBackground), not pooled side objects — so they are surfaced via
      // the scene's asset manifest rather than liveSideObjectKinds.
      expect(JourneyAssets.all, contains(JourneyAssets.mountainRange));
      expect(JourneyAssets.all, contains(JourneyAssets.hills));
    });
  });

  group('TC-010 reduce-motion OVERRIDES the slower scroll (AC-9)', () {
    test('reduceMotionActive_noScroll_evenAtV2Rate', () {
      final game = buildMotionGame(cruiseSpeed: kV2CruiseSpeed);
      game.applyState(
        moving: true,
        mode: TravelMode.motorbike,
        reduceMotion: true,
        timeOfDayHours: 12,
      );
      final offsets = pumpOffsets(game, frames: 300);
      for (final o in offsets) {
        expect(o, closeTo(0, kEps), reason: 'reduce-motion suppresses scroll');
      }
      // No scenery streams (frozen) and no curve phase advance.
      expect(game.liveSideObjectCount, 0);
      expect(game.scrollVelocity, 0);
    });

    test('reduceMotion_stillDistinguishesActiveFromStopped_viaPose', () {
      final active = buildMotionGame(cruiseSpeed: kV2CruiseSpeed);
      active.applyState(
        moving: true,
        mode: TravelMode.motorbike,
        reduceMotion: true,
        timeOfDayHours: 12,
      );
      final stopped = buildMotionGame(cruiseSpeed: kV2CruiseSpeed);
      stopped.applyState(
        moving: false,
        mode: TravelMode.motorbike,
        reduceMotion: true,
        timeOfDayHours: 12,
      );
      // Neither scrolls (reduce-motion), but the scene knows moving was
      // requested — the screen overlay/indicator conveys it (asserted in the
      // screen widget test). Both are frozen at the offset level.
      pump(active, frames: 30);
      pump(stopped, frames: 30);
      expect(active.roadScrollOffset, closeTo(0, kEps));
      expect(stopped.roadScrollOffset, closeTo(0, kEps));
    });
  });

  group('TC-011 idle/paused still parks — independent of #3/#5 (AC-10)', () {
    test('idle_freezesRoadObjectsAndVehicle_atV2Rate', () {
      final game = buildMotionGame(cruiseSpeed: kV2CruiseSpeed);
      // Active first so there is something to freeze.
      driveActive(game);
      pump(game, frames: 120);
      expect(game.roadScrollOffset, greaterThan(0));

      // Then idle/stopped → eases to a stop and parks.
      driveStopped(game);
      // Settle the ease.
      pump(game, frames: 60);
      final double parked = game.roadScrollOffset;
      pump(game, frames: 200);
      // Road frozen, vehicle parked.
      expect(game.roadScrollOffset, closeTo(parked, kEps));
      expect(game.isVehicleRunning, isFalse);
      expect(game.scrollVelocity, 0);
    });
  });
}
