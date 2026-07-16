// Unit tests for the RoadRoute domain type (route-real-road / AC-2/AC-4).
//
// Pure + deterministic: a small straight-ish RoadPath in memory. Covers the
// DETOUR model (route-real-road) — the drawn line must TOUCH every real
// waypoint via a highway spur:
//   - the drawn line starts/ends at the REAL start/end (not the snapped vertex)
//   - waypointCoordinates ARE the real input waypoints (markers at true cities)
//   - an OFF-highway stop is reached by a spur (path contains the real stop and
//     returns to its snapped road vertex); the detour grows the route length
//   - the drawn line still travels the road slice in travel order at a seam
//   - coordinateAtFraction rides the drawn line by the progress fraction (AC-5)
//   - stretchBetween follows the drawn line across interior vertices (idle trace)

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/domain/road_path.dart';
import 'package:focus_journey/features/route/domain/road_route.dart';

GeoCoordinate _c(double lon, double lat) =>
    GeoCoordinate(longitude: lon, latitude: lat);

/// A south→north road at lon 105 with 0.25° vertex spacing (9.0 .. 12.0).
RoadPath _road() => RoadPath(<GeoCoordinate>[
  for (var i = 0; i <= 12; i++) _c(105.0, 9.0 + i * 0.25),
]);

void main() {
  group('RoadRoute default (start → end, no stops)', () {
    test('the drawn line starts/ends at the REAL waypoints, not the snapped '
        'vertices', () {
      final road = _road();
      // Off-road-ish endpoints (0.01–0.02° away from the nearest vertex).
      final start = _c(105.01, 9.02);
      final end = _c(104.99, 11.98);
      final route = RoadRoute.build(
        road: road,
        waypoints: <GeoCoordinate>[start, end],
      );
      expect(route.isEmpty, isFalse);
      // waypointCoordinates ARE the real input waypoints (markers at true cities).
      expect(route.waypointCoordinates.first, start);
      expect(route.waypointCoordinates.last, end);
      // The drawn line touches the real start and end exactly.
      expect(route.points.first, start);
      expect(route.points.last, end);
      // It still threads the road: the snapped road vertices are on the line.
      expect(route.points.contains(_c(105.0, 9.0)), isTrue);
      expect(route.points.contains(_c(105.0, 12.0)), isTrue);
    });

    test('coordinateAtFraction(0/1) return the REAL start/end', () {
      final route = RoadRoute.build(
        road: _road(),
        waypoints: <GeoCoordinate>[_c(105.01, 9.02), _c(104.99, 11.98)],
      );
      expect(route.coordinateAtFraction(0), _c(105.01, 9.02));
      expect(route.coordinateAtFraction(1), _c(104.99, 11.98));
    });

    test('length equals the road sub-path length when the endpoints are '
        'on-road', () {
      final road = _road();
      final route = RoadRoute.build(
        road: road,
        waypoints: <GeoCoordinate>[_c(105, 9), _c(105, 12)],
      );
      expect(route.routeLengthKm, closeTo(road.lengthKm, 1e-6));
    });
  });

  group('RoadRoute with an off-highway stop (AC-4)', () {
    test('spurs off the road to reach the real stop and returns to the road; '
        'the detour grows the route length', () {
      final road = _road();
      // A stop 1° EAST of the road at lat 10.5 — genuinely off the highway.
      final stop = _c(106.0, 10.5);
      final route = RoadRoute.build(
        road: road,
        waypoints: <GeoCoordinate>[_c(105, 9), stop, _c(105, 12)],
      );
      // Three real waypoints — the mid one is the true (off-road) stop.
      expect(route.waypointCoordinates.length, 3);
      expect(route.waypointCoordinates[1], stop);
      // The drawn line CONTAINS the real off-road stop (the spur reaches it).
      expect(route.points.contains(stop), isTrue);
      // And it RETURNS to the stop's snapped road vertex (105, 10.5) so the next
      // slice continues along the highway — the out-and-back spur is present.
      final stopVertexUses = route.points
          .where((p) => p == _c(105.0, 10.5))
          .length;
      expect(stopVertexUses, greaterThanOrEqualTo(2));
      // The round-trip detour grows the route beyond the no-stop length.
      final noStop = RoadRoute.build(
        road: road,
        waypoints: <GeoCoordinate>[_c(105, 9), _c(105, 12)],
      );
      expect(route.routeLengthKm, greaterThan(noStop.routeLengthKm));
    });
  });

  group('RoadRoute marker riding (AC-5)', () {
    test('coordinateAtFraction interpolates along the road', () {
      final route = RoadRoute.build(
        road: _road(),
        waypoints: <GeoCoordinate>[_c(105, 9), _c(105, 12)],
      );
      expect(route.coordinateAtFraction(0).latitude, closeTo(9.0, 1e-9));
      expect(route.coordinateAtFraction(1).latitude, closeTo(12.0, 1e-9));
      // Halfway along a straight-lon road ≈ latitude 10.5.
      expect(route.coordinateAtFraction(0.5).latitude, closeTo(10.5, 0.05));
    });
  });

  group('RoadRoute.stretchBetween', () {
    test('follows the road across interior vertices', () {
      final route = RoadRoute.build(
        road: _road(),
        waypoints: <GeoCoordinate>[_c(105, 9), _c(105, 12)],
      );
      final stretch = route.stretchBetween(0, route.routeLengthKm);
      expect(stretch.points.first.latitude, closeTo(9.0, 1e-9));
      expect(stretch.points.last.latitude, closeTo(12.0, 1e-9));
      expect(stretch.points.length, greaterThan(2));
    });

    test('a zero-width span yields an empty stretch', () {
      final route = RoadRoute.build(
        road: _road(),
        waypoints: <GeoCoordinate>[_c(105, 9), _c(105, 12)],
      );
      expect(route.stretchBetween(10, 10).isEmpty, isTrue);
    });
  });

  test('fewer than two waypoints yields an empty route', () {
    final route = RoadRoute.build(
      road: _road(),
      waypoints: <GeoCoordinate>[_c(105, 9)],
    );
    expect(route.isEmpty, isTrue);
    expect(route.routeLengthKm, 0);
  });
}
