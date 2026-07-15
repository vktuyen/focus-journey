// Deterministic unit tests for LaunchGateCubit — the thin holder of "is the
// Resume vs Start over prompt currently shown" (journey-reset AC-5/AC-6/AC-7,
// TC-709..TC-713 + TC-720 seeding side).
//
// Scope: seeding the prompt from the persisted route lifecycle at construction
// (only `active` seeds it shown) and the resume()/dismissAfterStartOver()
// transitions. No widget tree, no I/O — the cubit is seeded from a plain
// RouteLifecycle? value.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/reset/presentation/launch_gate_cubit.dart';
import 'package:focus_journey/features/route/domain/route_plan.dart';

void main() {
  group('LaunchGateCubit seeding (TC-710..TC-713, TC-709)', () {
    test('activeLifecycle_seedsPromptShown', () {
      final cubit = LaunchGateCubit(lifecycle: RouteLifecycle.active);
      expect(cubit.showPrompt, isTrue);
      expect(cubit.state, isTrue);
      cubit.close();
    });

    test('completedLifecycle_seedsPromptSuppressed', () {
      final cubit = LaunchGateCubit(lifecycle: RouteLifecycle.completed);
      expect(cubit.showPrompt, isFalse);
      cubit.close();
    });

    test('abandonedLifecycle_seedsPromptSuppressed', () {
      final cubit = LaunchGateCubit(lifecycle: RouteLifecycle.abandoned);
      expect(cubit.showPrompt, isFalse);
      cubit.close();
    });

    test('nullLifecycle_freshOrPostReset_seedsPromptSuppressed', () {
      // AC-5 / TC-709: a post-Factory-reset rebuild (no persisted route) starts
      // with the prompt suppressed.
      final cubit = LaunchGateCubit(lifecycle: null);
      expect(cubit.showPrompt, isFalse);
      cubit.close();
    });
  });

  group('LaunchGateCubit transitions', () {
    test('resume_whenPromptShown_dismissesIt', () async {
      final cubit = LaunchGateCubit(lifecycle: RouteLifecycle.active);
      final emitted = <bool>[];
      cubit.stream.listen(emitted.add);

      cubit.resume();

      expect(cubit.showPrompt, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(emitted, <bool>[false]);
      await cubit.close();
    });

    test('dismissAfterStartOver_whenPromptShown_dismissesIt', () async {
      // AC-9/AC-11: after a Start over the prompt is dismissed to enter the new
      // route.
      final cubit = LaunchGateCubit(lifecycle: RouteLifecycle.active);
      cubit.dismissAfterStartOver();
      expect(cubit.showPrompt, isFalse);
      await cubit.close();
    });

    test('resume_whenPromptAlreadyHidden_isInert', () async {
      final cubit = LaunchGateCubit(lifecycle: null);
      final emitted = <bool>[];
      cubit.stream.listen(emitted.add);

      cubit.resume();
      cubit.dismissAfterStartOver();

      await Future<void>.delayed(Duration.zero);
      expect(emitted, isEmpty);
      expect(cubit.showPrompt, isFalse);
      await cubit.close();
    });
  });
}
