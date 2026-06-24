// Focused unit tests for the SharedPreferencesCompactWindowPositionRepository.
//
// Scope: the compact-position persistence seam over the real shared_preferences
// impl, driven by SharedPreferences.setMockInitialValues({}) so there is no real
// disk I/O or platform channel (AC-8 round-trip + null-when-absent). Mirrors the
// v1 shared_preferences repository tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/mini_window/data/shared_preferences_compact_window_position_repository.dart';
import 'package:focus_journey/features/mini_window/domain/window_position.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPreferencesCompactWindowPositionRepository', () {
    test('load_freshInstall_returnsNull', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesCompactWindowPositionRepository(prefs);
      expect(await repo.load(), isNull);
    });

    test('saveThenLoad_roundTripsPosition', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesCompactWindowPositionRepository(prefs);

      await repo.save(const WindowPosition(x: 314.0, y: 159.0));
      final loaded = await repo.load();

      expect(loaded, const WindowPosition(x: 314.0, y: 159.0));
    });

    test('load_partialData_returnsNull', () async {
      // Only x present (e.g. an interrupted save) → treat as absent, not crash.
      SharedPreferences.setMockInitialValues(<String, Object>{
        SharedPreferencesCompactWindowPositionRepository.keyX: 100.0,
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesCompactWindowPositionRepository(prefs);
      expect(await repo.load(), isNull);
    });
  });
}
