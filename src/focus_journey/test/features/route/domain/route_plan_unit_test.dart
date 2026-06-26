// Dedicated, exhaustive unit pass for the route-planner-v2 RoutePlan descriptor
// (ADR-0005 decisions 4/5; spec AC-7/AC-8/AC-12). PURE DOMAIN — no Flutter
// binding, no timers, no I/O.
//
// Pins down: toJson/fromJson round-trip (ids + offset + lifecycle by name),
// corrupt/missing/wrong-typed → FormatException (mirrors RouteSelection.fromJson),
// the 3-state lifecycle, toResolved == RoutePlanner.fromOrderedIds, and that
// toSelection derives a start+direction the UNCHANGED RouteProgressResolver
// agrees with (AC-7).
//
// Fixture chain: mui/can_tho/da_lat/da_nang/ha_noi/ha_giang,
// segments [60,170,300,310,600], cumulative 0/60/230/530/840/1440.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/domain/journey_direction.dart';
import 'package:focus_journey/features/route/domain/route_plan.dart';
import 'package:focus_journey/features/route/domain/route_planner.dart';
import 'package:focus_journey/features/route/domain/route_progress_resolver.dart';

import '../map_test_fixtures.dart';

const double _tol = 1e-6;

void main() {
  final chain = buildFixtureChain();
  final geography = buildFixtureGeography(chain);

  group('RoutePlan — toJson/fromJson round-trip (AC-12)', () {
    test('roundTrip_preservesIdsOffsetAndLifecycle', () {
      const plan = RoutePlan(
        orderedNodeIds: <String>['can_tho', 'da_lat', 'da_nang'],
        routeStartOffsetKm: 1500.5,
        lifecycle: RouteLifecycle.active,
      );
      final restored = RoutePlan.fromJson(plan.toJson());
      expect(restored, plan); // Equatable structural equality.
      expect(restored.orderedNodeIds, <String>['can_tho', 'da_lat', 'da_nang']);
      expect(restored.routeStartOffsetKm, closeTo(1500.5, _tol));
      expect(restored.lifecycle, RouteLifecycle.active);
    });

    test('toJson_serialisesLifecycleByName', () {
      const plan = RoutePlan(
        orderedNodeIds: <String>['can_tho', 'da_nang'],
        routeStartOffsetKm: 0,
        lifecycle: RouteLifecycle.abandoned,
      );
      expect(plan.toJson()['lifecycle'], 'abandoned');
    });

    test('everyLifecycleState_roundTripsByName', () {
      for (final lc in RouteLifecycle.values) {
        final plan = RoutePlan(
          orderedNodeIds: const <String>['can_tho', 'da_nang'],
          routeStartOffsetKm: 12.5,
          lifecycle: lc,
        );
        final restored = RoutePlan.fromJson(plan.toJson());
        expect(restored.lifecycle, lc);
        expect(restored, plan);
      }
    });

    test('integerOffsetInJson_decodesAsDouble', () {
      // A JSON int (no decimal) must decode cleanly via num.toDouble().
      final restored = RoutePlan.fromJson(<String, dynamic>{
        'orderedNodeIds': <String>['can_tho', 'da_nang'],
        'routeStartOffsetKm': 230,
        'lifecycle': 'active',
      });
      expect(restored.routeStartOffsetKm, closeTo(230.0, _tol));
    });

    test('fromResolved_capturesTravelOrderIdsAndOffset', () {
      final resolved = RoutePlanner.resolve(
        fullChain: chain,
        fullGeography: geography,
        start: nodeById(chain, 'da_nang'),
        end: nodeById(chain, 'can_tho'),
      );
      final plan = RoutePlan.fromResolved(resolved, routeStartOffsetKm: 740);
      expect(plan.orderedNodeIds, resolved.orderedNodeIds);
      expect(plan.routeStartOffsetKm, closeTo(740, _tol));
      expect(plan.lifecycle, RouteLifecycle.active);
    });
  });

  group('RoutePlan.fromJson — corrupt input → FormatException', () {
    test('missingOrderedNodeIds_throwsFormatException', () {
      expect(
        () => RoutePlan.fromJson(<String, dynamic>{
          'routeStartOffsetKm': 0,
          'lifecycle': 'active',
        }),
        throwsFormatException,
      );
    });

    test('orderedNodeIdsNotAList_throwsFormatException', () {
      expect(
        () => RoutePlan.fromJson(<String, dynamic>{
          'orderedNodeIds': 'can_tho,da_nang',
          'routeStartOffsetKm': 0,
          'lifecycle': 'active',
        }),
        throwsFormatException,
      );
    });

    test('orderedNodeIdsWithNonStringElement_throwsFormatException', () {
      expect(
        () => RoutePlan.fromJson(<String, dynamic>{
          'orderedNodeIds': <dynamic>['can_tho', 42],
          'routeStartOffsetKm': 0,
          'lifecycle': 'active',
        }),
        throwsFormatException,
      );
    });

    test('fewerThanTwoIds_throwsFormatException', () {
      expect(
        () => RoutePlan.fromJson(<String, dynamic>{
          'orderedNodeIds': <String>['can_tho'],
          'routeStartOffsetKm': 0,
          'lifecycle': 'active',
        }),
        throwsFormatException,
      );
    });

    test('missingOffset_throwsFormatException', () {
      expect(
        () => RoutePlan.fromJson(<String, dynamic>{
          'orderedNodeIds': <String>['can_tho', 'da_nang'],
          'lifecycle': 'active',
        }),
        throwsFormatException,
      );
    });

    test('offsetWrongType_throwsFormatException', () {
      expect(
        () => RoutePlan.fromJson(<String, dynamic>{
          'orderedNodeIds': <String>['can_tho', 'da_nang'],
          'routeStartOffsetKm': 'far',
          'lifecycle': 'active',
        }),
        throwsFormatException,
      );
    });

    test('unknownLifecycleName_throwsFormatException', () {
      expect(
        () => RoutePlan.fromJson(<String, dynamic>{
          'orderedNodeIds': <String>['can_tho', 'da_nang'],
          'routeStartOffsetKm': 0,
          'lifecycle': 'sideways',
        }),
        throwsFormatException,
      );
    });

    test('missingLifecycle_throwsFormatException', () {
      expect(
        () => RoutePlan.fromJson(<String, dynamic>{
          'orderedNodeIds': <String>['can_tho', 'da_nang'],
          'routeStartOffsetKm': 0,
        }),
        throwsFormatException,
      );
    });
  });

  group('RoutePlan — lifecycle flags + copyWith', () {
    test('lifecycleFlags_matchTheEnumState', () {
      const active = RoutePlan(
        orderedNodeIds: <String>['can_tho', 'da_nang'],
        routeStartOffsetKm: 0,
      );
      expect(active.isActive, isTrue);
      expect(active.isCompleted, isFalse);
      expect(active.isAbandoned, isFalse);

      final completed = active.copyWith(lifecycle: RouteLifecycle.completed);
      expect(completed.isCompleted, isTrue);
      expect(completed.isActive, isFalse);

      final abandoned = active.copyWith(lifecycle: RouteLifecycle.abandoned);
      expect(abandoned.isAbandoned, isTrue);
      expect(abandoned.isCompleted, isFalse);
    });

    test('copyWith_keepsIdsAndOffset_onlyMutatesLifecycle', () {
      const plan = RoutePlan(
        orderedNodeIds: <String>['can_tho', 'da_lat', 'da_nang'],
        routeStartOffsetKm: 740,
      );
      final next = plan.copyWith(lifecycle: RouteLifecycle.completed);
      expect(next.orderedNodeIds, plan.orderedNodeIds);
      expect(next.routeStartOffsetKm, closeTo(740, _tol));
      expect(next.lifecycle, RouteLifecycle.completed);
    });

    test('defaultLifecycle_isActive', () {
      const plan = RoutePlan(
        orderedNodeIds: <String>['can_tho', 'da_nang'],
        routeStartOffsetKm: 0,
      );
      expect(plan.lifecycle, RouteLifecycle.active);
    });
  });

  group('RoutePlan.toResolved — matches RoutePlanner (AC-12)', () {
    test('toResolved_equalsFromOrderedIdsOutput', () {
      const plan = RoutePlan(
        orderedNodeIds: <String>['can_tho', 'da_lat', 'da_nang'],
        routeStartOffsetKm: 0,
      );
      final viaPlan = plan.toResolved(chain, geography);
      final viaPlanner = RoutePlanner.fromOrderedIds(
        fullChain: chain,
        fullGeography: geography,
        orderedNodeIds: plan.orderedNodeIds,
      );
      expect(viaPlan.orderedNodeIds, viaPlanner.orderedNodeIds);
      expect(viaPlan.subPathKm, closeTo(viaPlanner.subPathKm, _tol));
      expect(
        viaPlan.canonicalOriginKm,
        closeTo(viaPlanner.canonicalOriginKm, _tol),
      );
      expect(viaPlan.subChain.segmentsKm, viaPlanner.subChain.segmentsKm);
    });

    test('toResolved_isDeterministicAcrossCalls', () {
      const plan = RoutePlan(
        orderedNodeIds: <String>['da_nang', 'da_lat', 'can_tho'],
        routeStartOffsetKm: 0,
      );
      final a = plan.toResolved(chain, geography);
      final b = plan.toResolved(chain, geography);
      expect(a.orderedNodeIds, b.orderedNodeIds);
      expect(a.subChain.segmentsKm, b.subChain.segmentsKm);
    });
  });

  group('RoutePlan.toSelection — unchanged resolver agrees (AC-7)', () {
    test('northBoundPlan_derivesTowardHaGiangFromSouthTipStart', () {
      const plan = RoutePlan(
        orderedNodeIds: <String>['can_tho', 'da_lat', 'da_nang'],
        routeStartOffsetKm: 0,
      );
      final resolved = plan.toResolved(chain, geography);
      final selection = plan.toSelection(resolved);
      expect(selection.start.id, 'can_tho');
      expect(selection.direction, JourneyDirection.towardHaGiang);
    });

    test('southBoundPlan_derivesTowardMuiCaMauFromNorthTipStart', () {
      const plan = RoutePlan(
        orderedNodeIds: <String>['da_nang', 'da_lat', 'can_tho'],
        routeStartOffsetKm: 0,
      );
      final resolved = plan.toResolved(chain, geography);
      final selection = plan.toSelection(resolved);
      expect(selection.start.id, 'da_nang');
      expect(selection.direction, JourneyDirection.towardMuiCaMau);
    });

    test('resolverOverDerivedSelection_walksTheAuthoredSubPathToCompletion', () {
      // The whole AC-7 reuse invariant: feed the derived selection + sub-chain to
      // the UNCHANGED RouteProgressResolver and confirm it agrees with the
      // authored route's length and end.
      const plan = RoutePlan(
        orderedNodeIds: <String>['can_tho', 'da_lat', 'da_nang'],
        routeStartOffsetKm: 0,
      );
      final resolved = plan.toResolved(chain, geography);
      final selection = plan.toSelection(resolved);

      // At routeDistanceKm == 0: at the start, nothing passed beyond origin.
      final atStart = RouteProgressResolver.resolve(
        routeDistanceKm: 0,
        selection: selection,
        chain: resolved.subChain,
      );
      expect(atStart.passed.map((n) => n.id).toList(), <String>['can_tho']);
      expect(atStart.isCompleted, isFalse);
      expect(atStart.destination.id, 'da_nang');
      expect(atStart.distanceToDestinationKm, closeTo(470, _tol));

      // At routeDistanceKm == subPathKm: completed at the authored end.
      final atEnd = RouteProgressResolver.resolve(
        routeDistanceKm: resolved.subPathKm,
        selection: selection,
        chain: resolved.subChain,
      );
      expect(atEnd.isCompleted, isTrue);
      expect(atEnd.destination.id, 'da_nang');
      expect(atEnd.fractionAlongRoute, closeTo(1.0, _tol));
    });

    test('resolverOverSouthBoundDerivedSelection_endsAtTheChosenSouthEnd', () {
      const plan = RoutePlan(
        orderedNodeIds: <String>['da_nang', 'da_lat', 'can_tho'],
        routeStartOffsetKm: 0,
      );
      final resolved = plan.toResolved(chain, geography);
      final selection = plan.toSelection(resolved);
      final atEnd = RouteProgressResolver.resolve(
        routeDistanceKm: resolved.subPathKm,
        selection: selection,
        chain: resolved.subChain,
      );
      expect(atEnd.destination.id, 'can_tho');
      expect(atEnd.isCompleted, isTrue);
    });

    test('completedPlan_derivesCompletedSelection', () {
      const plan = RoutePlan(
        orderedNodeIds: <String>['can_tho', 'da_nang'],
        routeStartOffsetKm: 0,
        lifecycle: RouteLifecycle.completed,
      );
      final resolved = plan.toResolved(chain, geography);
      expect(plan.toSelection(resolved).completed, isTrue);
    });

    test('activeAndAbandonedPlans_deriveNonCompletedSelection', () {
      for (final lc in <RouteLifecycle>[
        RouteLifecycle.active,
        RouteLifecycle.abandoned,
      ]) {
        final plan = RoutePlan(
          orderedNodeIds: const <String>['can_tho', 'da_nang'],
          routeStartOffsetKm: 0,
          lifecycle: lc,
        );
        final resolved = plan.toResolved(chain, geography);
        expect(plan.toSelection(resolved).completed, isFalse);
      }
    });
  });
}
