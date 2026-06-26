// journey-scene-v2 #5 (AC-3/AC-4/AC-5) — the per-surface visibility-driven
// animate/pause logic, against an INJECTED MockWindowVisibilityController.
//
// These prove the LOGIC (occlusion gates animation, NOT focus), not the real OS
// occlusion API (that is the manual [REAL-OS] triad TC-M1/TC-M2/TC-M3). Frames
// and visibility are driven deterministically — no real timers, no real window.
//
// Reconciliation with the single-window two-mode model (ADR-0003): the shell
// gates off the CURRENTLY-SHOWN surface — main in full mode, pip in compact.
// AC-5 per-surface independence is exercised by switching the shown surface and
// flipping each surface's visibility independently.

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
import 'package:focus_journey/features/window_visibility/data/mock_window_visibility_controller.dart';
import 'package:focus_journey/features/window_visibility/domain/surface_visibility.dart';

class _ScriptableJourneyCubit extends JourneyCubit {
  void push(JourneyViewState state) => emit(state);
}

class _FixedClock implements Clock {
  _FixedClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

void _drainAssetException(WidgetTester tester) {
  final ex = tester.takeException();
  if (ex != null && !ex.toString().contains('Unable to load asset')) {
    throw ex as Object;
  }
}

JourneyViewState _moving() => const JourneyViewState(
  motion: JourneyMotion.moving,
  mode: TravelMode.motorbike,
  distanceKm: 3.0,
  hasRealState: true,
);

Future<({JourneyGame game, _ScriptableJourneyCubit cubit, AppShellCubit shell})>
_pumpShell(
  WidgetTester tester, {
  required MockWindowVisibilityController visibility,
}) async {
  final controller = MockWindowModeController();
  addTearDown(controller.dispose);
  final cubit = _ScriptableJourneyCubit();
  addTearDown(cubit.close);
  final shellCubit = AppShellCubit(controller: controller);
  addTearDown(shellCubit.close);
  final game = JourneyGame();

  await tester.pumpWidget(
    MaterialApp(
      home: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<JourneyCubit>.value(value: cubit),
          BlocProvider<AppShellCubit>.value(value: shellCubit),
        ],
        child: AppShell(
          clock: _FixedClock(DateTime(2026, 6, 24, 12)),
          controller: controller,
          visibility: visibility,
          gameFactory: () => game,
          fullBuilder: (g) => Scaffold(body: GameWidget<JourneyGame>(game: g)),
        ),
      ),
    ),
  );
  await tester.pump();
  _drainAssetException(tester);
  return (game: game, cubit: cubit, shell: shellCubit);
}

void main() {
  group('AC-3 animate when visible-but-unfocused', () {
    testWidgets('mainVisible_active_runsEvenWhenFocusElsewhere', (
      tester,
    ) async {
      // visible main; "another app has focus" is modelled by NOT touching the
      // app lifecycle (the shell no longer gates on focus).
      final vis = MockWindowVisibilityController(mainVisible: true);
      addTearDown(vis.dispose);
      final h = await _pumpShell(tester, visibility: vis);

      h.cubit.push(_moving());
      await tester.pump();
      await tester.pump();
      _drainAssetException(tester);

      expect(
        h.game.paused,
        isFalse,
        reason: 'visible + active must animate even when unfocused (AC-3)',
      );
      // And it actually advances.
      final before = h.game.roadScrollOffset;
      for (var i = 0; i < 30; i++) {
        h.game.update(1 / 60);
      }
      expect(h.game.roadScrollOffset, greaterThan(before));
    });
  });

  group('AC-4 pause when not visible (frozen, no per-frame work)', () {
    for (final variant in <String>['hidden', 'minimized', 'tray']) {
      testWidgets('notVisible_${variant}_active_pauses', (tester) async {
        final vis = MockWindowVisibilityController(mainVisible: true);
        addTearDown(vis.dispose);
        final h = await _pumpShell(tester, visibility: vis);

        h.cubit.push(_moving());
        await tester.pump();
        await tester.pump();
        _drainAssetException(tester);
        expect(h.game.paused, isFalse);

        // The OS reports the (single) main surface is no longer on screen —
        // hidden / minimized / hidden-to-tray all collapse to visible=false.
        vis.setVisible(WindowSurface.main, false);
        await tester.pump();
        await tester.pump();
        _drainAssetException(tester);

        expect(
          h.game.paused,
          isTrue,
          reason: 'not-visible while active must pause (AC-4 / $variant)',
        );
        // Offset frozen and no per-frame work (a paused game advances nothing).
        final frozen = h.game.roadScrollOffset;
        h.game.update(1 / 60);
        expect(h.game.roadScrollOffset, frozen);
      });
    }

    testWidgets('returnsToVisible_resumes', (tester) async {
      final vis = MockWindowVisibilityController(mainVisible: true);
      addTearDown(vis.dispose);
      final h = await _pumpShell(tester, visibility: vis);
      h.cubit.push(_moving());
      await tester.pump();
      await tester.pump();
      _drainAssetException(tester);

      vis.setVisible(WindowSurface.main, false);
      await tester.pump();
      await tester.pump();
      expect(h.game.paused, isTrue);

      vis.setVisible(WindowSurface.main, true);
      await tester.pump();
      await tester.pump();
      _drainAssetException(tester);
      expect(h.game.paused, isFalse, reason: 'resume when visible again');
    });
  });

  group('AC-5 per-surface — one visible, the other hidden', () {
    testWidgets('compactShown_gatesOnPip_notMain', (tester) async {
      // Main hidden, pip visible. In compact mode the SHOWN surface is the pip,
      // so the scene animates even though main is hidden.
      final vis = MockWindowVisibilityController(
        mainVisible: false,
        pipVisible: true,
      );
      addTearDown(vis.dispose);
      final h = await _pumpShell(tester, visibility: vis);

      h.cubit.push(_moving());
      await tester.pump();
      await tester.pump();
      _drainAssetException(tester);
      // Full mode: gates on main (hidden) → paused.
      expect(h.game.paused, isTrue, reason: 'full mode gates on main (hidden)');

      // Switch to compact: now the shown surface is the pip (visible) → runs.
      await h.shell.enterCompact();
      await tester.pump();
      await tester.pump();
      _drainAssetException(tester);
      expect(
        h.game.paused,
        isFalse,
        reason: 'compact gates on pip (visible) — per-surface (AC-5)',
      );

      // Now hide the pip while compact → pause; main visibility is irrelevant.
      vis.setVisible(WindowSurface.pip, false);
      await tester.pump();
      await tester.pump();
      _drainAssetException(tester);
      expect(
        h.game.paused,
        isTrue,
        reason: 'compact gates on pip (now hidden)',
      );
    });
  });
}
