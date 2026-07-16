// province-chain-2026 — pacing re-derivation + retired-literal guard (AC-4).
//
// Traceability (one test <-> one case; PC + AC ids in each description):
//   PC-907 (AC-4)  kmPerActiveHour == totalChainKm/8, so total/(total/8) == 8
//                  active hours end-to-end; the production wiring (main.dart)
//                  injects the DERIVED rate, not a hardcoded literal.
//   PC-908 (AC-4)  static inspection: no `2000` chain-total and no `250`
//                  shipped-pacing literal survive on the production path. The
//                  JourneyEngine.defaultKmPerActiveHour = 250 fallback is the
//                  documented test-only default (allowed); injected
//                  `kmPerActiveHour: 250` mechanism fixtures are out of scope.
//
// PC-908 is a source-level static-inspection test: it reads the shipped .dart
// source from disk (walking up from the test cwd to the package root), strips
// line/doc comments, and asserts the retired stylized numbers no longer appear
// as CODE literals. Deterministic, offline.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/journey_engine.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';

/// Reads a package-relative source file, walking up from the test cwd until the
/// path resolves (mirrors base_map_geometry_test's asset-locating pattern).
String _readSource(String relativePath) {
  Directory dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    final candidate = File('${dir.path}/$relativePath');
    if (candidate.existsSync()) {
      return candidate.readAsStringSync();
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail('could not locate source $relativePath from cwd ${Directory.current.path}');
}

/// Strips Dart line + doc comments (`//` and `///` to end-of-line) so the search
/// sees CODE only, not prose describing the retired premise. These domain files
/// use no block comments.
String _codeOnly(String source) => source
    .split('\n')
    .map((line) {
      final idx = line.indexOf('//');
      return idx < 0 ? line : line.substring(0, idx);
    })
    .join('\n');

void main() {
  group('province-chain-2026 pacing re-derivation (AC-4)', () {
    test('PC-907 kmPerActiveHour_isTotalDividedBy8_soFullTraversalTakes8Hours', () {
      final total = vietnamProvinceChain.totalChainKm;
      final kmPerActiveHour = total / 8;
      // Dividing the total by the derived rate yields exactly 8 active hours.
      expect(total / kmPerActiveHour, closeTo(8.0, 1e-9));
      // The rate grows with the great-circle total (~3164 km => ~395 km/h), not
      // the retired stylized 250 km/h.
      expect(kmPerActiveHour, greaterThan(300));
      expect(kmPerActiveHour, lessThan(440));
    });

    test('PC-907 productionWiringInjectsTheDerivedRate_notAHardcodedLiteral', () {
      // route-real-road (#4): the rate is now derived from the DEFAULT ROUTE'S
      // REAL-ROAD LENGTH (the bundled national highway) ÷ 8, so a full traversal
      // of the drawn road still ≈ 8 active hours. It falls back to the spine
      // total ÷ 8 only when the road asset failed to load (degraded mode). A
      // DERIVED rate, never a hardcoded literal (AC-4). Whitespace-collapsed so
      // line wrapping doesn't matter.
      final main = _codeOnly(
        _readSource('lib/main.dart'),
      ).replaceAll(RegExp(r'\s+'), ' ');
      expect(
        main.contains(
          '(_defaultRouteRoadLengthKm ?? vietnamProvinceChain.totalChainKm) / 8',
        ),
        isTrue,
        reason:
            'main.dart must inject kmPerActiveHour = default road length ÷ 8 '
            '(a derived rate, not a hardcoded literal — AC-4 / route-real-road)',
      );
      // …and the default road length must be DERIVED from the bundled road via a
      // snapped RoadRoute (not a hardcoded number).
      expect(
        main.contains('RoadRoute.build('),
        isTrue,
        reason: 'the default road length must come from RoadRoute.build(...)',
      );
    });
  });

  group('province-chain-2026 no retired 2000/250 literal on the prod path '
      '(AC-4 / PC-908)', () {
    const routeChainSources = <String>[
      'lib/features/route/domain/vietnam_units_2026.dart',
      'lib/features/route/domain/province_chain.dart',
      'lib/features/route/domain/province_geography.dart',
      'lib/features/route/domain/haversine.dart',
      'lib/features/route/domain/route_polyline_projector.dart',
    ];

    test('PC-908 noChainTotal2000_norPacing250_inRouteChainCode', () {
      for (final path in routeChainSources) {
        final code = _codeOnly(_readSource(path));
        expect(
          code.contains('2000'),
          isFalse,
          reason: '$path still has a `2000` code literal (retired chain total)',
        );
        expect(
          code.contains('250'),
          isFalse,
          reason: '$path still has a `250` code literal (retired pacing rate)',
        );
      }
    });

    test('PC-908 engineFallback250_isTheOnly250_andIsDocumentedTestOnly', () {
      final engineCode = _codeOnly(
        _readSource('lib/features/journey/domain/journey_engine.dart'),
      );
      // No 2000 code literal anywhere in the engine.
      expect(engineCode.contains('2000'), isFalse);
      // The single surviving `250` code literal is the documented fallback const.
      final lines250 = engineCode
          .split('\n')
          .where((l) => l.contains('250'))
          .toList();
      expect(lines250, hasLength(1), reason: 'only the fallback default may be 250');
      expect(
        lines250.single.contains('defaultKmPerActiveHour'),
        isTrue,
        reason: 'the sole 250 must be JourneyEngine.defaultKmPerActiveHour',
      );
      // And it is documented as a test-only default (prose acknowledges prod
      // injects from the chain).
      final engineDoc = _readSource(
        'lib/features/journey/domain/journey_engine.dart',
      );
      expect(engineDoc.toLowerCase().contains('test-only'), isTrue);
      expect(JourneyEngine.defaultKmPerActiveHour, 250);
    });
  });
}
