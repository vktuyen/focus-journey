// Inline SANITY unit tests for the pure route-progress domain — the resolver
// and the chain-integrity invariant. These are a small confidence check by the
// implementer; the full AC-mapped suite (TC-001..TC-018, TC-NF1/NF4) is owned by
// the unit-test-writer. No timers, no DateTime.now(), no Flutter, no I/O.
//
// They run against the ACs' worked-example FIXTURE chain (total 1440 km), keyed
// off structure not literals, exactly as the test-case conventions prescribe.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/domain/journey_direction.dart';
import 'package:focus_journey/features/route/domain/province.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/route_progress_resolver.dart';
import 'package:focus_journey/features/route/domain/route_selection.dart';

const double kTol = 1e-6;

void main() {
  // A fixture aligned with the ACs' load-bearing numbers (Đà Nẵng 470 km from
  // Cần Thơ, Hà Giang 1380 km from Cần Thơ ⇒ total 1440 km, the % denominator).
  // Cumulative-from-Mũi: 0/60/230/530/840/1440 via the 5 segments below.
  final ProvinceChain fixture = ProvinceChain(
    nodes: const <Province>[
      Province(id: 'mui', name: 'Mũi Cà Mau'),
      Province(id: 'can_tho', name: 'Cần Thơ'),
      Province(id: 'da_lat', name: 'Đà Lạt'),
      Province(id: 'da_nang', name: 'Đà Nẵng'),
      Province(id: 'ha_noi', name: 'Hà Nội'),
      Province(id: 'ha_giang', name: 'Hà Giang'),
    ],
    segmentsKm: const <double>[60, 170, 300, 310, 600],
  );

  RouteSelection sel(
    String startId,
    JourneyDirection direction, {
    double offset = 0,
  }) => RouteSelection.create(
    start: fixture.nodes.firstWhere((p) => p.id == startId),
    direction: direction,
    routeStartOffsetKm: offset,
    chain: fixture,
  );

  group('ProvinceChain integrity (TC-NF4 sanity)', () {
    test('fixture is ordered, all-positive, and sums to its total', () {
      expect(fixture.segmentsKm.every((s) => s > 0), isTrue);
      final sum = fixture.segmentsKm.fold<double>(0, (a, b) => a + b);
      expect(sum, closeTo(fixture.totalChainKm, kTol));
    });

    test('production chain sums to ~2000 and has ~10-15 nodes', () {
      expect(vietnamProvinceChain.totalChainKm, closeTo(2000, kTol));
      expect(vietnamProvinceChain.nodes.length, inInclusiveRange(10, 15));
      expect(vietnamProvinceChain.segmentsKm.every((s) => s > 0), isTrue);
    });

    test('rejects a non-positive segment', () {
      expect(
        () => ProvinceChain(
          nodes: const <Province>[
            Province(id: 'a', name: 'A'),
            Province(id: 'b', name: 'B'),
          ],
          segmentsKm: const <double>[0],
        ),
        throwsArgumentError,
      );
    });
  });

  group('RouteProgressResolver (AC-1..AC-5 sanity, north from Cần Thơ)', () {
    // Cần Thơ start, cumulative-from-start: Đà Lạt 170, Đà Nẵng 470, Hà Nội 780,
    // Hà Giang 1080.
    test('AC-1 mid-chain at routeDistanceKm=400', () {
      final pos = RouteProgressResolver.resolve(
        routeDistanceKm: 400,
        selection: sel('can_tho', JourneyDirection.towardHaGiang),
        chain: fixture,
      );
      expect(pos.passed.map((p) => p.id), <String>['can_tho', 'da_lat']);
      expect(pos.next!.id, 'da_nang');
      expect(pos.distanceToNextKm, closeTo(70, kTol)); // 470 - 400
      expect(pos.currentSegmentFrom.id, 'da_lat');
      expect(pos.currentSegmentTo.id, 'da_nang');
      expect(pos.percentOfCountry, closeTo(400 / 1440 * 100, 1e-3));
      expect(pos.isCompleted, isFalse);
    });

    test('AC-2 distance 0 → origin only, in-progress', () {
      final pos = RouteProgressResolver.resolve(
        routeDistanceKm: 0,
        selection: sel('can_tho', JourneyDirection.towardHaGiang),
        chain: fixture,
      );
      expect(pos.passed.map((p) => p.id), <String>['can_tho']);
      expect(pos.next!.id, 'da_lat');
      expect(pos.distanceToNextKm, closeTo(170, kTol));
      expect(pos.percentOfCountry, 0);
      expect(pos.isCompleted, isFalse);
      expect(pos.fractionAlongRoute, closeTo(0, kTol));
    });

    test('AC-3/4/5 boundary triplet 169/170/171 around Đà Lạt', () {
      final before = RouteProgressResolver.resolve(
        routeDistanceKm: 169,
        selection: sel('can_tho', JourneyDirection.towardHaGiang),
        chain: fixture,
      );
      final on = RouteProgressResolver.resolve(
        routeDistanceKm: 170,
        selection: sel('can_tho', JourneyDirection.towardHaGiang),
        chain: fixture,
      );
      final after = RouteProgressResolver.resolve(
        routeDistanceKm: 171,
        selection: sel('can_tho', JourneyDirection.towardHaGiang),
        chain: fixture,
      );
      expect(before.next!.id, 'da_lat');
      expect(before.distanceToNextKm, closeTo(1, kTol));
      // Boundary: reached exactly → passed, next advances (AC-3).
      expect(on.passed.map((p) => p.id), contains('da_lat'));
      expect(on.next!.id, 'da_nang');
      expect(on.distanceToNextKm, closeTo(300, kTol));
      expect(after.passed.map((p) => p.id), contains('da_lat'));
      expect(after.next!.id, 'da_nang');
      expect(after.distanceToNextKm, closeTo(299, kTol));
    });
  });

  group('Direction + offset + completion sanity', () {
    test('AC-7 south is the mirror of north from Đà Nẵng at 300', () {
      final south = RouteProgressResolver.resolve(
        routeDistanceKm: 300,
        selection: sel('da_nang', JourneyDirection.towardMuiCaMau),
        chain: fixture,
      );
      expect(south.passed.map((p) => p.id), <String>['da_nang', 'da_lat']);
      expect(south.next!.id, 'can_tho');
      expect(south.distanceToNextKm, closeTo(170, kTol));
    });

    test('AC-8 % uses full-chain denominator in both directions', () {
      final north = RouteProgressResolver.resolve(
        routeDistanceKm: 200,
        selection: sel('da_lat', JourneyDirection.towardHaGiang),
        chain: fixture,
      );
      final south = RouteProgressResolver.resolve(
        routeDistanceKm: 200,
        selection: sel('da_lat', JourneyDirection.towardMuiCaMau),
        chain: fixture,
      );
      expect(north.percentOfCountry, closeTo(200 / 1440 * 100, 1e-3));
      expect(south.percentOfCountry, closeTo(200 / 1440 * 100, 1e-3));
    });

    test('AC-14b same routeDistanceKm under non-zero offset → identical', () {
      final a = RouteProgressResolver.resolve(
        routeDistanceKm: 400,
        selection: sel('can_tho', JourneyDirection.towardHaGiang),
        chain: fixture,
      );
      // Run B: offset 1100, cumulative 1500 → routeDistanceKm 400.
      final b = RouteProgressResolver.resolve(
        routeDistanceKm: 1500 - 1100,
        selection: sel('can_tho', JourneyDirection.towardHaGiang, offset: 1100),
        chain: fixture,
      );
      expect(a, equals(b));
    });

    test('AC-11/12 completion caps % at 100 and clamps marker', () {
      final dest = fixture.distanceToDestination(
        fixture.nodes.firstWhere((p) => p.id == 'can_tho'),
        JourneyDirection.towardHaGiang,
      );
      final pos = RouteProgressResolver.resolve(
        routeDistanceKm: dest + 500, // well beyond
        selection: sel('can_tho', JourneyDirection.towardHaGiang),
        chain: fixture,
      );
      expect(pos.isCompleted, isTrue);
      expect(pos.percentOfCountry, lessThanOrEqualTo(100));
      expect(pos.next, isNull);
      expect(pos.fractionAlongRoute, closeTo(1, kTol));
      expect(
        pos.routeDistanceKm,
        closeTo(dest, kTol),
      ); // clamped to destination
      expect(pos.destination.id, 'ha_giang');
    });

    test('AC-15 off-direction tip is rejected by the model guard', () {
      expect(
        () => RouteSelection.create(
          start: fixture.nodes.firstWhere((p) => p.id == 'ha_giang'),
          direction: JourneyDirection.towardHaGiang,
          routeStartOffsetKm: 0,
          chain: fixture,
        ),
        throwsArgumentError,
      );
    });

    test('NF1 determinism: same inputs twice → equal', () {
      final s = sel('can_tho', JourneyDirection.towardHaGiang);
      final a = RouteProgressResolver.resolve(
        routeDistanceKm: 412.5,
        selection: s,
        chain: fixture,
      );
      final b = RouteProgressResolver.resolve(
        routeDistanceKm: 412.5,
        selection: s,
        chain: fixture,
      );
      expect(a, equals(b));
    });
  });
}
