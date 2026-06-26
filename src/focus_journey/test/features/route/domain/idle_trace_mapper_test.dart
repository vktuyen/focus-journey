// Unit tests for the segment→geometry seam (map-experience Decision C).
// IdleTraceMapper.resolve maps the idle-accounting distance-keyed segment record
// (absolute cumulative km) onto the CURRENT route's red stretches: active
// segments produce none; idle segments are re-based by routeStartOffsetKm,
// clipped to [0, routeLength], and projected through stretchBetween.
//
// Pure-function tests: no Flutter, no I/O, no timers. Synthetic chain/geography
// (A--100-->B--100-->C, total 200 km) so geometry is hand-checkable.
//
// Covers:
//   AC-6   only idle segments produce red stretches; active produce none
//   AC-7   zero idle segments → empty list
//   AC-8   re-base by offset + clip to [0, routeLength] (current route only)
//   AC-9   voluntary vs lockSleep cause preserved on the IdleStretch
//   AC-12  pure read — recorded cause/classification kept untouched
//   (documented) zero-width idle segment (fromKm == toKm) → no visible stretch

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/activity_segment.dart';
import 'package:focus_journey/features/route/domain/journey_direction.dart';
import 'package:focus_journey/features/route/domain/province.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/idle_trace_mapper.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/domain/route_polyline_projector.dart';

const double kTol = 1e-6;

const Province a = Province(id: 'a', name: 'A');
const Province b = Province(id: 'b', name: 'B');
const Province c = Province(id: 'c', name: 'C');

const GeoCoordinate coordA = GeoCoordinate(latitude: 10.0, longitude: 105.0);
const GeoCoordinate coordB = GeoCoordinate(latitude: 12.0, longitude: 106.0);
const GeoCoordinate coordC = GeoCoordinate(latitude: 20.0, longitude: 104.0);

RoutePolylineProjector _projector() {
  final chain = ProvinceChain(
    nodes: const <Province>[a, b, c],
    segmentsKm: const <double>[100, 100],
  );
  final geo = ProvinceGeography(
    chain: chain,
    coordinates: const <String, GeoCoordinate>{
      'a': coordA,
      'b': coordB,
      'c': coordC,
    },
  );
  return RoutePolylineProjector.fromRoute(
    start: a,
    direction: JourneyDirection.towardHaGiang,
    geography: geo,
  );
}

ActivitySegment _seg(
  double fromKm,
  double toKm, {
  SegmentClassification classification = SegmentClassification.idle,
  SegmentCause cause = SegmentCause.voluntary,
}) => ActivitySegment(
  fromKm: fromKm,
  toKm: toKm,
  elapsed: Duration.zero,
  classification: classification,
  cause: cause,
);

void main() {
  group('classification filtering (AC-6)', () {
    test('idleSegment_producesOneStretch', () {
      final result = IdleTraceMapper.resolve(
        segments: <ActivitySegment>[_seg(25, 75)],
        routeStartOffsetKm: 0,
        projector: _projector(),
      );
      expect(result, hasLength(1));
      expect(result.single.polyline.points, hasLength(2));
    });

    test('activeSegment_producesNoStretch', () {
      final result = IdleTraceMapper.resolve(
        segments: <ActivitySegment>[
          _seg(
            25,
            75,
            classification: SegmentClassification.active,
            cause: SegmentCause.none,
          ),
        ],
        routeStartOffsetKm: 0,
        projector: _projector(),
      );
      expect(result, isEmpty);
    });

    test('mixedSegments_onlyIdleOnesProduceStretches', () {
      final result = IdleTraceMapper.resolve(
        segments: <ActivitySegment>[
          _seg(10, 30),
          _seg(
            30,
            60,
            classification: SegmentClassification.active,
            cause: SegmentCause.none,
          ),
          _seg(60, 90),
        ],
        routeStartOffsetKm: 0,
        projector: _projector(),
      );
      expect(result, hasLength(2));
    });
  });

  group('zero-idle route (AC-7)', () {
    test('noSegments_yieldsEmptyList', () {
      final result = IdleTraceMapper.resolve(
        segments: const <ActivitySegment>[],
        routeStartOffsetKm: 0,
        projector: _projector(),
      );
      expect(result, isEmpty);
    });

    test('allActiveSegments_yieldsEmptyList', () {
      final result = IdleTraceMapper.resolve(
        segments: <ActivitySegment>[
          _seg(
            0,
            100,
            classification: SegmentClassification.active,
            cause: SegmentCause.none,
          ),
          _seg(
            100,
            200,
            classification: SegmentClassification.active,
            cause: SegmentCause.none,
          ),
        ],
        routeStartOffsetKm: 0,
        projector: _projector(),
      );
      expect(result, isEmpty);
    });
  });

  group('re-base by offset + clip to current route (AC-8)', () {
    test('segmentEntirelyBeforeOffset_isDropped', () {
      // Offset 1000 → route window is absolute [1000, 1200]. A segment at
      // [800, 900] is a prior route — dropped.
      final result = IdleTraceMapper.resolve(
        segments: <ActivitySegment>[_seg(800, 900)],
        routeStartOffsetKm: 1000,
        projector: _projector(),
      );
      expect(result, isEmpty);
    });

    test('segmentEntirelyBeyondRouteEnd_isDropped', () {
      // Route window absolute [0, 200]. A segment at [250, 300] is past the end.
      final result = IdleTraceMapper.resolve(
        segments: <ActivitySegment>[_seg(250, 300)],
        routeStartOffsetKm: 0,
        projector: _projector(),
      );
      expect(result, isEmpty);
    });

    test('inWindowSegment_isReBasedByOffset', () {
      // Offset 1000: absolute [1025, 1075] → route km [25, 75].
      final withOffset = IdleTraceMapper.resolve(
        segments: <ActivitySegment>[_seg(1025, 1075)],
        routeStartOffsetKm: 1000,
        projector: _projector(),
      );
      final atZero = IdleTraceMapper.resolve(
        segments: <ActivitySegment>[_seg(25, 75)],
        routeStartOffsetKm: 0,
        projector: _projector(),
      );
      expect(withOffset, equals(atZero)); // TC-212: keys off route km
    });

    test('partiallyOutsideSegment_isTrimmedToRouteWindow', () {
      // Absolute [-50, 50] with offset 0 → route [0, 50] (front trimmed to 0).
      final result = IdleTraceMapper.resolve(
        segments: <ActivitySegment>[_seg(-50, 50)],
        routeStartOffsetKm: 0,
        projector: _projector(),
      );
      expect(result, hasLength(1));
      final points = result.single.polyline.points;
      // Trimmed start sits on the origin pin (route km 0).
      expect(points.first.latitude, closeTo(coordA.latitude, kTol));
      expect(points.first.longitude, closeTo(coordA.longitude, kTol));
    });

    test('tailBeyondRouteEnd_isClampedToDestination', () {
      // Route [0,200]; segment [150, 9999] → trimmed to [150, 200], ending at C.
      final result = IdleTraceMapper.resolve(
        segments: <ActivitySegment>[_seg(150, 9999)],
        routeStartOffsetKm: 0,
        projector: _projector(),
      );
      expect(result, hasLength(1));
      final points = result.single.polyline.points;
      expect(points.last.latitude, closeTo(coordC.latitude, kTol));
      expect(points.last.longitude, closeTo(coordC.longitude, kTol));
    });
  });

  group('cause preserved on the stretch (AC-9 / AC-12)', () {
    test('voluntaryCause_isCarriedThrough', () {
      final result = IdleTraceMapper.resolve(
        segments: <ActivitySegment>[
          _seg(25, 75, cause: SegmentCause.voluntary),
        ],
        routeStartOffsetKm: 0,
        projector: _projector(),
      );
      expect(result.single.cause, SegmentCause.voluntary);
    });

    test('lockSleepCause_isCarriedThrough', () {
      final result = IdleTraceMapper.resolve(
        segments: <ActivitySegment>[
          _seg(25, 75, cause: SegmentCause.lockSleep),
        ],
        routeStartOffsetKm: 0,
        projector: _projector(),
      );
      expect(result.single.cause, SegmentCause.lockSleep);
    });

    test('mixedCauses_eachStretchKeepsItsOwnCause', () {
      final result = IdleTraceMapper.resolve(
        segments: <ActivitySegment>[
          _seg(10, 30, cause: SegmentCause.voluntary),
          _seg(60, 90, cause: SegmentCause.lockSleep),
        ],
        routeStartOffsetKm: 0,
        projector: _projector(),
      );
      expect(result, hasLength(2));
      expect(result[0].cause, SegmentCause.voluntary);
      expect(result[1].cause, SegmentCause.lockSleep);
    });
  });

  group('zero-width idle segment — documented honest result', () {
    test('fromKmEqualsToKm_yieldsNoVisibleStretch (engine idle shape)', () {
      // The real engine records an idle ActivitySegment as fromKm == toKm (idle
      // accrues no distance). Documented behaviour: no road drawn behind it.
      final result = IdleTraceMapper.resolve(
        segments: <ActivitySegment>[_seg(80, 80)],
        routeStartOffsetKm: 0,
        projector: _projector(),
      );
      expect(result, isEmpty);
    });
  });

  group('multiple non-contiguous idle segments (TC-204)', () {
    test('threeIdleSegments_yieldThreeStretchesInOrder', () {
      final result = IdleTraceMapper.resolve(
        segments: <ActivitySegment>[
          _seg(20, 40),
          _seg(
            40,
            120,
            classification: SegmentClassification.active,
            cause: SegmentCause.none,
          ),
          _seg(120, 140),
          _seg(
            140,
            170,
            classification: SegmentClassification.active,
            cause: SegmentCause.none,
          ),
          _seg(170, 190),
        ],
        routeStartOffsetKm: 0,
        projector: _projector(),
      );
      expect(result, hasLength(3));
      // First stretch starts at route km 20 (inside A→B, fraction 0.2):
      // lat = 10 + 0.2*2 = 10.4; long = 105 + 0.2*1 = 105.2.
      expect(result.first.polyline.points.first.latitude, closeTo(10.4, kTol));
    });
  });

  group('result is unmodifiable (AC-12 read-only)', () {
    test('returnedList_cannotBeMutated', () {
      final result = IdleTraceMapper.resolve(
        segments: <ActivitySegment>[_seg(25, 75)],
        routeStartOffsetKm: 0,
        projector: _projector(),
      );
      expect(() => result.add(result.first), throwsUnsupportedError);
    });
  });
}
