// Unit tests for the SINGLE real-geography model (map-experience Decision B):
// GeoCoordinate (lerp + Equatable) and ProvinceGeography (chain-integrity guard,
// bbox guard, canonical ordering) plus the production vietnamProvinceGeography
// constant.
//
// Pure-data tests: no Flutter, no I/O, no timers, no latlong2. Mirrors the
// province_chain_test.dart style. Asserts against BOTH a small synthetic
// fixture (to pin exact lerp math by hand) and the production constant.
//
// Covers: AC-4 (provinces at real lat/long, chained in order — TC-209),
//         AC-5 (single geography model — TC-211).

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/domain/province.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';

const double kTol = 1e-9;

// Vietnam bounding box (degrees) the production data must sit inside (TC-209).
const double _minLat = 8.5;
const double _maxLat = 23.5;
const double _minLong = 102.0;
const double _maxLong = 110.0;

const Province south = Province(id: 'south', name: 'South tip');
const Province mid = Province(id: 'mid', name: 'Middle');
const Province north = Province(id: 'north', name: 'North tip');

ProvinceChain _synthChain() => ProvinceChain(
  nodes: const <Province>[south, mid, north],
  segmentsKm: const <double>[100, 100],
);

ProvinceGeography _synthGeography(ProvinceChain chain) => ProvinceGeography(
  chain: chain,
  coordinates: const <String, GeoCoordinate>{
    'south': GeoCoordinate(latitude: 9.0, longitude: 105.0),
    'mid': GeoCoordinate(latitude: 15.0, longitude: 107.0),
    'north': GeoCoordinate(latitude: 21.0, longitude: 104.0),
  },
);

void main() {
  group('GeoCoordinate — lerpTo + Equatable (AC-4)', () {
    const a = GeoCoordinate(latitude: 10.0, longitude: 100.0);
    const b = GeoCoordinate(latitude: 20.0, longitude: 110.0);

    test('lerpTo_atZero_returnsThisEndpoint', () {
      final result = a.lerpTo(b, 0);
      expect(result.latitude, closeTo(10.0, kTol));
      expect(result.longitude, closeTo(100.0, kTol));
    });

    test('lerpTo_atOne_returnsOtherEndpoint', () {
      final result = a.lerpTo(b, 1);
      expect(result.latitude, closeTo(20.0, kTol));
      expect(result.longitude, closeTo(110.0, kTol));
    });

    test('lerpTo_atMidpoint_returnsHandComputedMidpoint', () {
      final result = a.lerpTo(b, 0.5);
      expect(result.latitude, closeTo(15.0, kTol));
      expect(result.longitude, closeTo(105.0, kTol));
    });

    test('lerpTo_atQuarter_returnsHandComputedQuarter', () {
      final result = a.lerpTo(b, 0.25);
      expect(result.latitude, closeTo(12.5, kTol));
      expect(result.longitude, closeTo(102.5, kTol));
    });

    test('lerpTo_clampsNegativeFractionToZero', () {
      final result = a.lerpTo(b, -1.0);
      expect(result, a);
    });

    test('lerpTo_clampsAboveOneToOne', () {
      final result = a.lerpTo(b, 2.0);
      expect(result, b);
    });

    test('equalCoordinates_areEquatableEqual', () {
      const x = GeoCoordinate(latitude: 10.0, longitude: 100.0);
      const y = GeoCoordinate(latitude: 10.0, longitude: 100.0);
      expect(x, equals(y));
      expect(x.hashCode, equals(y.hashCode));
    });

    test('differingCoordinates_areNotEqual', () {
      expect(a, isNot(equals(b)));
    });
  });

  group('ProvinceGeography — chain-integrity guard (TC-209)', () {
    test('constructs_whenEveryChainProvinceHasACoordinate', () {
      final chain = _synthChain();
      expect(() => _synthGeography(chain), returnsNormally);
    });

    test('throws_whenAChainProvinceHasNoCoordinate', () {
      final chain = _synthChain();
      expect(
        () => ProvinceGeography(
          chain: chain,
          coordinates: const <String, GeoCoordinate>{
            'south': GeoCoordinate(latitude: 9.0, longitude: 105.0),
            // 'mid' missing
            'north': GeoCoordinate(latitude: 21.0, longitude: 104.0),
          },
        ),
        throwsArgumentError,
      );
    });

    test('throws_whenACoordinateSitsOutsideTheVietnamBbox', () {
      final chain = _synthChain();
      expect(
        () => ProvinceGeography(
          chain: chain,
          coordinates: const <String, GeoCoordinate>{
            'south': GeoCoordinate(latitude: 9.0, longitude: 105.0),
            // longitude swapped with latitude — a typo the guard must reject.
            'mid': GeoCoordinate(latitude: 107.0, longitude: 15.0),
            'north': GeoCoordinate(latitude: 21.0, longitude: 104.0),
          },
        ),
        throwsArgumentError,
      );
    });

    test('extraCoordinatesForNonChainProvinces_areTolerated', () {
      // An extra entry is harmless: only chain ids are validated/consumed.
      final chain = _synthChain();
      expect(
        () => ProvinceGeography(
          chain: chain,
          coordinates: const <String, GeoCoordinate>{
            'south': GeoCoordinate(latitude: 9.0, longitude: 105.0),
            'mid': GeoCoordinate(latitude: 15.0, longitude: 107.0),
            'north': GeoCoordinate(latitude: 21.0, longitude: 104.0),
            'orphan': GeoCoordinate(latitude: 12.0, longitude: 106.0),
          },
        ),
        returnsNormally,
      );
    });

    test('coordinateOf_throws_forAProvinceNotInTheChain', () {
      final geography = _synthGeography(_synthChain());
      const stranger = Province(id: 'stranger', name: 'Stranger');
      expect(() => geography.coordinateOf(stranger), throwsArgumentError);
    });

    test('canonicalCoordinates_followChainOrderSouthToNorth', () {
      final geography = _synthGeography(_synthChain());
      final coords = geography.canonicalCoordinates;
      expect(coords, hasLength(3));
      expect(coords.first.latitude, closeTo(9.0, kTol)); // south first
      expect(coords.last.latitude, closeTo(21.0, kTol)); // north last
    });
  });

  group('vietnamProvinceGeography — production data integrity (TC-209)', () {
    test('hasACoordinateForEveryChainCheckpoint', () {
      for (final node in vietnamProvinceChain.nodes) {
        expect(
          () => vietnamProvinceGeography.coordinateOf(node),
          returnsNormally,
          reason: 'missing coordinate for ${node.id}',
        );
      }
    });

    test('coversAllThirteenProvinces', () {
      expect(vietnamProvinceChain.nodes, hasLength(13));
      expect(vietnamProvinceGeography.canonicalCoordinates, hasLength(13));
    });

    test('everyCoordinateSitsInsideTheVietnamBbox', () {
      for (final coord in vietnamProvinceGeography.canonicalCoordinates) {
        expect(
          coord.latitude,
          inInclusiveRange(_minLat, _maxLat),
          reason: 'latitude ${coord.latitude} out of bbox',
        );
        expect(
          coord.longitude,
          inInclusiveRange(_minLong, _maxLong),
          reason: 'longitude ${coord.longitude} out of bbox',
        );
      }
    });

    test('canonicalCoordinates_traceSouthTipToNorthTip', () {
      final coords = vietnamProvinceGeography.canonicalCoordinates;
      // Mũi Cà Mau (~8.6 N) is the south tip; Hà Giang (~22.8 N) the north tip.
      expect(coords.first.latitude, lessThan(coords.last.latitude));
      expect(coords.first.latitude, lessThan(10.0));
      expect(coords.last.latitude, greaterThan(22.0));
    });

    test('roadIsNotASingleStraightLine_consecutiveLegsAreNotAllColinear', () {
      // AC-4: the outline must trace the country, not a stylized straight line.
      // Cross-product of consecutive leg vectors must be non-zero somewhere.
      final coords = vietnamProvinceGeography.canonicalCoordinates;
      var foundBend = false;
      for (var i = 1; i < coords.length - 1; i++) {
        final ax = coords[i].longitude - coords[i - 1].longitude;
        final ay = coords[i].latitude - coords[i - 1].latitude;
        final bx = coords[i + 1].longitude - coords[i].longitude;
        final by = coords[i + 1].latitude - coords[i].latitude;
        final cross = ax * by - ay * bx;
        if (cross.abs() > 1e-6) {
          foundBend = true;
          break;
        }
      }
      expect(
        foundBend,
        isTrue,
        reason: 'road is colinear — not a country shape',
      );
    });
  });
}
