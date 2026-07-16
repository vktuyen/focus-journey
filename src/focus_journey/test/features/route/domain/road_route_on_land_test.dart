// Verifies the DRAWN road route against the REAL bundled geometry
// (route-real-road / AC-2 / AC-5). Loads both shipped assets from disk, builds
// the default route (Cà Mau → Cao Bằng, no stops) along the road, and asserts:
//   - the sub-path runs start → end along the road (no straight sea chord)
//   - it stays on land when densely sampled against BaseMapGeometry.containsLandmass
//     (the real road is on land by construction; the simplified base-map coastline
//     sits just inland of the real road in a few spots, so we assert a HIGH on-land
//     fraction — the curator measured ~99.5% — not a strict 100%)
//   - the default route is drawn as (essentially) the ENTIRE bundled road.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/data/base_map_repository.dart';
import 'package:focus_journey/features/route/data/road_path_repository.dart';
import 'package:focus_journey/features/route/domain/base_map_geometry.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/domain/road_path.dart';
import 'package:focus_journey/features/route/domain/road_route.dart';

String _readAsset(String relativePath) {
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
  fail('could not locate $relativePath from cwd ${Directory.current.path}');
}

void main() {
  late RoadPath road;
  late BaseMapGeometry base;
  late RoadRoute defaultRoute;

  setUpAll(() {
    road = AssetRoadPathRepository.parseGeoJson(_readAsset(kRoadPathAssetPath));
    base = AssetBaseMapRepository.parseGeoJson(_readAsset(kBaseMapAssetPath));
    // The default route: the south tip (Cà Mau) → the north tip (Cao Bằng),
    // no stops — exactly the two chain endpoints.
    final chain = vietnamProvinceChain;
    final start = vietnamProvinceGeography.coordinateOf(chain.nodes.first);
    final end = vietnamProvinceGeography.coordinateOf(chain.nodes.last);
    defaultRoute = RoadRoute.build(
      road: road,
      waypoints: <GeoCoordinate>[start, end],
    );
  });

  test('the default route is drawn as (nearly) the whole bundled road', () {
    // Cà Mau + Cao Bằng snap to the nearest road vertices near the two ends; the
    // province CENTRES sit slightly inland of the road's physical tips (and the
    // road ends ~19 km short of Cao Bằng), so the drawn sub-path covers MOST of
    // the road AND now spurs out to the real province centres (route-real-road
    // detour). The route length is therefore the road slice PLUS the two
    // start/end connectors — within a small band of the full road.
    expect(defaultRoute.routeLengthKm, greaterThan(road.lengthKm * 0.95));
    // The detour connectors (notably the ~19 km end connector to Cao Bằng) push
    // the length modestly ABOVE the raw road length — but not by more than the
    // round-trip of the two connectors.
    expect(defaultRoute.routeLengthKm, lessThan(road.lengthKm + 80));
    // The drawn line touches the REAL province centres (south → north).
    expect(defaultRoute.points.first.latitude, lessThan(10));
    expect(defaultRoute.points.last.latitude, greaterThan(22));
  });

  test('the drawn road route stays on land when densely sampled (AC-5)', () {
    // Densely sample: every vertex + the midpoint of every segment.
    final points = defaultRoute.points;
    var total = 0;
    var onLand = 0;
    for (var i = 0; i < points.length; i++) {
      total++;
      if (base.containsLandmass(points[i])) {
        onLand++;
      }
      if (i + 1 < points.length) {
        final mid = points[i].lerpTo(points[i + 1], 0.5);
        total++;
        if (base.containsLandmass(mid)) {
          onLand++;
        }
      }
    }
    final fraction = onLand / total;
    // The real road is on land by construction; the small residual is where the
    // SIMPLIFIED base-map coastline sits just inland of the real coastal road
    // (curator: ~99.5% on land). Assert a high on-land fraction, not a strict 100%.
    expect(
      fraction,
      greaterThan(0.985),
      reason: 'road route on-land fraction was $fraction (expected > 0.985)',
    );
  });

  test('a route WITH an off-highway marked stop spurs out to the real stop and '
      'stays on land (AC-8)', () {
    // An Giang sits ~71 km WEST of the bundled national road — a genuinely
    // off-highway anchor. The drawn line must DETOUR out to its real centre and
    // back (route-real-road / AC-4/AC-8), still on land.
    final chain = vietnamProvinceChain;
    final start = vietnamProvinceGeography.coordinateOf(chain.nodes.first);
    final end = vietnamProvinceGeography.coordinateOf(chain.nodes.last);
    final anGiang = vietnamProvinceGeography.coordinateOf(
      chain.nodes.firstWhere((n) => n.id == 'an_giang'),
    );
    final stopRoute = RoadRoute.build(
      road: road,
      waypoints: <GeoCoordinate>[start, anGiang, end],
    );

    // The spur genuinely reaches the real off-highway stop.
    expect(stopRoute.points.contains(anGiang), isTrue);
    // The out-and-back detour grows the route beyond the no-stop default.
    expect(stopRoute.routeLengthKm, greaterThan(defaultRoute.routeLengthKm));

    // Densely sample the drawn line (every vertex + each segment midpoint)
    // against the SIMPLIFIED base-map coastline. The spur chords the ~71 km out
    // to An Giang across the Mekong delta (inland), so it stays on land to the
    // same high standard the default route holds (curator residual: ~99.5%).
    final points = stopRoute.points;
    var total = 0;
    var onLand = 0;
    for (var i = 0; i < points.length; i++) {
      total++;
      if (base.containsLandmass(points[i])) {
        onLand++;
      }
      if (i + 1 < points.length) {
        final mid = points[i].lerpTo(points[i + 1], 0.5);
        total++;
        if (base.containsLandmass(mid)) {
          onLand++;
        }
      }
    }
    final fraction = onLand / total;
    expect(
      fraction,
      greaterThan(0.985),
      reason: 'stop-spur route on-land fraction was $fraction (expected > 0.985)',
    );
  });

  test('the km readout equals the drawn road sub-path length', () {
    // The route length the "km to end" readout keys off is the DRAWN road
    // sub-path length (route-real-road / #4) — the km matches what is drawn.
    // Sanity: a real-world national-highway length (~2.4k–2.6k km), now with the
    // detour connectors out to the real province centres included.
    expect(defaultRoute.routeLengthKm, greaterThan(2400));
    expect(defaultRoute.routeLengthKm, lessThan(2700));
    // It is the road sub-path length PLUS the two start/end connectors — close to
    // the full bundled road, never wildly beyond it.
    expect(defaultRoute.routeLengthKm, lessThan(road.lengthKm + 80));
  });
}
