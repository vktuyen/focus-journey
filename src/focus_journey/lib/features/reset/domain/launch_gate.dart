/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
///
/// journey-reset (AC-6/AC-7). THE launch-gate decision, extracted as a pure
/// function so it is unit-testable in isolation (TC-709..TC-713) with no widget
/// tree, no `shared_preferences`, and no engine. It maps the persisted route
/// lifecycle at launch → whether to show the Resume vs Start over prompt.
library;

import '../../route/domain/route_plan.dart';

/// What the launch flow should do after loading persisted state.
enum LaunchDecision {
  /// An `active` route is in progress → show the Resume vs Start over prompt
  /// BEFORE entering the journey (AC-6).
  resumeOrStartOver,

  /// No `active` route (fresh install, post-Factory-reset, or a completed /
  /// abandoned route) → suppress the prompt and go straight to onboarding /
  /// route-authoring (AC-5/AC-7).
  proceed,
}

/// Decides the launch gate from the persisted route [lifecycle] (or `null` when
/// no route is persisted at all — a fresh install or a post-Factory-reset
/// state).
///
/// The ONLY input is the lifecycle: an `active` route is the sole state that is
/// resumable, so it is the sole state that prompts. `completed` and `abandoned`
/// are terminal (ADR-0005 / BR-10) and `null` is empty — all three proceed with
/// no prompt. Pure and total: same input → same output, every enum value + null
/// handled.
LaunchDecision decideLaunch(RouteLifecycle? lifecycle) {
  return lifecycle == RouteLifecycle.active
      ? LaunchDecision.resumeOrStartOver
      : LaunchDecision.proceed;
}
