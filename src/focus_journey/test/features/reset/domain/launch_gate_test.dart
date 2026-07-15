// Deterministic unit tests for decideLaunch — the pure launch-gate decision
// (journey-reset AC-5/AC-6/AC-7, TC-709..TC-713).
//
// Scope: the total, side-effect-free mapping from the persisted route lifecycle
// (or null) to a LaunchDecision. No widget tree, no shared_preferences, no
// engine — a pure function, so the tests are plain, fast, and exhaustive over
// every RouteLifecycle enum value + null.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/reset/domain/launch_gate.dart';
import 'package:focus_journey/features/route/domain/route_plan.dart';

void main() {
  group('decideLaunch (TC-710..TC-713, TC-709)', () {
    test('activeRoute_promptsResumeOrStartOver', () {
      // AC-6 / TC-710: an active route is the sole resumable state.
      expect(
        decideLaunch(RouteLifecycle.active),
        LaunchDecision.resumeOrStartOver,
      );
    });

    test('completedRoute_proceedsWithoutPrompt', () {
      // AC-7 / TC-712: completed is terminal, not resumable.
      expect(decideLaunch(RouteLifecycle.completed), LaunchDecision.proceed);
    });

    test('abandonedRoute_proceedsWithoutPrompt', () {
      // AC-7 / TC-713: abandoned is terminal (ADR-0005), not resumable.
      expect(decideLaunch(RouteLifecycle.abandoned), LaunchDecision.proceed);
    });

    test('nullLifecycle_freshOrPostReset_proceedsWithoutPrompt', () {
      // AC-5/AC-7 / TC-709 + TC-711: no persisted route (fresh install or
      // post-Factory-reset) suppresses the prompt.
      expect(decideLaunch(null), LaunchDecision.proceed);
    });

    test('everyLifecycleValueIsHandled_onlyActivePrompts', () {
      // Totality guard: exactly one enum value (active) prompts; a new lifecycle
      // value added later defaults to proceed and this documents the contract.
      for (final lifecycle in RouteLifecycle.values) {
        final decision = decideLaunch(lifecycle);
        if (lifecycle == RouteLifecycle.active) {
          expect(decision, LaunchDecision.resumeOrStartOver);
        } else {
          expect(decision, LaunchDecision.proceed);
        }
      }
    });

    test('isPure_sameInputSameOutput', () {
      expect(
        decideLaunch(RouteLifecycle.active),
        decideLaunch(RouteLifecycle.active),
      );
      expect(decideLaunch(null), decideLaunch(null));
    });
  });
}
