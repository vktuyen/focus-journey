// Dedicated, exhaustive unit pass for the route-planner-v2 persistence seam
// (ADR-0005 decision 4; spec AC-12). Uses the REAL SharedPreferences impl with
// setMockInitialValues({}) (in-memory, no disk I/O) as the existing data tests
// do — the repository IS the persistence boundary, so the unit under test is
// that boundary.
//
// Pins down: savePlan→loadPlan round-trip across all lifecycle states; legacy
// RouteSelection → RoutePlan forward migration (active + completed); the v2 blob
// supersedes a stale legacy blob; corrupt v2 / corrupt legacy → null;
// off-direction-tip legacy → null; and (province-chain-2026 AC-9) a
// structurally-valid plan whose ids are RETIRED (not in the current chain)
// migrates BY RESET to a fresh full-spine active plan (not null, not id-remap).
//
// Fixture chain: mui/can_tho/da_lat/da_nang/ha_noi/ha_giang,
// segments [60,170,300,310,600], cumulative 0/60/230/530/840/1440.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/data/shared_preferences_route_repository.dart';
import 'package:focus_journey/features/route/domain/coastal_corridor.dart';
import 'package:focus_journey/features/route/domain/journey_direction.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
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

    test('v2BlobWithRetiredIds_migratesByResetToDefaultCorridor', () async {
      // province-chain-2026 AC-9 + route-real-road AC-1: a structurally-valid plan
      // whose ids no longer resolve against the current chain is forward-migrated
      // BY RESET — a fresh DEFAULT COASTAL CORRIDOR active plan stamped at the
      // current cumulative — not dropped to null and not id-remapped. (The fixture
      // chain's 'ha_noi' node collides with the excluded set, so the fixture
      // corridor is the chain minus 'ha_noi' — exactly coastalCorridorNodeIds.)
      final repo = await repoWith(<String, Object>{
        SharedPreferencesRouteRepository.planStorageKey: jsonEncode(
          const <String, dynamic>{
            'orderedNodeIds': <String>['atlantis', 'mordor'],
            'routeStartOffsetKm': 999,
            'lifecycle': 'active',
          },
        ),
      });
      final migrated = await repo.loadPlan(currentCumulativeKm: 123.0);
      expect(migrated, isNotNull);
      expect(
        migrated!.orderedNodeIds,
        coastalCorridorNodeIds(chain),
        reason: 'reset plan is the default coastal corridor, south→north',
      );
      expect(migrated.lifecycle, RouteLifecycle.active);
      expect(
        migrated.routeStartOffsetKm,
        closeTo(123.0, _tol),
        reason: 'stamped at the current engine cumulative (BR-8)',
      );
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

  // ---------------------------------------------------------------------------
  // province-chain-2026 — migration BY RESET over the PRODUCTION 34-unit chain
  // (AC-9). These exercise the real retired pre-2025 ids (mui_ca_mau, sa_pa,
  // ha_giang) against the shipped vietnamProvinceChain / vietnamProvinceGeography,
  // covering both the v2 RoutePlan and legacy RouteSelection decode paths.
  //   PC-919  retired-id RoutePlan AND legacy RouteSelection -> fresh full-spine
  //           active plan stamped at the current cumulative.
  //   PC-920  routeStartOffsetKm == currentCumulativeKm (BR-8: the cumulative is
  //           an external never-reset store the repo never touches).
  //   PC-921  retired-but-recognisable -> reset; corrupt/undecodable -> null.
  //   PC-922  the migrated plan's ids are the default COASTAL CORRIDOR (the
  //           inland-trimmed south→north sweep — route-real-road AC-1), never a
  //           nearest-unit remap onto a wrong current unit. (Was the full 34-spine
  //           before route-real-road replaced the all-34 tour with the corridor.)
  // ---------------------------------------------------------------------------
  group('production 34-unit chain — migrate by reset (AC-9)', () {
    final prodChain = vietnamProvinceChain;
    final prodGeography = vietnamProvinceGeography;
    // route-real-road: the migration-reset target is now the coastal corridor
    // (deep-inland units removed), NOT the full 34-node spine.
    final corridorIds = coastalCorridorNodeIds(prodChain);

    Future<SharedPreferencesRouteRepository> prodRepoWith(
      Map<String, Object> initial,
    ) async {
      SharedPreferences.setMockInitialValues(initial);
      final prefs = await SharedPreferences.getInstance();
      return SharedPreferencesRouteRepository(prefs, prodChain, prodGeography);
    }

    test(
      'PC-919/920/922 retiredIdV2Plan_resetsToCorridorActiveAtCumulative',
      () async {
        final repo = await prodRepoWith(<String, Object>{
          SharedPreferencesRouteRepository.planStorageKey: jsonEncode(
            const <String, dynamic>{
              // Retired pre-2025 / 13-node ids, no longer in the 34-unit chain.
              'orderedNodeIds': <String>['mui_ca_mau', 'da_nang', 'ha_giang'],
              'routeStartOffsetKm': 42,
              'lifecycle': 'active',
            },
          ),
        });
        final migrated = await repo.loadPlan(currentCumulativeKm: 314.0);
        expect(migrated, isNotNull);
        // PC-922: the default COASTAL CORRIDOR, south->north — not a remapped
        // subset, and not the all-34 tour (the inland units are trimmed).
        expect(migrated!.orderedNodeIds, corridorIds);
        expect(migrated.orderedNodeIds.length, lessThan(34));
        expect(migrated.orderedNodeIds.first, prodChain.southTip.id);
        expect(migrated.orderedNodeIds.last, prodChain.northTip.id);
        expect(migrated.lifecycle, RouteLifecycle.active);
        // PC-920: stamped at the current engine cumulative (BR-8), NOT the legacy
        // offset (42) that came off the retired blob.
        expect(migrated.routeStartOffsetKm, closeTo(314.0, _tol));
      },
    );

    test(
      'PC-919 retiredStartIdLegacySelection_resetsToCorridorActive',
      () async {
        // The legacy RouteSelection decode path (no v2 blob present): a retired
        // start id migrates BY RESET, not dropped to null.
        final repo = await prodRepoWith(<String, Object>{
          SharedPreferencesRouteRepository.storageKey: legacyBlob(
            startId: 'sa_pa', // retired pre-2025 id
            direction: JourneyDirection.towardHaGiang,
            offset: 77,
          ),
        });
        final migrated = await repo.loadPlan(currentCumulativeKm: 500.0);
        expect(migrated, isNotNull);
        expect(migrated!.orderedNodeIds, corridorIds);
        expect(migrated.lifecycle, RouteLifecycle.active);
        expect(migrated.routeStartOffsetKm, closeTo(500.0, _tol));
      },
    );

    test('PC-920 resetStamp_clampsNegativeCumulativeToZero', () async {
      final repo = await prodRepoWith(<String, Object>{
        SharedPreferencesRouteRepository.planStorageKey: jsonEncode(
          const <String, dynamic>{
            'orderedNodeIds': <String>['ha_giang', 'sa_pa'],
            'routeStartOffsetKm': 10,
            'lifecycle': 'active',
          },
        ),
      });
      final migrated = await repo.loadPlan(currentCumulativeKm: -5.0);
      expect(migrated!.routeStartOffsetKm, closeTo(0.0, _tol));
    });

    test(
      'PC-921 recognisableRetired_resets_butCorruptUndecodable_returnsNull',
      () async {
        // Recognisable retired v2 plan -> reset.
        final resetRepo = await prodRepoWith(<String, Object>{
          SharedPreferencesRouteRepository.planStorageKey: jsonEncode(
            const <String, dynamic>{
              'orderedNodeIds': <String>['ha_giang', 'mui_ca_mau'],
              'routeStartOffsetKm': 0,
              'lifecycle': 'active',
            },
          ),
        });
        expect(await resetRepo.loadPlan(currentCumulativeKm: 1.0), isNotNull);

        // Genuinely corrupt blob -> "no saved route" (null), never a reset/crash.
        final corruptRepo = await prodRepoWith(<String, Object>{
          SharedPreferencesRouteRepository.planStorageKey: '{ not json at all',
        });
        expect(await corruptRepo.loadPlan(currentCumulativeKm: 1.0), isNull);

        // Corrupt legacy blob (no v2) -> null.
        final corruptLegacyRepo = await prodRepoWith(<String, Object>{
          SharedPreferencesRouteRepository.storageKey: '<<<garbage>>>',
        });
        expect(
          await corruptLegacyRepo.loadPlan(currentCumulativeKm: 1.0),
          isNull,
        );
      },
    );

    test('PC-922 migratedPlanIsCoastalCorridor_notANearestUnitRemap', () async {
      final repo = await prodRepoWith(<String, Object>{
        SharedPreferencesRouteRepository.planStorageKey: jsonEncode(
          const <String, dynamic>{
            'orderedNodeIds': <String>['mui_ca_mau', 'sa_pa'],
            'routeStartOffsetKm': 0,
            'lifecycle': 'active',
          },
        ),
      });
      final migrated = await repo.loadPlan(currentCumulativeKm: 0);
      // The result is the default coastal corridor from the south tip to the
      // north tip — never a 2-node subset derived by remapping the two retired
      // ids, and never the all-34 inland tour.
      expect(migrated!.orderedNodeIds.first, prodChain.southTip.id);
      expect(migrated.orderedNodeIds.last, prodChain.northTip.id);
      expect(migrated.orderedNodeIds, corridorIds);
      expect(migrated.orderedNodeIds.length, greaterThan(2));
      expect(migrated.orderedNodeIds.length, lessThan(34));
    });

    test('S3 migrateByReset_persistsResetSoStartupIsDeterministic', () async {
      // S3 (province-chain-2026 self-review): the migrate-by-reset path must
      // PERSIST the fresh coastal-corridor plan (and clear the stale legacy blob) so
      // the reset runs exactly ONCE — a subsequent launch reads the migrated
      // in-chain plan directly rather than re-running the reset every launch
      // until the user next saves.
      final repo = await prodRepoWith(<String, Object>{
        SharedPreferencesRouteRepository.planStorageKey: jsonEncode(
          const <String, dynamic>{
            'orderedNodeIds': <String>['mui_ca_mau', 'sa_pa'],
            'routeStartOffsetKm': 99,
            'lifecycle': 'active',
          },
        ),
        // A stale legacy blob that the persist-on-migrate must also clear.
        SharedPreferencesRouteRepository.storageKey: '{stale legacy}',
      });
      final first = await repo.loadPlan(currentCumulativeKm: 200.0);
      expect(first!.orderedNodeIds, corridorIds);

      // The reset plan is now persisted under the plan key; the stale legacy
      // blob is gone.
      final prefs = await SharedPreferences.getInstance();
      final persisted = prefs.getString(
        SharedPreferencesRouteRepository.planStorageKey,
      );
      expect(persisted, isNotNull);
      expect(persisted, contains(prodChain.southTip.id));
      expect(
        prefs.getString(SharedPreferencesRouteRepository.storageKey),
        isNull,
      );

      // A fresh repo over the SAME prefs reads the migrated in-chain plan
      // DIRECTLY (no second reset) — deterministic, idempotent startup.
      final relaunched = SharedPreferencesRouteRepository(
        prefs,
        prodChain,
        prodGeography,
      );
      final second = await relaunched.loadPlan(currentCumulativeKm: 200.0);
      expect(second!.orderedNodeIds, corridorIds);
      expect(second.routeStartOffsetKm, closeTo(200.0, _tol));
    });
  });
}
