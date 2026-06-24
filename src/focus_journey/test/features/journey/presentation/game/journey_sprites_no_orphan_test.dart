// B-1 regression test for the journey-view Flame scene.
//
// THE DEFECT (B-1): JourneySprites previously called Flame's `Images.load(path)`
// for EVERY manifest entry, including the genuinely-absent `vehicles/ship.png`.
// Flame 1.35.1's `_ImageAsset.future` constructor registers an internal
// `_future!.then((image){...})` listener with NO `onError`
// (package:flame/src/cache/images.dart). The caller's try/catch around the
// awaited future handles control flow, but that orphan listener has no error
// handler, so the rejection for the missing asset escapes to the zone's
// uncaught-error handler. In the real app (lib/main.dart has no
// runZonedGuarded, no PlatformDispatcher.onError, no FlutterError.onError) that
// becomes a spurious async "Unable to load asset" error on EVERY launch.
//
// THIS TEST exercises the UNGUARDED load path: it does NOT swallow the orphan
// and does NOT pre-seed a stub image. It uses `runZonedGuarded` ONLY as the
// assertion mechanism — to CAPTURE any uncaught async error that arrives — then
// asserts ZERO uncaught errors arrived, while still proving `vehicles/ship.png`
// degrades to a placeholder (AC-14 graceful degradation).
//
// Against the OLD code this test FAILS: the orphan "Unable to load asset"
// rejection lands in the capture handler, so `uncaught` is non-empty.
// Against the FIXED code (manifest pre-check → never calls Images.load for the
// absent ship.png) NO orphan future is ever created, so `uncaught` is empty.

import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_assets.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_game.dart';

void main() {
  // Real (non-mocked) root asset bundle — the manifest reflects pubspec.yaml,
  // where vehicles/ship.png is genuinely absent. No stub is pre-seeded.
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'loading the real JourneyGame with an absent asset emits NO uncaught zone '
    'error, yet still degrades ship.png to a placeholder (AC-14, B-1)',
    () async {
      final List<Object> uncaught = <Object>[];
      late JourneyGame game;
      final Completer<void> loaded = Completer<void>();

      // runZonedGuarded is used ONLY to capture uncaught async errors so we can
      // assert there are none. We do NOT silently swallow — every captured
      // error is recorded and asserted against below.
      runZonedGuarded(
        () async {
          game = JourneyGame();
          await game.onLoad();
          game.onGameResize(Vector2(800, 600));
          if (!loaded.isCompleted) {
            loaded.complete();
          }
        },
        (Object error, StackTrace stack) {
          // Record EVERYTHING. With the fix, this handler must never fire for a
          // load error. (Test fails if the orphan rejection escapes here.)
          uncaught.add(error);
          if (!loaded.isCompleted) {
            loaded.complete();
          }
        },
      );

      await loaded.future;
      // Give any orphan rejected future time to settle inside this zone so it
      // would be caught by the handler above if it existed (it must not).
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // CORE B-1 ASSERTION: zero uncaught async errors reached the zone.
      expect(
        uncaught,
        isEmpty,
        reason:
            'A missing asset must not leak an uncaught zone error '
            '(Flame _ImageAsset.future orphan rejection). Got: $uncaught',
      );

      // AC-14 still holds: ship.png degraded to a placeholder; the other 9
      // curated assets loaded, so only ship.png is reported failed.
      expect(game.hasPlaceholderAssets, isTrue);
      expect(game.failedAssetPaths, contains(JourneyAssets.vehicleShip));
      expect(
        game.failedAssetPaths.length,
        1,
        reason: 'only the genuinely-absent ship.png should degrade',
      );
    },
  );
}
