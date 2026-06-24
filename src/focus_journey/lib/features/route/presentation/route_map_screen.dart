/// Presentation layer. The custom-painted map screen: the route polyline +
/// pins + current-position marker, a "next: `<province>` in N km" / "% of
/// country" readout, the start picker (when no route is active), and completion
/// celebration + summary (when the route is done).
///
/// SEPARATION INVARIANT (AC-16/AC-17/TC-016/TC-017): reads ONLY the
/// [RouteProgressCubit]'s state (which is derived purely from the engine's
/// cumulative `distanceKm` scalar). Imports NO `ActivityPlugin`, NO
/// `MethodChannel`, NO OS/idle/lock/sleep API, and never mutates engine state.
///
/// PRIVACY (AC-18 / TC-NF3): the map is entirely custom-painted — NO network, NO
/// tile provider, NO external map service.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/province_chain.dart';
import '../domain/route_position.dart';
import '../domain/route_selection.dart';
import 'route_map_painter.dart';
import 'route_progress_cubit.dart';
import 'route_view_state.dart';
import 'start_picker.dart';

/// The map/overview screen for the route. Reachable from the journey screen.
class RouteMapScreen extends StatelessWidget {
  /// Creates the map screen over the injected [chain] (for the picker geometry).
  const RouteMapScreen({required this.chain, super.key});

  /// The province chain — supplies the picker options and pin order.
  final ProvinceChain chain;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your journey across Vietnam')),
      body: BlocBuilder<RouteProgressCubit, RouteViewState>(
        // Rebuild only on changes the map actually renders — the selection, the
        // resolved position, or completion. A bare `cumulativeDistanceKm` tick
        // (emitted ~1 Hz, e.g. while a completed route is frozen or the marker
        // sits still) is NOT rendered, so it must not rebuild the subtree or
        // reallocate the static geometry (smooth-paint NFR / TC-NF2).
        buildWhen: (prev, next) =>
            prev.hasRoute != next.hasRoute ||
            prev.selection != next.selection ||
            prev.position != next.position,
        builder: (context, state) {
          if (!state.hasRoute) {
            return SingleChildScrollView(
              child: StartPicker(
                chain: chain,
                onConfirm: (start, direction) => context
                    .read<RouteProgressCubit>()
                    .startNewRoute(start, direction),
              ),
            );
          }
          final selection = state.selection!;
          final position = state.position!;
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _RouteMap(chain: chain, selection: selection, position: position),
              _RouteReadout(position: position),
              if (state.isCompleted)
                _CompletionCelebration(
                  position: position,
                  onStartNew: () => _openPicker(context),
                ),
            ],
          );
        },
      ),
    );
  }

  void _openPicker(BuildContext context) {
    final cubit = context.read<RouteProgressCubit>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SingleChildScrollView(
          child: StartPicker(
            chain: chain,
            onConfirm: (start, direction) {
              cubit.startNewRoute(start, direction);
              Navigator.of(dialogContext).pop();
            },
          ),
        ),
      ),
    );
  }
}

/// The custom-painted map. Builds the (static) geometry once per layout size and
/// repaints only when the position changes (smooth-paint NFR / TC-NF2).
class _RouteMap extends StatelessWidget {
  const _RouteMap({
    required this.chain,
    required this.selection,
    required this.position,
  });

  final ProvinceChain chain;
  final RouteSelection selection;
  final RoutePosition position;

  @override
  Widget build(BuildContext context) {
    final ordered = orderedProvincesFor(
      selection,
      chain.checkpointsAhead(selection.start, selection.direction),
    );
    // Per-pin cumulative-distance fractions (km from start ÷ route length),
    // so pins are laid out proportionally to real distance (unequal segments).
    final fractions = cumulativeFractionsFor(chain, selection, ordered);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        // Geometry is value-equal on (size, orderedProvinces, fractions), so even
        // though a fresh instance is built here, the painter's `shouldRepaint`
        // geometry clause is false across a position-only change — no per-frame
        // static-geometry repaint (TC-NF2). LayoutBuilder fires only on resize.
        final geometry = RouteMapGeometry(
          size: size,
          orderedProvinces: ordered,
          cumulativeFractions: fractions,
        );
        return CustomPaint(
          size: size,
          painter: RouteMapPainter(geometry: geometry, position: position),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

/// The "next: `<province>` in N km" / "% of country" readout overlay.
class _RouteReadout extends StatelessWidget {
  const _RouteReadout({required this.position});

  final RoutePosition position;

  @override
  Widget build(BuildContext context) {
    final percent = position.percentOfCountry.toStringAsFixed(1);
    final nextText = position.next == null
        ? 'Arrived at ${position.destination.name}'
        : 'Next: ${position.next!.name} in '
              '${position.distanceToNextKm.toStringAsFixed(0)} km';
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(
                  label: nextText,
                  child: Text(
                    nextText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Semantics(
                  label: '$percent percent of the country covered',
                  child: Text(
                    '$percent% of Vietnam',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The completion celebration + summary: provinces crossed + total route
/// distance, retains progress, and offers an EXPLICIT "start a new journey"
/// action — no auto-advance (AC-13).
class _CompletionCelebration extends StatelessWidget {
  const _CompletionCelebration({
    required this.position,
    required this.onStartNew,
  });

  final RoutePosition position;
  final VoidCallback onStartNew;

  @override
  Widget build(BuildContext context) {
    final crossed = position.passed.map((p) => p.name).join(' → ');
    final total = position.distanceToDestinationKm.toStringAsFixed(0);
    // Honest % — matches the readout overlay's formatting. A tip-to-tip route
    // proudly shows 100; a mid-chain route shows its true arrival % (< 100),
    // never a hardcoded 100 that would contradict the readout (AC-11).
    final percent = position.percentOfCountry.toStringAsFixed(1);
    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                'You reached ${position.destination.name}!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$total km · $percent% of Vietnam',
              style: const TextStyle(color: Colors.amberAccent, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Provinces crossed:\n$crossed',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('completion_start_new'),
              onPressed: onStartNew,
              child: const Text('Start a new journey'),
            ),
          ],
        ),
      ),
    );
  }
}
