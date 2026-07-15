// Widget tests for the launch Resume vs Start over prompt (journey-reset).
//
// Drives the REAL LaunchPrompt + a small harness mirroring the composition
// root's `fullBuilder` gate (BlocBuilder<LaunchGateCubit, bool> → prompt vs
// proceed), seeded from the persisted route lifecycle exactly as main.dart
// seeds the LaunchGateCubit. Start over drives the REAL showStartOverAuthoring
// hand-off. Pure: no engine, no ticker, no timers, no network — an in-memory
// RouteRepository + in-memory settings fakes back the cubits.
//
// Traceability (one test group ↔ one case; TC + AC ids in each description):
//   TC-710  (AC-6)  `active` lifecycle → the prompt is shown, both options
//                   present, BEFORE the journey is entered
//   TC-709  (AC-5, AC-7) null (post-reset / fresh) lifecycle → NO prompt
//   TC-711  (AC-7)  fresh install (no plan) → NO prompt
//   TC-712  (AC-7)  `completed` lifecycle → NO prompt
//   TC-713  (AC-7)  `abandoned` lifecycle → NO prompt
//   TC-710  (AC-6)  Resume dismisses the prompt (proceeds on restored state)
//   TC-716  (AC-9)  Start over opens the authoring/abandon entry
//   TC-725  (NFR-3) keyboard-reachable + screen-reader labelled; Resume is the
//                   default focus; Start over labelled as retention-preserving
//
// Run: fvm flutter test test/features/reset/presentation/launch_prompt_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/reset/presentation/launch_gate_cubit.dart';
import 'package:focus_journey/features/reset/presentation/launch_prompt.dart';
import 'package:focus_journey/features/reset/presentation/reset_copy.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/domain/route_plan.dart';
import 'package:focus_journey/features/route/domain/route_repository.dart';
import 'package:focus_journey/features/route/domain/route_selection.dart';
import 'package:focus_journey/features/route/presentation/route_planner_flow.dart';
import 'package:focus_journey/features/route/presentation/route_progress_cubit.dart';
import 'package:focus_journey/features/stats/domain/app_settings.dart';
import 'package:focus_journey/features/stats/domain/stats_repositories.dart';
import 'package:focus_journey/features/stats/presentation/settings_cubit.dart';

/// In-memory [RouteRepository] — no shared_preferences. Seed with an active
/// plan for the Start over hand-off.
class _FakeRouteRepository implements RouteRepository {
  _FakeRouteRepository({this.plan});
  RoutePlan? plan;
  RouteSelection? selection;

  @override
  Future<RouteSelection?> load() async => selection;
  @override
  Future<void> save(RouteSelection s) async => selection = s;
  @override
  Future<RoutePlan?> loadPlan() async => plan;
  @override
  Future<void> savePlan(RoutePlan p) async => plan = p;
}

/// Minimal in-memory settings fakes so a SettingsCubit can be provided into the
/// Start over authoring subtree (the cosmetic vehicle pick reads it).
class _FakeSettingsRepository implements SettingsRepository {
  AppSettings? _stored;
  @override
  Future<AppSettings?> load() async => _stored;
  @override
  Future<void> save(AppSettings settings) async => _stored = settings;
}

class _FakeStartupController implements StartupController {
  @override
  Future<bool> isEnabled() async => false;
  @override
  Future<void> setEnabled(bool enabled) async {}
}

void main() {
  /// An in-progress active plan over the real spine (two contiguous ids).
  RoutePlan activePlan() => const RoutePlan(
    orderedNodeIds: <String>['can_tho', 'ho_chi_minh'],
    routeStartOffsetKm: 0,
  );

  /// Pumps the launch gate exactly as the composition root's `fullBuilder`
  /// does: when the gate says "show prompt", render LaunchPrompt; otherwise
  /// render a stand-in for the onboarding/journey the app proceeds to.
  Future<LaunchGateCubit> pumpGate(
    WidgetTester tester, {
    required RouteLifecycle? lifecycle,
    RoutePlan? seededPlan,
  }) async {
    final gate = LaunchGateCubit(lifecycle: lifecycle);
    addTearDown(gate.close);
    final routeRepo = _FakeRouteRepository(plan: seededPlan);
    final routeCubit = RouteProgressCubit(
      chain: vietnamProvinceChain,
      geography: vietnamProvinceGeography,
      repository: routeRepo,
      initialPlan: seededPlan,
    );
    addTearDown(routeCubit.close);
    final settingsCubit = SettingsCubit(
      repository: _FakeSettingsRepository(),
      startupController: _FakeStartupController(),
      applyIdleThreshold: (_) {},
    );
    addTearDown(settingsCubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<LaunchGateCubit>.value(value: gate),
            BlocProvider<RouteProgressCubit>.value(value: routeCubit),
            BlocProvider<SettingsCubit>.value(value: settingsCubit),
          ],
          child: BlocBuilder<LaunchGateCubit, bool>(
            builder: (context, showPrompt) {
              if (showPrompt) {
                return LaunchPrompt(
                  chain: vietnamProvinceChain,
                  geography: vietnamProvinceGeography,
                );
              }
              return const Scaffold(
                body: Center(child: Text('proceeded-onboarding')),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return gate;
  }

  group('TC-710 (AC-6) active route → Resume vs Start over prompt', () {
    testWidgets(
      'the prompt is shown with BOTH options before entering the journey',
      (tester) async {
        await pumpGate(
          tester,
          lifecycle: RouteLifecycle.active,
          seededPlan: activePlan(),
        );

        expect(find.byKey(const Key('launch-prompt')), findsOneWidget);
        expect(find.byKey(const Key('launch-prompt-resume')), findsOneWidget);
        expect(
          find.byKey(const Key('launch-prompt-start-over')),
          findsOneWidget,
        );
        // The user is NOT dropped into onboarding/journey while a route is active.
        expect(find.text('proceeded-onboarding'), findsNothing);
      },
    );

    testWidgets('choosing Resume dismisses the prompt and proceeds', (
      tester,
    ) async {
      await pumpGate(
        tester,
        lifecycle: RouteLifecycle.active,
        seededPlan: activePlan(),
      );

      await tester.tap(find.byKey(const Key('launch-prompt-resume')));
      await tester.pumpAndSettle();

      // Prompt gone; the app has proceeded past the gate (onto the restored
      // journey — its exact-position restore is asserted in the integration leg).
      expect(find.byKey(const Key('launch-prompt')), findsNothing);
      expect(find.text('proceeded-onboarding'), findsOneWidget);
    });
  });

  group('TC-709 (AC-5, AC-7) post-reset / null lifecycle → no prompt', () {
    testWidgets('a null lifecycle (wiped / fresh) suppresses the prompt', (
      tester,
    ) async {
      await pumpGate(tester, lifecycle: null);
      expect(find.byKey(const Key('launch-prompt')), findsNothing);
      expect(find.text('proceeded-onboarding'), findsOneWidget);
    });
  });

  group('TC-711 (AC-7) fresh install → no prompt', () {
    testWidgets('no persisted plan goes straight to onboarding', (tester) async {
      await pumpGate(tester, lifecycle: null, seededPlan: null);
      expect(find.byKey(const Key('launch-prompt')), findsNothing);
      expect(find.text('proceeded-onboarding'), findsOneWidget);
    });
  });

  group('TC-712 (AC-7) completed route → no prompt', () {
    testWidgets('a completed lifecycle proceeds without a prompt', (
      tester,
    ) async {
      await pumpGate(tester, lifecycle: RouteLifecycle.completed);
      expect(find.byKey(const Key('launch-prompt')), findsNothing);
      expect(find.text('proceeded-onboarding'), findsOneWidget);
    });
  });

  group('TC-713 (AC-7) abandoned route → no prompt', () {
    testWidgets('an abandoned lifecycle proceeds without a prompt', (
      tester,
    ) async {
      await pumpGate(tester, lifecycle: RouteLifecycle.abandoned);
      expect(find.byKey(const Key('launch-prompt')), findsNothing);
      expect(find.text('proceeded-onboarding'), findsOneWidget);
    });
  });

  group('TC-716 (AC-9) Start over opens the authoring / abandon entry', () {
    testWidgets(
      'tapping Start over opens the shipped route-planner authoring flow',
      (tester) async {
        await pumpGate(
          tester,
          lifecycle: RouteLifecycle.active,
          seededPlan: activePlan(),
        );

        await tester.tap(find.byKey(const Key('launch-prompt-start-over')));
        await tester.pumpAndSettle();

        // The Start over hand-off routes through the shipped RoutePlannerFlow
        // (the ADR-0005 authoring entry) — NOT a parallel reset dialog.
        expect(find.byType(RoutePlannerFlow), findsOneWidget);
        // The prompt is still underneath (cancelling authoring leaves Resume
        // reachable — AC-8), so the gate has not dismissed yet.
        expect(find.byKey(const Key('launch-prompt')), findsOneWidget);
      },
    );
  });

  group('TC-725 (NFR-3) keyboard-reachable + screen-reader labelled', () {
    testWidgets(
      'Resume is the default focus, Start over exposes a retention-naming '
      'semantic label, and both options are reachable',
      (tester) async {
        await pumpGate(
          tester,
          lifecycle: RouteLifecycle.active,
          seededPlan: activePlan(),
        );

        // Resume is the autofocused default (a keyboard user lands on the safe,
        // non-destructive continue action first).
        final resume = tester.widget<FilledButton>(
          find.byKey(const Key('launch-prompt-resume')),
        );
        expect(resume.autofocus, isTrue);

        // Start over carries a meaningful accessible name that states it KEEPS
        // lifetime data (surfacing the asymmetry vs Factory reset — AC-12/NFR-3).
        expect(
          find.bySemanticsLabel(LaunchPromptCopy.startOverSemanticLabel),
          findsOneWidget,
        );

        // Both interactive options are present + reachable.
        expect(find.byKey(const Key('launch-prompt-resume')), findsOneWidget);
        expect(
          find.byKey(const Key('launch-prompt-start-over')),
          findsOneWidget,
        );
      },
    );
  });
}
