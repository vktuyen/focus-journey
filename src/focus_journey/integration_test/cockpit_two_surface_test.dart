// journey-pov AC-11 two-surface wiring + headline mode-flow smoke.
//
// ADR-0003: the full window and the always-on-top mini-window PiP render the
// SAME JourneyGame instance. The cockpit is a fraction of the LIVE viewport, so
// the SAME game rendered at the full-window size and at the sized-down PiP size
// shows the cockpit on BOTH surfaces, scaled proportionally (per the AC-5
// band). We model the two surfaces by rendering the one shared game at the two
// sizes (onGameResize → render), exactly as the per-surface render path does.
//
// NO real OS, NO real timers, NO wall-clock waits — the scene is driven via
// applyState(...) + update(dt) and rendered into a bounds-recording canvas.
//
// Covers:
//   TC-209 AC-11        — cockpit on BOTH surfaces, scaled per the AC-5 band
//   TC-221 AC-1/3/6/7/8/11 — headline smoke: car → motorbike → walk → car on
//                            both surfaces; gating, clean revert + restore
//
// The real-OS "cockpit looks right on a live frameless always-on-top PiP +
// pauses on real occlusion" legs are the MANUAL carries TC-M-PIP (and the
// inherited PiP pause logic is journey-scene-v2's; this slice only confirms the
// cockpit rides it — see tests/cases/journey-pov-manual-checklist.md).
//
// Runs headless under `flutter test` and on a desktop device:
//   fvm flutter test integration_test/cockpit_two_surface_test.dart
//   fvm flutter test integration_test/cockpit_two_surface_test.dart -d macos

import 'dart:async';
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_game.dart';
import 'package:integration_test/integration_test.dart';

/// Full-window vs sized-down PiP viewports (the two surfaces share one game).
final Vector2 kFullViewport = Vector2(1280, 800);
final Vector2 kPipViewport = Vector2(360, 220);

/// Bounds-recording canvas: per primitive-draw, the vertical extent touched.
/// Lets us measure the cockpit band per surface without a raster surface.
class _BoundsCanvas implements Canvas {
  final List<({double minY, double maxY})> draws =
      <({double minY, double maxY})>[];

  void _add(double a, double b) =>
      draws.add((minY: a < b ? a : b, maxY: a < b ? b : a));

  @override
  void drawRect(Rect rect, Paint paint) => _add(rect.top, rect.bottom);
  @override
  void drawRRect(RRect rrect, Paint paint) => _add(rrect.top, rrect.bottom);
  @override
  void drawCircle(Offset c, double radius, Paint paint) =>
      _add(c.dy - radius, c.dy + radius);
  @override
  void drawLine(Offset p1, Offset p2, Paint paint) => _add(p1.dy, p2.dy);
  @override
  void drawPath(Path path, Paint paint) {
    final Rect b = path.getBounds();
    _add(b.top, b.bottom);
  }

  @override
  void drawImageRect(Image image, Rect src, Rect dst, Paint paint) =>
      _add(dst.top, dst.bottom);
  @override
  void noSuchMethod(Invocation invocation) {}
}

/// The recorded draws of one rendered frame: per-draw vertical extents.
typedef FrameDraws = List<({double minY, double maxY})>;

/// Renders [game] at [size] (resizing to that surface first) and returns the
/// recorded per-draw y-extents. The same game is shared across both surfaces
/// (ADR-0003).
FrameDraws renderAt(JourneyGame game, Vector2 size) {
  game.onGameResize(size);
  final canvas = _BoundsCanvas();
  game.render(canvas);
  return canvas.draws;
}

/// Loads a sprite-backed game (render needs the sprite store initialised),
/// swallowing ONLY Flame's expected orphan "Unable to load asset" rejection for
/// the intentionally-absent assets (ship.png + the 3 procedural cockpit shapes).
/// Mirrors the unit harness `loadJourneyGame()`; any other zone error re-throws.
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

  void apply(JourneyGame game, TravelMode mode) => game.applyState(
    moving: true,
    mode: mode,
    reduceMotion: true, // freeze scroll for a deterministic two-surface compare
    timeOfDayHours: 12,
  );

  testWidgets(
    'TC-209 cockpit on BOTH surfaces, scaled per the AC-5 band (AC-11)',
    (tester) async {
      for (final mode in <TravelMode>[TravelMode.car, TravelMode.motorbike]) {
        final game = await loadGame();
        apply(game, mode);

        // The cockpit fraction is a fraction of the LIVE viewport, so the SAME
        // game shows the cockpit at both sizes, occupying the SAME fraction.
        final double fraction = game.cockpitViewportFraction;
        expect(fraction, inInclusiveRange(0.30, 0.40));

        // FULL window: cockpit composited (more draws than the bare-scene
        // baseline at the same surface).
        final full = renderAt(game, kFullViewport);
        // PiP: same shared game, sized down — cockpit still composited.
        final pip = renderAt(game, kPipViewport);

        expect(game.isCockpitActive, isTrue, reason: '$mode cockpit active');

        // Per-surface AC-5 band: the cockpit's added draws (vs a bare walk
        // scene at the SAME surface size) predominantly sit in the lower
        // `fraction` of THAT surface's height — proportional, not fixed px.
        await _assertCockpitInLowerBand(
          cockpitDraws: full,
          surface: kFullViewport,
          fraction: fraction,
          label: '$mode FULL',
        );
        await _assertCockpitInLowerBand(
          cockpitDraws: pip,
          surface: kPipViewport,
          fraction: fraction,
          label: '$mode PiP',
        );

        // The road is still readable above the cockpit on BOTH surfaces (draws
        // exist above each surface's dash line).
        final double fullTop = kFullViewport.y * (1 - fraction);
        final double pipTop = kPipViewport.y * (1 - fraction);
        expect(full.any((d) => d.minY < fullTop - 1.0), isTrue);
        expect(pip.any((d) => d.minY < pipTop - 1.0), isTrue);
      }
    },
  );

  testWidgets(
    'TC-221 headline smoke: car → motorbike → walk → car on both surfaces',
    (tester) async {
      final game = await loadGame();

      int fullDraws() => renderAt(game, kFullViewport).length;
      int pipDraws() => renderAt(game, kPipViewport).length;

      // Baseline bare-scene draw counts (walk, no cockpit) per surface.
      apply(game, TravelMode.walk);
      final int bareFull = fullDraws();
      final int barePip = pipDraws();
      expect(game.isCockpitActive, isFalse);

      // 1) car → cockpit appears on BOTH surfaces (more draws than bare).
      apply(game, TravelMode.car);
      expect(game.isCockpitActive, isTrue);
      final int carFull = fullDraws();
      final int carPip = pipDraws();
      expect(carFull, greaterThan(bareFull));
      expect(carPip, greaterThan(barePip));

      // 2) motorbike → motorbike cockpit on both surfaces.
      apply(game, TravelMode.motorbike);
      expect(game.isCockpitActive, isTrue);
      expect(fullDraws(), greaterThan(bareFull));
      expect(pipDraws(), greaterThan(barePip));

      // 3) walk → cockpit removed, side-view sprite, NO residual on either
      //    surface (draw count returns to the bare-scene baseline).
      apply(game, TravelMode.walk);
      expect(game.isCockpitActive, isFalse);
      expect(
        fullDraws(),
        bareFull,
        reason: 'no residual cockpit on the full window after revert (AC-7)',
      );
      expect(
        pipDraws(),
        barePip,
        reason: 'no residual cockpit on the PiP after revert (AC-7)',
      );

      // 4) back to car → cockpit restored cleanly on both surfaces (identical
      //    to the first car render — stateless painter, no carry-over, AC-8).
      apply(game, TravelMode.car);
      expect(game.isCockpitActive, isTrue);
      expect(fullDraws(), carFull, reason: 'clean restore on full window (AC-8)');
      expect(pipDraws(), carPip, reason: 'clean restore on the PiP (AC-8)');
    },
  );
}

/// Asserts the COCKPIT draws (the suffix added over a bare scene rendered at
/// the SAME surface size) predominantly sit in the lower [fraction] of the
/// surface height. The bare baseline is a fresh walk scene at the same size.
Future<void> _assertCockpitInLowerBand({
  required List<({double minY, double maxY})> cockpitDraws,
  required Vector2 surface,
  required double fraction,
  required String label,
}) async {
  final bare = await loadGame();
  bare.applyState(
    moving: true,
    mode: TravelMode.walk,
    reduceMotion: true,
    timeOfDayHours: 12,
  );
  final baseline = renderAt(bare, surface);
  expect(
    cockpitDraws.length,
    greaterThan(baseline.length),
    reason: '$label must composite a cockpit foreground',
  );
  final added = cockpitDraws.sublist(baseline.length);
  final double dashLine = surface.y * (1 - fraction);
  final int inLowerBand = added
      .where((d) => (d.minY + d.maxY) / 2 >= dashLine - 1.0)
      .length;
  expect(
    inLowerBand,
    greaterThanOrEqualTo((added.length * 0.6).ceil()),
    reason:
        '$label: the cockpit must occupy the lower $fraction of the surface '
        '(added=${added.length}, lower-band=$inLowerBand)',
  );
}
