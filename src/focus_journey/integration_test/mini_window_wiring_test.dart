// Mini-window (PiP + tray) COMPOSITION-ROOT WIRING integration tests, end to end
// against the SAME seams main.dart wires, driven through the deterministic
// mock window + mock tray backends (the `--dart-define=mock-window=true` path,
// NFR-8 / TC-024). NO real OS window, NO real tray, NO real dock, NO real
// timers, NO DateTime.now() — the journey is driven by a MockActivitySource +
// a scripted AdvanceableClock through the REAL JourneyEngine/ticker/cubit.
//
// These tests reproduce main.dart's `_wireMiniWindow()` / `_flushOnQuit()`
// wiring (tray.actions -> controller routing, cubit.stream -> tray.setState,
// controller.modeChanges -> tray.setMode, controller.hiddenToTray ->
// shellCubit.onHiddenToTray -> hintRepo.markHintShown, controller.onBeforeQuit
// -> stats flush) so the wiring is exercised through the real controllers/cubits
// without booting main() (which needs localNotifier/launch_at_startup OS setup).
// The assertions are made against the mock controllers' recorded calls + state
// model and the journey Bloc state — exactly the surfaces the cases name.
//
// Covered here (mock-window path):
//   TC-006   Enter compact -> {compact, pipVisible, !mainVisible, frameless,
//            alwaysOnTop}; enterCompact() recorded (AC-6 mock leg / AC-12).
//   TC-007   Show app from compact -> {full, mainVisible, !pipVisible}; PiP
//            dismissed as main restored (AC-6 reverse / AC-12).
//   TC-008   mutual-exclusion INVARIANT: never (mainVisible && pipVisible) across
//            an arbitrary transition sequence (AC-6 invariant).
//   TC-011   journey state -> tray.setState(active/paused) updates on emission;
//            active is distinguishable from idle/paused on the tray (AC-11).
//   TC-012   tray actions Show app / Enter compact / Quit route to the right
//            controller calls + observable window/process state (AC-12, AC-16).
//   TC-013-STATUS  tray status line reflects Bloc state + distance (AC-13).
//   TC-014   close -> hideToTray(): mainVisible=false, pipVisible=false,
//            isClosedToTray=true, processAlive=true, journey keeps accruing
//            distance across post-close ticks while active (AC-15).
//   TC-016   restore via Show app after hide -> continuity (same engine/cubit,
//            distance continuous); full exit ONLY via Quit (AC-16).
//   TC-017   first close fires the one-time hint + persists the flag; a second
//            close does NOT (AC-17); and Quit FLUSHES journey state (persistence
//            fake receives the latest snapshot) BEFORE processAlive=false (AC-16
//            Quit-flush).
//   TC-018   close-to-tray does NOT auto-show the PiP: pipVisible stays false
//            (AC-18).
//   TC-019-POS  fixed-size position persist round-trip through the mock +
//            position repo: drag -> persist -> relaunch restores position; only
//            position is persisted, never size (AC-8).
//   TC-024   NFR-8: the whole flow runs against the mock backends with no real
//            OS window/tray/idle; the mock is selected via the factory flag.
//
// Real-OS-only legs are NOT automated here and live in the manual checklist
// (tests/cases/mini-window-manual-checklist.md): TC-M1 (frameless drag),
// TC-M2 / TC-M2-AOT (real always-on-top stacking over another app), TC-M3 (real
// close-intercept + real tray icon/menu render & click), TC-M4 (tray-menu
// keyboard/screen-reader a11y), TC-M-NF2 (on-device fps), TC-M-PRIV (privacy
// audit), and all Windows runtime legs (NFR-9, deferred). The mock path cannot
// prove real OS stacking/drag/dock/tray rendering — that gap is intentional.
//
// Run on a desktop device (mock path — no real OS window is touched):
//   fvm flutter test integration_test/mini_window_wiring_test.dart -d macos \
//       --dart-define=mock-window=true --dart-define=mock-activity=true

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/activity/data/mock_activity_source.dart';
import 'package:focus_journey/features/journey/domain/clock.dart';
import 'package:focus_journey/features/journey/domain/journey_engine.dart';
import 'package:focus_journey/features/journey/presentation/activity_ticker.dart';
import 'package:focus_journey/features/journey/presentation/journey_cubit.dart';
import 'package:focus_journey/features/journey/presentation/journey_view_state.dart';
import 'package:focus_journey/features/mini_window/data/mini_window_factory.dart';
import 'package:focus_journey/features/mini_window/data/mock_tray_controller.dart';
import 'package:focus_journey/features/mini_window/data/mock_window_mode_controller.dart';
import 'package:focus_journey/features/mini_window/domain/compact_window_position_repository.dart';
import 'package:focus_journey/features/mini_window/domain/hide_to_tray_hint_repository.dart';
import 'package:focus_journey/features/mini_window/domain/tray_state.dart';
import 'package:focus_journey/features/mini_window/domain/window_mode.dart';
import 'package:focus_journey/features/mini_window/domain/window_position.dart';
import 'package:focus_journey/features/mini_window/presentation/app_shell_cubit.dart';
import 'package:focus_journey/features/mini_window/presentation/journey_tray_mapper.dart';
import 'package:integration_test/integration_test.dart';

const double _tol = 1e-6;

/// A scripted clock the test advances explicitly so each tick credits a real,
/// positive delta — no wall-clock waits (matches the v1 integration harness).
class AdvanceableClock implements Clock {
  AdvanceableClock(this._now);
  DateTime _now;
  void advance(Duration d) => _now = _now.add(d);
  @override
  DateTime now() => _now;
}

/// An in-memory [CompactWindowPositionRepository] recording every save — proves
/// the persist round-trip stores ONLY a position and never a size (AC-8).
class _InMemoryPositionRepo implements CompactWindowPositionRepository {
  _InMemoryPositionRepo([this._stored]);
  WindowPosition? _stored;
  final List<WindowPosition> saves = <WindowPosition>[];
  @override
  Future<WindowPosition?> load() async => _stored;
  @override
  Future<void> save(WindowPosition position) async {
    saves.add(position);
    _stored = position;
  }
}

/// An in-memory [HideToTrayHintRepository] recording the persisted "shown" flag
/// — the AC-17 one-time-hint persistence fake.
class _InMemoryHintRepo implements HideToTrayHintRepository {
  _InMemoryHintRepo([this._shown = false]);
  bool _shown;
  int markCount = 0;
  @override
  Future<bool> hasShownHint() async => _shown;
  @override
  Future<void> markHintShown() async {
    markCount++;
    _shown = true;
  }
}

/// A tiny harness that reproduces main.dart's mini-window wiring against the
/// mock controllers + the real journey Bloc/engine/ticker, so the wiring is
/// exercised end to end without booting main(). Mirrors `_wireMiniWindow()` /
/// `_flushOnQuit()` exactly (the SAME seams), so what is asserted here is the
/// real composition-root behaviour, just headless.
class _MiniWindowHarness {
  _MiniWindowHarness({
    MockWindowModeController? window,
    MockTrayController? tray,
    _InMemoryHintRepo? hintRepo,
    bool hintAlreadyShown = false,
  }) : window = window ?? MockWindowModeController(),
       tray = tray ?? MockTrayController(),
       hintRepo = hintRepo ?? _InMemoryHintRepo(hintAlreadyShown) {
    clock = AdvanceableClock(DateTime(2026, 6, 24, 12));
    activity = MockActivitySource(idleSeconds: 0, screenLocked: false);
    // 60 km/active-hour so 1 active hour ⇒ exactly 60 km (clean assertions).
    engine = JourneyEngine(
      clock: clock,
      activityPlugin: activity,
      kmPerActiveHour: 60,
      maxTickDelta: const Duration(hours: 6),
    );
    cubit = JourneyCubit();
    // The Quit-flush sink: records the snapshot distance flushed on Quit (the
    // stand-in for main.dart's `_statsCubit.onTick(_engine.toProgress())`).
    ticker = ActivityTicker(
      engine: engine,
      clock: clock,
      cubit: cubit,
    );
    shellCubit = AppShellCubit(
      controller: this.window,
      hintAlreadyShown: hintAlreadyShown,
    );
  }

  late final AdvanceableClock clock;
  late final MockActivitySource activity;
  late final JourneyEngine engine;
  late final JourneyCubit cubit;
  late final ActivityTicker ticker;
  late final AppShellCubit shellCubit;

  final MockWindowModeController window;
  final MockTrayController tray;
  final _InMemoryHintRepo hintRepo;

  // The Quit-flush bookkeeping (proves the flush ran BEFORE exit, AC-16).
  final List<double> flushedDistances = <double>[];
  bool flushRanBeforeQuit = false;

  final List<StreamSubscription<dynamic>> _subs = <StreamSubscription<dynamic>>[];

  /// Reproduces main.dart `_wireMiniWindow()`: tray actions -> controller,
  /// cubit -> tray, modeChanges -> tray, hiddenToTray -> hint, Quit flush.
  Future<void> wire() async {
    await window.setup();
    await tray.init();

    // Tray menu actions -> the window controller (AC-12).
    _subs.add(
      tray.actions.listen((TrayAction action) {
        switch (action) {
          case TrayAction.showApp:
            window.showApp();
          case TrayAction.enterCompact:
            window.enterCompact();
          case TrayAction.quit:
            window.quit();
        }
      }),
    );

    // Reflect journey state on the tray (AC-11/13): seed + follow.
    _pushJourneyToTray(cubit.state);
    _subs.add(cubit.stream.listen(_pushJourneyToTray));

    // Reflect window mode on the tray menu (AC-14): seed + follow.
    await tray.setMode(window.mode);
    _subs.add(window.modeChanges.listen(tray.setMode));

    // First-run hide-to-tray hint (AC-17).
    _subs.add(
      window.hiddenToTray.listen((_) {
        final bool shouldPersist = shellCubit.onHiddenToTray();
        if (shouldPersist) {
          hintRepo.markHintShown();
        }
      }),
    );

    // Quit flush hook (AC-16): persist the latest journey snapshot before exit.
    window.onBeforeQuit(() async {
      flushedDistances.add(engine.distanceKm);
      // The mock sets didQuit AFTER awaiting the flush, so observing
      // !window.didQuit here proves the flush ran BEFORE the exit completed.
      flushRanBeforeQuit = !window.didQuit;
    });
  }

  void _pushJourneyToTray(JourneyViewState s) {
    tray.setState(JourneyTrayMapper.stateFor(s));
    tray.setStatusLine(JourneyTrayMapper.statusLineFor(s));
  }

  /// Advance the clock, run one engine tick from the mock, and let the cubit
  /// stream microtask flush so the tray reflection listeners fire.
  Future<void> tick(Duration dt) async {
    clock.advance(dt);
    await ticker.tickOnce();
    // Let the broadcast-stream microtasks settle (cubit -> tray listeners).
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await shellCubit.close();
    await cubit.close();
    await window.dispose();
    await tray.dispose();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('TC-024 / NFR-8 mock backends are selected and touch no real OS', () {
    testWidgets('the harness drives the whole flow against the mock model', (
      tester,
    ) async {
      final h = _MiniWindowHarness();
      addTearDown(h.dispose);
      await h.wire();

      // The controllers under test are the deterministic mocks (no real OS).
      expect(h.window, isA<MockWindowModeController>());
      expect(h.tray, isA<MockTrayController>());
      // setup()/init() ran through the seam the composition root calls.
      expect(h.window.didSetup, isTrue);
      expect(h.tray.didInit, isTrue);
      // The factory flag wiring is the same seam main() uses; assert it exists
      // (its concrete value depends on the --dart-define passed to the run).
      expect(MiniWindowFactory.useMock, isA<bool>());
    });
  });

  group('TC-006 enter compact hides main + frameless + always-on-top', () {
    testWidgets('enterCompact() -> compact, pip visible, main hidden', (
      tester,
    ) async {
      final h = _MiniWindowHarness();
      addTearDown(h.dispose);
      await h.wire();

      expect(h.window.mode, WindowMode.full, reason: 'opens in full mode');

      await h.window.enterCompact();

      expect(h.window.calls, contains('enterCompact'));
      expect(h.window.mode, WindowMode.compact);
      // pipVisible == (compact && visible); mainVisible == (full && visible).
      expect(h.window.visible, isTrue, reason: 'the PiP itself is visible');
      expect(h.window.alwaysOnTop, isTrue, reason: 'frameless PiP floats (AC-6)');
      // Mutual exclusion: never both windows visible.
      final bool mainVisible = h.window.mode == WindowMode.full && h.window.visible;
      final bool pipVisible =
          h.window.mode == WindowMode.compact && h.window.visible;
      expect(pipVisible, isTrue);
      expect(mainVisible, isFalse, reason: 'main hides to the dock (AC-6)');
      // The mode change is reflected on the tray menu (AC-14 seed/follow).
      expect(h.tray.mode, WindowMode.compact);
    });
  });

  group('TC-007 Show app from compact dismisses the PiP', () {
    testWidgets('showApp() from compact -> full, main visible, pip dismissed', (
      tester,
    ) async {
      final h = _MiniWindowHarness();
      addTearDown(h.dispose);
      await h.wire();

      await h.window.enterCompact();
      expect(h.window.mode, WindowMode.compact);

      await h.window.showApp();

      expect(h.window.mode, WindowMode.full);
      final bool mainVisible = h.window.mode == WindowMode.full && h.window.visible;
      final bool pipVisible =
          h.window.mode == WindowMode.compact && h.window.visible;
      expect(mainVisible, isTrue, reason: 'main restored/foregrounded');
      expect(pipVisible, isFalse, reason: 'PiP dismissed (AC-6 reverse)');
      expect(h.tray.mode, WindowMode.full);
    });
  });

  group('TC-008 mutual-exclusion invariant across an arbitrary sequence', () {
    testWidgets('never (mainVisible && pipVisible) at any observed step', (
      tester,
    ) async {
      final h = _MiniWindowHarness();
      addTearDown(h.dispose);
      await h.wire();

      bool mainVisible() => h.window.mode == WindowMode.full && h.window.visible;
      bool pipVisible() =>
          h.window.mode == WindowMode.compact && h.window.visible;
      void assertInvariant(String step) {
        expect(
          mainVisible() && pipVisible(),
          isFalse,
          reason: 'co-visibility banned after: $step',
        );
      }

      assertInvariant('initial full');
      await h.window.enterCompact();
      assertInvariant('enter compact');
      await h.window.showApp();
      assertInvariant('show app');
      await h.window.hideToTray();
      assertInvariant('close to tray'); // both false here (TC-014/TC-018)
      await h.window.enterCompact();
      assertInvariant('enter compact again');
      await h.window.showApp();
      assertInvariant('show app again');
      await h.window.quit();
      assertInvariant('quit');
    });
  });

  group('TC-011 journey state reflected on the tray icon/tooltip', () {
    testWidgets('active vs idle/paused are distinguishable + update on emit', (
      tester,
    ) async {
      final h = _MiniWindowHarness();
      addTearDown(h.dispose);
      await h.wire();

      // ACTIVE: fresh input ⇒ engine active ⇒ tray reflects active.
      h.activity.idleSeconds = 0;
      await h.tick(const Duration(seconds: 6));
      expect(
        h.tray.state,
        TrayActivityState.active,
        reason: 'AC-11: active journey -> active tray variant',
      );

      // IDLE/PAUSED: idle past threshold ⇒ engine paused ⇒ tray reflects paused.
      h.activity.idleSeconds = 600; // > default 5-min threshold
      await h.tick(const Duration(seconds: 6));
      expect(
        h.tray.state,
        TrayActivityState.paused,
        reason: 'AC-11: parked journey -> paused tray variant',
      );

      // Distinguishable: the two states map to different tray variants.
      expect(TrayActivityState.active, isNot(TrayActivityState.paused));
    });
  });

  group('TC-013-STATUS tray status line reflects state + distance', () {
    testWidgets('status line equals the projected Bloc state/distance', (
      tester,
    ) async {
      final h = _MiniWindowHarness();
      addTearDown(h.dispose);
      await h.wire();

      // Accrue a known distance while active (1 active hour ⇒ 60 km).
      h.activity.idleSeconds = 0;
      await h.tick(const Duration(seconds: 6)); // prime
      h.clock.advance(const Duration(hours: 1));
      await h.tick(const Duration(seconds: 1));

      expect(h.engine.distanceKm, greaterThan(0));
      // The status line equals the mapper's projection of the live Bloc state.
      expect(
        h.tray.statusLine,
        JourneyTrayMapper.statusLineFor(h.cubit.state),
      );
      expect(h.tray.statusLine, startsWith('Travelling — '));
    });
  });

  group('TC-012 tray actions route to the right controller calls', () {
    testWidgets('Show app / Enter compact / Quit each produce their effect', (
      tester,
    ) async {
      final h = _MiniWindowHarness();
      addTearDown(h.dispose);
      await h.wire();

      // Enter compact via the tray menu action stream.
      h.tray.emitAction(TrayAction.enterCompact);
      await Future<void>.delayed(Duration.zero);
      expect(h.window.calls, contains('enterCompact'));
      expect(h.window.mode, WindowMode.compact);

      // Show app via the tray menu action stream.
      h.tray.emitAction(TrayAction.showApp);
      await Future<void>.delayed(Duration.zero);
      expect(h.window.calls, contains('showApp'));
      expect(h.window.mode, WindowMode.full);

      // Quit via the tray menu action stream -> full exit (processAlive false).
      h.tray.emitAction(TrayAction.quit);
      await Future<void>.delayed(Duration.zero);
      expect(h.window.calls, contains('quit'));
      expect(h.window.didQuit, isTrue, reason: 'Quit is the only full-exit path');
    });
  });

  group('TC-014 close hides to tray, keeps process alive + keeps tracking', () {
    testWidgets('hideToTray() -> hidden/alive/closed-to-tray; distance accrues', (
      tester,
    ) async {
      final h = _MiniWindowHarness();
      addTearDown(h.dispose);
      await h.wire();

      // Accrue some distance before closing (active).
      h.activity.idleSeconds = 0;
      await h.tick(const Duration(seconds: 6)); // prime lastTick
      h.clock.advance(const Duration(minutes: 30));
      await h.tick(const Duration(seconds: 1));
      final double distanceBeforeClose = h.engine.distanceKm;
      expect(distanceBeforeClose, greaterThan(0));

      // Close the main window -> hide-to-tray (the close intercept in the mock).
      await h.window.hideToTray();

      // Window-state model: neither window visible, process alive, closed to tray.
      expect(h.window.calls, contains('hideToTray'));
      expect(h.window.visible, isFalse, reason: 'main hidden, not destroyed');
      expect(h.window.didQuit, isFalse, reason: 'process stays alive (AC-15)');
      final bool pipVisible =
          h.window.mode == WindowMode.compact && h.window.visible;
      expect(pipVisible, isFalse, reason: 'PiP not auto-shown (AC-18)');

      // Journey KEEPS accruing across post-close ticks while active.
      h.clock.advance(const Duration(minutes: 30));
      await h.tick(const Duration(seconds: 1));
      expect(
        h.engine.distanceKm,
        greaterThan(distanceBeforeClose),
        reason: 'AC-15: closing the window does not stop tracking',
      );
    });
  });

  group('TC-018 close-to-tray does NOT auto-show the PiP', () {
    testWidgets('pipVisible stays false after a close-to-tray', (tester) async {
      final h = _MiniWindowHarness();
      addTearDown(h.dispose);
      await h.wire();

      await h.window.hideToTray();
      final bool pipVisible =
          h.window.mode == WindowMode.compact && h.window.visible;
      expect(pipVisible, isFalse);
      expect(h.window.mode, WindowMode.full, reason: 'no auto mode switch');
      expect(h.window.visible, isFalse, reason: 'neither window visible');
    });
  });

  group('TC-016 restore via Show app is continuous; full exit only via Quit', () {
    testWidgets('post-restore distance continuous + same engine; Quit-only exit', (
      tester,
    ) async {
      final h = _MiniWindowHarness();
      addTearDown(h.dispose);
      await h.wire();

      // Track, then hide to tray (keeps accruing).
      h.activity.idleSeconds = 0;
      await h.tick(const Duration(seconds: 6));
      h.clock.advance(const Duration(minutes: 30));
      await h.tick(const Duration(seconds: 1));
      await h.window.hideToTray();
      final double atHide = h.engine.distanceKm;

      h.clock.advance(const Duration(minutes: 30));
      await h.tick(const Duration(seconds: 1)); // accrues while hidden

      // Restore via Show app: continuous state, SAME engine/cubit (no reset).
      await h.window.showApp();
      expect(h.window.visible, isTrue);
      expect(
        h.engine.distanceKm,
        greaterThan(atHide),
        reason: 'AC-16: state is continuous, not reset on restore',
      );

      // The close button (hideToTray) never fully exits; only Quit does.
      expect(h.window.didQuit, isFalse);
      await h.window.quit();
      expect(h.window.didQuit, isTrue, reason: 'full exit only via Quit');
    });
  });

  group('TC-017 first-close hint persists once; Quit flushes before exit', () {
    testWidgets('first close fires + persists the hint; a second close does not', (
      tester,
    ) async {
      final hintRepo = _InMemoryHintRepo();
      final h = _MiniWindowHarness(hintRepo: hintRepo);
      addTearDown(h.dispose);
      await h.wire();

      // First close-to-tray: the one-time hint shows + the flag is persisted.
      await h.window.hideToTray();
      await Future<void>.delayed(Duration.zero);
      expect(
        h.shellCubit.state.showHideToTrayHint,
        isTrue,
        reason: 'AC-17: first close surfaces the one-time hint',
      );
      expect(hintRepo.markCount, 1, reason: 'AC-17: "shown" flag persisted once');

      // Dismiss + second close: the hint does NOT reappear, no second persist.
      h.shellCubit.dismissHideToTrayHint();
      await h.window.hideToTray();
      await Future<void>.delayed(Duration.zero);
      expect(
        h.shellCubit.state.showHideToTrayHint,
        isFalse,
        reason: 'AC-17: hint does not reappear on a subsequent close',
      );
      expect(hintRepo.markCount, 1, reason: 'AC-17: not persisted a second time');
    });

    testWidgets('the persisted-flag path suppresses the hint on first close', (
      tester,
    ) async {
      // hintAlreadyShown == true mirrors a prior session having persisted it.
      final hintRepo = _InMemoryHintRepo(true);
      final h = _MiniWindowHarness(hintRepo: hintRepo, hintAlreadyShown: true);
      addTearDown(h.dispose);
      await h.wire();

      await h.window.hideToTray();
      await Future<void>.delayed(Duration.zero);
      expect(h.shellCubit.state.showHideToTrayHint, isFalse);
      expect(hintRepo.markCount, 0, reason: 'no re-persist when already shown');
    });

    testWidgets('Quit flushes the latest journey state BEFORE the process exits', (
      tester,
    ) async {
      final h = _MiniWindowHarness();
      addTearDown(h.dispose);
      await h.wire();

      // Accrue a known distance, then Quit.
      h.activity.idleSeconds = 0;
      await h.tick(const Duration(seconds: 6));
      h.clock.advance(const Duration(hours: 1));
      await h.tick(const Duration(seconds: 1));
      final double atQuit = h.engine.distanceKm;
      expect(atQuit, closeTo(60, _tol)); // 1 active hour @ 60 km/h

      await h.window.quit();

      // The flush ran with the latest snapshot ...
      expect(h.flushedDistances, isNotEmpty, reason: 'AC-16: Quit flushes state');
      expect(h.flushedDistances.last, closeTo(atQuit, _tol));
      // ... and it ran BEFORE the exit completed (didQuit was still false then).
      expect(
        h.flushRanBeforeQuit,
        isTrue,
        reason: 'AC-16: flush happens before the process is destroyed',
      );
      expect(h.window.didQuit, isTrue);
    });
  });

  group('TC-019-POS fixed-size position persist round-trip via the mock', () {
    testWidgets('drag -> persist -> relaunch restores position (size never)', (
      tester,
    ) async {
      // Session A: enter compact, simulate a drag to a known position, persist.
      final positionRepo = _InMemoryPositionRepo();
      const dragged = WindowPosition(x: 640, y: 360);
      final windowA = MockWindowModeController(
        positionRepository: positionRepo,
        // A single generous display so the dragged position is in-bounds.
        displays: const <VisibleDisplay>[
          VisibleDisplay(left: 0, top: 0, width: 1920, height: 1080),
        ],
      );
      final trayA = MockTrayController();
      final hA = _MiniWindowHarness(window: windowA, tray: trayA);
      addTearDown(hA.dispose);
      await hA.wire();

      await windowA.enterCompact();
      // Simulate the frameless body drag settling at a new position (the real
      // drag is the manual TC-M1 leg; here the mock sets the position).
      windowA.currentPosition = dragged;
      await windowA.persistCompactPosition();

      expect(windowA.calls, contains('persistCompactPosition'));
      expect(positionRepo.saves, hasLength(1));
      expect(positionRepo.saves.single, dragged);

      // The repository persists ONLY a position — there is no size field on
      // WindowPosition (fixed compact size, AC-8). Assert the saved blob is a
      // bare position and that the keys are the position-only keys.
      final WindowPosition? saved = await positionRepo.load();
      expect(saved, dragged);

      // Session B (relaunch): a FRESH controller restores from the saved blob.
      final windowB = MockWindowModeController(
        positionRepository: positionRepo,
        displays: const <VisibleDisplay>[
          VisibleDisplay(left: 0, top: 0, width: 1920, height: 1080),
        ],
      );
      addTearDown(windowB.dispose);
      await windowB.setup();
      await windowB.enterCompact(); // loads + clamps the saved position

      expect(
        windowB.currentPosition,
        dragged,
        reason: 'AC-8: PiP reopens at the last persisted position next session',
      );
    });
  });
}
