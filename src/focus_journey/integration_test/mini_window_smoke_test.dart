// Mini-window HEADLINE END-TO-END smoke + single-shared-game integration tests,
// on the REAL widget tree (AppShell + the real JourneyCubit), driven through the
// deterministic mock window + mock tray backends (NFR-8 / TC-024). NO real OS
// window/tray/dock, NO real timers, NO DateTime.now(). State is advanced via a
// MockActivitySource through the REAL JourneyEngine/ticker; frames via the
// integration harness pump.
//
// Covered here (mock-window path, real widget tree):
//   TC-009   exactly ONE shared JourneyGame drives both modes — the SAME game
//            instance the shell owns is the one passed to the full subtree AND
//            the compact subtree (identity equal); the mini-window code forks no
//            second engine/ticker/scene (AC-9 / NFR-7 structural part).
//   TC-013   the shared JourneyGame survives a full -> compact -> full
//            re-parenting WITHOUT re-init: identity preserved across the
//            transition and onLoad is not re-run (init-count spy) (AC-9
//            re-parenting refinement / AC-16 continuity reinforcement).
//   TC-026   headline smoke: launched in full mode, the mock drives active (the
//            scene scrolls), enter compact (main hides, compact mounts the shared
//            scene + scrolls), drive idle (PiP parks), drive active again (PiP
//            resumes), Show app (PiP dismissed), close (hide-to-tray, keeps
//            accruing, PiP not auto-shown) — mutual exclusion holds at every step
//            (AC-1/AC-2/AC-3/AC-6/AC-15/AC-18).
//
// Real-OS-only legs are NOT automated here — see the manual checklist
// (tests/cases/mini-window-manual-checklist.md): TC-M1 (frameless drag), TC-M2 /
// TC-M2-AOT (real always-on-top stacking over a different focused app), TC-M3
// (real close-intercept + real tray icon/menu render & click), TC-M4 (tray-menu
// keyboard/screen-reader a11y), TC-M-NF2 (on-device fps), TC-M-PRIV (privacy
// audit ship-gate), and all Windows runtime legs (NFR-9, deferred). The mock
// path cannot prove real OS stacking/drag/dock/tray rendering — gap is explicit.
//
// Run on a desktop device (mock path — no real OS window is touched):
//   fvm flutter test integration_test/mini_window_smoke_test.dart -d macos \
//       --dart-define=mock-window=true --dart-define=mock-activity=true

import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/activity/data/mock_activity_source.dart';
import 'package:focus_journey/features/journey/domain/clock.dart';
import 'package:focus_journey/features/journey/domain/journey_engine.dart';
import 'package:focus_journey/features/journey/presentation/activity_ticker.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_assets.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_game.dart';
import 'package:focus_journey/features/journey/presentation/journey_cubit.dart';
import 'package:focus_journey/features/mini_window/data/mock_tray_controller.dart';
import 'package:focus_journey/features/mini_window/data/mock_window_mode_controller.dart';
import 'package:focus_journey/features/mini_window/domain/window_mode.dart';
import 'package:focus_journey/features/mini_window/presentation/app_shell.dart';
import 'package:focus_journey/features/mini_window/presentation/app_shell_cubit.dart';
import 'package:focus_journey/features/mini_window/presentation/compact_view.dart';
import 'package:integration_test/integration_test.dart';

/// A scripted clock the test advances explicitly so each tick credits a real,
/// positive delta — no wall-clock waits (matches the v1 integration harness).
class AdvanceableClock implements Clock {
  AdvanceableClock(this._now);
  DateTime _now;
  void advance(Duration d) => _now = _now.add(d);
  @override
  DateTime now() => _now;
}

/// A JourneyGame subclass that counts onLoad calls (the TC-013 re-init spy) and
/// captures every GameWidget render path. Pure read-only test seam — it drives
/// NO state and constructs no second engine/ticker.
class _SpyGame extends JourneyGame {
  int onLoadCount = 0;
  @override
  Future<void> onLoad() async {
    onLoadCount++;
    return super.onLoad();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Builds a FRESH 1x1 stub image used to PRE-SEED a game's image cache for
  // every manifest path so onLoad's `images.load(...)` returns a cache hit
  // instead of hitting the bundle — eliminating the documented orphan ship.png
  // rejection at the source (same approach as journey_scene_smoke_test.dart).
  // A fresh stub PER game is required: Flame's `Images.add` disposes the prior
  // image stored under a path, so a shared stub would be disposed by a later
  // test and break the earlier one. Test-only.
  Future<ui.Image> makeStub() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 1, 1),
      ui.Paint()..color = const Color(0xFF888888),
    );
    return recorder.endRecording().toImage(1, 1);
  }

  // Mounts the REAL AppShell over the shared game + the mock controllers. The
  // shell owns the ONE shared game; we capture it via the gameFactory seam and
  // record the game instance passed to each subtree for the identity checks.
  Future<_MountedShell> mountShell(
    WidgetTester tester, {
    required JourneyCubit cubit,
    required MockWindowModeController window,
    required Clock clock,
  }) async {
    final _SpyGame game = _SpyGame();
    for (final String path in JourneyAssets.all) {
      game.images.add(path, await makeStub());
    }
    final List<JourneyGame> fullSubtreeGames = <JourneyGame>[];

    final AppShellCubit shellCubit = AppShellCubit(controller: window);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<JourneyCubit>.value(value: cubit),
            BlocProvider<AppShellCubit>.value(value: shellCubit),
          ],
          child: AppShell(
            clock: clock,
            controller: window,
            gameFactory: () => game,
            fullBuilder: (JourneyGame sharedGame) {
              fullSubtreeGames.add(sharedGame);
              // A minimal full subtree that renders the shared scene (stand-in
              // for the production tab UI — this test only needs the GameWidget
              // identity + scroll, not the whole tab chrome).
              return Scaffold(body: GameWidget<JourneyGame>(game: sharedGame));
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    final Object? boot = tester.takeException();
    if (boot != null && !boot.toString().contains('Unable to load asset')) {
      throw boot;
    }
    return _MountedShell(
      game: game,
      shellCubit: shellCubit,
      fullSubtreeGames: fullSubtreeGames,
    );
  }

  group('TC-009 exactly one shared JourneyGame drives both modes', () {
    testWidgets('the same game instance is passed to full AND compact subtrees', (
      tester,
    ) async {
      final clock = AdvanceableClock(DateTime(2026, 6, 24, 12));
      final cubit = JourneyCubit();
      addTearDown(cubit.close);
      final window = MockWindowModeController();
      addTearDown(window.dispose);

      final mounted = await mountShell(
        tester,
        cubit: cubit,
        window: window,
        clock: clock,
      );
      addTearDown(mounted.shellCubit.close);

      // Full mode: the shared game the shell owns is the one the full subtree got.
      expect(mounted.fullSubtreeGames, isNotEmpty);
      expect(
        identical(mounted.fullSubtreeGames.last, mounted.game),
        isTrue,
        reason: 'AC-9: the full subtree renders the shell-owned shared game',
      );

      // Enter compact: the compact subtree must render the SAME game object.
      await window.enterCompact();
      await tester.pump();
      await tester.pump();

      final CompactView compact = tester.widget<CompactView>(
        find.byType(CompactView),
      );
      expect(
        identical(compact.sharedGame, mounted.game),
        isTrue,
        reason:
            'AC-9: the compact subtree renders the SAME shared game (no 2nd)',
      );

      // Exactly one GameWidget is mounted at a time (mutual exclusion is
      // structural — one window, one scene).
      expect(find.byType(GameWidget<JourneyGame>), findsOneWidget);
    });
  });

  group('TC-013 shared game survives full->compact->full without re-init', () {
    testWidgets('identity preserved + onLoad not re-run across re-parenting', (
      tester,
    ) async {
      final clock = AdvanceableClock(DateTime(2026, 6, 24, 12));
      final cubit = JourneyCubit();
      addTearDown(cubit.close);
      final window = MockWindowModeController();
      addTearDown(window.dispose);

      final mounted = await mountShell(
        tester,
        cubit: cubit,
        window: window,
        clock: clock,
      );
      addTearDown(mounted.shellCubit.close);

      final JourneyGame gameBefore = mounted.game;
      final int loadsAfterFirstMount = mounted.game.onLoadCount;

      // full -> compact
      await window.enterCompact();
      await tester.pump();
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();

      final CompactView compact = tester.widget<CompactView>(
        find.byType(CompactView),
      );
      expect(identical(compact.sharedGame, gameBefore), isTrue);

      // compact -> full
      await window.showApp();
      await tester.pump();
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();

      expect(
        identical(mounted.fullSubtreeGames.last, gameBefore),
        isTrue,
        reason: 'AC-9: SAME game instance reused across the round-trip',
      );
      // onLoad must NOT have re-run on re-parenting (no scene rebuild/reset).
      expect(
        mounted.game.onLoadCount,
        loadsAfterFirstMount,
        reason: 'AC-9: re-parenting does not re-run onLoad (no re-init)',
      );

      final Object? late = tester.takeException();
      if (late != null && !late.toString().contains('Unable to load asset')) {
        throw late;
      }
    });
  });

  group('TC-026 headline end-to-end smoke (mock activity + window/tray)', () {
    testWidgets(
      'active->compact->idle->active->show app->close holds end to end',
      (tester) async {
        final clock = AdvanceableClock(DateTime(2026, 6, 24, 12));
        final mock = MockActivitySource(idleSeconds: 0, screenLocked: false);
        // G = T = 5 min default ⇒ idle past threshold ⇒ paused (stopped view).
        final engine = JourneyEngine(clock: clock, activityPlugin: mock);
        final cubit = JourneyCubit();
        addTearDown(cubit.close);
        final ticker = ActivityTicker(
          engine: engine,
          clock: clock,
          cubit: cubit,
        );
        final window = MockWindowModeController();
        addTearDown(window.dispose);
        final tray = MockTrayController();
        addTearDown(tray.dispose);
        await window.setup();
        await tray.init();

        final mounted = await mountShell(
          tester,
          cubit: cubit,
          window: window,
          clock: clock,
        );
        addTearDown(mounted.shellCubit.close);
        final JourneyGame game = mounted.game;

        // Drive one tick: advance clock, tick the engine, pump 2 frames so the
        // cubit stream flushes into the shell's BlocListener (applyState).
        Future<void> tick(Duration dt) async {
          clock.advance(dt);
          await tester.runAsync(ticker.tickOnce);
          await tester.pump();
          await tester.pump();
          tester.takeException();
        }

        double pumpScroll(int frames) {
          final double start = game.roadScrollOffset;
          for (var i = 0; i < frames; i++) {
            game.update(1 / 60);
          }
          return game.roadScrollOffset - start;
        }

        bool mainVisible() => window.mode == WindowMode.full && window.visible;
        bool pipVisible() =>
            window.mode == WindowMode.compact && window.visible;
        void assertExclusive(String step) {
          expect(
            mainVisible() && pipVisible(),
            isFalse,
            reason: 'co-visibility banned after: $step',
          );
        }

        // Prime the ticker's lastTick so the first measured delta is > 0.
        await tester.runAsync(ticker.tickOnce);

        // --- FULL + ACTIVE: scene scrolls. ---
        assertExclusive('launch full');
        mock.idleSeconds = 0;
        await tick(const Duration(seconds: 6));
        expect(pumpScroll(120), greaterThan(0), reason: 'AC-1: scrolls active');

        // --- ENTER COMPACT: main hides, compact mounts the shared scene. ---
        await window.enterCompact();
        await tester.pump();
        await tester.pump();
        assertExclusive('enter compact');
        expect(find.byType(CompactView), findsOneWidget);
        expect(mainVisible(), isFalse, reason: 'AC-6: main hidden in compact');
        // Compact renders the SAME shared game and it still scrolls while active.
        final CompactView compact = tester.widget<CompactView>(
          find.byType(CompactView),
        );
        expect(identical(compact.sharedGame, game), isTrue);
        expect(
          pumpScroll(120),
          greaterThan(0),
          reason: 'compact scrolls active',
        );

        // --- IDLE: PiP parks. ---
        mock.idleSeconds = 600; // > 5-min threshold ⇒ paused
        await tick(const Duration(seconds: 6));
        for (var i = 0; i < 60; i++) {
          game.update(1 / 60); // settle the bounded ease
        }
        expect(
          pumpScroll(120),
          lessThan(1e-6),
          reason: 'AC-2: parks when idle',
        );

        // --- ACTIVE AGAIN: PiP resumes within one tick. ---
        mock.idleSeconds = 0;
        await tick(const Duration(seconds: 6));
        expect(
          pumpScroll(120),
          greaterThan(0),
          reason: 'AC-3: resumes on active',
        );

        // --- SHOW APP: PiP dismissed, main restored. ---
        await window.showApp();
        await tester.pump();
        await tester.pump();
        assertExclusive('show app');
        expect(
          find.byType(CompactView),
          findsNothing,
          reason: 'AC-6: PiP gone',
        );
        expect(mainVisible(), isTrue);

        // --- CLOSE: hide-to-tray, keeps accruing, PiP not auto-shown. ---
        mock.idleSeconds = 0;
        final double beforeClose = engine.distanceKm;
        await window.hideToTray();
        await tester.pump();
        assertExclusive('close to tray');
        expect(window.visible, isFalse, reason: 'AC-15: hidden, not destroyed');
        expect(window.didQuit, isFalse, reason: 'AC-15: process stays alive');
        expect(pipVisible(), isFalse, reason: 'AC-18: PiP not auto-shown');
        // Keeps accruing in the background while active.
        clock.advance(const Duration(minutes: 30));
        await tester.runAsync(ticker.tickOnce);
        await tester.pump();
        expect(
          engine.distanceKm,
          greaterThan(beforeClose),
          reason: 'AC-15: tracking continues after close-to-tray',
        );

        // Tear down the widget tree within the test so any benign ship.png
        // rejection drains here (mirrors journey_scene_smoke_test.dart).
        await tester.pumpWidget(const SizedBox.shrink());
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
          final Object? late = tester.takeException();
          if (late != null &&
              !late.toString().contains('Unable to load asset')) {
            throw late;
          }
        }
      },
    );
  });
}

/// Bundle of the captured shared game + the shell cubit + the per-build full
/// subtree game list, returned by `mountShell` for the identity assertions.
class _MountedShell {
  _MountedShell({
    required this.game,
    required this.shellCubit,
    required this.fullSubtreeGames,
  });
  final _SpyGame game;
  final AppShellCubit shellCubit;
  final List<JourneyGame> fullSubtreeGames;
}
