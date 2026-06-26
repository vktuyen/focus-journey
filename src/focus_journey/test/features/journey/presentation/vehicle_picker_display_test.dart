// Screen-level widget tests for the vehicle-picker COSMETIC DISPLAY OVERRIDE
// composed at the JourneyScreen presentation seam (ADR-0007). Authored by
// test-script-author from tests/cases/vehicle-picker.md. One group per case;
// each carries its TC-id + AC-id for traceability.
//
//   TC-601 (AC-1 / NFR-1) — a pick changes the displayed vehicle within ≤1 frame:
//                  the next applyState hands the chosen mode `m` to the scene, so
//                  JourneyGame.currentMode == m AND currentVehicleAsset resolves
//                  to m's skin — on the emission triggered by the pick.
//   TC-602 (AC-2) — the cockpit-vs-side-view branch resolves off the DISPLAYED
//                  (overridden) mode, not the engine mode: car-over-walk shows the
//                  car cockpit (isCockpitActive == true); bicycle-over-car shows
//                  the bicycle side-view (isCockpitActive == false). No split-brain.
//   TC-603 (AC-3) — a set preference WINS for display regardless of the engine
//                  mode: with vehiclePreference == p, every engine mode still
//                  yields currentMode == p.
//   TC-604 (AC-4) — no preference → the displayed mode follows the engine mode;
//                  a fresh first launch (no stored preference) shows the engine
//                  default (motorbike). _proposed-resolution leg (see the case)._
//   TC-606p (AC-6) — a restored preference seeds the displayed mode BEFORE the
//                  first applyState: the scene opens on the restored mode.
//   TC-616 (NFR-1 runtime half) — the override is composed at/above the view
//                  state; driving many frames with a preference set leaves the
//                  scene's per-frame contract unchanged (currentMode stays the
//                  composed value; pumping does not throw / re-resolve).
//
// The override seam is `JourneyScreen._applyToScene`:
//     mode: _readVehiclePreference(context) ?? s.mode
// composed at/above JourneyViewState and handed to JourneyGame.applyState — the
// scene takes ONE `mode:` value. These tests drive the REAL JourneyScreen with a
// real JourneyCubit + real SettingsCubit and an injected motion-only JourneyGame
// (no sprite load, no OS, no timers), then assert the game's currentMode /
// isCockpitActive / currentVehicleAsset seams (journey-pov), exactly as the cases
// require. No wall-clock waits — a pick lands on the next emission's pump.

import 'package:flame/game.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/clock.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_game.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_skins.dart';
import 'package:focus_journey/features/journey/presentation/journey_cubit.dart';
import 'package:focus_journey/features/journey/presentation/journey_screen.dart';
import 'package:focus_journey/features/journey/presentation/journey_view_state.dart';
import 'package:focus_journey/features/stats/domain/app_settings.dart';
import 'package:focus_journey/features/stats/presentation/settings_cubit.dart';

import '../../stats/stats_test_fixtures.dart';

/// A cubit whose state we drive directly (scriptable — no engine/OS/timers).
class _ScriptableJourneyCubit extends JourneyCubit {
  void push(JourneyViewState state) => emit(state);
}

/// A fixed-noon clock (the tint hour only — never a motion decision).
class _FixedClock implements Clock {
  _FixedClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

final DateTime _noon = DateTime(2026, 6, 26, 12);

JourneyViewState _engineView(
  TravelMode engineMode, {
  JourneyMotion motion = JourneyMotion.moving,
}) => JourneyViewState(
  motion: motion,
  mode: engineMode,
  distanceKm: 1,
  hasRealState: true,
);

/// Builds a motion-only [JourneyGame] (no sprite load — the cosmetic seams
/// currentMode / isCockpitActive / currentVehicleAsset are derived from `_mode`
/// and need no images).
JourneyGame _motionGame() {
  final JourneyGame game = JourneyGame();
  game.onGameResize(Vector2(800, 600));
  return game;
}

/// The expected per-mode sprite path (journey-pov skin), so currentVehicleAsset
/// can be asserted to resolve off the COMPOSED mode (not the engine mode).
String _skinFor(TravelMode mode) => JourneySkins.of(mode).assetPath;

/// Mounts the real JourneyScreen wired to a real SettingsCubit + a scriptable
/// JourneyCubit, with an injected motion game. Returns the game + both cubits.
Future<({JourneyGame game, _ScriptableJourneyCubit journey, SettingsCubit settings})>
    _pumpScreen(
  WidgetTester tester, {
  AppSettings? initialSettings,
}) async {
  final JourneyGame game = _motionGame();
  final journey = _ScriptableJourneyCubit();
  addTearDown(journey.close);
  final settings = SettingsCubit(
    repository: InMemorySettingsRepository(),
    startupController: FakeStartupController(),
    applyIdleThreshold: (_) {},
    initialSettings: initialSettings,
  );
  addTearDown(settings.close);

  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(),
      child: MaterialApp(
        home: MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<JourneyCubit>.value(value: journey),
            BlocProvider<SettingsCubit>.value(value: settings),
          ],
          child: JourneyScreen(
            clock: _FixedClock(_noon),
            gameFactory: () => game,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return (game: game, journey: journey, settings: settings);
}

/// Pushes a journey-state emission and pumps twice (the Cubit stream microtask +
/// the rebuild) so the BlocListener drives applyState. No wall-clock wait.
Future<void> _pushEngine(
  WidgetTester tester,
  _ScriptableJourneyCubit journey,
  JourneyViewState state,
) async {
  journey.push(state);
  await tester.pump();
  await tester.pump();
}

/// Picks a vehicle via the SettingsCubit (the same write both pickers make) and
/// pumps twice so the vehicle-preference BlocListener re-applies the composed
/// mode (≤1 frame == the emission triggered by the pick).
Future<void> _pick(
  WidgetTester tester,
  SettingsCubit settings,
  TravelMode? mode,
) async {
  await settings.setVehicle(mode);
  await tester.pump();
  await tester.pump();
}

void main() {
  // ===========================================================================
  // TC-601 (AC-1 / NFR-1) — a pick changes the displayed vehicle within ≤1 frame.
  // ===========================================================================
  group('TC-601 pick → displayed vehicle swaps on the next emission (AC-1)', () {
    testWidgets('pick_m_makesCurrentMode_m_andSpriteResolveToM', (tester) async {
      final s = await _pumpScreen(tester);
      // Engine-derived mode is `walk`; no preference yet → scene follows engine.
      await _pushEngine(tester, s.journey, _engineView(TravelMode.walk));
      expect(s.game.currentMode, TravelMode.walk);

      // The user picks `car` (m != engine mode). On the emission triggered by the
      // pick, the composed mode becomes car and the next applyState hands it on.
      await _pick(tester, s.settings, TravelMode.car);

      expect(s.game.currentMode, TravelMode.car);
      expect(s.game.currentVehicleAsset, _skinFor(TravelMode.car));
    });

    testWidgets('everyPick_swapsBothCurrentModeAndSprite', (tester) async {
      final s = await _pumpScreen(tester);
      await _pushEngine(tester, s.journey, _engineView(TravelMode.motorbike));
      for (final TravelMode m in TravelMode.values) {
        await _pick(tester, s.settings, m);
        expect(s.game.currentMode, m, reason: 'composed mode must become $m');
        expect(s.game.currentVehicleAsset, _skinFor(m));
      }
    });
  });

  // ===========================================================================
  // TC-602 (AC-2) — cockpit branch resolves off the DISPLAYED (overridden) mode.
  // ===========================================================================
  group('TC-602 cockpit branch follows the displayed mode, no split-brain (AC-2)', () {
    testWidgets('engineWalk_pickCar_showsCarCockpit', (tester) async {
      final s = await _pumpScreen(tester);
      // Engine mode is a SIDE-VIEW mode (walk).
      await _pushEngine(tester, s.journey, _engineView(TravelMode.walk));
      expect(s.game.isCockpitActive, isFalse);

      // Pick car → displayed mode is car: cockpit active + car sprite.
      await _pick(tester, s.settings, TravelMode.car);
      expect(s.game.currentMode, TravelMode.car);
      expect(s.game.isCockpitActive, isTrue);
      expect(s.game.currentVehicleAsset, _skinFor(TravelMode.car));
    });

    testWidgets('engineCar_pickBicycle_showsBicycleSideView', (tester) async {
      final s = await _pumpScreen(tester);
      // Engine mode is a COCKPIT mode (car).
      await _pushEngine(tester, s.journey, _engineView(TravelMode.car));
      expect(s.game.isCockpitActive, isTrue);

      // Pick bicycle → displayed mode is bicycle: side-view, no cockpit.
      await _pick(tester, s.settings, TravelMode.bicycle);
      expect(s.game.currentMode, TravelMode.bicycle);
      expect(s.game.isCockpitActive, isFalse);
      expect(s.game.currentVehicleAsset, _skinFor(TravelMode.bicycle));
    });
  });

  // ===========================================================================
  // TC-603 (AC-3) — a set preference WINS for display regardless of engine mode.
  // ===========================================================================
  group('TC-603 a set preference wins for display every emission (AC-3)', () {
    for (final TravelMode p in <TravelMode>[TravelMode.car, TravelMode.bicycle]) {
      testWidgets('preference_${p.name}_winsAcrossVaryingEngineModes', (
        tester,
      ) async {
        final s = await _pumpScreen(
          tester,
          initialSettings: AppSettings(vehiclePreference: p),
        );
        // Vary the engine-derived mode across several values; the displayed mode
        // must stay `p` at every emission (precedence p ?? engineMode → p).
        for (final TravelMode engineMode in <TravelMode>[
          TravelMode.walk,
          TravelMode.car,
          TravelMode.ship,
          TravelMode.run,
          TravelMode.motorbike,
        ]) {
          await _pushEngine(tester, s.journey, _engineView(engineMode));
          expect(
            s.game.currentMode,
            p,
            reason: 'pref $p must win over engine $engineMode',
          );
          expect(s.game.currentVehicleAsset, _skinFor(p));
        }
      });
    }
  });

  // ===========================================================================
  // TC-604 (AC-4) — no preference → engine mode; first launch shows motorbike.
  // ===========================================================================
  group('TC-604 no preference follows engine; first launch = motorbike (AC-4)', () {
    testWidgets('nullPreference_displayedModeTracksTheEngineMode', (
      tester,
    ) async {
      // No stored preference (vehiclePreference == null).
      final s = await _pumpScreen(tester);
      for (final TravelMode engineMode in TravelMode.values) {
        await _pushEngine(tester, s.journey, _engineView(engineMode));
        expect(
          s.game.currentMode,
          engineMode,
          reason: 'with no preference the display follows the engine mode',
        );
      }
    });

    testWidgets('firstLaunch_noStoredPreference_showsEngineDefaultMotorbike', (
      tester,
    ) async {
      // Fresh first launch: default settings (vehiclePreference == null) and a
      // fresh JourneyCubit at JourneyViewState.initial (engine default motorbike,
      // pre-state). The composed displayed mode is motorbike before any pick.
      final JourneyGame game = _motionGame();
      final journey = JourneyCubit(); // initial(): motorbike, hasRealState false
      addTearDown(journey.close);
      final settings = SettingsCubit(
        repository: InMemorySettingsRepository(),
        startupController: FakeStartupController(),
        applyIdleThreshold: (_) {},
      );
      addTearDown(settings.close);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: MaterialApp(
            home: MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<JourneyCubit>.value(value: journey),
                BlocProvider<SettingsCubit>.value(value: settings),
              ],
              child: JourneyScreen(
                clock: _FixedClock(_noon),
                gameFactory: () => game,
              ),
            ),
          ),
        ),
      );
      // Pump so the BlocListener applies the initial state once.
      await tester.pump();
      await tester.pump();
      expect(
        game.currentMode,
        TravelMode.motorbike,
        reason: 'first launch shows the engine default (motorbike) until a pick',
      );
    });
  });

  // ===========================================================================
  // TC-606p (AC-6) — a restored preference seeds the display before first apply.
  // ===========================================================================
  group('TC-606p restored preference seeds the display before first apply (AC-6)', () {
    testWidgets('restoredPreference_opensTheSceneOnTheRestoredMode', (
      tester,
    ) async {
      // A prior session saved vehiclePreference == ship → the SettingsCubit is
      // constructed from that restored value, seeding the display before the
      // first applyState (the very first emission composes ship, not the default).
      final s = await _pumpScreen(
        tester,
        initialSettings: const AppSettings(vehiclePreference: TravelMode.ship),
      );
      // First real engine emission (engine default motorbike); the restored
      // preference must already win the very first composed displayed mode.
      await _pushEngine(tester, s.journey, _engineView(TravelMode.motorbike));
      expect(
        s.game.currentMode,
        TravelMode.ship,
        reason: 'the restored preference seeds the display ahead of the engine',
      );
      expect(s.game.currentVehicleAsset, _skinFor(TravelMode.ship));
    });
  });

  // ===========================================================================
  // TC-616 (NFR-1 runtime half) — many frames with a preference set keep the
  // scene's per-frame contract unchanged (no re-resolve / no throw per frame).
  // ===========================================================================
  group('TC-616 override is composed above the scene; per-frame contract holds (NFR-1)', () {
    testWidgets('pumpingManyFrames_withPreferenceSet_keepsComposedMode', (
      tester,
    ) async {
      final s = await _pumpScreen(
        tester,
        initialSettings: const AppSettings(vehiclePreference: TravelMode.car),
      );
      await _pushEngine(tester, s.journey, _engineView(TravelMode.walk));
      expect(s.game.currentMode, TravelMode.car);

      // Advance many scene frames directly (the per-frame loop). The composed
      // mode is fixed once at applyState; the scene does NOT re-resolve the
      // preference per frame, so currentMode is invariant and pumping is safe.
      expect(() {
        for (int i = 0; i < 120; i++) {
          s.game.update(1 / 60);
        }
      }, returnsNormally);
      expect(
        s.game.currentMode,
        TravelMode.car,
        reason: 'the scene re-resolves nothing per frame; the mode is fixed',
      );
    });
  });
}
