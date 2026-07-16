// Unit tests for the reset copy relabel (route-real-road / AC-6): the destructive
// full-wipe action reads as the friendlier "Reset everything" (no longer "Factory
// reset") and stays clearly distinct from the route-only "Start over" action.
// The wipe SCOPE (the dialog body naming lifetime distance/streaks/badges) is
// unchanged.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/reset/presentation/reset_copy.dart';

void main() {
  group('FactoryResetCopy — friendlier full-wipe wording (AC-6)', () {
    test('the action + dialog titles no longer say "Factory reset"', () {
      expect(FactoryResetCopy.actionTitle, 'Reset everything');
      expect(FactoryResetCopy.dialogTitle, 'Reset everything?');
      expect(FactoryResetCopy.actionTitle, isNot(contains('Factory reset')));
      expect(FactoryResetCopy.dialogTitle, isNot(contains('Factory reset')));
    });

    test('the error message no longer references "Factory reset"', () {
      expect(FactoryResetCopy.errorMessage, isNot(contains('Factory reset')));
      expect(FactoryResetCopy.errorMessage, contains('please try again'));
    });

    test('stays clearly distinct from the route-only "Start over" action', () {
      expect(LaunchPromptCopy.startOverLabel, 'Start over');
      expect(FactoryResetCopy.actionTitle, isNot(LaunchPromptCopy.startOverLabel));
    });

    test('the wipe SCOPE is unchanged (still names the lifetime data cleared)', () {
      expect(
        FactoryResetCopy.dialogBody,
        contains('lifetime distance, streaks, and badges'),
      );
      // Still frames the asymmetry vs the route-only Start over.
      expect(FactoryResetCopy.dialogBody, contains('Start over'));
    });
  });
}
