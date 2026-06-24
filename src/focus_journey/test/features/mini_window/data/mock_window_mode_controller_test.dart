// Deterministic unit tests for the mock WindowModeController behaviour model.
//
// Scope (mock path — NFR-8): enter-compact transition (TC-006), close-to-tray
// keeps process/visible model + PiP-not-auto-shown (TC-014 / AC-18), Show-app
// dismisses PiP (AC-16), always-on-top flag (TC-014-AOT), geometry persist +
// clamp via the repo seam (TC-019-POS), Quit flush + full-exit only via Quit
// (AC-16). No real OS window.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/mini_window/data/mock_window_mode_controller.dart';
import 'package:focus_journey/features/mini_window/domain/compact_geometry.dart';
import 'package:focus_journey/features/mini_window/domain/compact_window_position_repository.dart';
import 'package:focus_journey/features/mini_window/domain/window_mode.dart';
import 'package:focus_journey/features/mini_window/domain/window_position.dart';

/// In-memory position repository for the mock controller tests.
class _FakePositionRepo implements CompactWindowPositionRepository {
  WindowPosition? stored;

  @override
  Future<WindowPosition?> load() async => stored;

  @override
  Future<void> save(WindowPosition position) async => stored = position;
}

void main() {
  group('MockWindowModeController', () {
    test('startsInFullMode', () {
      final c = MockWindowModeController();
      expect(c.mode, WindowMode.full);
      expect(c.visible, isTrue);
    });

    test('enterCompact_setsCompactModeAlwaysOnTopAndEmits', () async {
      final c = MockWindowModeController();
      final emitted = <WindowMode>[];
      c.modeChanges.listen(emitted.add);

      await c.enterCompact();

      expect(c.mode, WindowMode.compact);
      expect(c.alwaysOnTop, isTrue);
      expect(c.visible, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(emitted, contains(WindowMode.compact));
      await c.dispose();
    });

    test('hideToTray_processStaysAlive_pipNotAutoShown', () async {
      final c = MockWindowModeController();
      await c.hideToTray();
      // Window hidden, but mode unchanged (no PiP auto-show — AC-18).
      expect(c.visible, isFalse);
      expect(c.mode, WindowMode.full);
      expect(c.didQuit, isFalse); // close != quit (AC-16)
    });

    test('showApp_fromCompact_dismissesPip_returnsToFull', () async {
      final c = MockWindowModeController();
      await c.enterCompact();
      await c.showApp();
      expect(c.mode, WindowMode.full); // mutually exclusive (AC-16)
      expect(c.alwaysOnTop, isFalse);
      await c.dispose();
    });

    test('setAlwaysOnTop_togglesFlag', () async {
      final c = MockWindowModeController();
      await c.setAlwaysOnTop(true);
      expect(c.alwaysOnTop, isTrue);
      await c.setAlwaysOnTop(false);
      expect(c.alwaysOnTop, isFalse);
    });

    test('enterCompact_clampsSavedPositionViaRepoSeam', () async {
      final repo = _FakePositionRepo()
        ..stored = const WindowPosition(x: -9999, y: -9999);
      final c = MockWindowModeController(
        positionRepository: repo,
        displays: const <VisibleDisplay>[
          VisibleDisplay(left: 0, top: 0, width: 1440, height: 900),
        ],
      );
      await c.enterCompact();
      // Off-screen saved position is clamped onto the visible display.
      expect(c.currentPosition.x, greaterThanOrEqualTo(0));
      expect(c.currentPosition.y, greaterThanOrEqualTo(0));
      expect(
        c.currentPosition.x + CompactGeometry.width,
        lessThanOrEqualTo(1440),
      );
    });

    test('persistCompactPosition_savesCurrentToRepo', () async {
      final repo = _FakePositionRepo();
      final c = MockWindowModeController(positionRepository: repo)
        ..currentPosition = const WindowPosition(x: 120, y: 80);
      await c.persistCompactPosition();
      expect(repo.stored, const WindowPosition(x: 120, y: 80));
    });

    test('quit_runsFlushHook_thenFullExit', () async {
      final c = MockWindowModeController();
      var flushed = false;
      c.onBeforeQuit(() async => flushed = true);
      await c.quit();
      expect(flushed, isTrue); // AC-16 Quit flushes state
      expect(c.didQuit, isTrue);
    });
  });
}
