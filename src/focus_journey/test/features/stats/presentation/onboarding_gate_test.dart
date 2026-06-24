// Widget tests for the first-run onboarding GATE (AC-20 / TC-021, leg b).
//
// Scope: the BlocBuilder<SettingsCubit, AppSettings> gate that main.dart wires
// at the app root (main.dart ~lines 301-312). On `!onboardingSeen` it shows the
// OnboardingScreen; once the seen-flag is set it switches to the home. This pins
// the BRANCHING that was previously untested — the "shown on first run / not
// re-shown next launch / re-openable from settings" contract.
//
// HARNESS, NOT THE REAL APP ROOT (deliberate): FocusJourneyApp cannot be pumped
// headlessly. Its initState builds the full DI graph against real OS/plugin
// seams — launchAtStartup.setup(), ActivityPluginFactory.create() (the real
// MethodChannelActivityPlugin under `flutter test`, since the `mock-activity`
// dart-define is not set), a LocalNotifierNotifier, a route-cubit stream
// listener, and _ticker.start() (a real periodic Timer that never settles under
// pumpAndSettle). Extracting the gate into production is out of scope (no
// production edits allowed), so this harness reproduces the EXACT gate widget
// from main.dart — the same BlocBuilder + buildWhen, the same real SettingsCubit
// over the shared FakeSettingsRepository, and the same
// `onComplete: () => context.read<SettingsCubit>().markOnboardingSeen()` wiring.
// The home branch is a sentinel (`_HomeSentinel`) because main.dart's real
// `_HomeTabs` is private and pulls in screens needing the journey/route/stats
// cubits; the gate's contract is purely WHICH branch renders for a given flag,
// which the sentinel observes faithfully.
//
// What is covered vs. delegated:
//   * First run (no flag) -> OnboardingScreen shown, home NOT shown.
//   * Completion -> markOnboardingSeen persists + the gate flips to home.
//   * Fresh pump with the flag already set (a "next launch") -> home shown,
//     onboarding NOT re-shown. This is the manual leg previously (mis)attributed
//     to a non-existent integration test in onboarding_screen_test.dart.
//   * The re-open-from-settings entry point is asserted in
//     settings_screen_test.dart (TC-021 "settings re-opens the privacy
//     promise"); here we assert the same PrivacyContent block is re-usable
//     standalone so the gate test stands alone for the re-openable claim too.
//
// Determinism: no real timers, no real OS — a no-op applyIdleThreshold recorder
// and an in-memory FakeSettingsRepository back the real SettingsCubit.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/stats/domain/app_settings.dart';
import 'package:focus_journey/features/stats/presentation/onboarding_screen.dart';
import 'package:focus_journey/features/stats/presentation/settings_cubit.dart';

import 'stats_test_fakes.dart';

/// A stand-in for main.dart's private `_HomeTabs` home branch. The gate's
/// contract is purely WHICH branch renders for a given seen-flag, so a sentinel
/// keyed widget lets us observe the switch without the real home's cubits.
const Key _homeKey = Key('home-sentinel');

class _HomeSentinel extends StatelessWidget {
  const _HomeSentinel();

  @override
  Widget build(BuildContext context) => const Scaffold(
    key: _homeKey,
    body: Center(child: Text('home')),
  );
}

/// Pumps the EXACT onboarding gate from main.dart over a real [SettingsCubit].
///
/// Mirrors main.dart's `BlocBuilder<SettingsCubit, AppSettings>` with the same
/// `buildWhen` (rebuild only when `onboardingSeen` flips) and the same
/// `onComplete` that calls `markOnboardingSeen()`.
Future<({SettingsCubit cubit, FakeSettingsRepository repo})> _pumpGate(
  WidgetTester tester, {
  AppSettings? initial,
}) async {
  // Tall surface so the onboarding ListView lays its claim cards out in one
  // frame (matches the onboarding/settings screen tests' convention).
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final repo = FakeSettingsRepository(initial);
  final cubit = SettingsCubit(
    repository: repo,
    startupController: FakeStartupController(),
    // No-op recorder: the gate never touches the engine seam (AC-9).
    applyIdleThreshold: (_) {},
    initialSettings: initial,
  );
  addTearDown(cubit.close);

  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<SettingsCubit>.value(
        value: cubit,
        // This is main.dart's gate, verbatim.
        child: BlocBuilder<SettingsCubit, AppSettings>(
          buildWhen: (prev, next) => prev.onboardingSeen != next.onboardingSeen,
          builder: (context, settings) {
            if (!settings.onboardingSeen) {
              return OnboardingScreen(
                onComplete: () =>
                    context.read<SettingsCubit>().markOnboardingSeen(),
              );
            }
            return const _HomeSentinel();
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (cubit: cubit, repo: repo);
}

void main() {
  group('TC-021 first-run onboarding gate (AC-20)', () {
    testWidgets('first run with no seen-flag shows onboarding, not home', (
      tester,
    ) async {
      // No initial settings => onboardingSeen defaults to false (a true first
      // launch with nothing persisted).
      await _pumpGate(tester);

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byKey(_homeKey), findsNothing);
      // A representative claim section confirms the real onboarding rendered.
      expect(find.byKey(const Key('privacy-reads')), findsOneWidget);
    });

    testWidgets(
      'completing onboarding persists the flag and flips the gate to home',
      (tester) async {
        final ctx = await _pumpGate(tester);
        expect(find.byType(OnboardingScreen), findsOneWidget);

        // Tap the real "Get started" button — the gate's onComplete calls
        // markOnboardingSeen() on the real cubit.
        await tester.tap(find.byKey(const Key('onboarding-continue')));
        await tester.pumpAndSettle();

        // The flag flipped + persisted (so a next launch reloads it true).
        expect(ctx.cubit.state.onboardingSeen, isTrue);
        expect(await ctx.repo.load(), isNotNull);
        expect((await ctx.repo.load())!.onboardingSeen, isTrue);

        // The gate switched branches: home is shown, onboarding is gone.
        expect(find.byKey(_homeKey), findsOneWidget);
        expect(find.byType(OnboardingScreen), findsNothing);
      },
    );

    testWidgets(
      'a next launch with the flag already set does NOT re-show onboarding',
      (tester) async {
        // Simulates "next launch": settings restored from the store already
        // have onboardingSeen == true (the manual leg previously mis-attributed
        // to a non-existent integration test).
        await _pumpGate(
          tester,
          initial: const AppSettings(onboardingSeen: true),
        );

        expect(find.byKey(_homeKey), findsOneWidget);
        expect(find.byType(OnboardingScreen), findsNothing);
      },
    );
  });

  group('TC-021 onboarding remains re-openable (AC-20)', () {
    // The settings entry point itself is exercised in settings_screen_test.dart
    // ("settings re-opens the privacy promise"). Here we assert the same
    // PrivacyContent block the settings tile re-opens renders standalone, so the
    // gate test alone documents that the trust promise is re-viewable post-gate.
    testWidgets('the re-openable PrivacyContent renders its claim sections', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PrivacyContent())),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('privacy-reads')), findsOneWidget);
      expect(find.byKey(const Key('privacy-never-reads')), findsOneWidget);
      expect(find.byKey(const Key('privacy-offline')), findsOneWidget);
      expect(
        find.byKey(const Key('privacy-active-vs-journey')),
        findsOneWidget,
      );
    });
  });
}
