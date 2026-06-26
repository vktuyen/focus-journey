// End-to-end (mock-path) integration test for the vehicle picker. Authored by
// test-script-author from tests/cases/vehicle-picker.md. Runs the REAL widget
// tree with deterministic in-memory fakes (no real OS, no real timers, no real
// shared_preferences, no network). The mock-path twin of the manual real-OS legs.
//
//   TC-618 (AC-1 / AC-6 / AC-11 / AC-13) — pick in the persistent picker reflects
//                  on the shared scene within a frame (car cockpit appears); a
//                  route-start pick (ship) propagates to the displayed mode and is
//                  written to the SINGLE preference; both pickers stay in sync off
//                  that one preference; after a "relaunch" (reconstruct the
//                  SettingsCubit from the persisted settings) the scene opens on
//                  ship (restored before the first applyState).
//
// Runs headless under `flutter test` and on a desktop device:
//   fvm flutter test integration_test/vehicle_picker_two_surface_test.dart
//   fvm flutter test integration_test/vehicle_picker_two_surface_test.dart -d macos

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
import 'package:focus_journey/features/stats/domain/stats_repositories.dart';
import 'package:focus_journey/features/stats/presentation/settings_cubit.dart';
import 'package:focus_journey/features/stats/presentation/vehicle_picker.dart';
import 'package:integration_test/integration_test.dart';

/// Binding-aware in-memory SettingsRepository (round-trips through JSON, like the
/// real shared_preferences repo) — a "relaunch" reloads exactly what was saved.
class _FakeSettingsRepo implements SettingsRepository {
  _FakeSettingsRepo([AppSettings? seed]) : _stored = seed;
  AppSettings? _stored;
  @override
  Future<AppSettings?> load() async => _stored;
  @override
  Future<void> save(AppSettings settings) async {
    _stored = AppSettings.fromJson(settings.toJson());
  }

  AppSettings? get stored => _stored;
}

class _FakeStartup implements StartupController {
  @override
  Future<bool> isEnabled() async => false;
  @override
  Future<void> setEnabled(bool enabled) async {}
}

class _FixedClock implements Clock {
  _FixedClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

/// A scriptable JourneyCubit so we drive the engine-derived mode deterministically.
class _ScriptableJourneyCubit extends JourneyCubit {
  void push(JourneyViewState state) => emit(state);
}

JourneyGame _motionGame() {
  final JourneyGame game = JourneyGame()..onGameResize(Vector2(800, 600));
  return game;
}

String _skinFor(TravelMode mode) => JourneySkins.of(mode).assetPath;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'TC-618 pick reflects on the shared scene; route-start propagates; relaunch '
    'restores (AC-1/AC-6/AC-11/AC-13)',
    (tester) async {
      final repo = _FakeSettingsRepo();
      final settings = SettingsCubit(
        repository: repo,
        startupController: _FakeStartup(),
        applyIdleThreshold: (_) {},
      );
      addTearDown(settings.close);

      final journey = _ScriptableJourneyCubit();
      addTearDown(journey.close);

      // The ONE shared JourneyGame (ADR-0003) the journey surface renders.
      final JourneyGame sharedGame = _motionGame();

      // Mount the real journey surface (standalone-owned game via gameFactory so
      // the screen drives applyState from BOTH cubits within ≤1 frame) plus the
      // persistent vehicle picker + a route-start picker, all on ONE SettingsCubit.
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: MaterialApp(
            home: MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<JourneyCubit>.value(value: journey),
                BlocProvider<SettingsCubit>.value(value: settings),
              ],
              child: Scaffold(
                body: Column(
                  children: <Widget>[
                    SizedBox(
                      height: 300,
                      child: JourneyScreen(
                        clock: _FixedClock(DateTime(2026, 6, 26, 12)),
                        gameFactory: () => sharedGame,
                      ),
                    ),
                    BlocBuilder<SettingsCubit, AppSettings>(
                      builder: (context, s) {
                        final selected =
                            s.vehiclePreference ?? TravelMode.motorbike;
                        return Column(
                          children: <Widget>[
                            VehiclePicker(
                              key: const Key('persistent-picker'),
                              selected: selected,
                              onSelected: settings.setVehicle,
                            ),
                            VehiclePicker(
                              key: const Key('routestart-picker'),
                              selected: selected,
                              onSelected: settings.setVehicle,
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // Drain any expected Flame missing-asset orphan rejection.
      final ex0 = tester.takeException();
      if (ex0 != null && !ex0.toString().contains('Unable to load asset')) {
        throw ex0 as Object;
      }

      // The engine-derived mode is `walk` (a side-view mode); no preference yet
      // → the shared scene follows the engine default.
      journey.push(
        const JourneyViewState(
          motion: JourneyMotion.moving,
          mode: TravelMode.walk,
          distanceKm: 1,
          hasRealState: true,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(sharedGame.currentMode, TravelMode.walk);
      expect(sharedGame.isCockpitActive, isFalse);

      // 1) Pick CAR in the persistent picker → the car cockpit appears on the
      //    shared scene within a frame (AC-1/AC-2), both pickers reflect car.
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('persistent-picker')),
          matching: find.byKey(const Key('vehicle-chip-car')),
        ),
      );
      await tester.pumpAndSettle();
      expect(settings.state.vehiclePreference, TravelMode.car);
      expect(sharedGame.currentMode, TravelMode.car);
      expect(sharedGame.isCockpitActive, isTrue);
      expect(sharedGame.currentVehicleAsset, _skinFor(TravelMode.car));

      // 2) Change via the ROUTE-START picker to SHIP → propagates to the displayed
      //    mode on the shared scene; the SINGLE preference becomes ship (AC-11/AC-13).
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('routestart-picker')),
          matching: find.byKey(const Key('vehicle-chip-ship')),
        ),
      );
      await tester.pumpAndSettle();
      expect(settings.state.vehiclePreference, TravelMode.ship);
      expect(sharedGame.currentMode, TravelMode.ship);
      expect(sharedGame.isCockpitActive, isFalse);
      expect(sharedGame.currentVehicleAsset, _skinFor(TravelMode.ship));

      // The pick was persisted (a relaunch will reload it).
      expect(repo.stored?.vehiclePreference, TravelMode.ship);

      // 3) "Relaunch": reconstruct the SettingsCubit from the persisted settings
      //    and assert the restored preference seeds the display BEFORE first apply.
      final reloaded = await repo.load();
      final relaunchedSettings = SettingsCubit(
        repository: repo,
        startupController: _FakeStartup(),
        applyIdleThreshold: (_) {},
        initialSettings: reloaded,
      );
      addTearDown(relaunchedSettings.close);

      final relaunchedJourney = _ScriptableJourneyCubit();
      addTearDown(relaunchedJourney.close);
      final JourneyGame relaunchedGame = _motionGame();

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: MaterialApp(
            home: MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<JourneyCubit>.value(value: relaunchedJourney),
                BlocProvider<SettingsCubit>.value(value: relaunchedSettings),
              ],
              child: Scaffold(
                body: SizedBox(
                  height: 300,
                  child: JourneyScreen(
                    clock: _FixedClock(DateTime(2026, 6, 26, 12)),
                    gameFactory: () => relaunchedGame,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final ex1 = tester.takeException();
      if (ex1 != null && !ex1.toString().contains('Unable to load asset')) {
        throw ex1 as Object;
      }

      // First real engine emission after relaunch (engine default motorbike); the
      // restored ship preference must already win the very first composed mode.
      relaunchedJourney.push(
        const JourneyViewState(
          motion: JourneyMotion.moving,
          mode: TravelMode.motorbike,
          distanceKm: 1,
          hasRealState: true,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(
        relaunchedGame.currentMode,
        TravelMode.ship,
        reason: 'after relaunch the scene opens on the restored ship preference',
      );
    },
  );
}
