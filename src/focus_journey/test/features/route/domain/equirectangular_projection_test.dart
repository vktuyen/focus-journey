// Unit tests for the georeferencing CORE of the bundled Vietnam base map
// (vietnam-map-fidelity / ADR-0008): the pure, closed-form equirectangular
// projection `(lat, lon) -> normalized (x, y)` under the fixed bounds
// N24 / S8 . W101.8 / E110.3.
//
// Pure-function tests: no Flutter widgets, no I/O, no timers, no network, no
// latlong2. Every expectation is hand-computed from the documented formula
//   x = (lon - 101.8) / (110.3 - 101.8)
//   y = (24   - lat) / (24   - 8)
// so a drift in the bounds or the formula fails loudly.
//
// Covers (see tests/cases/vietnam-map-fidelity.md):
//   TC-809  each checkpoint's lat/long -> exact closed-form normalized position
//   TC-811  bounds corners -> frame edges; out-of-bounds clamped (no NaN/wrap)
//   TC-807  the shipped S->N chain projects monotone-northward in y (pure half)

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/domain/equirectangular_projection.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';

const double kTol = 1e-6;
const double kTightTol = 1e-9;

// The single source of the documented formula, re-derived here so the test is
// independent of the production constants (it pins the CONTRACT, not the code).
const double _north = 24.0;
const double _south = 8.0;
const double _west = 101.8;
const double _east = 110.3;

double _expectX(double lon) => (lon - _west) / (_east - _west);
double _expectY(double lat) => (_north - lat) / (_north - _south);

void main() {
  group('EquirectangularBounds constants match the ADR-0008 declared frame', () {
    test('boundsAreN24S8W1018E1103', () {
      expect(EquirectangularBounds.north, _north);
      expect(EquirectangularBounds.south, _south);
      expect(EquirectangularBounds.west, _west);
      expect(EquirectangularBounds.east, _east);
    });
  });

  group('project — corners map to the frame edges (TC-811)', () {
    test('northWestCorner_mapsToTopLeft_0_0', () {
      final p = EquirectangularBounds.project(_north, _west);
      expect(p.x, closeTo(0.0, kTol));
      expect(p.y, closeTo(0.0, kTol));
    });

    test('southEastCorner_mapsToBottomRight_1_1', () {
      final p = EquirectangularBounds.project(_south, _east);
      expect(p.x, closeTo(1.0, kTol));
      expect(p.y, closeTo(1.0, kTol));
    });

    test('northEastCorner_mapsToTopRight_1_0', () {
      final p = EquirectangularBounds.project(_north, _east);
      expect(p.x, closeTo(1.0, kTol));
      expect(p.y, closeTo(0.0, kTol));
    });

    test('southWestCorner_mapsToBottomLeft_0_1', () {
      final p = EquirectangularBounds.project(_south, _west);
      expect(p.x, closeTo(0.0, kTol));
      expect(p.y, closeTo(1.0, kTol));
    });

    test('centreOfBounds_mapsToFrameCentre_half_half', () {
      final p = EquirectangularBounds.project(
        (_north + _south) / 2,
        (_west + _east) / 2,
      );
      expect(p.x, closeTo(0.5, kTol));
      expect(p.y, closeTo(0.5, kTol));
    });
  });

  group('project — named cities land at their closed-form position (TC-809)', () {
    // Coordinates named in the slice brief / conventions block. Each is asserted
    // against the hand-evaluated formula, not against a captured value.
    void expectCity(String name, double lat, double lon) {
      test('${name}_projectsToClosedFormNormalized', () {
        final p = EquirectangularBounds.project(lat, lon);
        expect(p.x, closeTo(_expectX(lon), kTol), reason: '$name x');
        expect(p.y, closeTo(_expectY(lat), kTol), reason: '$name y');
        // Real checkpoints sit well inside the bounds -> never clamped.
        expect(p.x, inInclusiveRange(0.0, 1.0));
        expect(p.y, inInclusiveRange(0.0, 1.0));
      });
    }

    expectCity('haNoi', 21.03, 105.85);
    expectCity('daNang', 16.06, 108.22);
    expectCity('hoChiMinhCity', 10.78, 106.70);
    // Shipped Mui Ca Mau coordinate (nudged onto the bundled coastline; see
    // province_geography.dart). Pure projection math — any in-bounds point
    // works — but keep it consistent with the shipped geography.
    expectCity('muiCaMau', 8.613, 104.725);
    expectCity('haGiang', 22.82, 104.98);
  });

  group('project — every shipped checkpoint projects on-frame (TC-809)', () {
    test('allThirteenChainCheckpointsProjectInsideZeroToOne', () {
      for (final coord in vietnamProvinceGeography.canonicalCoordinates) {
        final p = EquirectangularBounds.project(
          coord.latitude,
          coord.longitude,
        );
        expect(p.x, inInclusiveRange(0.0, 1.0), reason: '$coord x off-frame');
        expect(p.y, inInclusiveRange(0.0, 1.0), reason: '$coord y off-frame');
        // Inside the bounds the value must equal the raw formula (no clamping).
        expect(p.x, closeTo(_expectX(coord.longitude), kTol));
        expect(p.y, closeTo(_expectY(coord.latitude), kTol));
      }
    });
  });

  group('project — out-of-bounds is clamped, never NaN/overflow/wrap (TC-811)', () {
    test('latAboveNorth_clampsYToZero', () {
      final p = EquirectangularBounds.project(30.0, 106.0);
      expect(p.y, 0.0);
    });

    test('latBelowSouth_clampsYToOne', () {
      final p = EquirectangularBounds.project(0.0, 106.0);
      expect(p.y, 1.0);
    });

    test('lonWestOfBound_clampsXToZero', () {
      final p = EquirectangularBounds.project(16.0, 90.0);
      expect(p.x, 0.0);
    });

    test('lonEastOfBound_clampsXToOne', () {
      final p = EquirectangularBounds.project(16.0, 130.0);
      expect(p.x, 1.0);
    });

    test('wildlyOutOfRangeInput_yieldsFiniteClampedPoint_noNaN', () {
      final p = EquirectangularBounds.project(1000.0, -1000.0);
      expect(p.x.isNaN, isFalse);
      expect(p.y.isNaN, isFalse);
      expect(p.x, inInclusiveRange(0.0, 1.0));
      expect(p.y, inInclusiveRange(0.0, 1.0));
      // -1000 lon is west of the frame -> x=0; 1000 lat is north -> y=0.
      expect(p.x, 0.0);
      expect(p.y, 0.0);
    });
  });

  group('project — monotonic in each axis', () {
    test('increasingLat_strictlyDecreasesY_northwardIsUp', () {
      const lon = 106.0;
      final south = EquirectangularBounds.project(10.0, lon);
      final mid = EquirectangularBounds.project(15.0, lon);
      final north = EquirectangularBounds.project(20.0, lon);
      expect(south.y, greaterThan(mid.y));
      expect(mid.y, greaterThan(north.y));
    });

    test('increasingLon_strictlyIncreasesX_eastwardIsRight', () {
      const lat = 16.0;
      final west = EquirectangularBounds.project(lat, 103.0);
      final mid = EquirectangularBounds.project(lat, 106.0);
      final east = EquirectangularBounds.project(lat, 109.0);
      expect(west.x, lessThan(mid.x));
      expect(mid.x, lessThan(east.x));
    });
  });

  group('project — inverse relationship round-trips (documented)', () {
    // The projection is the closed-form inverse of
    //   lat = north - y*(north-south),  lon = west + x*(east-west)
    // Assert the round-trip for in-bounds inputs (clamping only fires outside).
    test('projectThenInvert_recoversLatLon_forInBoundsPoints', () {
      const samples = <List<double>>[
        <double>[8.0, 101.8],
        <double>[24.0, 110.3],
        <double>[16.0, 106.05],
        <double>[21.03, 105.85],
        <double>[10.78, 106.70],
      ];
      for (final s in samples) {
        final lat = s[0], lon = s[1];
        final p = EquirectangularBounds.project(lat, lon);
        final recoveredLat = _north - p.y * (_north - _south);
        final recoveredLon = _west + p.x * (_east - _west);
        expect(recoveredLat, closeTo(lat, kTightTol), reason: 'lat @($lat,$lon)');
        expect(recoveredLon, closeTo(lon, kTightTol), reason: 'lon @($lat,$lon)');
      }
    });
  });

  group('route S->N reads broadly northward in y (TC-807 — pure half)', () {
    test('shippedChainEndpointsAreTheProjectedYExtremes_broadlyNorthward', () {
      // canonicalCoordinates are ordered south tip -> north tip; northward is a
      // SMALLER y in the frame. Under province-chain-2026 the spine is a
      // hand-curated COAST-HUGGING order that threads inland units, so it is
      // deliberately NOT a strict per-index latitude sort (PC-904) — a strict
      // "y decreases at every step" assertion would contradict the resolved
      // coast-hugging decision. Instead assert the OVERALL northward reading:
      // the south tip projects to the largest y (bottom) and the north tip to
      // the smallest y (top), and the net trend is northward.
      final coords = vietnamProvinceGeography.canonicalCoordinates;
      final ys = <double>[
        for (final c in coords)
          EquirectangularBounds.project(c.latitude, c.longitude).y,
      ];
      final maxY = ys.reduce((a, b) => a > b ? a : b);
      final minY = ys.reduce((a, b) => a < b ? a : b);
      expect(ys.first, closeTo(maxY, 1e-9), reason: 'south tip is bottommost');
      expect(ys.last, closeTo(minY, 1e-9), reason: 'north tip is topmost');
      expect(ys.last, lessThan(ys.first), reason: 'net reading is northward');
    });
  });

  group('every 34-unit checkpoint projects on-canvas, no clamp fires '
      '(AC-7 / PC-915)', () {
    test('PC-915 all34CheckpointsStrictlyInsideZeroToOne_andUnclamped', () {
      final coords = vietnamProvinceGeography.canonicalCoordinates;
      expect(coords, hasLength(34));
      for (final c in coords) {
        final p = EquirectangularBounds.project(c.latitude, c.longitude);
        // Strictly within (0, 1): the 34 units sit well inside the map frame,
        // never on an edge.
        expect(
          p.x,
          greaterThan(0.0),
          reason: '$c x on/over the west edge (clamp risk)',
        );
        expect(p.x, lessThan(1.0), reason: '$c x on/over the east edge');
        expect(p.y, greaterThan(0.0), reason: '$c y on/over the north edge');
        expect(p.y, lessThan(1.0), reason: '$c y on/over the south edge');
        // Equality with the RAW unclamped formula proves the out-of-bounds
        // clamp never fired for any real checkpoint (a clamped point would
        // differ from the raw value).
        expect(p.x, closeTo(_expectX(c.longitude), kTightTol));
        expect(p.y, closeTo(_expectY(c.latitude), kTightTol));
      }
    });
  });

  group('NormalizedPoint — value semantics', () {
    test('equalComponents_areEquatableEqual', () {
      const a = NormalizedPoint(0.25, 0.75);
      const b = NormalizedPoint(0.25, 0.75);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('differingComponents_areNotEqual', () {
      expect(
        const NormalizedPoint(0.25, 0.75),
        isNot(equals(const NormalizedPoint(0.75, 0.25))),
      );
    });
  });
}
