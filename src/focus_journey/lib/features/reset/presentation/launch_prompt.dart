/// Presentation layer. The launch Resume vs Start over prompt (AC-6/AC-8/AC-9)
/// shown BEFORE entering the journey when an `active` route exists.
///
/// Resume dismisses the prompt and enters the journey on the EXISTING restored
/// state (position untouched — AC-8). Start over routes through the SHIPPED
/// ADR-0005 abandon path ([RouteProgressCubit.abandonAndStartNew] via the
/// existing [RoutePlannerFlow]) — it does NOT reimplement a parallel reset (AC-9)
/// and it keeps lifetime distance/streaks/badges (AC-12). If the user cancels
/// authoring, the prompt stays up so Resume is still available.
///
/// PRIVACY (NFR-2): reads no OS signal, no device location, no network — only
/// the static chain/geography + the existing cubits.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../journey/presentation/journey_gate_cubit.dart';
import '../../route/domain/province_chain.dart';
import '../../route/domain/province_geography.dart';
import '../../route/domain/road_path.dart';
import '../../route/presentation/map_surface.dart' show RouteStartVehiclePicker;
import '../../route/presentation/route_planner_flow.dart';
import '../../route/presentation/route_progress_cubit.dart';
import '../../stats/presentation/settings_cubit.dart';
import 'launch_gate_cubit.dart';
import 'reset_copy.dart';

/// The full-screen launch prompt. Keyboard-navigable + screen-reader reachable
/// (NFR-3); Start over is textually distinct from the destructive Factory reset
/// and names the retention of lifetime data (AC-12).
class LaunchPrompt extends StatelessWidget {
  /// Creates the prompt over the full [chain] / [geography] (for authoring on
  /// Start over).
  const LaunchPrompt({
    required this.chain,
    required this.geography,
    this.road,
    super.key,
  });

  /// The full spine (for the Start over authoring flow).
  final ProvinceChain chain;

  /// The static geography (for the Start over authoring flow).
  final ProvinceGeography geography;

  /// The bundled national road (route-real-road), forwarded to the Start over
  /// authoring flow so its review distance reflects the REAL road length. `null`
  /// (tests / degraded mode) falls back to the sub-chain km.
  final RoadPath? road;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      key: const Key('launch-prompt'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  LaunchPromptCopy.title,
                  style: text.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  LaunchPromptCopy.body,
                  style: text.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  key: const Key('launch-prompt-resume'),
                  autofocus: true,
                  onPressed: () => context.read<LaunchGateCubit>().resume(),
                  child: const Text(LaunchPromptCopy.resumeLabel),
                ),
                const SizedBox(height: 12),
                Semantics(
                  button: true,
                  label: LaunchPromptCopy.startOverSemanticLabel,
                  child: OutlinedButton(
                    key: const Key('launch-prompt-start-over'),
                    onPressed: () => _startOver(context),
                    child: const Text(LaunchPromptCopy.startOverLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Opens route authoring; on confirm, abandons the current route via the
  /// SHIPPED ADR-0005 path and dismisses the prompt onto the new route (AC-9).
  Future<void> _startOver(BuildContext context) async {
    await showStartOverAuthoring(
      context,
      chain: chain,
      geography: geography,
      road: road,
    );
  }
}

/// Opens the existing [RoutePlannerFlow] to author a replacement route and, on
/// confirm, retires the current route through the SHIPPED abandon lifecycle
/// ([RouteProgressCubit.abandonAndStartNew]) and dismisses the launch prompt
/// (AC-9/AC-11). Cancelling authoring leaves the current route fully intact and
/// the prompt still shown (AC-8 still reachable).
///
/// This is the ONE Start over hand-off — it reuses the shipped abandon path
/// rather than inventing a parallel reset (AC-9 / TC-717), so lifetime
/// distance/streaks/badges are preserved (AC-10/AC-12).
Future<void> showStartOverAuthoring(
  BuildContext context, {
  required ProvinceChain chain,
  required ProvinceGeography geography,
  RoadPath? road,
}) async {
  final RouteProgressCubit routeCubit = context.read<RouteProgressCubit>();
  final LaunchGateCubit gateCubit = context.read<LaunchGateCubit>();
  // Re-provide the SAME SettingsCubit into the dialog subtree (the root
  // navigator does not inherit it) so the cosmetic vehicle pick has one source.
  final SettingsCubit settingsCubit = context.read<SettingsCubit>();
  // route-real-road: pause the still-active route while re-authoring so it does
  // not accrue during setup; resume on close (cancel keeps the old route,
  // confirm starts the new one via onRouteStarted). Defensive for route-only
  // test hosts that mount no journey gate.
  JourneyGateCubit? journeyGate;
  try {
    journeyGate = context.read<JourneyGateCubit>();
  } on ProviderNotFoundException {
    journeyGate = null;
  }
  journeyGate?.beginAuthoring();
  try {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) =>
          BlocProvider<SettingsCubit>.value(
            value: settingsCubit,
            child: Dialog(
              child: SingleChildScrollView(
                child: RoutePlannerFlow(
                  chain: chain,
                  geography: geography,
                  road: road,
                  onConfirmed: (resolved) {
                    // Abandon the current route (new offset over the never-reset
                    // engine distance) and travel the newly authored one (AC-9).
                    routeCubit.abandonAndStartNew(resolved);
                    // Only NOW dismiss the prompt — onto the new active route.
                    gateCubit.dismissAfterStartOver();
                    Navigator.of(dialogContext).pop();
                  },
                  // Cancel: nothing recorded, current route + prompt untouched.
                  onCancelled: () => Navigator.of(dialogContext).pop(),
                  vehiclePicker: RouteStartVehiclePicker.maybeFor(dialogContext),
                ),
              ),
            ),
          ),
    );
  } finally {
    // Always resume the (still-active on cancel, or newly-confirmed) route, even
    // if the authoring dialog threw — otherwise the gate would be stuck paused
    // with no manual control to recover. Idempotent with onRouteStarted, and a
    // no-op if the gate was torn down mid-authoring.
    journeyGate?.endAuthoring();
  }
}
