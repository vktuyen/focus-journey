// Smoke tests for the route-planner-v2 persistence + legacy migration (ADR-0005
// decision 4 / AC-12) on the real SharedPreferences impl (setMockInitialValues —
// no disk I/O). Covers: RoutePlan round-trip, legacy RouteSelection → RoutePlan
// migration, completed-legacy → completed plan, corrupt → null.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/data/shared_preferences_route_repository.dart';
import 'package:focus_journey/features/route/domain/journey_direction.dart';
import 'package:focus_journey/features/route/domain/province.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/domain/route_plan.dart';
import 'package:focus_journey/features/route/domain/route_selection.dart';
import 'package:shared_preferences/shared_preferences.dart';

const double _tol = 1e-6;

const Province mui = Province(id: 'mui', name: 'Mũi Cà Mau');
const Province canTho = Province(id: 'can_tho', name: 'Cần Thơ');
const Province daLat = Province(id: 'da_lat', name: 'Đà Lạt');
const Province haGiang = Province(id: 'ha_giang', name: 'Hà Giang');

ProvinceChain _chain() => ProvinceChain(
  nodes: const <Province>[mui, canTho, daLat, haGiang],
  segmentsKm: const <double>[60, 170, 1210],
);

ProvinceGeography _geo(ProvinceChain chain) => ProvinceGeography(
  chain: chain,
  coordinates: const <String, GeoCoordinate>{
    'mui': GeoCoordinate(latitude: 8.62, longitude: 104.72),
    'can_tho': GeoCoordinate(latitude: 10.04, longitude: 105.78),
    'da_lat': GeoCoordinate(latitude: 11.94, longitude: 108.44),
    'ha_giang': GeoCoordinate(latitude: 22.82, longitude: 104.98),
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final chain = _chain();
  final geography = _geo(chain);

  Future<SharedPreferencesRouteRepository> repoWith(
    Map<String, Object> initial,
  ) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    return SharedPreferencesRouteRepository(prefs, chain, geography);
  }

  group('RoutePlan round-trip (AC-12)', () {
    test('savePlan then loadPlan preserves the plan', () async {
      final repo = await repoWith(<String, Object>{});
      const plan = RoutePlan(
        orderedNodeIds: <String>['can_tho', 'da_lat'],
        routeStartOffsetKm: 230,
      );
      await repo.savePlan(plan);
      expect(await repo.loadPlan(), plan);
    });

    test('savePlan clears any stale legacy blob', () async {
      final repo = await repoWith(<String, Object>{
        SharedPreferencesRouteRepository.storageKey:
            '{"startId":"can_tho","direction":"towardHaGiang",'
            '"routeStartOffsetKm":0,"completed":false}',
      });
      await repo.savePlan(
        const RoutePlan(
          orderedNodeIds: <String>['da_lat', 'ha_giang'],
          routeStartOffsetKm: 0,
        ),
      );
      // The legacy selection is gone; loadPlan returns the new plan.
      expect(await repo.load(), isNull);
      expect((await repo.loadPlan())!.orderedNodeIds, <String>[
        'da_lat',
        'ha_giang',
      ]);
    });

    test('no saved route → loadPlan returns null', () async {
      final repo = await repoWith(<String, Object>{});
      expect(await repo.loadPlan(), isNull);
    });
  });

  group(
    'legacy RouteSelection → RoutePlan migration (ADR-0005 decision 4)',
    () {
      test(
        'an active legacy blob migrates to a full start→tip sub-path',
        () async {
          const legacy = RouteSelection(
            start: canTho,
            direction: JourneyDirection.towardHaGiang,
            routeStartOffsetKm: 500,
          );
          final repo = await repoWith(<String, Object>{
            SharedPreferencesRouteRepository.storageKey: jsonEncode(
              legacy.toJson(),
            ),
          });
          final plan = await repo.loadPlan();
          expect(plan, isNotNull);
          // Full sub-path from can_tho to the north tip ha_giang.
          expect(plan!.orderedNodeIds, <String>[
            'can_tho',
            'da_lat',
            'ha_giang',
          ]);
          expect(plan.routeStartOffsetKm, closeTo(500, _tol));
          expect(plan.lifecycle, RouteLifecycle.active);
        },
      );

      test('a completed legacy blob migrates to a completed plan', () async {
        const legacy = RouteSelection(
          start: daLat,
          direction: JourneyDirection.towardMuiCaMau,
          routeStartOffsetKm: 0,
          completed: true,
        );
        final repo = await repoWith(<String, Object>{
          SharedPreferencesRouteRepository.storageKey: jsonEncode(
            legacy.toJson(),
          ),
        });
        final plan = await repo.loadPlan();
        expect(plan!.lifecycle, RouteLifecycle.completed);
        // da_lat → south tip mui.
        expect(plan.orderedNodeIds, <String>['da_lat', 'can_tho', 'mui']);
      });

      test('a corrupt blob → null (no saved route)', () async {
        final repo = await repoWith(<String, Object>{
          SharedPreferencesRouteRepository.storageKey: '{not valid json',
        });
        expect(await repo.loadPlan(), isNull);
      });

      test(
        'a corrupt v2 plan blob → null (does not fall back to legacy)',
        () async {
          final repo = await repoWith(<String, Object>{
            SharedPreferencesRouteRepository.planStorageKey: '{bad plan',
            SharedPreferencesRouteRepository.storageKey:
                '{"startId":"can_tho","direction":"towardHaGiang",'
                '"routeStartOffsetKm":0,"completed":false}',
          });
          expect(await repo.loadPlan(), isNull);
        },
      );
    },
  );
}
