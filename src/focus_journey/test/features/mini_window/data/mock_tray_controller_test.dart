// Deterministic unit tests for the mock TrayController behaviour model.
//
// Scope (mock path — NFR-8): tray reflects state (AC-11 / TC-011), menu actions
// emit on the action stream (AC-12 / TC-012 / TC-018), mode-aware menu (AC-14),
// status line (AC-13). No real OS tray.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/mini_window/data/mock_tray_controller.dart';
import 'package:focus_journey/features/mini_window/domain/tray_state.dart';
import 'package:focus_journey/features/mini_window/domain/window_mode.dart';

void main() {
  group('MockTrayController', () {
    test('init_setsInitialStateAndMode', () async {
      final t = MockTrayController();
      await t.init(
        initialState: TrayActivityState.active,
        initialMode: WindowMode.full,
      );
      expect(t.didInit, isTrue);
      expect(t.state, TrayActivityState.active);
      expect(t.mode, WindowMode.full);
      await t.dispose();
    });

    test('setState_reflectsJourneyState', () async {
      final t = MockTrayController();
      await t.init();
      await t.setState(TrayActivityState.active);
      expect(t.state, TrayActivityState.active);
      await t.setState(TrayActivityState.paused);
      expect(t.state, TrayActivityState.paused);
      await t.dispose();
    });

    test('actions_emitEachTrayAction', () async {
      final t = MockTrayController();
      await t.init();
      final received = <TrayAction>[];
      t.actions.listen(received.add);

      t.emitAction(TrayAction.showApp);
      t.emitAction(TrayAction.enterCompact);
      t.emitAction(TrayAction.quit);
      await Future<void>.delayed(Duration.zero);

      expect(received, <TrayAction>[
        TrayAction.showApp,
        TrayAction.enterCompact,
        TrayAction.quit,
      ]);
      await t.dispose();
    });

    test('setMode_updatesReflectedMode', () async {
      final t = MockTrayController();
      await t.init();
      await t.setMode(WindowMode.compact);
      expect(t.mode, WindowMode.compact);
      await t.dispose();
    });

    test('setStatusLine_storesStatus', () async {
      final t = MockTrayController();
      await t.init();
      await t.setStatusLine('Travelling — 1,240 km');
      expect(t.statusLine, 'Travelling — 1,240 km');
      await t.setStatusLine(null);
      expect(t.statusLine, isNull);
      await t.dispose();
    });
  });
}
