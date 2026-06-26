// Smoke unit tests for the route-planner-v2 RoutePlan descriptor (ADR-0005
// decisions 4/5): JSON round-trip, corrupt-safe fromJson, lifecycle, and the
// derived RouteSelection (AC-7). The exhaustive coverage is the dedicated unit
// pass; here we assert the load-bearing shapes.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/domain/journey_direction.dart';
import 'package:focus_journey/features/route/domain/route_plan.dart';

import '../map_test_fixtures.dart';

const double _tol = 1e-6;

void main() {
  final chain = buildFixtureChain();
  final geography = buildFixtureGeography(chain);

  group('JSON round-trip + lifecycle', () {
    test('toJson → fromJson preserves ids, offset, lifecycle', () {
      const plan = RoutePlan(
        orderedNodeIds: <String>['can_tho', 'da_lat', 'da_nang'],
        routeStartOffsetKm: 1500.0,
        lifecycle: RouteLifecycle.active,
      );
      final restored = RoutePlan.fromJson(plan.toJson());
      expect(restored, plan); // Equatable.
      expect(restored.routeStartOffsetKm, closeTo(1500.0, _tol));
      expect(restored.lifecycle, RouteLifecycle.active);
    });

    test('completed/abandoned names round-trip', () {
      for (final lc in RouteLifecycle.values) {
        final plan = RoutePlan(
          orderedNodeIds: const <String>['can_tho', 'da_nang'],
          routeStartOffsetKm: 0,
          lifecycle: lc,
        );
        expect(RoutePlan.fromJson(plan.toJson()).lifecycle, lc);
      }
    });
  });

  group('corrupt-safe fromJson throws FormatException', () {
    test('missing ids', () {
      expect(
        () => RoutePlan.fromJson(<String, dynamic>{
          'routeStartOffsetKm': 0,
          'lifecycle': 'active',
        }),
        throwsFormatException,
      );
    });

    test('fewer than two ids', () {
      expect(
        () => RoutePlan.fromJson(<String, dynamic>{
          'orderedNodeIds': <String>['can_tho'],
          'routeStartOffsetKm': 0,
          'lifecycle': 'active',
        }),
        throwsFormatException,
      );
    });

    test('unknown lifecycle name', () {
      expect(
        () => RoutePlan.fromJson(<String, dynamic>{
          'orderedNodeIds': <String>['can_tho', 'da_nang'],
          'routeStartOffsetKm': 0,
          'lifecycle': 'sideways',
        }),
        throwsFormatException,
      );
    });
  });

  group('toResolved + toSelection (AC-7 unchanged resolver input)', () {
    test('north-bound plan derives towardHaGiang over the sub-chain', () {
      const plan = RoutePlan(
        orderedNodeIds: <String>['can_tho', 'da_lat', 'da_nang'],
        routeStartOffsetKm: 0,
      );
      final resolved = plan.toResolved(chain, geography);
      final selection = plan.toSelection(resolved);
      expect(selection.start.id, 'can_tho');
      expect(selection.direction, JourneyDirection.towardHaGiang);
      expect(resolved.subPathKm, closeTo(470, _tol));
    });

    test('south-bound plan derives towardMuiCaMau', () {
      const plan = RoutePlan(
        orderedNodeIds: <String>['da_nang', 'da_lat', 'can_tho'],
        routeStartOffsetKm: 0,
      );
      final resolved = plan.toResolved(chain, geography);
      final selection = plan.toSelection(resolved);
      expect(selection.start.id, 'da_nang');
      expect(selection.direction, JourneyDirection.towardMuiCaMau);
    });

    test('a completed plan derives a completed selection (terminal)', () {
      const plan = RoutePlan(
        orderedNodeIds: <String>['can_tho', 'da_nang'],
        routeStartOffsetKm: 0,
        lifecycle: RouteLifecycle.completed,
      );
      final resolved = plan.toResolved(chain, geography);
      expect(plan.toSelection(resolved).completed, isTrue);
    });
  });
}
