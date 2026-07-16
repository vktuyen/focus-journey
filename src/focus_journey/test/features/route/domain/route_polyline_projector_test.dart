// Unit tests for the CORE projection algorithm (map-experience Decision A:
// curated km axis, per-leg lat/long lerp). RoutePolylineProjector turns a
// route-distance-km into a lat/long marker (coordinateAt) and an idle span into
// a road-following polyline stretch (stretchBetween).
//
// Pure-function tests: no Flutter, no I/O, no timers, no latlong2. A small
// SYNTHETIC chain + geography pins the lerp math with hand-computed expected
// coordinates; the production chain/geography exercises both real directions.
//
// Covers (mapping rule):
//   TC-205  distance 0 → start checkpoint coordinate
//   TC-206  distance >= routeLength → destination pin, no overshoot
//   TC-203  distance strictly inside a leg → leg-endpoint lerp by km-fraction
//   TC-202  span crossing a checkpoint → stretch includes the interior vertex
//   TC-207  point exactly on a checkpoint boundary → deterministic, stable
//   TC-NF1  determinism: same inputs → equal outputs
//   AC-4/AC-5 both travel directions project correctly

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/domain/journey_direction.dart';
import 'package:focus_journey/features/route/domain/province.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/domain/route_polyline_projector.dart';
import 'package:focus_journey/features/route/domain/route_selection.dart';

const double kTol = 1e-6;

// Synthetic 3-node chain: A --100km--> B --100km--> C (total 200 km).
// Cumulative-from-A: A=0, B=100, C=200.
// Coordinates chosen so each leg's lat/long lerp is trivial to hand-compute.
const Province a = Province(id: 'a', name: 'A');
const Province b = Province(id: 'b', name: 'B');
const Province c = Province(id: 'c', name: 'C');

const GeoCoordinate coordA = GeoCoordinate(latitude: 10.0, longitude: 105.0);
const GeoCoordinate coordB = GeoCoordinate(latitude: 12.0, longitude: 106.0);
const GeoCoordinate coordC = GeoCoordinate(latitude: 20.0, longitude: 104.0);

ProvinceChain _chain() => ProvinceChain(
  nodes: const <Province>[a, b, c],
  segmentsKm: const <double>[100, 100],
);

ProvinceGeography _geography(ProvinceChain chain) => ProvinceGeography(
  chain: chain,
  coordinates: const <String, GeoCoordinate>{
    'a': coordA,
    'b': coordB,
    'c': coordC,
  },
);

RoutePolylineProjector _northProjector() {
  final chain = _chain();
  final geo = _geography(chain);
  return RoutePolylineProjector.fromRoute(
    start: a,
    direction: JourneyDirection.towardHaGiang, // A → B → C
    geography: geo,
  );
}

void _expectCoord(GeoCoordinate actual, double lat, double long) {
  expect(actual.latitude, closeTo(lat, kTol));
  expect(actual.longitude, closeTo(long, kTol));
}

void main() {
  group('coordinateAt — boundaries (TC-205 / TC-206)', () {
    test('atZero_returnsStartCheckpointCoordinate (TC-205)', () {
      final projector = _northProjector();
      _expectCoord(
        projector.coordinateAt(0),
        coordA.latitude,
        coordA.longitude,
      );
    });

    test('belowZero_clampsToStartCheckpoint_noUnderflow (TC-205)', () {
      final projector = _northProjector();
      _expectCoord(
        projector.coordinateAt(-50),
        coordA.latitude,
        coordA.longitude,
      );
    });

    test('atRouteLength_returnsDestinationPin (TC-206)', () {
      final projector = _northProjector();
      expect(projector.routeLengthKm, closeTo(200, kTol));
      _expectCoord(
        projector.coordinateAt(200),
        coordC.latitude,
        coordC.longitude,
      );
    });

    test('beyondRouteLength_clampsToDestination_noOvershoot (TC-206)', () {
      final projector = _northProjector();
      _expectCoord(
        projector.coordinateAt(9999),
        coordC.latitude,
        coordC.longitude,
      );
    });

    test('nonFiniteDistance_clampsToStart_noCrash (TC-205)', () {
      final projector = _northProjector();
      _expectCoord(
        projector.coordinateAt(double.nan),
        coordA.latitude,
        coordA.longitude,
      );
    });
  });

  group('coordinateAt — interior of a leg (TC-203)', () {
    test('quarterIntoFirstLeg_lerpsLegEndpointsByKmFraction', () {
      final projector = _northProjector();
      // 25 km into the A→B leg (legKm=100) → fraction 0.25.
      // lat = 10 + 0.25*(12-10) = 10.5; long = 105 + 0.25*(106-105) = 105.25.
      _expectCoord(projector.coordinateAt(25), 10.5, 105.25);
    });

    test('midwayIntoSecondLeg_lerpsThatLegsEndpoints', () {
      final projector = _northProjector();
      // 150 km total = 50 km into the B→C leg → fraction 0.5.
      // lat = 12 + 0.5*(20-12) = 16; long = 106 + 0.5*(104-106) = 105.
      _expectCoord(projector.coordinateAt(150), 16.0, 105.0);
    });

    test(
      'exactlyOnInteriorCheckpoint_returnsThatCheckpointCoordinate (TC-207)',
      () {
        final projector = _northProjector();
        // 100 km = exactly node B.
        _expectCoord(
          projector.coordinateAt(100),
          coordB.latitude,
          coordB.longitude,
        );
      },
    );
  });

  group('baseRoutePolyline + orderedNodes (AC-4)', () {
    test('northRoute_listsCheckpointsOriginToDestinationInOrder', () {
      final projector = _northProjector();
      expect(projector.orderedNodes, <Province>[a, b, c]);
      final poly = projector.baseRoutePolyline;
      expect(poly, <GeoCoordinate>[coordA, coordB, coordC]);
    });

    test('baseRoutePolyline_isUnmodifiable', () {
      final projector = _northProjector();
      expect(
        () => projector.baseRoutePolyline.add(coordA),
        throwsUnsupportedError,
      );
    });
  });

  group('stretchBetween — single leg (TC-201/TC-203)', () {
    test('withinOneLeg_endpointsLerpedNoInteriorVertex', () {
      final projector = _northProjector();
      // [25, 75) inside the A→B leg.
      final stretch = projector.stretchBetween(25, 75);
      expect(stretch.points, hasLength(2));
      _expectCoord(stretch.points.first, 10.5, 105.25); // 25 km
      // 75 km → fraction 0.75: lat = 10 + 0.75*2 = 11.5; long = 105.75.
      _expectCoord(stretch.points.last, 11.5, 105.75);
    });

    test('zeroWidthSpan_yieldsEmptyPolyline', () {
      final projector = _northProjector();
      final stretch = projector.stretchBetween(40, 40);
      expect(stretch.isEmpty, isTrue);
      expect(stretch.points, isEmpty);
    });

    test('outOfRouteSpan_yieldsEmptyPolyline', () {
      final projector = _northProjector();
      // Both ends beyond route length clamp to the destination → zero width.
      final stretch = projector.stretchBetween(300, 400);
      expect(stretch.isEmpty, isTrue);
    });
  });

  group('stretchBetween — crossing a checkpoint boundary (TC-202)', () {
    test('spanCrossingNodeB_includesBAsAnInteriorVertex_followsRoadNotChord', () {
      final projector = _northProjector();
      // [50, 150) crosses node B (at 100). Expect: start@50, B (interior), end@150.
      final stretch = projector.stretchBetween(50, 150);
      expect(stretch.points, hasLength(3));
      // start @ 50 km on A→B (fraction 0.5): lat 11, long 105.5.
      _expectCoord(stretch.points[0], 11.0, 105.5);
      // interior vertex = node B's real coordinate (the boundary point).
      _expectCoord(stretch.points[1], coordB.latitude, coordB.longitude);
      // end @ 150 km (fraction 0.5 of B→C): lat 16, long 105.
      _expectCoord(stretch.points[2], 16.0, 105.0);
    });

    test('boundaryNodeNotDuplicated_whenSpanEndsExactlyOnIt (TC-207)', () {
      final projector = _northProjector();
      // [50, 100): end is exactly node B; B is the clamped endpoint, NOT an
      // additional interior vertex (no duplication of the boundary point).
      final stretch = projector.stretchBetween(50, 100);
      expect(stretch.points, hasLength(2));
      _expectCoord(stretch.points.first, 11.0, 105.5);
      _expectCoord(stretch.points.last, coordB.latitude, coordB.longitude);
    });

    test('boundaryNodeNotDuplicated_whenSpanStartsExactlyOnIt (TC-207)', () {
      final projector = _northProjector();
      // [100, 150): start is exactly node B; appears once as the start endpoint.
      final stretch = projector.stretchBetween(100, 150);
      expect(stretch.points, hasLength(2));
      _expectCoord(stretch.points.first, coordB.latitude, coordB.longitude);
      _expectCoord(stretch.points.last, 16.0, 105.0);
    });
  });

  group('determinism (TC-NF1)', () {
    test('sameSpan_resolvedTwice_yieldsEqualPolylines', () {
      final projector = _northProjector();
      final first = projector.stretchBetween(30, 170);
      final second = projector.stretchBetween(30, 170);
      expect(first, equals(second));
    });

    test('reversedArguments_normaliseToSameStretch', () {
      final projector = _northProjector();
      expect(
        projector.stretchBetween(150, 50),
        equals(projector.stretchBetween(50, 150)),
      );
    });
  });

  group('both travel directions (AC-4 / AC-5)', () {
    test('southRoute_fromCTowardA_reversesNodeOrderAndProjects', () {
      final chain = _chain();
      final geo = _geography(chain);
      final projector = RoutePolylineProjector.fromRoute(
        start: c,
        direction: JourneyDirection.towardMuiCaMau, // C → B → A
        geography: geo,
      );
      expect(projector.orderedNodes, <Province>[c, b, a]);
      expect(projector.routeLengthKm, closeTo(200, kTol));
      // Start pin is C; destination pin is A.
      _expectCoord(
        projector.coordinateAt(0),
        coordC.latitude,
        coordC.longitude,
      );
      _expectCoord(
        projector.coordinateAt(200),
        coordA.latitude,
        coordA.longitude,
      );
      // 100 km along C→B→A is exactly node B.
      _expectCoord(
        projector.coordinateAt(100),
        coordB.latitude,
        coordB.longitude,
      );
    });

    test('production_northFromMuiCaMau_marker0IsSouthTip (AC-5)', () {
      final projector = RoutePolylineProjector.fromRoute(
        start: vietnamProvinceChain.southTip,
        direction: JourneyDirection.towardHaGiang,
        geography: vietnamProvinceGeography,
      );
      final origin = vietnamProvinceGeography.coordinateOf(
        vietnamProvinceChain.southTip,
      );
      _expectCoord(
        projector.coordinateAt(0),
        origin.latitude,
        origin.longitude,
      );
      // Full south→north route length = the derived great-circle total
      // (province-chain-2026), not the retired stylized 2000 km.
      expect(
        projector.routeLengthKm,
        closeTo(vietnamProvinceChain.totalChainKm, kTol),
      );
    });

    test('production_southFromHaGiang_marker0IsNorthTip (AC-5)', () {
      final projector = RoutePolylineProjector.fromRoute(
        start: vietnamProvinceChain.northTip,
        direction: JourneyDirection.towardMuiCaMau,
        geography: vietnamProvinceGeography,
      );
      final origin = vietnamProvinceGeography.coordinateOf(
        vietnamProvinceChain.northTip,
      );
      _expectCoord(
        projector.coordinateAt(0),
        origin.latitude,
        origin.longitude,
      );
      expect(
        projector.routeLengthKm,
        closeTo(vietnamProvinceChain.totalChainKm, kTol),
      );
    });
  });

  group(
    'RoutePolylineProjector via RouteSelection (offset is geometry-agnostic)',
    () {
      test(
        'selectionWithOffset_routeLengthMatchesFromRoute (TC-212 geometry)',
        () {
          final chain = _chain();
          final geo = _geography(chain);
          final withOffset = RoutePolylineProjector(
            selection: RouteSelection.create(
              start: a,
              direction: JourneyDirection.towardHaGiang,
              routeStartOffsetKm: 1000,
              chain: chain,
            ),
            geography: geo,
          );
          // The offset re-bases cumulative→route km upstream; the projector's own
          // geometry (route km axis 0..200) is unaffected.
          expect(withOffset.routeLengthKm, closeTo(200, kTol));
          _expectCoord(withOffset.coordinateAt(25), 10.5, 105.25);
        },
      );
    },
  );
}
