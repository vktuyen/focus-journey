/// Presentation layer. The route-planner-v2 review-before-start screen (#9 /
/// AC-5/AC-6), updated for the real-road model (route-real-road).
///
/// Shows ONLY the meaningful **anchors** of the authored route — the start, any
/// user-marked stops (in travel order), and the end — plus the **route distance**
/// (the REAL road length between those anchors). The pass-through provinces that
/// sit between the anchors are NOT listed: the bundled national road physically
/// runs through every province in between, so those are implicit geometry that
/// always exists to draw the road, never a stop of the journey. Consequently the
/// old "remove/skip an auto-inserted intermediate" affordance is GONE — there is
/// nothing meaningful to skip when the road passes through every province anyway.
/// Every listed anchor is shown locked (kept).
///
/// ## ZERO SIDE EFFECT UNTIL CONFIRM (AC-6 — critical invariant)
/// The candidate route lives entirely in THIS widget (unchanged from [initial]).
/// Building, reviewing, or cancelling stamps NO `routeStartOffset`, writes NO
/// persisted state, alters NO segment/position — [onCancel] simply pops with
/// nothing recorded. Only [onConfirm] (wired by the host to
/// `RouteProgressCubit.confirmRoute`) mutates anything, and it receives the
/// candidate UNCHANGED (the engine/geometry still consume the full internal
/// sub-chain — only the DISPLAYED list is trimmed to anchors).
///
/// PRIVACY (NFR-2): the distance readout reads ONLY the static [ProvinceGeography]
/// coordinates + the bundled [RoadPath] reference geometry; no OS signal, no
/// device location, no network.
///
/// ACCESSIBILITY (NFR-3): the anchor list, the distance readout, and
/// confirm/cancel are keyboard-reachable + screen-reader labelled.
library;

import 'package:flutter/material.dart';

import '../domain/province.dart';
import '../domain/province_chain.dart';
import '../domain/province_geography.dart';
import '../domain/road_path.dart';
import '../domain/road_route.dart';
import '../domain/route_planner.dart';

/// The review-before-start screen for an authored route.
class RouteReviewScreen extends StatefulWidget {
  /// Creates the review screen.
  ///
  /// [chain] / [geography] are the full spine the candidate was resolved over.
  /// [start] / [end] / [markedStops] are the user's picks — together they form the
  /// anchor list that is displayed (start, marked stops in travel order, end).
  /// [initial] is the resolved candidate (from the picker), handed UNCHANGED to
  /// [onConfirm] on "start" (the only mutation — AC-6); [onCancel] returns with
  /// nothing recorded. [road], when provided, is the bundled national road used to
  /// measure the REAL road length between the anchors (the same axis the map
  /// draws); when `null` (tests / degraded mode where the asset failed to load)
  /// the readout falls back to the candidate's sub-chain km.
  const RouteReviewScreen({
    required this.chain,
    required this.geography,
    required this.start,
    required this.end,
    required this.initial,
    required this.onConfirm,
    required this.onCancel,
    this.markedStops = const <Province>[],
    this.road,
    this.vehiclePicker,
    super.key,
  });

  /// The full spine.
  final ProvinceChain chain;

  /// The static geography the anchors are positioned from (NFR-2).
  final ProvinceGeography geography;

  /// The user's chosen start endpoint.
  final Province start;

  /// The user's chosen end endpoint.
  final Province end;

  /// The user's marked stops — shown as anchors, in travel order (AC-4).
  final List<Province> markedStops;

  /// The resolved candidate (from the picker) — handed UNCHANGED to [onConfirm].
  final ResolvedRoute initial;

  /// The bundled national road (route-real-road). When present the distance
  /// readout is the REAL road length between the anchors (matching the map);
  /// `null` falls back to `initial.subPathKm`.
  final RoadPath? road;

  /// Called with the candidate on confirm "start" — the only mutation.
  final void Function(ResolvedRoute resolved) onConfirm;

  /// Called on cancel — returns with nothing recorded (AC-6).
  final VoidCallback onCancel;

  /// vehicle-picker AC-13 (Resolved decision 7): the optional, SKIPPABLE
  /// route-start vehicle-pick control surfaced on this review step. Supplied by
  /// the host (bound to the single `SettingsCubit` preference, pre-seeded per
  /// AC-12). Cosmetic-only (ADR-0007): it writes the preference, never the route
  /// — the route engine/resolver neither reads nor stores the vehicle. `null`
  /// (e.g. existing route tests) renders no vehicle control, leaving the review
  /// flow exactly as before.
  final Widget? vehiclePicker;

  @override
  State<RouteReviewScreen> createState() => _RouteReviewScreenState();
}

class _RouteReviewScreenState extends State<RouteReviewScreen> {
  /// The candidate route (unchanged from [initial] — AC-6: local-only, no
  /// persistence, no offset, no engine touch until confirm).
  late final ResolvedRoute _candidate;

  /// The displayed anchors — { start, end } ∪ marked stops, ordered by their
  /// position in the candidate's travel order (start first, end last).
  late final List<Province> _anchors;

  @override
  void initState() {
    super.initState();
    _candidate = widget.initial;
    final anchorIds = <String>{
      widget.start.id,
      widget.end.id,
      for (final stop in widget.markedStops) stop.id,
    };
    _anchors = <Province>[
      for (final node in _candidate.orderedNodes)
        if (anchorIds.contains(node.id)) node,
    ];
  }

  /// The route distance shown: the REAL road length between the anchors when a
  /// [RoadPath] is available (the same axis the map draws), else the candidate's
  /// sub-chain km (tests / degraded mode). Reads ONLY static reference geometry
  /// (NFR-2) — a cheap in-memory build, never disk/network (NFR-1).
  ///
  /// Computed ONCE (the candidate + anchors are fixed for the review) instead of
  /// re-running the nearest-vertex snap over the whole road on every rebuild.
  late final double _distanceKm = _computeDistanceKm();

  double _computeDistanceKm() {
    final road = widget.road;
    if (road == null) {
      return _candidate.subPathKm;
    }
    final waypoints = <GeoCoordinate>[
      for (final anchor in _anchors) widget.geography.coordinateOf(anchor),
    ];
    return RoadRoute.build(road: road, waypoints: waypoints).routeLengthKm;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalKm = _distanceKm;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text('Review your route', style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: 'Total route distance ${totalKm.round()} kilometres',
            child: Text(
              key: const Key('route_review_total_distance'),
              '${totalKm.round()} km · ${_anchors.first.name} → '
              '${_anchors.last.name}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final province in _anchors)
                    _AnchorRow(province: province),
                ],
              ),
            ),
          ),
          // vehicle-picker AC-13: the skippable, pre-seeded route-start vehicle
          // control. Cosmetic-only — writing through the host's SettingsCubit;
          // the route itself is untouched, and confirming works regardless of
          // whether the user touched it.
          if (widget.vehiclePicker != null) ...<Widget>[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Vehicle for this journey',
                style: theme.textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 8),
            widget.vehiclePicker!,
          ],
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  key: const Key('route_review_cancel'),
                  onPressed: widget.onCancel,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('route_review_confirm'),
                  // The ONLY mutation — hands the candidate (unchanged) to the
                  // host (AC-6/AC-7).
                  onPressed: () => widget.onConfirm(_candidate),
                  child: const Text('Start journey'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One anchor row in the route — the province name shown locked (kept). Every
/// displayed anchor (start, marked stop, end) is a meaningful stop of the
/// journey; the pass-through provinces between them are implicit road geometry
/// and are never listed here.
class _AnchorRow extends StatelessWidget {
  const _AnchorRow({required this.province});

  final Province province;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      key: Key('route_review_stop_${province.id}'),
      leading: const Icon(Icons.place_outlined, size: 18),
      title: Text(province.name),
      trailing: Semantics(
        label: 'Stop — kept',
        child: const Icon(Icons.lock_outline, size: 18),
      ),
    );
  }
}
