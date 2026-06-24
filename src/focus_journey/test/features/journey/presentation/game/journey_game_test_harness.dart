// Shared test harness for the journey-view Flame scene (TC-001..TC-027).
//
// WHY THIS EXISTS
// The scene is driven deterministically by `applyState(...)` + `update(dt)` with
// NO real timers and NO wall-clock waits (per tests/cases/journey-view.md
// conventions). Two seams make headless testing possible:
//
//  * MOTION-ONLY tests do not need sprites: `update(dt)` only touches the motion
//    model, the side-object pool, and the bob phase — never `_sprites`. So we
//    construct the game, call `onGameResize(...)`, and pump `update(dt)` WITHOUT
//    `onLoad()`. This keeps motion tests fast and asset-independent.
//
//  * ASSET tests (TC-011/TC-014) DO need `onLoad()`. Flame 1.35.1's image cache
//    chains an internal `.then()` with no `onError` (see
//    flame/src/cache/images.dart `_ImageAsset.future`), so a genuinely-missing
//    asset (vehicles/ship.png — intentionally absent, documented in CREDITS.md)
//    leaks an ORPHAN rejected future to the test zone even though
//    JourneySprites._tryLoad catches it for control flow. `loadJourneyGame()`
//    runs `onLoad()` inside a `runZonedGuarded` that swallows ONLY that expected
//    "Unable to load asset" rejection, so the graceful-degradation path
//    (AC-14/TC-014) can be asserted without a spurious test failure. We do NOT
//    modify production code to work around this Flame quirk.

import 'dart:async';

import 'package:flame/game.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_game.dart';

/// A standard viewport for headless pumps. Any positive size works; the motion
/// model is size-independent.
final Vector2 kTestViewport = Vector2(800, 600);

/// One 60 fps frame in seconds — the canonical pump step.
const double kFrameDt = 1 / 60;

/// Builds a motion-ready game WITHOUT loading sprites (motion tests don't need
/// them). The game is resized to [size] so `render`-independent pumps work.
JourneyGame buildMotionGame({
  Vector2? size,
  int sideObjectCapacity = 24,
  double cruiseSpeed = 320.0,
  double easeDuration = 0.35,
}) {
  final JourneyGame game = JourneyGame(
    sideObjectCapacity: sideObjectCapacity,
    cruiseSpeed: cruiseSpeed,
    easeDuration: easeDuration,
  );
  game.onGameResize(size ?? kTestViewport);
  return game;
}

/// Loads a fully sprite-backed game, swallowing ONLY Flame's expected orphan
/// "Unable to load asset" rejection for the intentionally-absent ship.png. Any
/// other zone error is re-thrown so real failures still surface.
Future<JourneyGame> loadJourneyGame({Vector2? size}) async {
  late JourneyGame game;
  final Completer<void> done = Completer<void>();
  Object? unexpected;
  runZonedGuarded(
    () async {
      game = JourneyGame();
      await game.onLoad();
      game.onGameResize(size ?? kTestViewport);
      if (!done.isCompleted) {
        done.complete();
      }
    },
    (Object error, StackTrace stack) {
      if (error.toString().contains('Unable to load asset')) {
        return; // expected AC-14 degradation (ship.png) — swallow.
      }
      unexpected ??= error;
      if (!done.isCompleted) {
        done.completeError(error, stack);
      }
    },
  );
  await done.future;
  // Let the orphan rejection settle inside our guarded zone before returning.
  await Future<void>.delayed(const Duration(milliseconds: 10));
  if (unexpected != null) {
    throw StateError('Unexpected zone error during onLoad: $unexpected');
  }
  return game;
}

/// Pumps [frames] frames of [dt] each and returns the road scroll offset after
/// each pump (length == [frames]). No wall-clock waits.
List<double> pumpOffsets(
  JourneyGame game, {
  int frames = 60,
  double dt = kFrameDt,
}) {
  final List<double> offsets = <double>[];
  for (int i = 0; i < frames; i++) {
    game.update(dt);
    offsets.add(game.roadScrollOffset);
  }
  return offsets;
}

/// Pumps [frames] frames of [dt] each (no recording). Convenience.
void pump(JourneyGame game, {int frames = 1, double dt = kFrameDt}) {
  for (int i = 0; i < frames; i++) {
    game.update(dt);
  }
}

/// Convenience: drive the scene as "active" with the given [mode].
void driveActive(
  JourneyGame game, {
  TravelMode mode = TravelMode.motorbike,
  bool reduceMotion = false,
  double timeOfDayHours = 12,
}) {
  game.applyState(
    moving: true,
    mode: mode,
    reduceMotion: reduceMotion,
    timeOfDayHours: timeOfDayHours,
  );
}

/// Convenience: drive the scene as "stopped" (idle/paused collapse to this).
void driveStopped(
  JourneyGame game, {
  TravelMode mode = TravelMode.motorbike,
  bool reduceMotion = false,
  double timeOfDayHours = 12,
}) {
  game.applyState(
    moving: false,
    mode: mode,
    reduceMotion: reduceMotion,
    timeOfDayHours: timeOfDayHours,
  );
}
