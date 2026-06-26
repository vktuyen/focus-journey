// NFR-1 hot-path runtime proxy for journey-cockpit-lean (TC-517 runtime leg).
//
// Authored by test-script-author from tests/cases/journey-cockpit-lean.md. The
// static no-allocation / no-loop source inspection is in
// journey_cockpit_lean_separation_static_test.dart; this is the RUNTIME proxy:
//   (a) the per-frame angle-update WORK does not grow with how long the session
//       has scrolled — the applied angle at a tiny roadScrollOffset and at a
//       huge one (after a long session) does the same bounded work + lands in
//       the same bounded angle range (the geometry slope is an O(1) closed form,
//       so the update is constant-cost regardless of worldDistance), and
//   (b) the composited cockpit-frame draw COUNT is stable across a long leaning
//       run (no per-frame growth that a leak/allocation would cause), with the
//       inherited bounded-pool guard re-checked WITH the lean active.
//
// Deterministic proxy for NFR-1; sustained >=30fps on both surfaces is the
// DEVICE leg TC-M-NF1 (manual checklist).
//
// NO real OS / timers / wall-clock — applyState + update(dt) only.

import 'dart:ui';

import 'package:flame/game.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/journey/presentation/game/scene_motion.dart';

import 'journey_game_test_harness.dart';

final Vector2 _viewport = Vector2(1280, 720);
const double _maxRollCap = 0.0523599;

class _CountingCanvas implements Canvas {
  int draws = 0;
  @override
  void noSuchMethod(Invocation invocation) {
    if (invocation.memberName.toString().contains('draw')) draws++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TC-517 lean per-frame angle update is constant-cost (NFR-1)', () {
    for (final mode in <TravelMode>[TravelMode.car, TravelMode.motorbike]) {
      test('${mode.name}_angleStaysBounded_atTinyAndHugeScrollOffset', () {
        // The angle update reads the geometry's O(1) closed-form slope, so the
        // applied angle stays in the SAME bounded range (|angle| <= cap) whether
        // worldDistance is tiny or enormous — the work does not grow with it.
        final game = buildMotionGame(size: _viewport, cruiseSpeed: kV2CruiseSpeed);
        driveActive(game, mode: mode);
        pump(game, frames: 200); // reach cruise

        // EARLY window (small worldDistance): sample the angle range.
        double earlyMax = 0;
        for (int i = 0; i < 4000; i++) {
          game.update(kFrameDt);
          final double a = game.appliedLeanAngle.abs();
          if (a > earlyMax) earlyMax = a;
          expect(a, lessThanOrEqualTo(_maxRollCap + 1e-9));
        }
        expect(
          game.roadScrollOffset,
          greaterThan(0),
          reason: 'sanity: the session has scrolled',
        );

        // Skip FAR ahead so worldDistance is enormous (a long session). At the
        // v2 cruise rate (~105 px/s) ~60k frames covers ~100k px — many heading
        // cycles past the early window, exercising the closed-form geometry at a
        // large worldDistance.
        pump(game, frames: 60000);
        final double hugeOffset = game.roadScrollOffset;
        expect(hugeOffset, greaterThan(90000),
            reason: 'sanity: worldDistance is now large (long session)');

        // LATE window (huge worldDistance): the angle is STILL bounded by the
        // same cap and still actually leans — no growth/decay/blow-up from a
        // distance-dependent cost.
        double lateMax = 0;
        for (int i = 0; i < 4000; i++) {
          game.update(kFrameDt);
          final double a = game.appliedLeanAngle.abs();
          if (a > lateMax) lateMax = a;
          expect(
            a,
            lessThanOrEqualTo(_maxRollCap + 1e-9),
            reason:
                'NFR-1: |angle| must stay bounded by the cap even at huge '
                'worldDistance (constant-cost update, no growth)',
          );
        }
        // The lean is still alive at huge distance (the cost did not collapse it).
        expect(lateMax, greaterThan(0.001),
            reason: 'NFR-1: the lean must still operate at huge worldDistance');
        // Both windows reach comparable magnitudes (the bend repeats cyclically);
        // we reject collapse toward 0 or explosion past the cap.
        expect(lateMax, greaterThan(earlyMax * 0.25));
      });
    }
  });

  group('TC-517 composited leaning draw work is bounded/stable (NFR-1)', () {
    for (final mode in <TravelMode>[TravelMode.car, TravelMode.motorbike]) {
      test('${mode.name}_drawCount_stable_andPoolBounded_overLongLeaningRun',
          () async {
        final game = await loadJourneyGame(size: _viewport);
        game.applyState(
          moving: true,
          mode: mode,
          reduceMotion: false, // lean ACTIVE throughout
          timeOfDayHours: 12,
        );
        pump(game, frames: 300); // fill the bounded pool, reach cruise

        int countDraws() {
          final c = _CountingCanvas();
          game.render(c);
          return c.draws;
        }

        final int first = countDraws();
        int maxSeen = first;
        int minSeen = first;
        for (int i = 0; i < 400; i++) {
          pump(game, frames: 5);
          final int n = countDraws();
          if (n > maxSeen) maxSeen = n;
          if (n < minSeen) minSeen = n;
          // Inherited bounded-pool guard, re-checked WITH the lean active.
          expect(
            game.liveSideObjectCount,
            lessThanOrEqualTo(game.sideObjectCapacity),
            reason: 'NFR-1: bounded pool must still hold with the lean active',
          );
          // The lean is genuinely active across the run.
          // (It is non-zero at most curving frames; not asserted every frame to
          // allow the rare near-straight inflection.)
        }
        // The composited draw count stays bounded with the lean active — a
        // per-frame cockpit/lean leak would grow it without bound.
        expect(
          maxSeen - minSeen,
          lessThanOrEqualTo(game.sideObjectCapacity),
          reason:
              'NFR-1: leaning draw count must stay bounded (min=$minSeen '
              'max=$maxSeen); a per-frame lean leak would grow it unboundedly',
        );
      });
    }
  });
}
