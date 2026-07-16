// Focused unit tests for the LocalDataStore (Factory-reset) facet of
// SharedPreferencesRouteRepository (journey-reset AC-3, TC-704 unit side).
//
// Separate from the existing route-repo tests so it does not clash. Scope: the
// route repo owns BOTH the v2 plan key AND the legacy v1 selection key, and its
// clear() must remove BOTH and only those — the legacy key is the one most
// likely to be forgotten. Driven by SharedPreferences.setMockInitialValues so
// there is no real disk / platform channel.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/data/shared_preferences_route_repository.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:shared_preferences/shared_preferences.dart';

// One foreign key from another store, to prove clear() removes ONLY its own.
const String _foreignKey = 'app_settings_v1';

Future<SharedPreferencesRouteRepository> _repoWithAllKeys() async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    SharedPreferencesRouteRepository.planStorageKey: '{"orderedNodeIds":["a","b"]}',
    SharedPreferencesRouteRepository.storageKey: '{"start":"a"}',
    _foreignKey: '{"seen":true}',
  });
  final prefs = await SharedPreferences.getInstance();
  return SharedPreferencesRouteRepository(prefs, vietnamProvinceChain);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPreferencesRouteRepository as LocalDataStore (TC-704, AC-3)', () {
    test('ownedKeys_isPlanKeyAndLegacyKey', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesRouteRepository(prefs, vietnamProvinceChain);

      expect(repo.ownedKeys, <String>{
        SharedPreferencesRouteRepository.planStorageKey,
        SharedPreferencesRouteRepository.storageKey,
      });
      // Guard the literal names too — these are the persisted contract.
      expect(repo.ownedKeys, <String>{'route_plan_v1', 'route_selection_v1'});
    });

    test('clear_removesBothPlanAndLegacyKeys', () async {
      final repo = await _repoWithAllKeys();
      final prefs = await SharedPreferences.getInstance();

      await repo.clear();

      expect(prefs.containsKey('route_plan_v1'), isFalse);
      expect(prefs.containsKey('route_selection_v1'), isFalse);
    });

    test('clear_removesOnlyOwnedKeys_foreignKeySurvives', () async {
      final repo = await _repoWithAllKeys();
      final prefs = await SharedPreferences.getInstance();

      await repo.clear();

      expect(prefs.getString(_foreignKey), '{"seen":true}');
    });

    test('clear_whenLegacyKeyAbsent_stillRemovesPlanKey', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SharedPreferencesRouteRepository.planStorageKey: '{"orderedNodeIds":["a","b"]}',
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesRouteRepository(prefs, vietnamProvinceChain);

      await repo.clear();

      expect(prefs.containsKey('route_plan_v1'), isFalse);
      expect(prefs.getKeys(), isEmpty);
    });
  });
}
