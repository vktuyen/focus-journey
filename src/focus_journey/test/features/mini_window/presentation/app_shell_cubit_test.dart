// Smoke unit tests for the AppShellCubit wiring (mini-window slice). The formal
// suite is authored by unit-test-writer next; these confirm the cubit compiles,
// mirrors the controller's mode, drives enterCompact/showApp, and gates the
// one-time hide-to-tray hint (AC-17). Deterministic — uses the mock controller
// (NFR-8); no real OS window.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/mini_window/data/mock_window_mode_controller.dart';
import 'package:focus_journey/features/mini_window/domain/window_mode.dart';
import 'package:focus_journey/features/mini_window/presentation/app_shell_cubit.dart';

void main() {
  group('AppShellCubit', () {
    test('startsInControllerMode', () {
      final controller = MockWindowModeController();
      addTearDown(controller.dispose);
      final cubit = AppShellCubit(controller: controller);
      addTearDown(cubit.close);

      expect(cubit.state.mode, WindowMode.full);
      expect(cubit.state.showHideToTrayHint, isFalse);
    });

    test('enterCompact_drivesControllerAndMirrorsMode', () async {
      final controller = MockWindowModeController();
      addTearDown(controller.dispose);
      final cubit = AppShellCubit(controller: controller);
      addTearDown(cubit.close);

      await cubit.enterCompact();
      // The controller's modeChanges stream is async; allow it to propagate.
      await Future<void>.delayed(Duration.zero);

      expect(controller.calls, contains('enterCompact'));
      expect(controller.mode, WindowMode.compact);
      expect(cubit.state.mode, WindowMode.compact);
    });

    test('showApp_fromCompact_returnsToFull', () async {
      final controller = MockWindowModeController();
      addTearDown(controller.dispose);
      final cubit = AppShellCubit(controller: controller);
      addTearDown(cubit.close);

      await cubit.enterCompact();
      await Future<void>.delayed(Duration.zero);
      await cubit.showApp();
      await Future<void>.delayed(Duration.zero);

      expect(controller.mode, WindowMode.full);
      expect(cubit.state.mode, WindowMode.full);
    });

    test('onHiddenToTray_firstTime_showsHintAndAsksToPersist', () {
      final controller = MockWindowModeController();
      addTearDown(controller.dispose);
      final cubit = AppShellCubit(controller: controller);
      addTearDown(cubit.close);

      final shouldPersist = cubit.onHiddenToTray();

      expect(shouldPersist, isTrue);
      expect(cubit.state.showHideToTrayHint, isTrue);
    });

    test('onHiddenToTray_whenAlreadyShown_doesNotShowAgain', () {
      final controller = MockWindowModeController();
      addTearDown(controller.dispose);
      final cubit = AppShellCubit(
        controller: controller,
        hintAlreadyShown: true,
      );
      addTearDown(cubit.close);

      final shouldPersist = cubit.onHiddenToTray();

      expect(shouldPersist, isFalse);
      expect(cubit.state.showHideToTrayHint, isFalse);
    });

    test('onHiddenToTray_isOneTimeWithinSession', () {
      final controller = MockWindowModeController();
      addTearDown(controller.dispose);
      final cubit = AppShellCubit(controller: controller);
      addTearDown(cubit.close);

      expect(cubit.onHiddenToTray(), isTrue);
      cubit.dismissHideToTrayHint();
      // A second close in the same session must not re-show the hint (AC-17).
      expect(cubit.onHiddenToTray(), isFalse);
      expect(cubit.state.showHideToTrayHint, isFalse);
    });

    // --- Formal mode-mirror coverage (AC-6 / AC-14 / TC-006 / TC-007). The
    // cubit MUST reflect whichever single mode the controller reports, so the
    // shell (and, via the same stream, the tray/menu) stays in sync. ---

    test('fullToCompactToFull_mirrorsControllerModeChangesInOrder', () async {
      final controller = MockWindowModeController();
      addTearDown(controller.dispose);
      final cubit = AppShellCubit(controller: controller);
      addTearDown(cubit.close);

      final observed = <WindowMode>[];
      final sub = cubit.stream.listen((s) => observed.add(s.mode));
      addTearDown(sub.cancel);

      // full → compact
      await cubit.enterCompact();
      await Future<void>.delayed(Duration.zero);
      // compact → full (Show app dismisses the PiP — mutually exclusive)
      await cubit.showApp();
      await Future<void>.delayed(Duration.zero);

      // The cubit mirrored exactly the controller's transitions, in order.
      expect(observed, <WindowMode>[WindowMode.compact, WindowMode.full]);
      expect(cubit.state.mode, WindowMode.full);
    });

    test('showApp_whileAlreadyFull_doesNotEmitARedundantModeChange', () async {
      // TC-007 boundary: Show app from full mode foregrounds the window but does
      // NOT re-emit a mode change (the mode did not change), so the tray/menu is
      // not needlessly churned.
      final controller = MockWindowModeController();
      addTearDown(controller.dispose);
      final cubit = AppShellCubit(controller: controller);
      addTearDown(cubit.close);

      final observed = <WindowMode>[];
      final sub = cubit.stream.listen((s) => observed.add(s.mode));
      addTearDown(sub.cancel);

      await cubit.showApp();
      await Future<void>.delayed(Duration.zero);

      expect(observed, isEmpty);
      expect(controller.calls, contains('showApp'));
      expect(cubit.state.mode, WindowMode.full);
    });

    test('hint_isOrthogonalToMode_modeMirrorPreservesHintFlag', () async {
      // The one-time hint flag must survive a mode transition (copyWith only
      // overrides mode), so a queued first-run hint is not lost when the user
      // happens to enter compact.
      final controller = MockWindowModeController();
      addTearDown(controller.dispose);
      final cubit = AppShellCubit(controller: controller);
      addTearDown(cubit.close);

      expect(cubit.onHiddenToTray(), isTrue);
      expect(cubit.state.showHideToTrayHint, isTrue);

      await cubit.enterCompact();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.mode, WindowMode.compact);
      expect(cubit.state.showHideToTrayHint, isTrue);
    });
  });
}
