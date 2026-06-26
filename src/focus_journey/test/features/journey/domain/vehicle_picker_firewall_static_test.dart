// FIREWALL static-inspection guards for the vehicle picker (ADR-0007). Authored
// by test-script-author from tests/cases/vehicle-picker.md. Modelled on
// journey_cockpit_lean_separation_static_test.dart (comment-stripped CODE-only
// matching; import/reference scan). This is the LOAD-BEARING case of the slice.
//
//   TC-610  (AC-10) — the engine references NEITHER the preference NOR the
//                  settings store: journey_engine.dart imports/references NONE of
//                  {AppSettings, vehiclePreference, SettingsCubit, SettingsRepository,
//                  shared_preferences}. The preference reaches the render ONLY via
//                  the applyState(mode:) seam (composed above JourneyViewState,
//                  never read by the engine). journey_cubit.dart + journey_view_state.dart
//                  (the engine-read path) are equally clean. Designed to go RED the
//                  moment someone wires the pick toward accrual/speed.
//   TC-610b (AC-10 negative twin) — documents + PROVES TC-610 is an ABSENCE-of-
//                  reference assertion, not a happy-path import scan: a synthetic
//                  engine source that imports/references AppSettings.vehiclePreference
//                  / SettingsCubit must FAIL the same scan. (Fault-injection on an
//                  in-memory copy of the source — no production file is mutated.)
//   TC-616  (NFR-1 static half) — the override is an O(1) composition where the
//                  view state is assembled, via the SHARED composeDisplayedMode
//                  helper called at BOTH applyState seams: JourneyScreen
//                  (standalone path) AND AppShell (the production shared-game
//                  driver: full window + PiP, ADR-0003) — NOT inside JourneyGame
//                  per frame. applyState's signature is unchanged (one `mode:`
//                  value) and JourneyGame does not read the preference /
//                  SettingsCubit at all.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _journeyEngine = 'lib/features/journey/domain/journey_engine.dart';
const String _journeyCubit =
    'lib/features/journey/presentation/journey_cubit.dart';
const String _journeyViewState =
    'lib/features/journey/presentation/journey_view_state.dart';
const String _journeyScreen =
    'lib/features/journey/presentation/journey_screen.dart';
const String _journeyGame =
    'lib/features/journey/presentation/game/journey_game.dart';
const String _appShell =
    'lib/features/mini_window/presentation/app_shell.dart';

Directory _packageRoot() {
  Directory dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync() &&
        Directory('${dir.path}/lib/features/journey').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      return Directory.current;
    }
    dir = parent;
  }
}

/// Strips `//`, `///`, and `/* */` comments so matches are against CODE only —
/// the engine DELIBERATELY documents the firewall in doc comments (naming the
/// forbidden APIs to say it does NOT use them).
String _stripComments(String source) {
  final noBlock = source.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  final buffer = StringBuffer();
  for (final line in noBlock.split('\n')) {
    final idx = line.indexOf('//');
    buffer.writeln(idx >= 0 ? line.substring(0, idx) : line);
  }
  return buffer.toString();
}

List<String> _importTargets(String source) {
  final re = RegExp(r'''(?:import|export)\s+['"]([^'"]+)['"]''');
  return re.allMatches(source).map((m) => m.group(1)!).toList();
}

/// The forbidden tokens that would mean the engine-read path is coupled to the
/// cosmetic preference / settings store (the ADR-0007 firewall breach).
const List<String> _forbiddenPreferenceTokens = <String>[
  'AppSettings',
  'vehiclePreference',
  'SettingsCubit',
  'SettingsRepository',
  'shared_preferences',
  'setVehicle',
];

/// The import targets that would couple the engine-read path to settings.
bool _isForbiddenImport(String imp) =>
    imp.contains('app_settings') ||
    imp.contains('settings_cubit') ||
    imp.contains('stats_repositories') ||
    imp.contains('shared_preferences') ||
    imp.contains('shared_preferences_settings_repository');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final root = _packageRoot();

  String code(String rel) {
    final file = File('${root.path}/$rel');
    expect(file.existsSync(), isTrue, reason: 'missing source: $rel');
    return _stripComments(file.readAsStringSync());
  }

  /// The shared firewall scan: [rel]'s CODE contains none of the forbidden
  /// preference/settings tokens and imports nothing coupling it to the store.
  void expectFirewallClean(String rel) {
    final src = code(rel);
    for (final t in _forbiddenPreferenceTokens) {
      expect(
        src.contains(t),
        isFalse,
        reason:
            'AC-10 firewall: $rel must reference NONE of the cosmetic '
            'preference / settings store — found "$t"',
      );
    }
    for (final imp in _importTargets(src)) {
      expect(
        _isForbiddenImport(imp),
        isFalse,
        reason:
            'AC-10 firewall: $rel must not import the settings store ("$imp")',
      );
    }
  }

  // ===========================================================================
  // TC-610 (AC-10) — the engine + engine-read path reference neither the
  // preference nor the settings store.
  // ===========================================================================
  group('TC-610 engine + read path reference neither preference nor store (AC-10)', () {
    test('journeyEngine_referencesNoPreferenceOrSettingsStore', () {
      expectFirewallClean(_journeyEngine);
    });

    test('journeyCubit_referencesNoPreferenceOrSettingsStore', () {
      // The engine-read path (the cubit) must NOT apply the preference either —
      // it stays a pure engine reader (ADR-0007 rejected alternative 4).
      expectFirewallClean(_journeyCubit);
    });

    test('journeyViewState_referencesNoPreferenceOrSettingsStore', () {
      // The view state is composed from engine values; the override term is
      // applied ABOVE it (in JourneyScreen), so it too is firewall-clean.
      expectFirewallClean(_journeyViewState);
    });

    test('journeyEngine_importsOnlyPureDomainDeps', () {
      // Positive allowlist: the engine imports only pure-domain siblings — no
      // Flutter, no Bloc, no settings, no platform channel.
      for (final imp in _importTargets(code(_journeyEngine))) {
        final bool allowed = imp.startsWith('dart:') ||
            (imp.endsWith('.dart') &&
                !imp.startsWith('package:flutter') &&
                !imp.contains('bloc') &&
                !imp.contains('settings') &&
                !imp.contains('stats'));
        expect(
          allowed,
          isTrue,
          reason:
              'AC-10: journey_engine.dart may import only pure-domain deps — '
              'disallowed "$imp"',
        );
      }
    });
  });

  // ===========================================================================
  // TC-610b (AC-10 negative twin) — the SAME scan FAILS on a wired engine.
  // ===========================================================================
  group('TC-610b a preference-wired engine FAILS the firewall scan (AC-10)', () {
    // Fault-injection on an in-memory COPY of the real engine source (no
    // production file is touched): splice in a hypothetical line that reads the
    // cosmetic preference toward accrual. The TC-610 scan must flag it RED.
    test('mutatedEngineThatReadsThePreference_isCaughtByTheScan', () {
      final realEngine = code(_journeyEngine);
      // The wiring a regression would introduce: import the settings store +
      // read AppSettings.vehiclePreference into the accrual path.
      const injectedImport =
          "import '../../stats/domain/app_settings.dart';\n";
      const injectedUse =
          '  void _leak(AppSettings s) { _distanceKm += '
          's.vehiclePreference == TravelMode.car ? 1 : 0; }\n';
      final mutated = injectedImport + realEngine + injectedUse;

      // Re-run the SAME forbidden-token + import checks the TC-610 guard runs;
      // at least one must now fire (the scan is an absence-of-reference assert,
      // not a happy-path import list).
      final List<String> hits = <String>[];
      for (final t in _forbiddenPreferenceTokens) {
        if (mutated.contains(t)) hits.add('token:$t');
      }
      for (final imp in _importTargets(mutated)) {
        if (_isForbiddenImport(imp)) hits.add('import:$imp');
      }
      expect(
        hits,
        isNotEmpty,
        reason:
            'TC-610b: a preference-wired engine MUST be caught — the firewall '
            'scan would have passed silently otherwise',
      );
      // Be explicit about WHAT it caught (documents the firewall genuinely bites).
      expect(hits, contains('token:AppSettings'));
      expect(hits, contains('token:vehiclePreference'));
      expect(hits, contains('import:../../stats/domain/app_settings.dart'));
    });

    test('theRealEngine_passesTheSameScan_thatTheMutantFails', () {
      // The control: the un-mutated real engine has ZERO hits, proving the RED in
      // the mutant is caused by the injected wiring, not by the scan itself.
      final realEngine = code(_journeyEngine);
      final List<String> hits = <String>[];
      for (final t in _forbiddenPreferenceTokens) {
        if (realEngine.contains(t)) hits.add('token:$t');
      }
      for (final imp in _importTargets(realEngine)) {
        if (_isForbiddenImport(imp)) hits.add('import:$imp');
      }
      expect(hits, isEmpty);
    });
  });

  // ===========================================================================
  // TC-616 (NFR-1 static half) — the override is composed ABOVE the view state;
  // JourneyGame gains no per-frame preference cost; applyState contract unchanged.
  // ===========================================================================
  group('TC-616 override composed above the view state; scene contract unchanged (NFR-1)', () {
    test('journeyScreen_composesTheOverrideAtTheApplyStateSeam', () {
      // The override term is the O(1) nullable-coalesce where the displayed mode
      // is handed to applyState, composed at/above JourneyViewState via the
      // SHARED composeDisplayedMode(context, engineMode) seam helper (= the
      // `vehiclePreference ?? engineMode` term, factored into one place so the
      // standalone JourneyScreen path and the production AppShell path cannot
      // drift — ADR-0007).
      final screen = code(_journeyScreen);
      expect(
        screen.contains('composeDisplayedMode(context, s.mode)'),
        isTrue,
        reason:
            'NFR-1/AC-3: the displayed mode = vehiclePreference ?? engineMode, '
            'composed at the applyState seam via the shared helper',
      );
    });

    test('appShell_composesTheOverrideAtTheProductionApplyStateSeam', () {
      // The PRODUCTION applyState driver (shared game: full window + PiP,
      // ADR-0003) must compose the SAME override at its seam, else a live pick
      // would not change the rendered vehicle on the real path (AC-1/AC-2/AC-3/
      // AC-6). Asserted via the shared composeDisplayedMode helper.
      final shell = code(_appShell);
      expect(
        shell.contains('composeDisplayedMode(context, s.mode)'),
        isTrue,
        reason:
            'AC-1/AC-3 (production path): AppShell._applyToScene must compose '
            'vehiclePreference ?? engineMode at the shared-game applyState seam',
      );
    });

    test('journeyGame_doesNotReadThePreferenceOrSettings', () {
      // The scene takes ONE plain `mode:` value via applyState — it never reads
      // the preference / SettingsCubit, so there is no per-frame override cost.
      expectFirewallClean(_journeyGame);
    });

    test('journeyGame_applyStateSignatureIsTheUnchangedOneValueContract', () {
      // applyState still takes a single `mode:` TravelMode — the override added
      // no parameter / no per-frame re-resolution to the scene's hot-path API.
      final game = code(_journeyGame);
      expect(game.contains('void applyState('), isTrue);
      expect(
        game.contains('required TravelMode mode'),
        isTrue,
        reason: 'applyState must still take ONE plain mode value (NFR-1)',
      );
    });
  });
}
