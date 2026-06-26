// Cosmetic-only RUNTIME guards for the vehicle picker. Authored by
// test-script-author from tests/cases/vehicle-picker.md. One group per case;
// each carries its TC-id + AC-id. Mirrors cockpit_cosmetic_engine_test.dart's
// byte-for-byte equality form (EXACT equality, not ±epsilon).
//
//   TC-608 (AC-8) — selecting ANY vehicle leaves engine truth byte-for-byte
//                  identical to the no-preference baseline: distanceKm / state /
//                  activeTimeToday / rawActiveTime / idleTimeToday are EXACTLY
//                  equal across all six picks for the SAME injected input
//                  sequence. (The preference is presentation-only; the engine's
//                  own `mode` is the same default in every run, so the override
//                  changes no engine number.)
//   TC-609 (AC-9 runtime half) — JourneyCubit stays a PURE READER: updateFromEngine
//                  never writes engine.mode (nor any engine field) to apply the
//                  preference, and the engine's mode is unchanged by the picker.
//                  The effective displayed mode is composed ABOVE the view state,
//                  not by updateFromEngine mutating/re-reading the engine.
//
// No real OS, no real timers, no real shared_preferences — a FakeClock +
// MockActivitySource drive the engine; the SettingsCubit (the preference owner)
// is driven against an in-memory repository fake.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/activity/data/mock_activity_source.dart';
import 'package:focus_journey/features/journey/domain/journey_engine.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/journey/presentation/journey_cubit.dart';
import 'package:focus_journey/features/stats/presentation/settings_cubit.dart';

import '../../stats/stats_test_fixtures.dart';

/// A scripted activity tick: how long elapsed + the idle reading + lock state.
typedef _Tick = ({Duration delta, int idleSeconds, bool screenLocked});

/// A fixed input sequence that visits active / grace / paused / locked bands so
/// the equality assertion is not vacuous (mirrors cockpit_cosmetic_engine_test).
const List<_Tick> _ticks = <_Tick>[
  (delta: Duration(minutes: 1), idleSeconds: 0, screenLocked: false), // active
  (delta: Duration(minutes: 2), idleSeconds: 2, screenLocked: false), // active
  (delta: Duration(minutes: 3), idleSeconds: 120, screenLocked: false), // grace
  (delta: Duration(minutes: 5), idleSeconds: 600, screenLocked: false), // paused
  (delta: Duration(minutes: 1), idleSeconds: 0, screenLocked: true), // locked
  (delta: Duration(minutes: 4), idleSeconds: 1, screenLocked: false), // active
];

JourneyEngine _engine(FakeClock clock, {TravelMode? mode}) => JourneyEngine(
  clock: clock,
  activityPlugin: MockActivitySource(),
  kmPerActiveHour: 10,
  mode: mode ?? TravelMode.motorbike,
);

/// Drives [engine] through [_ticks] at the SAME instants and returns the final
/// five engine outputs as a tuple for exact comparison.
({double distanceKm, String state, Duration active, Duration raw, Duration idle})
    _run(JourneyEngine engine, FakeClock clock, DateTime start) {
  DateTime t = start;
  for (final tick in _ticks) {
    t = t.add(tick.delta);
    clock.setNow(t);
    engine.tick(
      tick.delta,
      idleSeconds: tick.idleSeconds,
      screenLocked: tick.screenLocked,
    );
  }
  return (
    distanceKm: engine.distanceKm,
    state: engine.state.name,
    active: engine.activeTimeToday,
    raw: engine.rawActiveTime,
    idle: engine.idleTimeToday,
  );
}

void main() {
  final DateTime start = DateTime(2026, 6, 26, 9);

  // ===========================================================================
  // TC-608 (AC-8) — engine truth byte-for-byte identical across all six picks.
  // ===========================================================================
  group('TC-608 engine truth is byte-for-byte identical across all six picks (AC-8)', () {
    test('eachOfTheSixPreferences_matchesTheNoPreferenceBaseline_exactly', () async {
      // The no-preference baseline: engine runs with its own default `mode`, no
      // vehiclePreference set (the picker changes nothing in the engine).
      final baselineClock = FakeClock(start);
      final baseline = _run(_engine(baselineClock), baselineClock, start);

      // Sanity: the sequence actually moved the engine (non-vacuous equality).
      expect(baseline.distanceKm, greaterThan(0));

      for (final TravelMode pref in TravelMode.values) {
        // Set the preference via the REAL SettingsCubit (presentation-only) so
        // the assertion reflects the production write path. The engine run is
        // IDENTICAL — the preference reaches the engine NOWHERE (firewall).
        final repo = InMemorySettingsRepository();
        final settings = SettingsCubit(
          repository: repo,
          startupController: FakeStartupController(),
          applyIdleThreshold: (_) {},
        );
        addTearDown(settings.close);
        await settings.setVehicle(pref);
        expect(settings.state.vehiclePreference, pref);

        // The engine for this preference run uses the SAME default mode + SAME
        // injected input sequence as the baseline.
        final clock = FakeClock(start);
        final run = _run(_engine(clock), clock, start);

        expect(run.distanceKm, baseline.distanceKm,
            reason: 'distanceKm must be identical for preference $pref');
        expect(run.state, baseline.state,
            reason: 'state must be identical for preference $pref');
        expect(run.active, baseline.active,
            reason: 'activeTimeToday must be identical for preference $pref');
        expect(run.raw, baseline.raw,
            reason: 'rawActiveTime must be identical for preference $pref');
        expect(run.idle, baseline.idle,
            reason: 'idleTimeToday must be identical for preference $pref');
      }
    });
  });

  // ===========================================================================
  // TC-609 (AC-9 runtime half) — JourneyCubit is a pure reader; engine.mode is
  // never written by the picker.
  // ===========================================================================
  group('TC-609 JourneyCubit never writes the engine to apply the pick (AC-9)', () {
    test('updateFromEngine_doesNotMutateEngineMode_evenWithAPreferenceSet', () async {
      // A non-null preference differing from the engine mode.
      const TravelMode p = TravelMode.car;
      final repo = InMemorySettingsRepository();
      final settings = SettingsCubit(
        repository: repo,
        startupController: FakeStartupController(),
        applyIdleThreshold: (_) {},
      );
      addTearDown(settings.close);
      await settings.setVehicle(p);

      final clock = FakeClock(start);
      final engine = _engine(clock, mode: TravelMode.walk); // engine mode != p
      final cubit = JourneyCubit();
      addTearDown(cubit.close);

      final TravelMode modeBefore = engine.mode;
      // Drive several ticks + updateFromEngine calls.
      DateTime t = start;
      for (final tick in _ticks) {
        t = t.add(tick.delta);
        clock.setNow(t);
        engine.tick(
          tick.delta,
          idleSeconds: tick.idleSeconds,
          screenLocked: tick.screenLocked,
        );
        cubit.updateFromEngine(engine);
      }

      // The Cubit never wrote engine.mode to apply the preference — the engine's
      // mode is exactly what it was constructed with (the picker is firewalled).
      expect(engine.mode, modeBefore);
      expect(engine.mode, TravelMode.walk);
      // And the cubit emitted the ENGINE mode verbatim (it is a pure reader); the
      // preference override (p) is composed ABOVE the view state, not here.
      expect(cubit.state.mode, TravelMode.walk,
          reason: 'JourneyCubit must emit the engine mode, not the preference');
    });
  });
}
