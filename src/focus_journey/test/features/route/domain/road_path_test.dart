// Unit tests for the RoadPath domain type (route-real-road / AC-1).
//
// Pure + deterministic: builds small RoadPaths in memory. Covers:
//   - cumulative great-circle km precompute + total length
//   - stitching ordered segments into ONE path (dropping a duplicate join point)
//   - nearest-vertex snapping picks the closest road vertex

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/domain/haversine.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/domain/road_path.dart';

GeoCoordinate _c(double lon, double lat) =>
    GeoCoordinate(longitude: lon, latitude: lat);

void main() {
  group('RoadPath cumulative distance', () {
    test('precomputes cumulative great-circle km and total length', () {
      final path = RoadPath(<GeoCoordinate>[
        _c(105.0, 9.0),
        _c(105.0, 10.0),
        _c(105.0, 11.0),
      ]);
      final leg = greatCircleKm(9.0, 105.0, 10.0, 105.0);
      expect(path.cumulativeKmAt(0), 0);
      expect(path.cumulativeKmAt(1), closeTo(leg, 1e-9));
      expect(path.cumulativeKmAt(2), closeTo(2 * leg, 1e-6));
      expect(path.lengthKm, closeTo(2 * leg, 1e-6));
    });

    test('rejects a path with fewer than two vertices', () {
      expect(() => RoadPath(<GeoCoordinate>[_c(105, 9)]), throwsArgumentError);
    });
  });

  group('RoadPath.stitch', () {
    test('concatenates ordered segments into one path', () {
      final path = RoadPath.stitch(<List<GeoCoordinate>>[
        <GeoCoordinate>[_c(105, 9), _c(105, 10)],
        <GeoCoordinate>[_c(105.1, 10.2), _c(105.1, 11)],
      ]);
      // All four vertices survive (the segments do not share an exact endpoint).
      expect(path.points.length, 4);
      expect(path.points.first, _c(105, 9));
      expect(path.points.last, _c(105.1, 11));
    });

    test('drops an exact duplicate join vertex at the seam', () {
      final path = RoadPath.stitch(<List<GeoCoordinate>>[
        <GeoCoordinate>[_c(105, 9), _c(105, 10)],
        <GeoCoordinate>[_c(105, 10), _c(105, 11)], // starts on the prior end.
      ]);
      expect(path.points.length, 3); // the shared (105,10) is not duplicated.
    });
  });

  group('RoadPath.nearestVertexIndex', () {
    final path = RoadPath(<GeoCoordinate>[
      _c(105.0, 9.0),
      _c(105.0, 9.5),
      _c(105.0, 10.0),
      _c(105.0, 10.5),
    ]);

    test('snaps a point to the closest vertex', () {
      expect(path.nearestVertexIndex(_c(105.02, 9.98)), 2);
      expect(path.nearestVertexIndex(_c(105.0, 9.0)), 0);
      expect(path.nearestVertexIndex(_c(104.9, 10.49)), 3);
    });
  });
}
