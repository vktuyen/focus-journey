// journey-scene-art-v3 two-surface wiring + headline mock-driven long-journey
// smoke. One case per scenario; names carry TC-ID + AC-IDs for traceability.
//
// ADR-0003: the full window and the always-on-top mini-window PiP render the
// SAME JourneyGame instance, so the re-sourced art lands on BOTH by construction
// — modelled by rendering the one shared game at the full size and the sized-down
// PiP size (onGameResize → render), exactly as the per-surface render path does.
//
// NO real OS, NO real timers, NO wall-clock waits — driven via applyState(...) +
// update(dt). The qualitative look (cohesion, beach look, animal cohesion,
// PiP-size look) is the manual gate TC-M-SPIKE; on-device fps is TC-M-NF1.
//
// Covers:
//   TC-304 (AC-4)             — re-sourced art on BOTH surfaces, no divergence
//   TC-319 (AC-3/4/5/6/7)     — long mock journey lands family + beach band +
//                               animals on both surfaces; spacing cadence holds
//
// Runs headless under `flutter test` and on a desktop device:
//   fvm flutter test integration_test/journey_scene_art_v3_smoke_test.dart
//   fvm flutter test integration_test/journey_scene_art_v3_smoke_test.dart -d macos

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_game.dart';
import 'package:focus_journey/features/journey/presentation/game/side_object_pool.dart';
import 'package:integration_test/integration_test.dart';

/// Full-window vs sized-down PiP viewports (the two surfaces share one game).
final Vector2 kFullViewport = Vector2(1280, 800);
final Vector2 kPipViewport = Vector2(360, 220);

const double kFrameDt = 1 / 60;

const List<SideObjectKind> kAnimalKinds = <SideObjectKind>[
  SideObjectKind.waterBuffalo,
  SideObjectKind.dog,
  SideObjectKind.chicken,
  SideObjectKind.bird,
];

/// A canvas that records each drawImageRect's source-image identity so we can
/// capture the SET of distinct images requested per surface (the "no per-surface
/// asset divergence" assertion). Identity is the Image instance (the shared game
/// resolves each path to one cached Image).
class _ImageSetCanvas implements Canvas {
  final Set<int> imageIds = <int>{};
  int imageRectCount = 0;

  @override
  void drawImageRect(Image image, Rect src, Rect dst, Paint paint) {
    imageRectCount++;
    imageIds.add(identityHashCode(image));
  }

  @override
  void noSuchMethod(Invocation invocation) {}
}

/// Renders [game] at [size] and returns the distinct image identities drawn.
Set<int> imagesDrawnAt(JourneyGame game, Vector2 size) {
  game.onGameResize(size);
  final canvas = _ImageSetCanvas();
  game.render(canvas);
  return canvas.imageIds;
}

/// Loads a sprite-backed game, swallowing ONLY Flame's expected orphan
/// "Unable to load asset" rejection for the intentionally-absent procedural
/// cockpit shapes. Mirrors the unit harness; any other zone error re-throws.
Future<JourneyGame> loadGame() async {
  late JourneyGame game;
  final Completer<void> done = Completer<void>();
  Object? unexpected;
  runZonedGuarded(
    () async {
      game = JourneyGame();
      await game.onLoad();
      game.onGameResize(kFullViewport);
      if (!done.isCompleted) done.complete();
    },
    (Object error, StackTrace stack) {
      if (error.toString().contains('Unable to load asset')) return;
      unexpected ??= error;
      if (!done.isCompleted) done.completeError(error, stack);
    },
  );
  await done.future;
  await Future<void>.delayed(const Duration(milliseconds: 10));
  if (unexpected != null) {
    throw StateError('Unexpected zone error during onLoad: $unexpected');
  }
  return game;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'TC-304 re-sourced art lands on BOTH surfaces with no divergence (AC-4)',
    (tester) async {
      final game = await loadGame();
      // Drive into the beach phase so both backdrop themes + pooled kinds are
      // exercised on whichever frame we capture; reduce-motion OFF, active.
      game.applyState(
        moving: true,
        mode: TravelMode.motorbike,
        reduceMotion: false,
        timeOfDayHours: 12,
      );
      for (int i = 0; i < 60000; i++) {
        game.update(kFrameDt);
        if (game.isBeachBackdropActive && game.liveSideObjectCount > 4) break;
      }

      // Render the SAME shared game at both surfaces.
      final full = imagesDrawnAt(game, kFullViewport);
      final pip = imagesDrawnAt(game, kPipViewport);

      // Both surfaces composited the re-sourced art (image draws happened).
      expect(full, isNotEmpty, reason: 'full window must draw re-sourced art');
      expect(pip, isNotEmpty, reason: 'PiP must draw re-sourced art');

      // No per-surface asset divergence: the PiP requests a SUBSET-or-equal set
      // of the SAME shared Image instances the full window does (they share one
      // game/sprite cache — there is no surface-specific asset swap). Any image
      // drawn on the PiP must also be available to the full surface.
      expect(
        pip.difference(full),
        isEmpty,
        reason:
            'the PiP must not request any image the full window does not — both '
            'share one JourneyGame instance, so no divergence (AC-4)',
      );
    },
  );

  testWidgets(
    'TC-319 long mock journey lands family + beach band + animals on both '
    'surfaces; spacing cadence holds (AC-3/4/5/6/7)',
    (tester) async {
      final game = await loadGame();
      game.applyState(
        moving: true,
        mode: TravelMode.motorbike,
        reduceMotion: false,
        timeOfDayHours: 12,
      );

      // Drive a long enough journey to cycle the backdrop themes (beach appears)
      // AND exercise a full spawn cycle (every animal kind enters the pool).
      bool sawBeach = false;
      bool sawHighland = false;
      final Set<SideObjectKind> seenKinds = <SideObjectKind>{};
      for (int i = 0; i < 120000; i++) {
        game.update(kFrameDt);
        if (game.backdropThemeIndex == 0) sawHighland = true;
        if (game.isBeachBackdropActive) sawBeach = true;
        seenKinds.addAll(game.liveSideObjectKinds);
        if (sawBeach &&
            sawHighland &&
            kAnimalKinds.every(seenKinds.contains)) {
          break;
        }
      }

      // AC-5: the beach/coast band appeared in the backdrop rotation.
      expect(sawHighland, isTrue, reason: 'highland theme must appear');
      expect(sawBeach, isTrue, reason: 'beach band must appear (AC-5)');
      // AC-6: every side-view animal kind entered the live pool.
      for (final kind in kAnimalKinds) {
        expect(seenKinds, contains(kind), reason: 'animal $kind in pool (AC-6)');
      }

      // AC-3 / AC-4: the re-sourced family renders on BOTH surfaces (image draws
      // on each), with no per-surface divergence (PiP images ⊆ full images).
      final full = imagesDrawnAt(game, kFullViewport);
      final pip = imagesDrawnAt(game, kPipViewport);
      expect(full, isNotEmpty);
      expect(pip, isNotEmpty);
      expect(pip.difference(full), isEmpty, reason: 'no divergence (AC-4)');

      // AC-7: the pooled-object even-spacing cadence still holds along the curve
      // (the band is exempt — it is not in liveCentreLinePoints).
      final pts = game.liveCentreLinePoints;
      if (pts.length >= 6) {
        final List<double> gaps = <double>[];
        for (int i = 1; i < pts.length; i++) {
          final double dw = pts[i].world - pts[i - 1].world;
          final double dl = pts[i].lateral - pts[i - 1].lateral;
          gaps.add(math.sqrt(dw * dw + dl * dl));
        }
        final double mean = gaps.reduce((a, b) => a + b) / gaps.length;
        for (final g in gaps) {
          expect(
            (g - mean).abs(),
            lessThanOrEqualTo(0.20 * mean + 1e-6),
            reason: 'spacing cadence must hold with the new kinds (AC-7)',
          );
        }
      }
    },
  );
}
