// province-chain-2026 — sub-chain route authoring over the 34-unit spine (AC-8).
//
// Traceability (one test <-> one case; PC + AC ids in each description):
//   PC-916 (AC-8)  a user-authored start/end (+ stop) sub-chain over the NEW
//                  34-unit spine derives a valid ProvinceChain (ordered, unique
//                  ids, n-1 strictly-positive segments summing to its own total),
//                  via the UNCHANGED RoutePlanner.
//   PC-917 (AC-8)  the 3-state lifecycle (active/completed/abandoned) round-trips
//                  by name over the new production chain (BR-10); completed and
//                  abandoned are distinct terminal states.
//   PC-918 (AC-8)  invalid picks (start==end, unknown id, fewer than two ids)
//                  throw ArgumentError over the rebuilt chain — malformed
//                  sub-chains fail loudly at authoring, not at paint.
//
// Pure-data test over the PRODUCTION vietnamProvinceChain / vietnamProvinceGeography:
// no Flutter, no I/O, no timers, no network.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/domain/province.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/domain/route_plan.dart';
import 'package:focus_journey/features/route/domain/route_planner.dart';

const double _tol = 1e-6;

Province _node(String id) =>
    vietnamProvinceChain.nodes.firstWhere((n) => n.id == id);

void main() {
  final chain = vietnamProvinceChain;
  final geography = vietnamProvinceGeography;

  group('sub-chain authoring derives a valid ProvinceChain (AC-8 / PC-916)', () {
    test('PC-916 startEndSubChain_isOrderedUniquePositiveAndSumsToItsTotal', () {
      final resolved = RoutePlanner.resolve(
        fullChain: chain,
        fullGeography: geography,
        start: _node('can_tho'),
        end: _node('da_nang'),
      );
      final sub = resolved.subChain;
      // Ordered south->north, at least two nodes.
      expect(sub.nodes.length, greaterThanOrEqualTo(2));
      expect(sub.southTip.id, 'can_tho');
      expect(sub.northTip.id, 'da_nang');
      // Unique ids.
      final ids = sub.nodes.map((n) => n.id).toSet();
      expect(ids.length, sub.nodes.length);
      // n-1 strictly-positive segments.
      expect(sub.segmentsKm.length, sub.nodes.length - 1);
      for (final s in sub.segmentsKm) {
        expect(s, greaterThan(0));
      }
      // Segments sum to the sub-chain's own total.
      final sum = sub.segmentsKm.fold<double>(0, (a, b) => a + b);
      expect(sub.totalChainKm, closeTo(sum, _tol));
      expect(resolved.subPathKm, closeTo(sub.totalChainKm, _tol));
    });

    test('PC-916 markedStopOutsideSpan_extendsSpan_stillValid', () {
      // A stop north of the end extends the span to include it (AC-4 authoring),
      // and the derived sub-chain stays valid over the 34-unit spine.
      final resolved = RoutePlanner.resolve(
        fullChain: chain,
        fullGeography: geography,
        start: _node('can_tho'),
        end: _node('da_nang'),
        markedStops: <Province>[_node('ninh_binh')],
      );
      expect(resolved.subChain.northTip.id, 'ninh_binh');
      final sum = resolved.subChain.segmentsKm.fold<double>(0, (a, b) => a + b);
      expect(resolved.subChain.totalChainKm, closeTo(sum, _tol));
    });
  });

  group('sub-chain lifecycle round-trips per BR-10 (AC-8 / PC-917)', () {
    RoutePlan planFor(RouteLifecycle lifecycle) {
      final resolved = RoutePlanner.resolve(
        fullChain: chain,
        fullGeography: geography,
        start: _node('can_tho'),
        end: _node('da_nang'),
      );
      return RoutePlan.fromResolved(
        resolved,
        routeStartOffsetKm: 100,
        lifecycle: lifecycle,
      );
    }

    test('PC-917 everyLifecycleState_roundTripsByNameOverProductionChain', () {
      for (final lc in RouteLifecycle.values) {
        final plan = planFor(lc);
        final restored = RoutePlan.fromJson(plan.toJson());
        expect(restored, plan);
        expect(restored.lifecycle, lc);
        // Re-derives against the production spine deterministically.
        final resolved = restored.toResolved(chain, geography);
        expect(resolved.orderedNodeIds, plan.orderedNodeIds);
      }
    });

    test('PC-917 completedAndAbandoned_areDistinctTerminalStates', () {
      final active = planFor(RouteLifecycle.active);
      expect(active.isActive, isTrue);
      // Completion latches (fires celebration); abandon is a distinct terminal
      // state with no celebration (BR-10).
      final completed = active.copyWith(lifecycle: RouteLifecycle.completed);
      final abandoned = active.copyWith(lifecycle: RouteLifecycle.abandoned);
      expect(completed.isCompleted, isTrue);
      expect(completed.isAbandoned, isFalse);
      expect(abandoned.isAbandoned, isTrue);
      expect(abandoned.isCompleted, isFalse);
      expect(completed, isNot(equals(abandoned)));
      // copyWith retains ids + offset — only the lifecycle mutates.
      expect(completed.orderedNodeIds, active.orderedNodeIds);
      expect(completed.routeStartOffsetKm, active.routeStartOffsetKm);
    });
  });

  group('authoring rejects invalid picks over the new spine (AC-8 / PC-918)', () {
    test('PC-918 startEqualsEnd_throwsArgumentError', () {
      expect(
        () => RoutePlanner.resolve(
          fullChain: chain,
          fullGeography: geography,
          start: _node('da_nang'),
          end: _node('da_nang'),
        ),
        throwsArgumentError,
      );
    });

    test('PC-918 unknownEndpointId_throwsArgumentError', () {
      const stranger = Province(id: 'atlantis', name: 'Atlantis');
      expect(
        () => RoutePlanner.resolve(
          fullChain: chain,
          fullGeography: geography,
          start: _node('can_tho'),
          end: stranger,
        ),
        throwsArgumentError,
      );
    });

    test('PC-918 fewerThanTwoIds_throwsArgumentError', () {
      expect(
        () => RoutePlanner.fromOrderedIds(
          fullChain: chain,
          fullGeography: geography,
          orderedNodeIds: const <String>['can_tho'],
        ),
        throwsArgumentError,
      );
    });

    test('PC-918 unknownIdInOrderedList_throwsArgumentError', () {
      expect(
        () => RoutePlanner.fromOrderedIds(
          fullChain: chain,
          fullGeography: geography,
          orderedNodeIds: const <String>['can_tho', 'atlantis'],
        ),
        throwsArgumentError,
      );
    });
  });
}
