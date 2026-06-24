// Deterministic unit tests for the pure, framework-free RouteProgressResolver —
// the PURE HEART of route-progress. No real timers, no DateTime.now(), no
// Flutter, no I/O: position is a pure function of (routeDistanceKm, selection,
// chain). See tests/cases/route-progress.md (TC-001..TC-014b, TC-NF1) and
// specs/route-progress/acceptance-criteria.md (AC-1..AC-13).
//
// Conventions mirror test/features/journey/domain/journey_engine_test.dart:
// group by behaviour, name tests as <subject>_<condition>_<expected> sentences,
// and cite the AC/TC in comments.
//
// Tests key off the fixture's STRUCTURE (ordered nodes + positive segment
// distances + declared total), with the AC's literal numbers asserted only as
// the worked illustration. The fixture is built explicitly here so the AC
// literals are checkable independently of the production 2000 km constant.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/domain/journey_direction.dart';
import 'package:focus_journey/features/route/domain/province.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/route_progress_resolver.dart';
import 'package:focus_journey/features/route/domain/route_selection.dart';

const double kTol = 1e-6;

// --- Worked-example fixture (the corrected 2026-06-24 diagram) ----------------
//
//   Mũi Cà Mau ─60→ Cần Thơ ─170→ Đà Lạt ─300→ Đà Nẵng ─310→ Hà Nội ─600→ Hà Giang
//        0          60         230        530        840        1440
//
// Segments [60,170,300,310,600] sum to 1440. From Cần Thơ's start position
// (cumulative 60): Đà Nẵng = 470 km, Hà Giang = 1380 km. From Đà Nẵng
// (cumulative 530): south to Đà Lạt = 300 km, to Cần Thơ = 470 km.
const Province muiCaMau = Province(id: 'mui_ca_mau', name: 'Mũi Cà Mau');
const Province canTho = Province(id: 'can_tho', name: 'Cần Thơ');
const Province daLat = Province(id: 'da_lat', name: 'Đà Lạt');
const Province daNang = Province(id: 'da_nang', name: 'Đà Nẵng');
const Province haNoi = Province(id: 'ha_noi', name: 'Hà Nội');
const Province haGiang = Province(id: 'ha_giang', name: 'Hà Giang');

ProvinceChain _fixtureChain() => ProvinceChain(
  nodes: const <Province>[muiCaMau, canTho, daLat, daNang, haNoi, haGiang],
  segmentsKm: const <double>[60, 170, 300, 310, 600],
);

/// A selection that bypasses the create() guard so the resolver math can be
/// exercised directly (offset is irrelevant: the resolver only sees the already
/// subtracted routeDistanceKm — TC conventions).
RouteSelection _selection(
  Province start,
  JourneyDirection direction, {
  double offset = 0,
  bool completed = false,
}) => RouteSelection(
  start: start,
  direction: direction,
  routeStartOffsetKm: offset,
  completed: completed,
);

void main() {
  final chain = _fixtureChain();
  // Total chain length is the source of truth — keyed structurally, not literal.
  final double total = chain.totalChainKm; // 1440 in the fixture.

  group('RouteProgressResolver — mid-chain happy path (AC-1 / TC-001)', () {
    final pos = RouteProgressResolver.resolve(
      routeDistanceKm: 400,
      selection: _selection(canTho, JourneyDirection.towardHaGiang),
      chain: chain,
    );

    test('passed_isOriginPlusEveryCheckpointWithinDistance', () {
      // Structural: origin + every checkpoint whose cumulative-from-start <= 400.
      // Đà Lạt is 170 from Cần Thơ (<=400, passed); Đà Nẵng is 470 (>400, not).
      expect(pos.passed, <Province>[canTho, daLat]);
    });

    test('next_isFirstUnpassedCheckpoint', () {
      expect(pos.next, daNang);
    });

    test('distanceToNext_isNextCumulativeMinusDistance', () {
      // Đà Nẵng is 470 km from Cần Thơ; 470 − 400 = 70 km (the AC literal).
      expect(pos.distanceToNextKm, closeTo(70, kTol));
    });

    test('currentSegment_isLastPassedToNext', () {
      expect(pos.currentSegmentFrom, daLat);
      expect(pos.currentSegmentTo, daNang);
    });

    test('percentOfCountry_isDistanceOverFullChain', () {
      // 400 / 1440 * 100 ≈ 27.78% (the AC literal).
      expect(pos.percentOfCountry, closeTo(400 / total * 100, kTol));
      expect(pos.percentOfCountry, closeTo(27.7778, 1e-3));
    });

    test('route_isInProgressNotCompleted', () {
      expect(pos.isCompleted, isFalse);
      expect(pos.destination, haGiang);
    });
  });

  group('RouteProgressResolver — distance 0 at start (AC-2 / TC-002)', () {
    final pos = RouteProgressResolver.resolve(
      routeDistanceKm: 0,
      selection: _selection(canTho, JourneyDirection.towardHaGiang),
      chain: chain,
    );

    test('passed_isOriginOnly', () {
      expect(pos.passed, <Province>[canTho]);
    });

    test('next_isImmediatelyFollowingCheckpoint', () {
      expect(pos.next, daLat);
    });

    test('distanceToNext_isFirstSegmentLength', () {
      expect(pos.distanceToNextKm, closeTo(170, kTol));
    });

    test('currentSegment_isOriginToNext', () {
      expect(pos.currentSegmentFrom, canTho);
      expect(pos.currentSegmentTo, daLat);
    });

    test('percent_isZero_andInProgress_andMarkerOnStartPin', () {
      expect(pos.percentOfCountry, closeTo(0, kTol));
      expect(pos.isCompleted, isFalse);
      // fractionAlongRoute == 0 ⇒ marker sits exactly on the start pin.
      expect(pos.fractionAlongRoute, closeTo(0, kTol));
      expect(pos.routeDistanceKm, closeTo(0, kTol));
    });
  });

  group('RouteProgressResolver — boundary triplet 169/170/171 (AC-3/4/5)', () {
    RouteSelection sel() => _selection(canTho, JourneyDirection.towardHaGiang);

    test(
      'at169_daLatNotYetPassed_nextIsDaLat_remainderIs1 (AC-4 / TC-004)',
      () {
        final pos = RouteProgressResolver.resolve(
          routeDistanceKm: 169,
          selection: sel(),
          chain: chain,
        );
        expect(pos.passed, <Province>[canTho]);
        expect(pos.next, daLat);
        expect(pos.distanceToNextKm, closeTo(1, kTol));
        expect(pos.currentSegmentFrom, canTho);
        expect(pos.currentSegmentTo, daLat);
        expect(pos.percentOfCountry, closeTo(169 / total * 100, kTol));
        expect(pos.percentOfCountry, closeTo(11.7361, 1e-3));
      },
    );

    test('at170_daLatPassed_nextAdvances_remainderIs300 (AC-3 / TC-003)', () {
      final pos = RouteProgressResolver.resolve(
        routeDistanceKm: 170,
        selection: sel(),
        chain: chain,
      );
      // Reached at exactly its distance counts as passed; next advances.
      expect(pos.passed, <Province>[canTho, daLat]);
      expect(pos.next, daNang);
      expect(pos.distanceToNextKm, closeTo(300, kTol));
      expect(pos.currentSegmentFrom, daLat);
      expect(pos.currentSegmentTo, daNang);
    });

    test('at171_daLatPassed_nextIsDaNang_remainderIs299 (AC-5 / TC-005)', () {
      final pos = RouteProgressResolver.resolve(
        routeDistanceKm: 171,
        selection: sel(),
        chain: chain,
      );
      expect(pos.passed, <Province>[canTho, daLat]);
      expect(pos.next, daNang);
      expect(pos.distanceToNextKm, closeTo(299, kTol));
      expect(pos.currentSegmentFrom, daLat);
      expect(pos.currentSegmentTo, daNang);
    });

    test('atCheckpoint_isDeterministic_noFlicker (AC-3 determinism)', () {
      final a = RouteProgressResolver.resolve(
        routeDistanceKm: 170,
        selection: sel(),
        chain: chain,
      );
      final b = RouteProgressResolver.resolve(
        routeDistanceKm: 170,
        selection: sel(),
        chain: chain,
      );
      expect(a, b); // Equatable field-by-field equality.
    });
  });

  group('RouteProgressResolver — monotonic advance (AC-6 / TC-006)', () {
    test('increasingDistance_passedCountAndPercentAndMarker_nonDecreasing', () {
      final sel = _selection(canTho, JourneyDirection.towardHaGiang);
      const sequence = <double>[0, 60, 169, 170, 171, 400, 1000, 1380, 1500];

      var prevPassed = -1;
      var prevPercent = -1.0;
      var prevFraction = -1.0;
      Province? prevNext;
      var sawDestinationAsNext = false;

      for (final d in sequence) {
        final pos = RouteProgressResolver.resolve(
          routeDistanceKm: d,
          selection: sel,
          chain: chain,
        );
        expect(
          pos.passed.length,
          greaterThanOrEqualTo(prevPassed),
          reason: 'passed count regressed at $d',
        );
        expect(
          pos.percentOfCountry,
          greaterThanOrEqualTo(prevPercent - kTol),
          reason: '% regressed at $d',
        );
        expect(
          pos.fractionAlongRoute,
          greaterThanOrEqualTo(prevFraction - kTol),
          reason: 'marker moved backward at $d',
        );
        // next never regresses to an already-passed checkpoint: once it has
        // advanced past a node, that node never reappears as `next`.
        if (prevNext != null && pos.next != null) {
          expect(
            pos.passed.contains(prevNext) || pos.next == prevNext,
            isTrue,
            reason: 'next regressed at $d',
          );
        }
        if (pos.next == null) {
          sawDestinationAsNext = true;
        }
        prevPassed = pos.passed.length;
        prevPercent = pos.percentOfCountry;
        prevFraction = pos.fractionAlongRoute;
        prevNext = pos.next;
      }
      expect(sawDestinationAsNext, isTrue, reason: 'route should complete');
    });
  });

  group(
    'RouteProgressResolver — direction handling (AC-7/AC-8 / TC-007/008)',
    () {
      test('south_walksOppositeOrder_fromDaNang (AC-7 / TC-007)', () {
        // From Đà Nẵng (cumulative 530) going south: Đà Lạt is 300 km away.
        final pos = RouteProgressResolver.resolve(
          routeDistanceKm: 300,
          selection: _selection(daNang, JourneyDirection.towardMuiCaMau),
          chain: chain,
        );
        expect(pos.passed, <Province>[daNang, daLat]);
        expect(pos.next, canTho);
        expect(pos.distanceToNextKm, closeTo(170, kTol));
        expect(pos.currentSegmentFrom, daLat);
        expect(pos.currentSegmentTo, canTho);
        expect(pos.destination, muiCaMau);
      });

      test('north_isMirrorOfSouth_sameStartSameDistance (AC-7 / TC-007)', () {
        // From Đà Nẵng (cumulative 530) going north: Hà Nội is 310 km away, so at
        // 300 km Hà Nội is NOT yet reached — next is Hà Nội (the mirror walk).
        final pos = RouteProgressResolver.resolve(
          routeDistanceKm: 300,
          selection: _selection(daNang, JourneyDirection.towardHaGiang),
          chain: chain,
        );
        // Compute expected structurally rather than from prose.
        expect(pos.passed, <Province>[daNang]);
        expect(pos.next, haNoi);
        expect(pos.destination, haGiang);
        // Only difference vs the south run is traversal direction.
      });

      test('direction_setsDestinationTip_fromDaLat (AC-8 / TC-008)', () {
        final north = RouteProgressResolver.resolve(
          routeDistanceKm: 0,
          selection: _selection(daLat, JourneyDirection.towardHaGiang),
          chain: chain,
        );
        final south = RouteProgressResolver.resolve(
          routeDistanceKm: 0,
          selection: _selection(daLat, JourneyDirection.towardMuiCaMau),
          chain: chain,
        );
        expect(north.destination, haGiang);
        expect(south.destination, muiCaMau);
      });

      test(
        'percent_usesFullChainDenominator_bothDirections (AC-8 / TC-008)',
        () {
          // Same routeDistanceKm in either direction ⇒ identical % (full-chain
          // denominator, NOT the chosen-direction remaining span).
          final north = RouteProgressResolver.resolve(
            routeDistanceKm: 200,
            selection: _selection(daLat, JourneyDirection.towardHaGiang),
            chain: chain,
          );
          final south = RouteProgressResolver.resolve(
            routeDistanceKm: 200,
            selection: _selection(daLat, JourneyDirection.towardMuiCaMau),
            chain: chain,
          );
          expect(north.percentOfCountry, closeTo(200 / total * 100, kTol));
          expect(south.percentOfCountry, closeTo(200 / total * 100, kTol));
          expect(north.percentOfCountry, closeTo(south.percentOfCountry, kTol));
        },
      );
    },
  );

  group('RouteProgressResolver — completion (AC-11/12/13 / TC-011/012/013)', () {
    // Cần Thơ → Hà Giang distance-to-destination = 1380 km (structural).
    final double toDest = chain.distanceToDestination(
      canTho,
      JourneyDirection.towardHaGiang,
    );

    test('toDest_isStructural_1380 (AC-11)', () {
      expect(toDest, closeTo(1380, kTol));
    });

    test(
      'exactlyAtDestination_completed_percentIsHonestArrivalValue (AC-11 / TC-011)',
      () {
        final pos = RouteProgressResolver.resolve(
          routeDistanceKm: toDest,
          selection: _selection(canTho, JourneyDirection.towardHaGiang),
          chain: chain,
        );
        expect(pos.isCompleted, isTrue);
        expect(pos.passed.last, haGiang);
        expect(pos.next, isNull);
        // 1380 / 1440 * 100 = 95.83% — a mid-chain route completes at its HONEST
        // arrival %, not a forced 100 (Kevin's ratified semantics: % stays
        // full-chain `routeDistanceKm ÷ totalChainKm`).
        expect(pos.percentOfCountry, closeTo(toDest / total * 100, kTol));
        expect(pos.percentOfCountry, closeTo(95.8333, 1e-3));
        expect(pos.fractionAlongRoute, closeTo(1, kTol));
      },
    );

    test(
      'beyondDestination_allOutputsFrozenAtArrival_percentDoesNotDrift (AC-13)',
      () {
        // Frozen-terminal: feeding distance PAST the destination (incl. past the
        // full chain) must reproduce the at-arrival outputs byte-for-byte. The %
        // must NOT drift from 95.83% upward toward 100 (the old bug clamped only
        // the marker, leaving % computed off the un-clamped distance).
        final atEnd = RouteProgressResolver.resolve(
          routeDistanceKm: toDest,
          selection: _selection(canTho, JourneyDirection.towardHaGiang),
          chain: chain,
        );
        for (final d in <double>[
          toDest,
          toDest + 50,
          total,
          total + 200,
          99999,
        ]) {
          final pos = RouteProgressResolver.resolve(
            routeDistanceKm: d,
            selection: _selection(canTho, JourneyDirection.towardHaGiang),
            chain: chain,
          );
          expect(pos.isCompleted, isTrue, reason: 'should be completed at $d');
          // Frozen at the HONEST arrival %, never the 100 cap (mid-chain route).
          expect(
            pos.percentOfCountry,
            closeTo(95.8333, 1e-3),
            reason: '% drifted at $d',
          );
          expect(pos.percentOfCountry, closeTo(atEnd.percentOfCountry, kTol));
          expect(pos.passed, atEnd.passed, reason: 'passed changed at $d');
          expect(pos.passed.last, haGiang);
          expect(pos.next, isNull, reason: 'next not null at $d');
          expect(pos.distanceToNextKm, closeTo(0, kTol));
          // Display distance clamped to the destination — marker never overshoots.
          expect(pos.routeDistanceKm, closeTo(toDest, kTol));
          expect(pos.fractionAlongRoute, closeTo(1, kTol));
          // Field-by-field identical to the at-arrival position (Equatable).
          expect(pos, atEnd, reason: 'position not frozen at $d');
        }
      },
    );

    test('tipToTipRoute_arrivesAtExactly100Percent (AC-11)', () {
      // A full tip-to-tip route (Mũi Cà Mau → Hà Giang) spans the whole chain,
      // so its honest arrival % is exactly 100 — distinct from the mid-chain
      // route's honest < 100.
      final tipToTip = chain.distanceToDestination(
        muiCaMau,
        JourneyDirection.towardHaGiang,
      );
      expect(tipToTip, closeTo(total, kTol));
      for (final d in <double>[tipToTip, tipToTip + 500]) {
        final pos = RouteProgressResolver.resolve(
          routeDistanceKm: d,
          selection: _selection(muiCaMau, JourneyDirection.towardHaGiang),
          chain: chain,
        );
        expect(pos.isCompleted, isTrue);
        expect(pos.percentOfCountry, closeTo(100, kTol));
        expect(pos.passed.last, haGiang);
        expect(pos.next, isNull);
        expect(pos.fractionAlongRoute, closeTo(1, kTol));
      }
    });

    test(
      'persistedCompletedFlag_belowDestination_rendersFullyArrived (AC-13 / issue 3)',
      () {
        // A RouteSelection restored with completed=true but a routeDistanceKm
        // BELOW its destination must still render as fully arrived: completion
        // clamps every output to arrival, never `isCompleted=true` with
        // `next != null`. (The old code clamped only the marker, so a persisted
        // below-destination selection rendered completed-but-still-en-route.)
        final pos = RouteProgressResolver.resolve(
          routeDistanceKm: 100,
          selection: _selection(
            canTho,
            JourneyDirection.towardHaGiang,
            completed: true,
          ),
          chain: chain,
        );
        expect(pos.isCompleted, isTrue);
        // Fully arrived: destination passed, nothing ahead, fraction 1, % frozen
        // at the honest arrival value (not the persisted 100 km / 1440).
        expect(pos.next, isNull);
        expect(pos.passed.last, haGiang);
        expect(pos.distanceToNextKm, closeTo(0, kTol));
        expect(pos.routeDistanceKm, closeTo(toDest, kTol));
        expect(pos.fractionAlongRoute, closeTo(1, kTol));
        expect(pos.percentOfCountry, closeTo(toDest / total * 100, kTol));
        expect(pos.percentOfCountry, closeTo(95.8333, 1e-3));
        // Identical to the natural at-arrival position (terminal == arrival).
        final atEnd = RouteProgressResolver.resolve(
          routeDistanceKm: toDest,
          selection: _selection(canTho, JourneyDirection.towardHaGiang),
          chain: chain,
        );
        expect(pos, atEnd);
      },
    );

    test(
      'afterCompletion_increasingDistance_noFurtherMovement (AC-13/TC-013)',
      () {
        final sel = _selection(canTho, JourneyDirection.towardHaGiang);
        final atEnd = RouteProgressResolver.resolve(
          routeDistanceKm: toDest,
          selection: sel,
          chain: chain,
        );
        final beyond1 = RouteProgressResolver.resolve(
          routeDistanceKm: toDest + 500,
          selection: sel,
          chain: chain,
        );
        final beyond2 = RouteProgressResolver.resolve(
          routeDistanceKm: toDest + 5000,
          selection: sel,
          chain: chain,
        );
        // Marker position (clamped distance + fraction) and passed list identical.
        expect(beyond1.routeDistanceKm, closeTo(atEnd.routeDistanceKm, kTol));
        expect(beyond2.routeDistanceKm, closeTo(atEnd.routeDistanceKm, kTol));
        expect(beyond1.passed, atEnd.passed);
        expect(beyond2.passed, atEnd.passed);
        expect(beyond1.destination, atEnd.destination);
        expect(beyond1.next, isNull);
        // % is also frozen at the arrival value — no forward progress at all.
        expect(beyond1.percentOfCountry, closeTo(atEnd.percentOfCountry, kTol));
        expect(beyond2.percentOfCountry, closeTo(atEnd.percentOfCountry, kTol));
        expect(
          beyond1.fractionAlongRoute,
          closeTo(atEnd.fractionAlongRoute, kTol),
        );
      },
    );
  });

  group('RouteProgressResolver — negative distance guard', () {
    test('negativeDistance_clampedToZero_noBackwardMovement', () {
      final pos = RouteProgressResolver.resolve(
        routeDistanceKm: -50,
        selection: _selection(canTho, JourneyDirection.towardHaGiang),
        chain: chain,
      );
      expect(pos.routeDistanceKm, closeTo(0, kTol));
      expect(pos.percentOfCountry, closeTo(0, kTol));
      expect(pos.passed, <Province>[canTho]);
      expect(pos.isCompleted, isFalse);
    });
  });

  group('RouteProgressResolver — non-finite distance guard (issue 3)', () {
    // A non-finite scalar must never produce the "in-progress with nothing
    // ahead" state the resolver doc forbids (isCompleted=false yet next=null,
    // fraction=1.0, garbage %). It is sanitised to 0 — a consistent, monotone,
    // terminal-safe position identical to a zero-distance start.
    final zero = RouteProgressResolver.resolve(
      routeDistanceKm: 0,
      selection: _selection(canTho, JourneyDirection.towardHaGiang),
      chain: chain,
    );

    for (final bad in <double>[
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      test('nonFinite($bad)_yieldsConsistentZeroDistancePosition', () {
        final pos = RouteProgressResolver.resolve(
          routeDistanceKm: bad,
          selection: _selection(canTho, JourneyDirection.towardHaGiang),
          chain: chain,
        );
        // Consistent + terminal-safe: in-progress IFF something is ahead.
        expect(pos.isCompleted, isFalse);
        expect(pos.next, isNotNull);
        expect(pos.routeDistanceKm.isFinite, isTrue);
        expect(pos.percentOfCountry.isFinite, isTrue);
        expect(pos.fractionAlongRoute.isFinite, isTrue);
        expect(pos.routeDistanceKm, closeTo(0, kTol));
        expect(pos.percentOfCountry, closeTo(0, kTol));
        expect(pos.fractionAlongRoute, closeTo(0, kTol));
        expect(pos.passed, <Province>[canTho]);
        // Byte-for-byte identical to the natural zero-distance position.
        expect(pos, zero);
      });
    }
  });

  group('RouteProgressResolver — offset transparency (AC-14 / TC-014b)', () {
    test('sameRouteDistance_identicalOutputs_regardlessOfOffset', () {
      // run A: offset 0, cumulative would be 400 ⇒ routeDistanceKm 400.
      final a = RouteProgressResolver.resolve(
        routeDistanceKm: 400,
        selection: _selection(
          canTho,
          JourneyDirection.towardHaGiang,
          offset: 0,
        ),
        chain: chain,
      );
      // run B: offset 1100, cumulative 1500 ⇒ routeDistanceKm 400 (same).
      final b = RouteProgressResolver.resolve(
        routeDistanceKm: 400,
        selection: _selection(
          canTho,
          JourneyDirection.towardHaGiang,
          offset: 1100,
        ),
        chain: chain,
      );
      // The resolver only ever sees routeDistanceKm, so outputs are identical.
      expect(a, b);
    });
  });

  group('RouteProgressResolver — determinism (NF / TC-NF1)', () {
    test('sameInputs_identicalRoutePosition_fieldByField', () {
      RouteSelection sel() => _selection(daLat, JourneyDirection.towardHaGiang);
      final first = RouteProgressResolver.resolve(
        routeDistanceKm: 250,
        selection: sel(),
        chain: chain,
      );
      final second = RouteProgressResolver.resolve(
        routeDistanceKm: 250,
        selection: sel(),
        chain: chain,
      );
      expect(first, second);
      expect(first.passed, second.passed);
      expect(first.next, second.next);
      expect(first.distanceToNextKm, second.distanceToNextKm);
      expect(first.currentSegmentFrom, second.currentSegmentFrom);
      expect(first.currentSegmentTo, second.currentSegmentTo);
      expect(first.percentOfCountry, second.percentOfCountry);
      expect(first.isCompleted, second.isCompleted);
      expect(first.fractionAlongRoute, second.fractionAlongRoute);
    });
  });
}
