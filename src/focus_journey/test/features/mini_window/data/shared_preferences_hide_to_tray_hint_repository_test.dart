// Focused unit tests for the SharedPreferencesHideToTrayHintRepository (AC-17).
//
// Scope: the one-time hide-to-tray hint flag round-trips over the real
// shared_preferences impl, driven by SharedPreferences.setMockInitialValues so
// there is no real disk I/O or platform channel. Mirrors the v1
// shared_preferences repository tests.
//
// TC-015 (persistence half): a fresh install reports "not yet shown"; after
// markHintShown() the flag persists; a flag already present round-trips true.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/mini_window/data/shared_preferences_hide_to_tray_hint_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPreferencesHideToTrayHintRepository (AC-17 / TC-015)', () {
    test('hasShownHint_freshInstall_returnsFalse', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesHideToTrayHintRepository(prefs);

      // No prior flag → the first close SHOULD show the hint.
      expect(await repo.hasShownHint(), isFalse);
    });

    test('markHintShown_thenHasShownHint_returnsTrue', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesHideToTrayHintRepository(prefs);

      await repo.markHintShown();

      // Subsequent closes must NOT re-show the hint (AC-17).
      expect(await repo.hasShownHint(), isTrue);
    });

    test('hasShownHint_flagPresentFromPriorSession_returnsTrue', () async {
      // Simulate a previous session that already showed the hint.
      SharedPreferences.setMockInitialValues(<String, Object>{
        SharedPreferencesHideToTrayHintRepository.storageKey: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesHideToTrayHintRepository(prefs);

      expect(await repo.hasShownHint(), isTrue);
    });

    test('markHintShown_isIdempotent', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesHideToTrayHintRepository(prefs);

      await repo.markHintShown();
      await repo.markHintShown(); // calling twice must stay "shown".

      expect(await repo.hasShownHint(), isTrue);
    });
  });
}
