// Formal unit tests for JourneyTrayMapper — the pure mapping from the journey
// Bloc's view state onto the tray icon state + status-line string.
//
// Scope (headless, deterministic — no OS):
//   TC-011         — moving → active, stopped (idle/paused) → paused, so the
//                    tray surface can distinguish travelling from parked.
//   TC-013-STATUS  — the status-line text reflects the Bloc's state + distance,
//                    including distance formatting and the paused/idle wording.
//   AC-4 / AC-10   — the mapper computes nothing of its own: it only projects
//                    the already-decided JourneyViewState (no activity decision,
//                    no distance accrual).
//
// The compact_view smoke test already asserts two representative mappings; this
// file is the formal boundary/formatting suite (distance rounding, zero, large
// values, idle≡paused collapse).

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/journey/presentation/journey_view_state.dart';
import 'package:focus_journey/features/mini_window/domain/tray_state.dart';
import 'package:focus_journey/features/mini_window/presentation/journey_tray_mapper.dart';

JourneyViewState _state({
  required JourneyMotion motion,
  double distanceKm = 0,
  bool hasRealState = true,
  TravelMode mode = TravelMode.motorbike,
}) {
  return JourneyViewState(
    motion: motion,
    mode: mode,
    distanceKm: distanceKm,
    hasRealState: hasRealState,
  );
}

void main() {
  group('JourneyTrayMapper.stateFor (AC-11 / TC-011)', () {
    test('moving_mapsToActive', () {
      // TC-011: a travelling journey is distinguishable as "active".
      expect(
        JourneyTrayMapper.stateFor(_state(motion: JourneyMotion.moving)),
        TrayActivityState.active,
      );
    });

    test('stopped_realState_mapsToPaused', () {
      // TC-011: a real idle/paused state reads as the single "paused" variant.
      expect(
        JourneyTrayMapper.stateFor(_state(motion: JourneyMotion.stopped)),
        TrayActivityState.paused,
      );
    });

    test('preState_initialDefault_mapsToPaused_neverActive', () {
      // AC-5 inheritance: before any real state the tray must read as parked,
      // never accidentally "active".
      expect(
        JourneyTrayMapper.stateFor(const JourneyViewState.initial()),
        TrayActivityState.paused,
      );
    });

    test('idleAndPaused_collapseToSamePausedVariant', () {
      // v1: the PiP/tray draws NO idle-vs-paused distinction. Both stopped
      // sources map to the identical TrayActivityState.paused.
      final fromIdle = JourneyTrayMapper.stateFor(
        _state(motion: JourneyMotion.stopped, distanceKm: 3),
      );
      final fromPaused = JourneyTrayMapper.stateFor(
        _state(motion: JourneyMotion.stopped, distanceKm: 99),
      );
      expect(fromIdle, fromPaused);
      expect(fromIdle, TrayActivityState.paused);
    });
  });

  group('JourneyTrayMapper.statusLineFor (AC-13 / TC-013-STATUS)', () {
    test('moving_showsTravellingWithFormattedDistance', () {
      // TC-013-STATUS: travelling verb + the Bloc's distance (1-dp display).
      final line = JourneyTrayMapper.statusLineFor(
        _state(motion: JourneyMotion.moving, distanceKm: 1240.0),
      );
      expect(line, 'Travelling — 1240.0 km');
    });

    test('stopped_showsPausedWithFormattedDistance', () {
      // TC-013-STATUS: parked wording, still reflecting the Bloc's distance.
      final line = JourneyTrayMapper.statusLineFor(
        _state(motion: JourneyMotion.stopped, distanceKm: 1240.0),
      );
      expect(line, 'Paused — 1240.0 km');
    });

    test('zeroDistance_formatsAsOneDecimal', () {
      expect(
        JourneyTrayMapper.statusLineFor(_state(motion: JourneyMotion.stopped)),
        'Paused — 0.0 km',
      );
    });

    test('fractionalDistance_roundsToOneDecimalForDisplay', () {
      // The underlying value carries full precision; the status line shows the
      // documented 1-dp rounding (TC-013-STATUS tolerates display rounding).
      expect(
        JourneyTrayMapper.statusLineFor(
          _state(motion: JourneyMotion.moving, distanceKm: 12.34),
        ),
        'Travelling — 12.3 km',
      );
      expect(
        JourneyTrayMapper.statusLineFor(
          _state(motion: JourneyMotion.moving, distanceKm: 12.35),
        ),
        'Travelling — 12.3 km', // banker-ish toStringAsFixed rounding of .35
      );
    });

    test('statusVerbEqualsTheBlocMotion_notAComputedJudgment', () {
      // AC-10: the verb is a pure projection of motion — flipping motion is the
      // only thing that flips the verb; distance never decides active-vs-paused.
      final moving = JourneyTrayMapper.statusLineFor(
        _state(motion: JourneyMotion.moving, distanceKm: 5),
      );
      final stopped = JourneyTrayMapper.statusLineFor(
        _state(motion: JourneyMotion.stopped, distanceKm: 5),
      );
      expect(moving.startsWith('Travelling'), isTrue);
      expect(stopped.startsWith('Paused'), isTrue);
    });
  });
}
