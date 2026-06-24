// Screen-level widget tests for the first-run onboarding / privacy screen.
//
// Scope: the OnboardingScreen + reusable PrivacyContent block. Asserts the trust
// promise copy is present (the four required claim sections) and that completing
// onboarding invokes the caller's persist callback. The first-run GATING itself
// (shown when !onboardingSeen, flips to home once the seen-flag is set, NOT
// re-shown on a next launch with the flag already set) is exercised in
// onboarding_gate_test.dart, which pumps the same BlocBuilder + buildWhen gate
// from main.dart over a real SettingsCubit. Here we assert the screen-level
// contract only.
//
// Covers (widget leg):
//   TC-021  first-run onboarding states what the app READS, what it NEVER reads,
//           that it is fully local/offline with no account, and how active vs
//           journey time differ; completing invokes onComplete (persist hook)
//
// AC-21 (copy <-> code release gate, TC-022) is a MANUAL /privacy-audit case —
// not asserted here; see tests/cases/local-stats-manual-checklist.md.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/stats/presentation/onboarding_screen.dart';

/// Sizes the test surface tall enough that the whole scrollable privacy content
/// is laid out in one frame (a ListView only builds its on-screen children, so
/// a short default viewport would leave the last claim Card un-built). Desktop
/// is the target platform, so a tall window is realistic.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('TC-021 onboarding states the full trust promise', () {
    testWidgets('all four required claim sections render', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onComplete: () {})),
      );
      await tester.pump();

      // (1) What the app reads.
      expect(find.byKey(const Key('privacy-reads')), findsOneWidget);
      expect(find.text('What this app reads'), findsOneWidget);
      // (2) What the app never reads.
      expect(find.byKey(const Key('privacy-never-reads')), findsOneWidget);
      expect(find.text('What this app never reads'), findsOneWidget);
      // (3) Fully local / offline, no account.
      expect(find.byKey(const Key('privacy-offline')), findsOneWidget);
      // (4) Active vs journey time difference.
      expect(
        find.byKey(const Key('privacy-active-vs-journey')),
        findsOneWidget,
      );
    });

    testWidgets('the read / never-read item lists are non-empty + specific', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onComplete: () {})),
      );
      // The copy enumerates the audited "reads" (idle + lock/sleep) and the
      // explicit non-surface (keystrokes, screen, clipboard, files, ...).
      expect(kPrivacyReads, isNotEmpty);
      expect(kPrivacyNeverReads, isNotEmpty);
      // A representative never-read claim is rendered.
      expect(
        find.textContaining('Keystrokes', findRichText: true),
        findsWidgets,
      );
      expect(find.textContaining('clipboard'), findsWidgets);
    });

    testWidgets('completing onboarding invokes the persist callback', (
      tester,
    ) async {
      var completed = 0;
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onComplete: () => completed++)),
      );
      expect(find.byKey(const Key('onboarding-continue')), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding-continue')));
      await tester.pump();
      // The caller (which persists the seen-flag, AC-20) is invoked exactly once.
      expect(completed, 1);
    });
  });

  group('TC-021 PrivacyContent is reusable (re-openable from settings)', () {
    testWidgets('the same content block renders standalone', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PrivacyContent())),
      );
      await tester.pump();
      // Re-opened from settings, the identical claim sections are present.
      expect(find.byKey(const Key('privacy-reads')), findsOneWidget);
      expect(find.byKey(const Key('privacy-never-reads')), findsOneWidget);
      expect(find.byKey(const Key('privacy-offline')), findsOneWidget);
      expect(
        find.byKey(const Key('privacy-active-vs-journey')),
        findsOneWidget,
      );
      // The active-vs-journey copy states raw is never larger than journey.
      expect(find.text('Active time vs journey time'), findsOneWidget);
    });
  });
}
