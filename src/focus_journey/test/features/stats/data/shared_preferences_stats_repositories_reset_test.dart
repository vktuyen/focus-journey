// Focused unit tests for the LocalDataStore (Factory-reset) facet of the three
// stats-feature repositories: settings, history, earned-badges (journey-reset
// AC-3, TC-704 unit side).
//
// Grouped in one reset-suffixed file so they do not clash with the existing
// per-repo tests. Each repo owns exactly one key and its clear() removes only
// that key. Populate all three keys, clear one repo, assert the sibling keys
// survive. Driven by SharedPreferences.setMockInitialValues (no disk/channel).

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/stats/data/shared_preferences_earned_badges_repository.dart';
import 'package:focus_journey/features/stats/data/shared_preferences_history_repository.dart';
import 'package:focus_journey/features/stats/data/shared_preferences_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _allThree() async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'app_settings_v1': '{"seen":true}',
    'stats_history_v1': '[]',
    'earned_badges_v1': '{"ids":[]}',
  });
  return SharedPreferences.getInstance();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPreferencesSettingsRepository as LocalDataStore (TC-704)', () {
    test('ownedKeys_isAppSettingsKey', () async {
      final prefs = await _allThree();
      expect(SharedPreferencesSettingsRepository(prefs).ownedKeys, <String>{
        'app_settings_v1',
      });
    });

    test('clear_removesOnlySettingsKey', () async {
      final prefs = await _allThree();
      await SharedPreferencesSettingsRepository(prefs).clear();

      expect(prefs.containsKey('app_settings_v1'), isFalse);
      expect(prefs.getString('stats_history_v1'), '[]');
      expect(prefs.getString('earned_badges_v1'), '{"ids":[]}');
    });
  });

  group('SharedPreferencesHistoryRepository as LocalDataStore (TC-704)', () {
    test('ownedKeys_isStatsHistoryKey', () async {
      final prefs = await _allThree();
      expect(SharedPreferencesHistoryRepository(prefs).ownedKeys, <String>{
        'stats_history_v1',
      });
    });

    test('clear_removesOnlyHistoryKey', () async {
      final prefs = await _allThree();
      await SharedPreferencesHistoryRepository(prefs).clear();

      expect(prefs.containsKey('stats_history_v1'), isFalse);
      expect(prefs.getString('app_settings_v1'), '{"seen":true}');
      expect(prefs.getString('earned_badges_v1'), '{"ids":[]}');
    });
  });

  group('SharedPreferencesEarnedBadgesRepository as LocalDataStore (TC-704)', () {
    test('ownedKeys_isEarnedBadgesKey', () async {
      final prefs = await _allThree();
      expect(SharedPreferencesEarnedBadgesRepository(prefs).ownedKeys, <String>{
        'earned_badges_v1',
      });
    });

    test('clear_removesOnlyEarnedBadgesKey', () async {
      final prefs = await _allThree();
      await SharedPreferencesEarnedBadgesRepository(prefs).clear();

      expect(prefs.containsKey('earned_badges_v1'), isFalse);
      expect(prefs.getString('app_settings_v1'), '{"seen":true}');
      expect(prefs.getString('stats_history_v1'), '[]');
    });
  });
}
