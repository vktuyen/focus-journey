/// Presentation layer. The route-planner-v2 review-before-start screen (#9 /
/// AC-5/AC-6).
///
/// Shows the resolved **ordered** route (`start → … → end`) + the **total route
/// distance**, and lets the user **remove/skip auto-inserted intermediates**
/// before committing — each removal re-resolves the route via the pure
/// [RoutePlanner] (a cheap in-memory recompute — NFR-1). Endpoints + marked stops
/// are NOT removable (the AC-2 2-checkpoint minimum / AC-4 protected stops).
///
/// ## ZERO SIDE EFFECT UNTIL CONFIRM (AC-6 — critical invariant)
/// The candidate route lives entirely in THIS widget's local state. Building,
/// editing, or cancelling stamps NO `routeStartOffset`, writes NO persisted
/// state, alters NO segment/position — [onCancel] simply pops with nothing
/// recorded. Only [onConfirm] (wired by the host to `RouteProgressCubit.confirmRoute`)
/// mutates anything.
///
/// PRIVACY (NFR-2): re-resolution reads ONLY the static [ProvinceChain] /
/// [ProvinceGeography]; no OS signal, no device location, no network.
///
/// ACCESSIBILITY (NFR-3): the ordered-route list, each remove control, the
/// distance readout, and confirm/cancel are keyboard-reachable + screen-reader
/// labelled.
library;

import 'package:flutter/material.dart';

import '../domain/province.dart';
import '../domain/province_chain.dart';
import '../domain/province_geography.dart';
import '../domain/route_planner.dart';

/// The review-before-start screen for an authored route.
class RouteReviewScreen extends StatefulWidget {
  /// Creates the review screen.
  ///
  /// [chain] / [geography] are the full spine the candidate re-resolves over.
  /// [start] / [end] / [markedStops] are the user's original picks (so a removal
  /// re-runs the planner with an accumulated `removedStops` set). [initial] is the
  /// first resolved candidate (from the picker). [onConfirm] fires with the
  /// CURRENT candidate when the user confirms "start" (the only mutation — AC-6);
  /// [onCancel] returns with nothing recorded.
  const RouteReviewScreen({
    required this.chain,
    required this.geography,
    required this.start,
    required this.end,
    required this.initial,
    required this.onConfirm,
    required this.onCancel,
    this.markedStops = const <Province>[],
    this.vehiclePicker,
    super.key,
  });

  /// The full spine.
  final ProvinceChain chain;

  /// The static geography the candidate re-resolves over (NFR-2).
  final ProvinceGeography geography;

  /// The user's chosen start endpoint.
  final Province start;

  /// The user's chosen end endpoint.
  final Province end;

  /// The user's marked stops (protected from removal — AC-4).
  final List<Province> markedStops;

  /// The initial resolved candidate (from the picker).
  final ResolvedRoute initial;

  /// Called with the CURRENT candidate on confirm "start" — the only mutation.
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
  /// The candidate route, recomputed locally on every edit (AC-6: local-only —
  /// no persistence, no offset, no engine touch until confirm).
  late ResolvedRoute _candidate;

  /// The interior checkpoints the user has skipped so far (accumulated across
  /// edits, fed back into the pure planner — AC-5).
  final Set<String> _removedStopIds = <String>{};

  late final Set<String> _protectedIds;

  @override
  void initState() {
    super.initState();
    _candidate = widget.initial;
    // Endpoints + marked stops are never removable (AC-2/AC-4/AC-5).
    _protectedIds = <String>{
      widget.start.id,
      widget.end.id,
      for (final stop in widget.markedStops) stop.id,
    };
  }

  void _removeStop(Province province) {
    setState(() {
      _removedStopIds.add(province.id);
      _reresolve();
    });
  }

  void _restoreStop(Province province) {
    setState(() {
      _removedStopIds.remove(province.id);
      _reresolve();
    });
  }

  /// Re-resolves the candidate via the pure planner with the current removals
  /// (NFR-1: a small in-memory recompute, never disk/network).
  void _reresolve() {
    _candidate = RoutePlanner.resolve(
      fullChain: widget.chain,
      fullGeography: widget.geography,
      start: widget.start,
      end: widget.end,
      markedStops: widget.markedStops,
      removedStops: _removedStopIds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ordered = _candidate.orderedNodes;
    final totalKm = _candidate.subPathKm;
    // Stops that have been removed (offered back so a removal is reversible).
    final removed = <Province>[
      for (final node in widget.chain.nodes)
        if (_removedStopIds.contains(node.id)) node,
    ];
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
              '${totalKm.round()} km · ${ordered.first.name} → '
              '${ordered.last.name}',
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
                  for (final province in ordered)
                    _OrderedStopRow(
                      province: province,
                      removable: !_protectedIds.contains(province.id),
                      onRemove: () => _removeStop(province),
                    ),
                  if (removed.isNotEmpty) ...<Widget>[
                    const Divider(),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Skipped (tap to add back)',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    for (final province in removed)
                      _RemovedStopRow(
                        province: province,
                        onRestore: () => _restoreStop(province),
                      ),
                  ],
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
                  // The ONLY mutation — hands the CURRENT candidate to the host
                  // (AC-6/AC-7).
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

/// One row in the ordered route — the province name + a remove control when it
/// is an auto-inserted (non-protected) intermediate (AC-5).
class _OrderedStopRow extends StatelessWidget {
  const _OrderedStopRow({
    required this.province,
    required this.removable,
    required this.onRemove,
  });

  final Province province;
  final bool removable;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      key: Key('route_review_stop_${province.id}'),
      leading: const Icon(Icons.place_outlined, size: 18),
      title: Text(province.name),
      trailing: removable
          ? IconButton(
              key: Key('route_review_remove_${province.id}'),
              tooltip: 'Skip ${province.name}',
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: onRemove,
            )
          : Semantics(
              label: 'Endpoint — kept',
              child: const Icon(Icons.lock_outline, size: 18),
            ),
    );
  }
}

/// A removed (skipped) intermediate, offered back so a removal is reversible.
class _RemovedStopRow extends StatelessWidget {
  const _RemovedStopRow({required this.province, required this.onRestore});

  final Province province;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      key: Key('route_review_removed_${province.id}'),
      leading: const Icon(Icons.add_circle_outline, size: 18),
      title: Text(
        province.name,
        style: const TextStyle(decoration: TextDecoration.lineThrough),
      ),
      onTap: onRestore,
    );
  }
}
