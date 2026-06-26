// Deterministic unit tests for the mock WindowVisibilityController — the seam
// the Flame scene + Bloc consume to satisfy journey-scene-v2 #5.
//
// Scope: animate-when-visible-but-unfocused (AC-3 maps to "stays visible"),
// pause-when-hidden (AC-4), per-surface evaluation (AC-5), and de-duplicated
// emission (NFR-1 — no redundant pause/resume churn). No real OS window.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/window_visibility/data/mock_window_visibility_controller.dart';
import 'package:focus_journey/features/window_visibility/domain/surface_visibility.dart';

void main() {
  group('MockWindowVisibilityController', () {
    test('defaults both surfaces to visible', () {
      final c = MockWindowVisibilityController();
      expect(c.isVisible(WindowSurface.main), isTrue);
      expect(c.isVisible(WindowSurface.pip), isTrue);
    });

    test('start records the call and marks started', () async {
      final c = MockWindowVisibilityController();
      await c.start();
      expect(c.started, isTrue);
      expect(c.calls, contains('start'));
    });

    test('setVisible(false) flips a surface to hidden (AC-4)', () {
      final c = MockWindowVisibilityController();
      c.setVisible(WindowSurface.main, false);
      expect(c.isVisible(WindowSurface.main), isFalse);
    });

    test('emits a per-surface change on transition (AC-5)', () {
      final c = MockWindowVisibilityController();
      expectLater(
        c.changes,
        emitsInOrder(<SurfaceVisibility>[
          const SurfaceVisibility(surface: WindowSurface.pip, visible: false),
          const SurfaceVisibility(surface: WindowSurface.main, visible: false),
        ]),
      );
      c.setVisible(WindowSurface.pip, false);
      c.setVisible(WindowSurface.main, false);
    });

    test('per-surface independence: hiding pip leaves main visible (AC-5)', () {
      final c = MockWindowVisibilityController(
        mainVisible: true,
        pipVisible: true,
      );
      c.setVisible(WindowSurface.pip, false);
      expect(c.isVisible(WindowSurface.pip), isFalse);
      expect(c.isVisible(WindowSurface.main), isTrue);
    });

    test('de-duplicates identical consecutive emissions (NFR-1)', () async {
      final c = MockWindowVisibilityController();
      final events = <SurfaceVisibility>[];
      final sub = c.changes.listen(events.add);
      c.setVisible(WindowSurface.main, false);
      c.setVisible(WindowSurface.main, false); // no-op (unchanged)
      c.setVisible(WindowSurface.main, true);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(events.map((e) => e.visible).toList(), <bool>[false, true]);
    });

    test('visibilityOf carries the surface tag', () {
      final c = MockWindowVisibilityController(pipVisible: false);
      final reading = c.visibilityOf(WindowSurface.pip);
      expect(reading.surface, WindowSurface.pip);
      expect(reading.visible, isFalse);
    });

    test('dispose closes the stream', () async {
      final c = MockWindowVisibilityController();
      await c.dispose();
      expect(c.calls, contains('dispose'));
    });
  });
}
