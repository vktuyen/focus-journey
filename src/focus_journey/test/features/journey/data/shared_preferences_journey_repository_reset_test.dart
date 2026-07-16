// Focused unit tests for the LocalDataStore (Factory-reset) facet of
// SharedPreferencesJourneyRepository (journey-reset AC-3, TC-704 unit side).
//
// Separate from the existing journey-repo tests so it does not clash. Scope:
// ownedKeys enumerates exactly the journey key and clear() removes only that
// key. Driven by SharedPreferences.setMockInitialValues (no real disk/channel).

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/data/shared_preferences_journey_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _foreignKey = 'stats_history_v1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPreferencesJourneyRepository as LocalDataStore (TC-704, AC-3)', () {
    test('ownedKeys_isJourneyProgressKey', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesJourneyRepository(prefs);

      expect(repo.ownedKeys, <String>{'journey_progress_v1'});
    });

    test('clear_removesOwnedKeyOnly', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SharedPreferencesJourneyRepository.storageKey: '{"distanceKm":42.0}',
        _foreignKey: '[]',
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesJourneyRepository(prefs);

      await repo.clear();

      expect(prefs.containsKey('journey_progress_v1'), isFalse);
      expect(prefs.getString(_foreignKey), '[]');
    });
  });
}
