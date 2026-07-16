// Focused unit tests for the LocalDataStore (Factory-reset) facet of the two
// mini_window repositories: the compact-window position (TWO prefs keys, x/y)
// and the hide-to-tray hint (journey-reset AC-3/AC-5, TC-704 + TC-707 unit side).
//
// These keys live OUTSIDE the journey/stats repos and are the most likely to be
// forgotten by a wipe, so they get an explicit reset-suffixed file. Each repo's
// clear() removes only its own key(s); the compact-position clear must remove
// BOTH x and y. Driven by SharedPreferences.setMockInitialValues (no
// disk/channel).

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/mini_window/data/shared_preferences_compact_window_position_repository.dart';
import 'package:focus_journey/features/mini_window/data/shared_preferences_hide_to_tray_hint_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _allMiniWindowKeys() async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'mini_window.compact_position.x': 120.0,
    'mini_window.compact_position.y': 340.0,
    'mini_window_hide_to_tray_hint_shown_v1': true,
    // A foreign key to prove clear() is scoped.
    'journey_progress_v1': '{"distanceKm":1.0}',
  });
  return SharedPreferences.getInstance();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPreferencesCompactWindowPositionRepository as LocalDataStore '
      '(TC-704, TC-707)', () {
    test('ownedKeys_isBothPositionKeys', () async {
      final prefs = await _allMiniWindowKeys();
      expect(
        SharedPreferencesCompactWindowPositionRepository(prefs).ownedKeys,
        <String>{
          SharedPreferencesCompactWindowPositionRepository.keyX,
          SharedPreferencesCompactWindowPositionRepository.keyY,
        },
      );
      // Guard the literal names too — the persisted contract.
      expect(
        SharedPreferencesCompactWindowPositionRepository(prefs).ownedKeys,
        <String>{
          'mini_window.compact_position.x',
          'mini_window.compact_position.y',
        },
      );
    });

    test('clear_removesBothXAndYSoPositionFallsBackToDefaults', () async {
      final prefs = await _allMiniWindowKeys();
      await SharedPreferencesCompactWindowPositionRepository(prefs).clear();

      expect(prefs.containsKey('mini_window.compact_position.x'), isFalse);
      expect(prefs.containsKey('mini_window.compact_position.y'), isFalse);
      // Sibling mini_window key + foreign key untouched.
      expect(prefs.getBool('mini_window_hide_to_tray_hint_shown_v1'), isTrue);
      expect(prefs.getString('journey_progress_v1'), '{"distanceKm":1.0}');
    });
  });

  group('SharedPreferencesHideToTrayHintRepository as LocalDataStore '
      '(TC-704, TC-707)', () {
    test('ownedKeys_isHideToTrayHintKey', () async {
      final prefs = await _allMiniWindowKeys();
      expect(
        SharedPreferencesHideToTrayHintRepository(prefs).ownedKeys,
        <String>{'mini_window_hide_to_tray_hint_shown_v1'},
      );
    });

    test('clear_removesOnlyHintKeySoTrayReturnsToDefault', () async {
      final prefs = await _allMiniWindowKeys();
      await SharedPreferencesHideToTrayHintRepository(prefs).clear();

      expect(prefs.containsKey('mini_window_hide_to_tray_hint_shown_v1'), isFalse);
      expect(prefs.getDouble('mini_window.compact_position.x'), 120.0);
      expect(prefs.getDouble('mini_window.compact_position.y'), 340.0);
      expect(prefs.getString('journey_progress_v1'), '{"distanceKm":1.0}');
    });
  });
}
