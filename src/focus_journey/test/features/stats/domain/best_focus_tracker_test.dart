// Unit tests for BestFocusTracker — the day's longest contiguous raw-active run
// (AC-3, TC-003). A tick is "raw-active" iff rawActiveTime increased since the
// previous snapshot; any non-increase (grace / idle / paused) breaks the run.
// Pure and deterministic: no clock, no OS, no DateTime.now() — the tracker is
// fed the engine's rawActiveTime counter directly. Keys off "longest raw-active
// run", not a literal duration, so it survives re-tuning of the OQ default.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/stats/domain/best_focus_tracker.dart';

void main() {
  group('BestFocusTracker — empty / single observation (AC-3)', () {
    test('newTracker_reportsZeroBest', () {
      expect(BestFocusTracker().bestFocusPeriod, Duration.zero);
    });

    test('firstObservationOnly_isJustBaseline_bestStaysZero', () {
      final tracker = BestFocusTracker();
      tracker.observe(const Duration(minutes: 7));
      // First sample only learns the baseline — no run extended yet.
      expect(tracker.bestFocusPeriod, Duration.zero);
    });

    test('noRawActiveAllDay_reportsZero', () {
      final tracker = BestFocusTracker();
      tracker.observe(Duration.zero);
      tracker.observe(Duration.zero);
      tracker.observe(Duration.zero);
      expect(tracker.bestFocusPeriod, Duration.zero);
    });
  });

  group('BestFocusTracker — a single uninterrupted run (AC-3)', () {
    test('contiguousIncreases_accumulateIntoTheRun', () {
      final tracker = BestFocusTracker();
      tracker.observe(Duration.zero); // baseline
      tracker.observe(const Duration(minutes: 1)); // run = 1
      tracker.observe(const Duration(minutes: 3)); // run = 3
      tracker.observe(const Duration(minutes: 6)); // run = 6
      expect(tracker.bestFocusPeriod, const Duration(minutes: 6));
    });
  });

  group('BestFocusTracker — grace / idle breaks the run (AC-3)', () {
    test('graceStretch_nonIncrease_breaksTheRunSoItIsNotCounted', () {
      final tracker = BestFocusTracker();
      tracker.observe(Duration.zero); // baseline
      tracker.observe(const Duration(minutes: 2)); // run = 2
      // Grace: rawActiveTime does NOT advance — the run breaks.
      tracker.observe(const Duration(minutes: 2));
      tracker.observe(const Duration(minutes: 3)); // new run = 1
      expect(tracker.bestFocusPeriod, const Duration(minutes: 2));
    });

    test('longerOfTwoRunsSeparatedByABreak_wins', () {
      final tracker = BestFocusTracker();
      tracker.observe(Duration.zero); // baseline
      // Run A: 3 min.
      tracker.observe(const Duration(minutes: 1));
      tracker.observe(const Duration(minutes: 3));
      // Break (idle stall — no advance).
      tracker.observe(const Duration(minutes: 3));
      // Run B: 5 min (the longer one) — should win.
      tracker.observe(const Duration(minutes: 5));
      tracker.observe(const Duration(minutes: 8));
      expect(tracker.bestFocusPeriod, const Duration(minutes: 5));
    });

    test('earlierLongerRun_isNotOverwrittenByALaterShorterRun', () {
      final tracker = BestFocusTracker();
      tracker.observe(Duration.zero); // baseline
      // Run A: 5 min (the longer one, comes first).
      tracker.observe(const Duration(minutes: 5));
      // Break.
      tracker.observe(const Duration(minutes: 5));
      // Run B: 2 min.
      tracker.observe(const Duration(minutes: 7));
      expect(tracker.bestFocusPeriod, const Duration(minutes: 5));
    });
  });

  group('BestFocusTracker — day boundary reset (AC-3 / AC-19)', () {
    test('resetForNewDay_zeroesBestAndRun_soNewDayStartsFresh', () {
      final tracker = BestFocusTracker();
      tracker.observe(Duration.zero);
      tracker.observe(const Duration(minutes: 10)); // best = 10
      expect(tracker.bestFocusPeriod, const Duration(minutes: 10));

      tracker.resetForNewDay(Duration.zero);
      expect(tracker.bestFocusPeriod, Duration.zero);

      // The new day accumulates from its own baseline only.
      tracker.observe(const Duration(minutes: 2)); // run = 2
      expect(tracker.bestFocusPeriod, const Duration(minutes: 2));
    });

    test('resetForNewDay_seedsBaseline_soNoSpuriousRunFromOldCounter', () {
      final tracker = BestFocusTracker();
      // Engine counter not yet zeroed at reset time: seed the baseline with it.
      tracker.resetForNewDay(const Duration(minutes: 40));
      // Next tick reads the same value (engine then zeroes on its own tick) —
      // a non-increase, so no spurious 40-minute run is recorded.
      tracker.observe(const Duration(minutes: 40));
      expect(tracker.bestFocusPeriod, Duration.zero);
    });
  });

  group('BestFocusTracker — determinism (TC-NF1)', () {
    test('identicalSequence_yieldsIdenticalBest', () {
      Duration run(BestFocusTracker t) {
        t.observe(Duration.zero);
        t.observe(const Duration(minutes: 4));
        t.observe(const Duration(minutes: 4)); // break
        t.observe(const Duration(minutes: 9));
        return t.bestFocusPeriod;
      }

      expect(run(BestFocusTracker()), run(BestFocusTracker()));
    });
  });
}
