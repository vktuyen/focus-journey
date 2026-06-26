// Dedicated, exhaustive unit pass for the route-planner-v2 persistence seam
// (ADR-0005 decision 4; spec AC-12). Uses the REAL SharedPreferences impl with
// setMockInitialValues({}) (in-memory, no disk I/O) as the existing data tests
// do — the repository IS the persistence boundary, so the unit under test is
// that boundary.
//
// Pins down: savePlan→loadPlan round-trip across all lifecycle states; legacy
// RouteSelection → RoutePlan forward migration (active + completed); the v2 blob
// supersedes a stale legacy blob; corrupt v2 / corrupt legacy / ids-not-in-chain
// → null; off-direction-tip legacy → null.
//
// Fixture chain: mui/can_tho/da_lat/da_nang/ha_noi/ha_giang,
// segments [60,170,300,310,600], cumulative 0/60/230/530/840/1440.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/data/shared_preferences_route_repository.dart';
import 'package:focus_journey/features/route/domain/journey_direction.dart';
import 'package:focus_journey/features/route/domain/route_plan.dart';
import 'package:focus_journey/features/route/domain/route_selection.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../map_test_fixtures.dart';

const double _tol = 1e-6;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final chain = buildFixtureChain();
  final geography = buildFixtureGeography(chain);

  Future<SharedPreferencesRouteRepository> repoWith(
    Map<String, Object> initial,
  ) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    return SharedPreferencesRouteRepository(prefs, chain, geography);
  }

  String legacyBlob({
    required String startId,
    required JourneyDirection direction,
    double offset = 0,
    bool completed = false,
  }) => jsonEncode(<String, dynamic>{
    'startId': startId,
    'direction': direction.name,
    'routeStartOffsetKm': offset,
    'completed': completed,
  });

  group('RoutePlan round-trip (AC-12)', () {
    test('savePlanThenLoadPlan_preservesActivePlan', () async {
      final repo = await repoWith(<String, Object>{});
      const plan = RoutePlan(
        orderedNodeIds: <String>['can_tho', 'da_lat', 'da_nang'],
        routeStartOffsetKm: 740,
      );
      await repo.savePlan(plan);
      expect(await repo.loadPlan(), plan);
    });

    test('savePlanThenLoadPlan_preservesEveryLifecycleState', () async {
      for (final lc in RouteLifecycle.values) {
        final repo = await repoWith(<String, Object>{});
        final plan = RoutePlan(
          orderedNodeIds: const <String>['da_lat', 'da_nang'],
          routeStartOffsetKm: 230,
          lifecycle: lc,
        );
        await repo.savePlan(plan);
        final restored = await repo.loadPlan();
        expect(restored, plan);
        expect(restored!.lifecycle, lc);
      }
    });

    test('noSavedRoute_loadPlanReturnsNull', () async {
      final repo = await repoWith(<String, Object>{});
      expect(await repo.loadPlan(), isNull);
    });

    test('savePlan_clearsStaleLegacyBlobSoNoReMigration', () async {
      final repo = await repoWith(<String, Object>{
        SharedPreferencesRouteRepository.storageKey: legacyBlob(
          startId: 'can_tho',
          direction: JourneyDirection.towardHaGiang,
        ),
      });
      await repo.savePlan(
        const RoutePlan(
          orderedNodeIds: <String>['da_lat', 'ha_noi'],
          routeStartOffsetKm: 0,
        ),
      );
      // Legacy selection gone; loadPlan returns the freshly-saved v2 plan.
      expect(await repo.load(), isNull);
      final restored = await repo.loadPlan();
      expect(restored!.orderedNodeIds, <String>['da_lat', 'ha_noi']);
    });
  });

  group('legacy RouteSelection → RoutePlan migration (AC-12)', () {
    test(
      'activeNorthBoundLegacy_migratesToFullStartToNorthTipSubPath',
      () async {
        final repo = await repoWith(<String, Object>{
          SharedPreferencesRouteRepository.storageKey: legacyBlob(
            startId: 'can_tho',
            direction: JourneyDirection.towardHaGiang,
            offset: 500,
          ),
        });
        final plan = await repo.loadPlan();
        expect(plan, isNotNull);
        // Full sub-path from can_tho to the north tip ha_giang.
        expect(plan!.orderedNodeIds, <String>[
          'can_tho',
          'da_lat',
          'da_nang',
          'ha_noi',
          'ha_giang',
        ]);
        expect(plan.routeStartOffsetKm, closeTo(500, _tol));
        expect(plan.lifecycle, RouteLifecycle.active);
      },
    );

    test(
      'activeSouthBoundLegacy_migratesToFullStartToSouthTipSubPath',
      () async {
        final repo = await repoWith(<String, Object>{
          SharedPreferencesRouteRepository.storageKey: legacyBlob(
            startId: 'da_nang',
            direction: JourneyDirection.towardMuiCaMau,
          ),
        });
        final plan = await repo.loadPlan();
        // da_nang → south tip mui (travel order).
        expect(plan!.orderedNodeIds, <String>[
          'da_nang',
          'da_lat',
          'can_tho',
          'mui',
        ]);
        expect(plan.lifecycle, RouteLifecycle.active);
      },
    );

    test('completedLegacy_migratesToCompletedPlan', () async {
      final repo = await repoWith(<String, Object>{
        SharedPreferencesRouteRepository.storageKey: legacyBlob(
          startId: 'da_lat',
          direction: JourneyDirection.towardMuiCaMau,
          completed: true,
        ),
      });
      final plan = await repo.loadPlan();
      expect(plan!.lifecycle, RouteLifecycle.completed);
      expect(plan.orderedNodeIds, <String>['da_lat', 'can_tho', 'mui']);
    });

    test('migratedPlanRebuildsToOriginalLength_viaToResolved', () async {
      final repo = await repoWith(<String, Object>{
        SharedPreferencesRouteRepository.storageKey: legacyBlob(
          startId: 'da_lat',
          direction: JourneyDirection.towardHaGiang,
        ),
      });
      final plan = await repo.loadPlan();
      final resolved = plan!.toResolved(chain, geography);
      // da_lat → ha_giang = 300 + 310 + 600 = 1210.
      expect(resolved.subPathKm, closeTo(1210, _tol));
    });
  });

  group('corrupt / unreadable → null (FormatException contract)', () {
    test('corruptLegacyBlob_returnsNull', () async {
      final repo = await repoWith(<String, Object>{
        SharedPreferencesRouteRepository.storageKey: '{not valid json',
      });
      expect(await repo.loadPlan(), isNull);
    });

    test('corruptV2Blob_returnsNullWithoutFallingBackToLegacy', () async {
      final repo = await repoWith(<String, Object>{
        SharedPreferencesRouteRepository.planStorageKey: '{bad plan',
        SharedPreferencesRouteRepository.storageKey: legacyBlob(
          startId: 'can_tho',
          direction: JourneyDirection.towardHaGiang,
        ),
      });
      // A written v2 blob (even corrupt) supersedes any legacy one.
      expect(await repo.loadPlan(), isNull);
    });

    test('v2BlobWithIdsNotInChain_returnsNull', () async {
      final repo = await repoWith(<String, Object>{
        SharedPreferencesRouteRepository.planStorageKey: jsonEncode(
          const <String, dynamic>{
            'orderedNodeIds': <String>['atlantis', 'mordor'],
            'routeStartOffsetKm': 0,
            'lifecycle': 'active',
          },
        ),
      });
      expect(await repo.loadPlan(), isNull);
    });

    test('v2BlobWithNonMonotonicIds_returnsNull', () async {
      final repo = await repoWith(<String, Object>{
        SharedPreferencesRouteRepository.planStorageKey: jsonEncode(
          const <String, dynamic>{
            'orderedNodeIds': <String>['can_tho', 'da_nang', 'da_lat'],
            'routeStartOffsetKm': 0,
            'lifecycle': 'active',
          },
        ),
      });
      expect(await repo.loadPlan(), isNull);
    });

    test('v2BlobWithUnknownLifecycle_returnsNull', () async {
      final repo = await repoWith(<String, Object>{
        SharedPreferencesRouteRepository.planStorageKey: jsonEncode(
          const <String, dynamic>{
            'orderedNodeIds': <String>['can_tho', 'da_nang'],
            'routeStartOffsetKm': 0,
            'lifecycle': 'sideways',
          },
        ),
      });
      expect(await repo.loadPlan(), isNull);
    });

    test('legacyOffDirectionTipBlob_returnsNull', () async {
      // North tip ha_giang heading further north is off-chain (zero-length) —
      // migration treats it as "no saved route".
      final repo = await repoWith(<String, Object>{
        SharedPreferencesRouteRepository.storageKey: legacyBlob(
          startId: 'ha_giang',
          direction: JourneyDirection.towardHaGiang,
        ),
      });
      expect(await repo.loadPlan(), isNull);
    });
  });

  group('legacy RouteSelection save/load seam still works', () {
    test('saveSelectionThenLoad_roundTrips', () async {
      final repo = await repoWith(<String, Object>{});
      final sel = RouteSelection.create(
        start: nodeById(chain, 'can_tho'),
        direction: JourneyDirection.towardHaGiang,
        routeStartOffsetKm: 60,
        chain: chain,
      );
      await repo.save(sel);
      expect(await repo.load(), sel);
    });
  });
}
