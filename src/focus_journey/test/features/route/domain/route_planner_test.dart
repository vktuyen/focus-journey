// Smoke unit tests for the route-planner-v2 pure domain (ADR-0005 decisions 1/2):
// RoutePlanner.resolve (auto-insert / span-extend / interior-merge) +
// RoutePlanner.fromOrderedIds (deterministic rebuild). Pure: no Flutter, no
// timers, no I/O. The exhaustive AC coverage is the dedicated unit-test pass;
// here we assert the load-bearing shapes (AC-1..AC-5).

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/domain/province.dart';
import 'package:focus_journey/features/route/domain/route_planner.dart';

import '../map_test_fixtures.dart';

const double _tol = 1e-6;

void main() {
  // Fixture chain: mui/can_tho/da_lat/da_nang/ha_noi/ha_giang,
  // segments [60,170,300,310,600], total 1440. Cumulative-from-mui:
  // 0/60/230/530/840/1440.
  final chain = buildFixtureChain();
  final geography = buildFixtureGeography(chain);

  group('AC-1/AC-3 auto-insert fills intermediates in spine order', () {
    test(
      'can_tho → da_nang yields the contiguous sub-path in travel order',
      () {
        final r = RoutePlanner.resolve(
          fullChain: chain,
          fullGeography: geography,
          start: nodeById(chain, 'can_tho'),
          end: nodeById(chain, 'da_nang'),
        );
        expect(r.orderedNodeIds, <String>['can_tho', 'da_lat', 'da_nang']);
        // subPathKm = 170 + 300 = 470 (the slice of the canonical segments).
        expect(r.subPathKm, closeTo(470, _tol));
        // canonicalOriginKm = cumulative-from-south-tip of can_tho = 60.
        expect(r.canonicalOriginKm, closeTo(60, _tol));
        expect(r.subChain.nodes.length, 3);
      },
    );

    test('south-bound route reverses travel order (direction implied)', () {
      final r = RoutePlanner.resolve(
        fullChain: chain,
        fullGeography: geography,
        start: nodeById(chain, 'da_nang'),
        end: nodeById(chain, 'can_tho'),
      );
      expect(r.orderedNodeIds, <String>['da_nang', 'da_lat', 'can_tho']);
      expect(r.subPathKm, closeTo(470, _tol));
      // The sub-chain itself stays canonical (south→north): can_tho first.
      expect(r.subChain.southTip.id, 'can_tho');
    });
  });

  group('AC-2 start == end is rejected', () {
    test('throws ArgumentError', () {
      expect(
        () => RoutePlanner.resolve(
          fullChain: chain,
          fullGeography: geography,
          start: nodeById(chain, 'da_lat'),
          end: nodeById(chain, 'da_lat'),
        ),
        throwsArgumentError,
      );
    });
  });

  group('AC-4 a marked stop outside the span extends the span', () {
    test('can_tho → da_lat + a ha_noi stop extends north to ha_noi', () {
      final r = RoutePlanner.resolve(
        fullChain: chain,
        fullGeography: geography,
        start: nodeById(chain, 'can_tho'),
        end: nodeById(chain, 'da_lat'),
        markedStops: <Province>[nodeById(chain, 'ha_noi')],
      );
      // Extended to ha_noi: can_tho → da_lat → da_nang → ha_noi.
      expect(r.orderedNodeIds, <String>[
        'can_tho',
        'da_lat',
        'da_nang',
        'ha_noi',
      ]);
      // 170 + 300 + 310 = 780.
      expect(r.subPathKm, closeTo(780, _tol));
    });
  });

  group('AC-5 interior removal merges adjacent segments (sums km)', () {
    test('removing da_lat from can_tho→da_nang keeps subPathKm exact', () {
      final r = RoutePlanner.resolve(
        fullChain: chain,
        fullGeography: geography,
        start: nodeById(chain, 'can_tho'),
        end: nodeById(chain, 'da_nang'),
        removedStops: <String>{'da_lat'},
      );
      expect(r.orderedNodeIds, <String>['can_tho', 'da_nang']);
      // Merged: 170 + 300 = 470 (the canonical axis stays exact).
      expect(r.subPathKm, closeTo(470, _tol));
      expect(r.subChain.segmentsKm.single, closeTo(470, _tol));
    });

    test('endpoints are never removable (the AC-2 minimum holds)', () {
      final r = RoutePlanner.resolve(
        fullChain: chain,
        fullGeography: geography,
        start: nodeById(chain, 'can_tho'),
        end: nodeById(chain, 'da_nang'),
        // Attempt to remove the endpoints — ignored (they are protected).
        removedStops: <String>{'can_tho', 'da_nang', 'da_lat'},
      );
      expect(r.orderedNodeIds, <String>['can_tho', 'da_nang']);
      expect(r.subChain.nodes.length, 2);
    });
  });

  group('fromOrderedIds rebuilds the same sub-chain deterministically', () {
    test('round-trips resolve → orderedNodeIds → fromOrderedIds', () {
      final resolved = RoutePlanner.resolve(
        fullChain: chain,
        fullGeography: geography,
        start: nodeById(chain, 'da_nang'),
        end: nodeById(chain, 'can_tho'),
      );
      final rebuilt = RoutePlanner.fromOrderedIds(
        fullChain: chain,
        fullGeography: geography,
        orderedNodeIds: resolved.orderedNodeIds,
      );
      expect(rebuilt.orderedNodeIds, resolved.orderedNodeIds);
      expect(rebuilt.subPathKm, closeTo(resolved.subPathKm, _tol));
      expect(
        rebuilt.canonicalOriginKm,
        closeTo(resolved.canonicalOriginKm, _tol),
      );
    });

    test('rejects a non-monotonic id list', () {
      expect(
        () => RoutePlanner.fromOrderedIds(
          fullChain: chain,
          fullGeography: geography,
          orderedNodeIds: const <String>['can_tho', 'da_nang', 'da_lat'],
        ),
        throwsArgumentError,
      );
    });
  });
}
