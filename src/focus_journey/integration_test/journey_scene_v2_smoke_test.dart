// E2E smoke (journey-scene-v2 TC-013): the mock-driven scene on the AppShell
// scrolls SLOWER than v1, keeps animating while visible-but-unfocused, pauses
// when not-visible, parks on idle, and resumes — on the REAL widget tree through
// the AppShell wiring, with a deterministic MockWindowVisibilityController (NO
// real OS occlusion). The mock-path twin of the manual [REAL-OS] triad.
//
// Covers AC-1 / AC-3 / AC-4 / AC-5 / AC-10 end to end. Frames are pumped by the
// harness; journey state via a scriptable cubit; visibility via the mock.
//
// Run on a desktop device, or headless under `flutter test`:
//   fvm flutter test integration_test/journey_scene_v2_smoke_test.dart -d macos

import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/clock.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_assets.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_game.dart';
import 'package:focus_journey/features/journey/presentation/game/scene_motion.dart';
import 'package:focus_journey/features/journey/presentation/journey_cubit.dart';
import 'package:focus_journey/features/journey/presentation/journey_view_state.dart';
import 'package:focus_journey/features/mini_window/data/mock_window_mode_controller.dart';
import 'package:focus_journey/features/mini_window/presentation/app_shell.dart';
import 'package:focus_journey/features/mini_window/presentation/app_shell_cubit.dart';
import 'package:focus_journey/features/window_visibility/data/mock_window_visibility_controller.dart';
import 'package:focus_journey/features/window_visibility/domain/surface_visibility.dart';
import 'package:integration_test/integration_test.dart';

class _ScriptableJourneyCubit extends JourneyCubit {
  void push(JourneyViewState s) => emit(s);
}

class _FixedClock implements Clock {
  const _FixedClock();
  @override
  DateTime now() => DateTime(2026, 6, 24, 12);
}

JourneyViewState _moving() => const JourneyViewState(
  motion: JourneyMotion.moving,
  mode: TravelMode.motorbike,
  distanceKm: 5.0,
  hasRealState: true,
);

JourneyViewState _idle() => const JourneyViewState(
  motion: JourneyMotion.stopped,
  mode: TravelMode.motorbike,
  distanceKm: 5.0,
  hasRealState: true,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late final ui.Image stub;
  setUpAll(() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 1, 1),
      ui.Paint()..color = const Color(0xFF888888),
    );
    stub = await recorder.endRecording().toImage(1, 1);
  });

  testWidgets('TC-013 mock-driven flow on the shared game across visibility', (
    tester,
  ) async {
    final controller = MockWindowModeController();
    addTearDown(controller.dispose);
    final cubit = _ScriptableJourneyCubit();
    addTearDown(cubit.close);
    final shellCubit = AppShellCubit(controller: controller);
    addTearDown(shellCubit.close);
    final vis = MockWindowVisibilityController(mainVisible: true);
    addTearDown(vis.dispose);

    late JourneyGame game;
    JourneyGame makeGame() {
      game = JourneyGame();
      for (final path in JourneyAssets.all) {
        game.images.add(path, stub);
      }
      return game;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<JourneyCubit>.value(value: cubit),
            BlocProvider<AppShellCubit>.value(value: shellCubit),
          ],
          child: AppShell(
            clock: const _FixedClock(),
            controller: controller,
            visibility: vis,
            gameFactory: makeGame,
            fullBuilder: (g) => Scaffold(body: GameWidget<JourneyGame>(game: g)),
          ),
        ),
      ),
    );
    await tester.pump();
    tester.takeException();

    // 1) Active + visible-but-unfocused → animates at the SLOWER v2 rate.
    cubit.push(_moving());
    await tester.pump();
    await tester.pump();
    tester.takeException();
    expect(game.paused, isFalse);
    expect(game.renderedCruiseSpeed, lessThan(kV1CruiseSpeed));
    final before = game.roadScrollOffset;
    for (var i = 0; i < 120; i++) {
      game.update(1 / 60);
    }
    expect(game.roadScrollOffset, greaterThan(before));

    // 2) Not visible → pauses (frozen, no per-frame work).
    vis.setVisible(WindowSurface.main, false);
    await tester.pump();
    await tester.pump();
    tester.takeException();
    expect(game.paused, isTrue);
    final frozen = game.roadScrollOffset;
    game.update(1 / 60);
    expect(game.roadScrollOffset, frozen);

    // 3) Visible again → resumes.
    vis.setVisible(WindowSurface.main, true);
    await tester.pump();
    await tester.pump();
    tester.takeException();
    expect(game.paused, isFalse);

    // 4) Idle → parks (paused), even though the surface is still visible.
    cubit.push(_idle());
    await tester.pump();
    await tester.pump();
    tester.takeException();
    expect(game.paused, isTrue, reason: 'idle parks regardless of visibility');

    // 5) Active + visible again → resumes at the slower rate.
    cubit.push(_moving());
    await tester.pump();
    await tester.pump();
    tester.takeException();
    expect(game.paused, isFalse);
  });
}
