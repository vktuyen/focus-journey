// Widget tests for the cosmetic vehicle-preference precedence composed at the
// JourneyScreen presentation seam (vehicle-picker AC-3 / AC-4 / AC-2, TC-603 /
// TC-604 / TC-602). Deterministic — a scriptable JourneyCubit emits arbitrary
// engine-derived view states, a real (injected) JourneyGame exposes currentMode
// / isCockpitActive, and one in-memory-backed SettingsCubit holds the cosmetic
// preference. No real engine, no OS, no shared_preferences.
//
// The override rule `displayedMode = vehiclePreference ?? engineMode` lives in
// JourneyScreen._applyToScene (it has no pure helper), so it is exercised here
// through the real seams: the value handed to JourneyGame.applyState(mode:) and
// thus JourneyGame.currentMode / isCockpitActive must equal that composition.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/clock.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_game.dart';
import 'package:focus_journey/features/journey/presentation/journey_cubit.dart';
import 'package:focus_journey/features/journey/presentation/journey_screen.dart';
import 'package:focus_journey/features/journey/presentation/journey_view_state.dart';
import 'package:focus_journey/features/stats/domain/app_settings.dart';
import 'package:focus_journey/features/stats/presentation/settings_cubit.dart';

import '../../stats/stats_test_fixtures.dart';

/// A cubit whose state we drive directly (scriptable fake — no engine, no OS).
class ScriptableJourneyCubit extends JourneyCubit {
  void push(JourneyViewState state) => emit(state);
}

/// Fixed-noon clock so the cosmetic tint is deterministic (never drives motion).
class FixedClock implements Clock {
  const FixedClock(this._now);
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

/// Mounts the JourneyScreen over [journeyCubit] + [settings], injecting [game]
/// via the gameFactory seam so the test can read currentMode / isCockpitActive.
Future<void> _pump(
  WidgetTester tester, {
  required JourneyGame game,
  required ScriptableJourneyCubit journeyCubit,
  required SettingsCubit settings,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(),
      child: MaterialApp(
        home: MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<JourneyCubit>.value(value: journeyCubit),
            BlocProvider<SettingsCubit>.value(value: settings),
          ],
          child: JourneyScreen(
            clock: FixedClock(DateTime(2026, 6, 23, 12)),
            gameFactory: () => game,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  _drainAssetException(tester);
}

Future<void> _push(
  WidgetTester tester,
  ScriptableJourneyCubit cubit,
  JourneyViewState state,
) async {
  cubit.push(state);
  await tester.pump();
  await tester.pump();
  _drainAssetException(tester);
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

  ScriptableJourneyCubit journeyCubit() {
    final cubit = ScriptableJourneyCubit();
    addTearDown(cubit.close);
    return cubit;
  }

  group('AC-3 — a set preference wins for display over the engine mode', () {
    testWidgets('preferenceCar_overridesEveryEngineMode', (tester) async {
      final game = JourneyGame();
      final journey = journeyCubit();
      final settings = settingsCubit(
        initialSettings: const AppSettings(vehiclePreference: TravelMode.car),
      );
      await _pump(
        tester,
        game: game,
        journeyCubit: journey,
        settings: settings,
      );

      // Vary the engine-derived mode; the displayed mode must stay the pick.
      for (final TravelMode engineMode in <TravelMode>[
        TravelMode.walk,
        TravelMode.ship,
        TravelMode.bicycle,
        TravelMode.car,
      ]) {
        await _push(tester, journey, _engineState(engineMode));
        expect(
          game.currentMode,
          TravelMode.car,
          reason: 'car preference wins over engine $engineMode',
        );
      }
      // Car is a cockpit mode — the branch resolves off the displayed value.
      expect(game.isCockpitActive, isTrue);
    });

    testWidgets('preferenceBicycle_sideViewMode_alsoWins', (tester) async {
      final game = JourneyGame();
      final journey = journeyCubit();
      final settings = settingsCubit(
        initialSettings: const AppSettings(
          vehiclePreference: TravelMode.bicycle,
        ),
      );
      await _pump(
        tester,
        game: game,
        journeyCubit: journey,
        settings: settings,
      );

      // Engine in a COCKPIT mode (car); a side-view pick must still win and the
      // cockpit branch must follow the displayed (bicycle) mode (AC-2).
      await _push(tester, journey, _engineState(TravelMode.car));
      expect(game.currentMode, TravelMode.bicycle);
      expect(game.isCockpitActive, isFalse);
    });
  });

  group('AC-4 — no preference → the engine-derived mode shows', () {
    testWidgets('nullPreference_displayedModeTracksTheEngineMode', (
      tester,
    ) async {
      final game = JourneyGame();
      final journey = journeyCubit();
      final settings = settingsCubit(); // default → vehiclePreference == null
      await _pump(
        tester,
        game: game,
        journeyCubit: journey,
        settings: settings,
      );

      for (final TravelMode engineMode in <TravelMode>[
        TravelMode.walk,
        TravelMode.car,
        TravelMode.ship,
        TravelMode.run,
      ]) {
        await _push(tester, journey, _engineState(engineMode));
        expect(
          game.currentMode,
          engineMode,
          reason: 'with no preference the engine mode shows',
        );
      }
    });

    testWidgets('firstLaunch_noStoredPreference_showsTheEngineDefaultMotorbike', (
      tester,
    ) async {
      // A fresh SettingsCubit (no stored preference → null) and the initial
      // engine view state (default motorbike) must open on motorbike (AC-4).
      final game = JourneyGame();
      final journey = journeyCubit();
      final settings = settingsCubit();
      await _pump(
        tester,
        game: game,
        journeyCubit: journey,
        settings: settings,
      );

      // Drive the engine's default initial state explicitly.
      await _push(
        tester,
        journey,
        _engineState(const JourneyViewState.initial().mode),
      );
      expect(game.currentMode, TravelMode.motorbike);
    });
  });

  group('AC-3/AC-4 — a live pick re-composes the displayed mode (≤1 frame)', () {
    testWidgets('settingThenClearingThePreference_swapsTheDisplayedMode', (
      tester,
    ) async {
      final game = JourneyGame();
      final journey = journeyCubit();
      final settings = settingsCubit(); // null → follows engine
      await _pump(
        tester,
        game: game,
        journeyCubit: journey,
        settings: settings,
      );

      // Engine on walk; no preference → walk shows.
      await _push(tester, journey, _engineState(TravelMode.walk));
      expect(game.currentMode, TravelMode.walk);

      // Pick car: the SettingsCubit emission re-applies the composed mode (AC-1).
      await settings.setVehicle(TravelMode.car);
      await tester.pump();
      await tester.pump();
      _drainAssetException(tester);
      expect(game.currentMode, TravelMode.car);
      expect(game.isCockpitActive, isTrue);

      // Clear the preference: display falls back to the engine mode (walk).
      await settings.setVehicle(null);
      await tester.pump();
      await tester.pump();
      _drainAssetException(tester);
      expect(game.currentMode, TravelMode.walk);
    });
  });
}
