/// Presentation layer. The route-planner-v2 endpoint + stop picker (#8/#9).
///
/// Lets the user pick **any one start checkpoint + any one end checkpoint** on
/// the spine (start == end disabled — AC-2) plus optional **stops** to mark
/// (AC-3/AC-4), then resolves the route via the pure [RoutePlanner] and hands the
/// [ResolvedRoute] to [onResolved] (the host shows the review-before-start screen
/// — AC-5). Direction is implied by which endpoint is the start (AC-1).
///
/// PRIVACY (NFR-2): reads NO OS signal, NO device location — it only lets the
/// user pick from the static [ProvinceChain] and resolves over the static
/// [ProvinceGeography]. No network, no platform channel.
///
/// ACCESSIBILITY (NFR-3): the start/end dropdowns, each stop checkbox, and the
/// continue button are keyboard-reachable and screen-reader labelled.
library;

import 'package:flutter/material.dart';

import '../domain/province.dart';
import '../domain/province_chain.dart';
import '../domain/province_geography.dart';
import '../domain/route_planner.dart';

/// A picker for a route's start + end endpoints + optional marked stops.
///
/// Resolves the route on "Continue" and calls [onResolved] with the resulting
/// [ResolvedRoute] (zero side effect — building/cancelling stamps nothing; the
/// host's review screen confirms before any mutation — AC-6).
class RoutePicker extends StatefulWidget {
  /// Creates the picker over [chain] / [geography]. [onResolved] fires with the
  /// resolved route when the user continues to review.
  const RoutePicker({
    required this.chain,
    required this.geography,
    required this.onResolved,
    this.onCancel,
    super.key,
  });

  /// The full spine the user picks endpoints/stops from.
  final ProvinceChain chain;

  /// The static geography the route is resolved over (NFR-2).
  final ProvinceGeography geography;

  /// Called with the resolved route AND the user's marked stops when the user
  /// continues to the review step. The marked stops are forwarded so the review
  /// screen can protect them from removal (AC-4 — a marked stop must stay in the
  /// route).
  final void Function(ResolvedRoute resolved, List<Province> markedStops)
  onResolved;

  /// Optional cancel callback (returns to the host without resolving anything).
  final VoidCallback? onCancel;

  @override
  State<RoutePicker> createState() => _RoutePickerState();
}

class _RoutePickerState extends State<RoutePicker> {
  late Province _start;
  late Province _end;
  final Set<String> _markedStopIds = <String>{};

  @override
  void initState() {
    super.initState();
    final nodes = widget.chain.nodes;
    _start = nodes.first;
    // Default the end to a DIFFERENT checkpoint so the picker opens valid (AC-2).
    _end = nodes.last;
  }

  /// The chain nodes available as END options for the current start: every node
  /// except the chosen start (start == end disabled — AC-2).
  bool _endEnabled(Province candidate) => candidate.id != _start.id;

  void _onStartChanged(Province? province) {
    if (province == null) return;
    setState(() {
      _start = province;
      // Keep end valid: if start now equals end, move end to a neighbour (AC-2).
      if (_end.id == _start.id) {
        _end = widget.chain.nodes.firstWhere(
          (p) => p.id != _start.id,
          orElse: () => widget.chain.nodes.last,
        );
      }
      // A marked stop equal to an endpoint is redundant; drop it to keep the
      // marked set strictly the "extra cities" the user cares about.
      _markedStopIds.removeWhere((id) => id == _start.id || id == _end.id);
    });
  }

  void _onEndChanged(Province? province) {
    if (province == null || province.id == _start.id) return;
    setState(() {
      _end = province;
      _markedStopIds.removeWhere((id) => id == _start.id || id == _end.id);
    });
  }

  void _toggleStop(Province province, bool? selected) {
    setState(() {
      if (selected ?? false) {
        _markedStopIds.add(province.id);
      } else {
        _markedStopIds.remove(province.id);
      }
    });
  }

  void _continue() {
    final marked = <Province>[
      for (final node in widget.chain.nodes)
        if (_markedStopIds.contains(node.id)) node,
    ];
    // Pure, deterministic resolve over static geography only (NFR-2 / AC-3/AC-4).
    final resolved = RoutePlanner.resolve(
      fullChain: widget.chain,
      fullGeography: widget.geography,
      start: _start,
      end: _end,
      markedStops: marked,
    );
    // Forward the marked stops so the review screen protects them (AC-4).
    widget.onResolved(resolved, marked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Stops the user can mark = every node that is not the current start/end.
    final stopCandidates = <Province>[
      for (final node in widget.chain.nodes)
        if (node.id != _start.id && node.id != _end.id) node,
    ];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text('Plan your route', style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: 12),
          Text('From', style: theme.textTheme.titleMedium),
          Semantics(
            label: 'Start checkpoint',
            child: DropdownButton<Province>(
              key: const Key('route_picker_start_dropdown'),
              value: _start,
              isExpanded: true,
              items: <DropdownMenuItem<Province>>[
                for (final province in widget.chain.nodes)
                  DropdownMenuItem<Province>(
                    value: province,
                    child: Text(province.name),
                  ),
              ],
              onChanged: _onStartChanged,
            ),
          ),
          const SizedBox(height: 12),
          Text('To', style: theme.textTheme.titleMedium),
          Semantics(
            label: 'End checkpoint',
            child: DropdownButton<Province>(
              key: const Key('route_picker_end_dropdown'),
              value: _end,
              isExpanded: true,
              items: <DropdownMenuItem<Province>>[
                for (final province in widget.chain.nodes)
                  DropdownMenuItem<Province>(
                    value: province,
                    // The same checkpoint as the start is disabled (AC-2).
                    enabled: _endEnabled(province),
                    child: Text(
                      _endEnabled(province)
                          ? province.name
                          : '${province.name} — same as start',
                    ),
                  ),
              ],
              onChanged: _onEndChanged,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Optional stops along the way',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Mark cities you care about. We fill in the checkpoints between your '
            'endpoints automatically; a stop outside that span extends the route '
            'to include it.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          // Bounded height so the stop list scrolls inside a dialog/card.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final province in stopCandidates)
                    CheckboxListTile(
                      key: Key('route_picker_stop_${province.id}'),
                      dense: true,
                      title: Text(province.name),
                      value: _markedStopIds.contains(province.id),
                      onChanged: (selected) => _toggleStop(province, selected),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              if (widget.onCancel != null)
                Expanded(
                  child: OutlinedButton(
                    key: const Key('route_picker_cancel'),
                    onPressed: widget.onCancel,
                    child: const Text('Cancel'),
                  ),
                ),
              if (widget.onCancel != null) const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('route_picker_continue'),
                  onPressed: _continue,
                  child: const Text('Review route'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
