// Unit tests for RouteSelection — the off-direction tip guard (AC-15 / TC-015
// negative leg) and the JSON round-trip / safe-degrade (B-4 pattern, AC-9/AC-10).
//
// Pure-Dart: no Flutter, no I/O, no timers.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/domain/journey_direction.dart';
import 'package:focus_journey/features/route/domain/province.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/route_selection.dart';

const double kTol = 1e-6;

const Province muiCaMau = Province(id: 'mui_ca_mau', name: 'Mũi Cà Mau');
const Province canTho = Province(id: 'can_tho', name: 'Cần Thơ');
const Province daLat = Province(id: 'da_lat', name: 'Đà Lạt');
const Province haGiang = Province(id: 'ha_giang', name: 'Hà Giang');

ProvinceChain _chain() => ProvinceChain(
  nodes: const <Province>[muiCaMau, canTho, daLat, haGiang],
  segmentsKm: const <double>[60, 170, 1210],
);

void main() {
  group('RouteSelection.create — off-direction tip guard (AC-15 / TC-015)', () {
    final chain = _chain();

    test('northTip_headingNorth_throwsArgumentError', () {
      expect(
        () => RouteSelection.create(
          start: haGiang,
          direction: JourneyDirection.towardHaGiang,
          routeStartOffsetKm: 0,
          chain: chain,
        ),
        throwsArgumentError,
      );
    });

    test('southTip_headingSouth_throwsArgumentError', () {
      expect(
        () => RouteSelection.create(
          start: muiCaMau,
          direction: JourneyDirection.towardMuiCaMau,
          routeStartOffsetKm: 0,
          chain: chain,
        ),
        throwsArgumentError,
      );
    });

    test('northTip_headingSouth_succeeds', () {
      final sel = RouteSelection.create(
        start: haGiang,
        direction: JourneyDirection.towardMuiCaMau,
        routeStartOffsetKm: 0,
        chain: chain,
      );
      expect(sel.start, haGiang);
      expect(sel.direction, JourneyDirection.towardMuiCaMau);
    });

    test('southTip_headingNorth_succeeds', () {
      final sel = RouteSelection.create(
        start: muiCaMau,
        direction: JourneyDirection.towardHaGiang,
        routeStartOffsetKm: 0,
        chain: chain,
      );
      expect(sel.start, muiCaMau);
    });

    test('midChainStart_bothDirections_succeed', () {
      expect(
        RouteSelection.create(
          start: daLat,
          direction: JourneyDirection.towardHaGiang,
          routeStartOffsetKm: 0,
          chain: chain,
        ).direction,
        JourneyDirection.towardHaGiang,
      );
      expect(
        RouteSelection.create(
          start: daLat,
          direction: JourneyDirection.towardMuiCaMau,
          routeStartOffsetKm: 0,
          chain: chain,
        ).direction,
        JourneyDirection.towardMuiCaMau,
      );
    });

    test('startNotInChain_throwsArgumentError', () {
      const stranger = Province(id: 'stranger', name: 'Nowhere');
      expect(
        () => RouteSelection.create(
          start: stranger,
          direction: JourneyDirection.towardHaGiang,
          routeStartOffsetKm: 0,
          chain: chain,
        ),
        throwsArgumentError,
      );
    });

    test('negativeOffset_throwsArgumentError', () {
      expect(
        () => RouteSelection.create(
          start: canTho,
          direction: JourneyDirection.towardHaGiang,
          routeStartOffsetKm: -1,
          chain: chain,
        ),
        throwsArgumentError,
      );
    });
  });

  group('RouteSelection — copyWith', () {
    test('completed_flips_otherFieldsUnchanged', () {
      const sel = RouteSelection(
        start: canTho,
        direction: JourneyDirection.towardHaGiang,
        routeStartOffsetKm: 1100,
      );
      final completed = sel.copyWith(completed: true);
      expect(completed.completed, isTrue);
      expect(completed.start, canTho);
      expect(completed.direction, JourneyDirection.towardHaGiang);
      expect(completed.routeStartOffsetKm, closeTo(1100, kTol));
    });
  });

  group('RouteSelection — JSON round-trip (AC-9/AC-10)', () {
    final chain = _chain();

    test('roundTrip_preservesAllFields_inProgress', () {
      const sel = RouteSelection(
        start: canTho,
        direction: JourneyDirection.towardHaGiang,
        routeStartOffsetKm: 0,
      );
      final restored = RouteSelection.fromJson(sel.toJson(), chain);
      expect(restored, sel); // Equatable.
    });

    test('roundTrip_preservesCompletedAndCapturedOffset (AC-10)', () {
      const sel = RouteSelection(
        start: daLat,
        direction: JourneyDirection.towardMuiCaMau,
        routeStartOffsetKm: 1500.5,
        completed: true,
      );
      final restored = RouteSelection.fromJson(sel.toJson(), chain);
      expect(restored, sel);
      expect(restored.completed, isTrue);
      expect(restored.routeStartOffsetKm, closeTo(1500.5, kTol));
    });
  });

  group('RouteSelection.fromJson — safe-degrade (B-4)', () {
    final chain = _chain();

    test('missingStartId_throwsFormatException', () {
      expect(
        () => RouteSelection.fromJson(<String, dynamic>{
          'direction': 'towardHaGiang',
          'routeStartOffsetKm': 0,
          'completed': false,
        }, chain),
        throwsFormatException,
      );
    });

    test('startIdNotInChain_throwsFormatException', () {
      expect(
        () => RouteSelection.fromJson(<String, dynamic>{
          'startId': 'atlantis',
          'direction': 'towardHaGiang',
          'routeStartOffsetKm': 0,
          'completed': false,
        }, chain),
        throwsFormatException,
      );
    });

    test('unknownDirection_throwsFormatException', () {
      expect(
        () => RouteSelection.fromJson(<String, dynamic>{
          'startId': 'can_tho',
          'direction': 'sideways',
          'routeStartOffsetKm': 0,
          'completed': false,
        }, chain),
        throwsFormatException,
      );
    });

    test('wrongTypedOffset_throwsFormatException', () {
      expect(
        () => RouteSelection.fromJson(<String, dynamic>{
          'startId': 'can_tho',
          'direction': 'towardHaGiang',
          'routeStartOffsetKm': 'oops',
          'completed': false,
        }, chain),
        throwsFormatException,
      );
    });

    test('missingCompletedFlag_throwsFormatException', () {
      expect(
        () => RouteSelection.fromJson(<String, dynamic>{
          'startId': 'can_tho',
          'direction': 'towardHaGiang',
          'routeStartOffsetKm': 0,
        }, chain),
        throwsFormatException,
      );
    });
  });
}
