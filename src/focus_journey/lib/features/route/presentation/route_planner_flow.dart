/// Presentation layer. The route-planner-v2 flow host (#8/#9/#10): picker →
/// review-before-start → confirm, plus the abandon confirm guard (#10).
///
/// Composes [RoutePicker] and [RouteReviewScreen] into the two-step authoring
/// flow and wires the confirm step to [RouteProgressCubit.confirmRoute] /
/// [RouteProgressCubit.abandonAndStartNew]. Holds the in-flight candidate in
/// LOCAL state only — nothing is stamped/persisted until confirm (AC-6).
///
/// PRIVACY (NFR-2): no OS signal, no device location, no network — only the
/// static chain/geography + the cubit's plain scalar seam.
library;

import 'package:flutter/material.dart';

import '../domain/province.dart';
import '../domain/province_chain.dart';
import '../domain/province_geography.dart';
import '../domain/road_path.dart';
import '../domain/route_planner.dart';
import 'route_picker.dart';
import 'route_progress_cubit.dart';
import 'route_review_screen.dart';

/// The two-step authoring flow: pick endpoints/stops, then review + confirm.
///
/// [onConfirmed] is invoked with the confirmed [ResolvedRoute] (the host commits
/// it via the cubit and closes the flow). [abandon] when true routes the confirm
/// through [RouteProgressCubit.abandonAndStartNew] (the abandon guard is shown by
/// the host BEFORE this flow opens — AC-9); otherwise it is a fresh start.
class RoutePlannerFlow extends StatefulWidget {
  /// Creates the flow over [chain] / [geography]. [onConfirmed] commits the
  /// confirmed route; [onCancelled] closes the flow with nothing recorded.
  const RoutePlannerFlow({
    required this.chain,
    required this.geography,
    required this.onConfirmed,
    required this.onCancelled,
    this.road,
    this.vehiclePicker,
    super.key,
  });

  /// The full spine.
  final ProvinceChain chain;

  /// The static geography (NFR-2).
  final ProvinceGeography geography;

  /// The bundled national road (route-real-road), forwarded to
  /// [RouteReviewScreen] so its distance readout reflects the REAL road length.
  /// `null` (tests / degraded mode) falls back to the sub-chain km.
  final RoadPath? road;

  /// Called with the confirmed candidate — the host commits it (the only
  /// mutation; AC-6/AC-7).
  final void Function(ResolvedRoute resolved) onConfirmed;

  /// Called when the user cancels out of the whole flow (nothing recorded).
  final VoidCallback onCancelled;

  /// vehicle-picker AC-13 (Resolved decision 7): the optional, SKIPPABLE
  /// route-start vehicle-pick control surfaced on the review/confirm step,
  /// forwarded to [RouteReviewScreen]. Cosmetic-only (ADR-0007): it writes the
  /// single `SettingsCubit` preference, never the route. `null` renders no
  /// vehicle control.
  final Widget? vehiclePicker;

  @override
  State<RoutePlannerFlow> createState() => _RoutePlannerFlowState();
}

class _RoutePlannerFlowState extends State<RoutePlannerFlow> {
  ResolvedRoute? _candidate;
  Province? _start;
  Province? _end;
  List<Province> _markedStops = const <Province>[];

  void _onResolved(
    ResolvedRoute resolved,
    Province start,
    Province end,
    List<Province> markedStops,
  ) {
    setState(() {
      _candidate = resolved;
      _start = start;
      _end = end;
      _markedStops = markedStops;
    });
  }

  void _backToPicker() {
    setState(() => _candidate = null);
  }

  @override
  Widget build(BuildContext context) {
    final candidate = _candidate;
    if (candidate == null) {
      return RoutePicker(
        chain: widget.chain,
        geography: widget.geography,
        onCancel: widget.onCancelled,
        onResolved: (resolved, markedStops) {
          // The candidate's travel-order endpoints ARE the picks (the planner is
          // pure; it already applied any AC-4 span extension from marked stops).
          // The review screen displays ONLY the anchors — the endpoints + the
          // marked stops (route-real-road): the pass-through provinces are
          // implicit road geometry, never listed. The real marked-stop list is
          // threaded through so those stops appear as anchors in travel order.
          _onResolved(
            resolved,
            resolved.orderedNodes.first,
            resolved.orderedNodes.last,
            markedStops,
          );
        },
      );
    }
    return RouteReviewScreen(
      chain: widget.chain,
      geography: widget.geography,
      start: _start!,
      end: _end!,
      markedStops: _markedStops,
      initial: candidate,
      road: widget.road,
      onConfirm: widget.onConfirmed,
      // Cancelling the review returns to the picker (nothing recorded — AC-6).
      onCancel: _backToPicker,
      // vehicle-picker AC-13: surface the skippable route-start vehicle control
      // on the review step (cosmetic-only; the route is untouched by it).
      vehiclePicker: widget.vehiclePicker,
    );
  }
}

/// Shows the AC-9 abandon confirm guard ("you'll lose progress on this route")
/// when [hasProgressToLose], returning whether the user confirmed. When there is
/// no progress to lose the guard is skipped and `true` is returned immediately
/// (a fresh start needs no confirm). Cancelling returns `false` — the caller then
/// does nothing, leaving the current route fully untouched (AC-9).
Future<bool> confirmAbandon(
  BuildContext context, {
  required bool hasProgressToLose,
}) async {
  if (!hasProgressToLose) {
    return true;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const Key('abandon_confirm_dialog'),
      title: const Text('Start a new route?'),
      content: const Text(
        "You'll lose progress on this route. Your lifetime distance is kept.",
      ),
      actions: <Widget>[
        TextButton(
          key: const Key('abandon_confirm_cancel'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Keep going'),
        ),
        FilledButton(
          key: const Key('abandon_confirm_ok'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Start new route'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
