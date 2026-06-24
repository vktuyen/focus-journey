// Smoke test for the journey-view presentation wiring. The formal journey-view
// suite (goldens / behaviour / separation, including Flame-scene asset mocking)
// is authored separately by unit-test-writer. This only confirms the Cubit maps
// engine snapshots to the view state and the overlay-gating rule (AC-2/AC-13)
// holds — it does not mount the Flame GameWidget (asset bundle not populated).

import 'package:flutter_test/flutter_test.dart';

import 'package:focus_journey/features/journey/domain/journey_state.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/journey/presentation/journey_view_state.dart';

void main() {
  group('JourneyViewState', () {
    test(
      'initial is parked, default skin, zero distance, no overlay (AC-13)',
      () {
        const JourneyViewState s = JourneyViewState.initial();
        expect(s.motion, JourneyMotion.stopped);
        expect(s.mode, TravelMode.motorbike);
        expect(s.distanceKm, 0);
        expect(s.hasRealState, isFalse);
        // First frame is parked WITHOUT the overlay (TC-013).
        expect(s.showPausedOverlay, isFalse);
      },
    );

    test('active maps to moving (AC-1)', () {
      final JourneyViewState s = JourneyViewState.fromEngine(
        JourneyState.active,
        TravelMode.car,
        42.0,
      );
      expect(s.motion, JourneyMotion.moving);
      expect(s.mode, TravelMode.car);
      expect(s.distanceKm, 42.0);
      expect(s.showPausedOverlay, isFalse);
    });

    test('idle and paused both map to stopped + overlay (AC-2/AC-3)', () {
      final JourneyViewState idle = JourneyViewState.fromEngine(
        JourneyState.idle,
        TravelMode.bicycle,
        7.0,
      );
      final JourneyViewState paused = JourneyViewState.fromEngine(
        JourneyState.paused,
        TravelMode.bicycle,
        7.0,
      );
      expect(idle.motion, JourneyMotion.stopped);
      expect(paused.motion, JourneyMotion.stopped);
      expect(idle.showPausedOverlay, isTrue);
      expect(paused.showPausedOverlay, isTrue);
      // Identical view in v1.
      expect(idle, equals(paused));
    });
  });
}
