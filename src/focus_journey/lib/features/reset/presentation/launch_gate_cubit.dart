/// Presentation layer. The Cubit that holds the launch gate's UI state: whether
/// the Resume vs Start over prompt is currently shown (AC-6/AC-7).
///
/// The DECISION itself is the pure [decideLaunch] function (domain) — this cubit
/// is only the thin, reconstruct-on-reset holder of "is the prompt up right
/// now". It is seeded from the persisted route lifecycle at construction, so a
/// post-Factory-reset rebuild (null lifecycle) starts with the prompt suppressed
/// (AC-5), and a relaunch with an `active` route starts with it shown (AC-6/11).
library;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../route/domain/route_plan.dart';
import '../domain/launch_gate.dart';

/// Owns whether the launch Resume/Start over prompt is currently shown.
class LaunchGateCubit extends Cubit<bool> {
  /// Creates the cubit, seeding the prompt from the persisted route [lifecycle]
  /// (null when no route is persisted). `true` iff an `active` route exists.
  LaunchGateCubit({required RouteLifecycle? lifecycle})
    : super(decideLaunch(lifecycle) == LaunchDecision.resumeOrStartOver);

  /// Whether the prompt should currently be shown.
  bool get showPrompt => state;

  /// The user chose Resume: dismiss the prompt and enter the journey unchanged
  /// (AC-8 — the restored state is untouched, so position is exact).
  void resume() {
    if (state) {
      emit(false);
    }
  }

  /// The user completed a Start over (route re-authored): dismiss the prompt and
  /// enter the journey on the NEW route (AC-9/AC-11). Not called if the user
  /// cancels authoring — the prompt then stays up so they can still Resume.
  void dismissAfterStartOver() {
    if (state) {
      emit(false);
    }
  }
}
