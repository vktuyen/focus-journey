// Widget tests for the cosmetic vehicle-preference override on the PRODUCTION
// shared-game path (the AppShell driver), tag TC-618 / AC-1 / AC-2 / AC-3 /
// AC-6 + ADR-0003 (two surfaces: full window + compact PiP).
//
// This is the test that pins review finding B2 (and would have caught B1): the
// override was wired only into the standalone JourneyScreen path, NOT into the
// production AppShell shared-game driver. The earlier precedence tests mount
// `JourneyScreen` with a gameFactory; this suite mounts the REAL `AppShell`
// (the production single-window two-mode shell, ADR-0003) so the override is
// asserted on the shell-owned shared `JourneyGame`, on BOTH window surfaces.
//
// Deterministic: a scriptable JourneyCubit emits arbitrary engine-derived view
// states, an injected JourneyGame (via the shell's gameFactory seam) exposes
// currentMode / isCockpitActive, and one in-memory-backed SettingsCubit holds
// the cosmetic preference. No real engine, no OS, no shared_preferences, no
// real timers.

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/clock.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_game.dart';
import 'package:focus_journey/features/journey/presentation/journey_cubit.dart';
import 'package:focus_journey/features/journey/presentation/journey_view_state.dart';
import 'package:focus_journey/features/mini_window/data/mock_window_mode_controller.dart';
import 'package:focus_journey/features/mini_window/presentation/app_shell.dart';
import 'package:focus_journey/features/mini_window/presentation/app_shell_cubit.dart';
import 'package:focus_journey/features/mini_window/presentation/compact_view.dart';
import 'package:focus_journey/features/stats/domain/app_settings.dart';
import 'package:focus_journey/features/stats/presentation/settings_cubit.dart';

import '../../stats/stats_test_fixtures.dart';

/// A cubit whose engine-derived state we drive directly (no engine, no OS).
class _ScriptableJourneyCubit extends JourneyCubit {
  void push(JourneyViewState state) => emit(state);
}

/// Fixed-noon clock so the cosmetic tint is deterministic (never drives motion).
class _FixedClock implements Clock {
  const _FixedClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

JourneyViewState _engineState(TravelMode mode) => JourneyViewState(
  motion: JourneyMotion.moving,
  mode: mode,
  distanceKm: 1,
  hasRealState: true,
);

void _drainAssetException(WidgetTester tester) {
  final ex = tester.takeException();
  if (ex != null && !ex.toString().contains('Unable to load asset')) {
    throw ex as Object;
  }
}

void main() {
  late InMemorySettingsRepository repository;
  late FakeStartupController startup;

  setUp(() {
    repository = InMemorySettingsRepository();
    startup = FakeStartupController();
  });

  SettingsCubit settingsCubit({AppSettings? initialSettings}) {
    final cubit = SettingsCubit(
      repository: repository,
      startupController: startup,
      applyIdleThreshold: (_) {},
      initialSettings: initialSettings,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  _ScriptableJourneyCubit journeyCubit() {
    final cubit = _ScriptableJourneyCubit();
    addTearDown(cubit.close);
    return cubit;
  }

  /// Mounts the REAL AppShell over the shared game (via gameFactory) plus the
  /// three cubits the production shell needs. The fullBuilder embeds the shared
  /// game in a GameWidget exactly as production does.
  Future<({MockWindowModeController controller, AppShellCubit shell})> pumpShell(
    WidgetTester tester, {
    required JourneyGame game,
    required _ScriptableJourneyCubit journey,
    required SettingsCubit settings,
  }) async {
    final controller = MockWindowModeController();
    addTearDown(controller.dispose);
    final shellCubit = AppShellCubit(controller: controller);
    addTearDown(shellCubit.close);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: MaterialApp(
          home: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<JourneyCubit>.value(value: journey),
              BlocProvider<AppShellCubit>.value(value: shellCubit),
              BlocProvider<SettingsCubit>.value(value: settings),
            ],
            child: AppShell(
              clock: _FixedClock(DateTime(2026, 6, 26, 12)),
              controller: controller,
              gameFactory: () => game,
              fullBuilder: (JourneyGame g) =>
                  Scaffold(body: GameWidget<JourneyGame>(game: g)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    _drainAssetException(tester);
    return (controller: controller, shell: shellCubit);
  }

  Future<void> push(
    WidgetTester tester,
    _ScriptableJourneyCubit cubit,
    JourneyViewState state,
  ) async {
    cubit.push(state);
    await tester.pump();
    await tester.pump();
    _drainAssetException(tester);
  }

  group('AppShell production shared-game path — vehicle override (TC-618)', () {
    testWidgets(
      'preferenceCar_rendersOnSharedGame_fullWindow (AC-2/AC-3)',
      (tester) async {
        final game = JourneyGame();
        final journey = journeyCubit();
        final settings = settingsCubit(
          initialSettings: const AppSettings(vehiclePreference: TravelMode.car),
        );
        await pumpShell(
          tester,
          game: game,
          journey: journey,
          settings: settings,
        );

        // Engine in a side-view mode (walk); the car preference must win on the
        // shell-owned shared game, and the cockpit branch follows the displayed
        // (car) mode — no split-brain (AC-2/AC-3).
        await push(tester, journey, _engineState(TravelMode.walk));
        expect(game.currentMode, TravelMode.car);
        expect(game.isCockpitActive, isTrue);
      },
    );

    testWidgets(
      'noPreference_engineModeShows_fullWindow (AC-4)',
      (tester) async {
        final game = JourneyGame();
        final journey = journeyCubit();
        final settings = settingsCubit(); // null → follows the engine mode
        await pumpShell(
          tester,
          game: game,
          journey: journey,
          settings: settings,
        );

        await push(tester, journey, _engineState(TravelMode.walk));
        expect(game.currentMode, TravelMode.walk);
        expect(game.isCockpitActive, isFalse);
      },
    );

    testWidgets(
      'livePick_reAppliesOnSharedGame_withinOneFrame_fullWindow (AC-1)',
      (tester) async {
        final game = JourneyGame();
        final journey = journeyCubit();
        final settings = settingsCubit(); // null → follows the engine mode
        await pumpShell(
          tester,
          game: game,
          journey: journey,
          settings: settings,
        );

        // Engine on walk, no preference → walk shows.
        await push(tester, journey, _engineState(TravelMode.walk));
        expect(game.currentMode, TravelMode.walk);

        // A live pick on the shell path must re-compose + re-apply via the
        // VehiclePreferenceListener WITHOUT a new engine emission (AC-1). One
        // settled frame after the SettingsCubit emits, the shared game shows it.
        await settings.setVehicle(TravelMode.motorbike);
        await tester.pump();
        _drainAssetException(tester);
        expect(game.currentMode, TravelMode.motorbike);
      },
    );

    testWidgets(
      'override_holdsOnCompactPiPSurface (ADR-0003 two-surface / AC-3)',
      (tester) async {
        final game = JourneyGame();
        final journey = journeyCubit();
        final settings = settingsCubit(
          initialSettings: const AppSettings(vehiclePreference: TravelMode.car),
        );
        final shell = await pumpShell(
          tester,
          game: game,
          journey: journey,
          settings: settings,
        );

        // Drive the single window to the compact PiP surface.
        await shell.shell.enterCompact();
        await tester.pump();
        await tester.pump();
        _drainAssetException(tester);
        // Confirm we are actually on the compact surface backed by the SAME game.
        final compact = tester.widget<CompactView>(find.byType(CompactView));
        expect(identical(compact.sharedGame, game), isTrue);

        // Engine in a side-view mode; the car override must hold on PiP too.
        await push(tester, journey, _engineState(TravelMode.walk));
        expect(game.currentMode, TravelMode.car);
        expect(game.isCockpitActive, isTrue);

        // And a live pick re-applies on the compact surface as well (AC-1).
        await settings.setVehicle(TravelMode.bicycle);
        await tester.pump();
        _drainAssetException(tester);
        expect(game.currentMode, TravelMode.bicycle);
        expect(game.isCockpitActive, isFalse);
      },
    );

    testWidgets(
      'restoredPreference_seedsBeforeFirstApply (AC-6)',
      (tester) async {
        // A SettingsCubit seeded with a saved preference BEFORE mount: the very
        // first engine emission must already display the restored mode, so the
        // scene opens on it (no flash of the engine mode first).
        final game = JourneyGame();
        final journey = journeyCubit();
        final settings = settingsCubit(
          initialSettings: const AppSettings(
            vehiclePreference: TravelMode.ship,
          ),
        );
        await pumpShell(
          tester,
          game: game,
          journey: journey,
          settings: settings,
        );

        // First (and only) engine emission carries the engine default; the
        // restored ship preference must already win on this first applyState.
        await push(tester, journey, _engineState(TravelMode.motorbike));
        expect(game.currentMode, TravelMode.ship);
      },
    );
  });
}
