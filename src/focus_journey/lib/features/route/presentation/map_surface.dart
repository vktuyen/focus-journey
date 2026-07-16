/// Presentation layer. The map surface that folds into the journey tab
/// (map-experience #4): an INLINE overlay on the journey tab that opens
/// FULL-SCREEN in the SAME window on tap (AC-1/AC-2/AC-3, per ADR-0003
/// single-window two-mode — a Material `Navigator.push`, never a new OS window).
///
/// It also RE-HOMES the start-picker + completion-celebration that previously
/// lived in `RouteMapScreen` (the removed standalone Map tab — AC-1): when no
/// route is active it shows the picker; when the route is completed it shows the
/// celebration over the full-screen map. Re-homing preserves those flows rather
/// than deleting the behaviour.
///
/// SEPARATION INVARIANT (AC-12): consumes ONLY the [MapCubit]'s [MapViewState]
/// and the [RouteProgressCubit] for the picker/celebration actions (which are
/// derived purely from the engine's aggregate scalar). No `ActivityPlugin`, no
/// `MethodChannel`, no geolocation/GPS, no engine mutation.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../journey/domain/travel_mode.dart';
import '../../journey/presentation/journey_gate_cubit.dart';
import '../../stats/domain/app_settings.dart';
import '../../stats/presentation/settings_cubit.dart';
import '../../stats/presentation/vehicle_picker.dart';
import '../domain/base_map_geometry.dart';
import '../domain/province_chain.dart';
import '../domain/province_geography.dart';
import '../domain/road_path.dart';
import '../domain/route_planner.dart';
import '../domain/route_position.dart';
import 'map_cubit.dart';
import 'map_view.dart';
import 'map_view_state.dart';
import 'route_planner_flow.dart';
import 'route_progress_cubit.dart';

/// The inline map overlay on the journey tab (AC-1). Tapping it opens the
/// full-screen map in the same window (AC-2).
class InlineMapOverlay extends StatelessWidget {
  /// Creates the inline overlay over the injected [chain] / [geography] (picker
  /// geometry + auto-insert). [baseMap] is the bundled Vietnam base geometry
  /// forwarded to [MapView] (AC-1/AC-2).
  const InlineMapOverlay({
    required this.chain,
    required this.geography,
    this.baseMap,
    this.road,
    super.key,
  });

  /// The province chain — supplies the picker options.
  final ProvinceChain chain;

  /// The static geography — drives the pure auto-insert (NFR-2).
  final ProvinceGeography geography;

  /// The bundled base-map geometry drawn beneath the overlays (AC-1/AC-2).
  final BaseMapGeometry? baseMap;

  /// The bundled national road (route-real-road), threaded to the planner flow's
  /// review step so its distance readout reflects the REAL road length. `null`
  /// (tests / degraded mode) falls back to the sub-chain km.
  final RoadPath? road;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MapCubit, MapViewState>(
      // No buildWhen needed: MapViewState is value-equatable, so BlocBuilder's
      // default already skips a rebuild on a bare distance tick that left the
      // projected state value-equal (NFR-1 / TC-229).
      builder: (context, state) {
        if (!state.hasRoute) {
          // No active route: the route-planner-v2 picker → review flow (#8/#9).
          return _InlinePlannerCard(
            chain: chain,
            geography: geography,
            road: road,
            onConfirmed: (resolved) =>
                context.read<RouteProgressCubit>().confirmRoute(resolved),
          );
        }
        // A compact, MOBA-style minimap floating as a HUD card. The whole card
        // is one tap target that opens the full-screen map (AC-2). It renders
        // the bundled offline Vietnam base (decimated for the small size — NFR-1)
        // with the base road, checkpoint pins, current-position marker, and the
        // red idle trace on top (AC-2/AC-8). No network of any kind (AC-10).
        return _MinimapCard(
          onTap: () => openFullScreenMap(
            context,
            chain: chain,
            geography: geography,
            baseMap: baseMap,
            road: road,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // Absorb map gestures so the minimap is a single tap target
              // (the full-screen surface is interactive instead).
              IgnorePointer(
                child: MapView(state: state, baseMap: baseMap, compact: true),
              ),
              const _ExpandHint(),
            ],
          ),
        );
      },
    );
  }
}

/// Opens the full-screen map within the SAME window via a Material route (AC-2 /
/// ADR-0003 — no new OS window). The cubits are provided from the calling
/// context so the full-screen surface shares the SAME [MapCubit] /
/// [RouteProgressCubit] instances (one source of truth).
Future<void> openFullScreenMap(
  BuildContext context, {
  required ProvinceChain chain,
  required ProvinceGeography geography,
  BaseMapGeometry? baseMap,
  RoadPath? road,
}) {
  final mapCubit = context.read<MapCubit>();
  final routeCubit = context.read<RouteProgressCubit>();
  // vehicle-picker AC-13: the pushed route may not inherit the root
  // SettingsCubit provider, so re-provide the SAME instance into the full-screen
  // map subtree (the route-start picker reads/writes it — AC-11 single source).
  // Defensive: only when a SettingsCubit is actually mounted — a route-only host
  // (e.g. map widget tests) has none, and the route-start picker is skippable
  // (AC-13), so the flow degrades gracefully instead of crashing.
  SettingsCubit? settingsCubit;
  try {
    settingsCubit = context.read<SettingsCubit>();
  } on ProviderNotFoundException {
    settingsCubit = null;
  }
  // route-real-road: re-provide the SAME journey gate into the pushed subtree so
  // the full-screen re-authoring (new-route / abandon) flow can pause the active
  // route during setup and resume it on close. Defensive — a route-only host
  // (map widget tests) has none, and the pause/resume then simply no-ops.
  JourneyGateCubit? gateCubit;
  try {
    gateCubit = context.read<JourneyGateCubit>();
  } on ProviderNotFoundException {
    gateCubit = null;
  }
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<MapCubit>.value(value: mapCubit),
          BlocProvider<RouteProgressCubit>.value(value: routeCubit),
          if (settingsCubit != null)
            BlocProvider<SettingsCubit>.value(value: settingsCubit),
          if (gateCubit != null)
            BlocProvider<JourneyGateCubit>.value(value: gateCubit),
        ],
        child: FullScreenMap(
          chain: chain,
          geography: geography,
          baseMap: baseMap,
          road: road,
        ),
      ),
    ),
  );
}

/// The full-screen map surface (AC-2/AC-3). Dismissable via a close button,
/// system back, OR the Esc key — all returning to the inline overlay (TC-223).
class FullScreenMap extends StatelessWidget {
  /// Creates the full-screen map over [chain] / [geography] (for the planner
  /// flow + auto-insert).
  const FullScreenMap({
    required this.chain,
    required this.geography,
    this.baseMap,
    this.road,
    super.key,
  });

  /// The province chain — supplies the planner flow.
  final ProvinceChain chain;

  /// The static geography — drives the pure auto-insert (NFR-2).
  final ProvinceGeography geography;

  /// The bundled base-map geometry drawn beneath the overlays (AC-1).
  final BaseMapGeometry? baseMap;

  /// The bundled national road (route-real-road), threaded to the planner flow's
  /// review step. `null` (tests / degraded mode) falls back to the sub-chain km.
  final RoadPath? road;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        // Esc dismisses (keyboard-reachable — NFR-3 / TC-223/TC-232).
        SingleActivator(LogicalKeyboardKey.escape): const DismissIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              Navigator.of(context).maybePop();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: BlocBuilder<MapCubit, MapViewState>(
              // MapViewState is value-equatable; BlocBuilder's default rebuild
              // gate already covers NFR-1 (no rebuild on a value-equal tick).
              builder: (context, state) {
                if (!state.hasRoute) {
                  return _FullScreenScaffold(
                    onClose: () => Navigator.of(context).maybePop(),
                    child: SingleChildScrollView(
                      child: RoutePlannerFlow(
                        chain: chain,
                        geography: geography,
                        road: road,
                        onConfirmed: (resolved) => context
                            .read<RouteProgressCubit>()
                            .confirmRoute(resolved),
                        onCancelled: () => Navigator.of(context).maybePop(),
                        // vehicle-picker AC-13: skippable, pre-seeded route-start
                        // vehicle control — present only when a SettingsCubit is
                        // mounted (else omitted, degrading gracefully).
                        vehiclePicker: RouteStartVehiclePicker.maybeFor(
                          context,
                        ),
                      ),
                    ),
                  );
                }
                return Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    MapView(state: state, baseMap: baseMap),
                    // Top-left route readout (re-homed from the old Map tab —
                    // reads ONLY state.position + countryPercent; pure visualizer,
                    // AC-8/AC-12).
                    if (state.position != null)
                      _RouteReadout(
                        position: state.position!,
                        countryPercent: state.countryPercent,
                        roadLengthKm: state.routeRoadLengthKm,
                      ),
                    // Bottom-left legend (symbol key + the AC-9 solid/dashed
                    // non-colour cue — doubles as the NFR-3 colour-blind aid).
                    const _MapLegend(),
                    // Top-right "new route" affordance (#10 abandon-and-restart):
                    // shows the AC-9 confirm guard when there is progress to lose,
                    // then opens the planner flow on confirm.
                    if (!state.isCompleted)
                      _NewRouteButton(
                        onPressed: () => _startNewRoute(context, abandon: true),
                      ),
                    if (state.isCompleted)
                      _CompletionCelebration(
                        position: state.position!,
                        countryPercent: state.countryPercent,
                        roadLengthKm: state.routeRoadLengthKm,
                        // Completion is NOT an abandon (no progress-loss guard —
                        // the route already finished, AC-10).
                        onStartNew: () =>
                            _startNewRoute(context, abandon: false),
                      ),
                    _CloseButton(
                      onClose: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Starts a new route via the planner flow (#8/#9/#10). When [abandon] is true,
  /// shows the AC-9 confirm guard first (only when there is progress to lose) and
  /// routes the confirm through `abandonAndStartNew` (new offset, prior plan
  /// abandoned, engine never reset — AC-10). When false (e.g. after completion),
  /// it is a fresh start with no guard. Cancelling the guard leaves everything
  /// untouched (AC-9).
  Future<void> _startNewRoute(
    BuildContext context, {
    required bool abandon,
  }) async {
    final cubit = context.read<RouteProgressCubit>();
    // route-real-road: pause the active route while the user re-authors so it
    // does not accrue during setup; resume on close (cancel keeps the old route,
    // confirm starts the new one via onRouteStarted). Captured before the awaits.
    JourneyGateCubit? gate;
    try {
      gate = context.read<JourneyGateCubit>();
    } on ProviderNotFoundException {
      gate = null;
    }
    if (abandon) {
      final proceed = await confirmAbandon(
        context,
        hasProgressToLose: cubit.hasProgressToLose,
      );
      if (!proceed) {
        return; // AC-9: cancel is fully inert.
      }
    }
    if (!context.mounted) {
      return;
    }
    // vehicle-picker AC-13: the dialog mounts on the root navigator, which does
    // not inherit the SettingsCubit provider, so re-provide the SAME cubit
    // instance into the dialog subtree (AC-11 single source — no second store).
    final settingsCubit = context.read<SettingsCubit>();
    gate?.beginAuthoring();
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => BlocProvider<SettingsCubit>.value(
          value: settingsCubit,
          child: Dialog(
            child: SingleChildScrollView(
              child: RoutePlannerFlow(
                chain: chain,
                geography: geography,
                road: road,
                onConfirmed: (resolved) {
                  if (abandon) {
                    cubit.abandonAndStartNew(resolved);
                  } else {
                    cubit.confirmRoute(resolved);
                  }
                  Navigator.of(dialogContext).pop();
                },
                onCancelled: () => Navigator.of(dialogContext).pop(),
                vehiclePicker: RouteStartVehiclePicker.maybeFor(dialogContext),
              ),
            ),
          ),
        ),
      );
    } finally {
      // Always resume the (still-active on cancel, or newly-confirmed) route,
      // even if building/showing the authoring dialog threw — otherwise the gate
      // would be stuck paused with no manual control to recover. Idempotent with
      // the confirm's onRouteStarted, and a no-op if the gate was torn down.
      gate?.endAuthoring();
    }
  }
}

/// A top-right "new route" affordance (#10): opens the planner flow, guarded by
/// the AC-9 abandon confirm when there is progress to lose. Keyboard-reachable +
/// screen-reader labelled (NFR-3).
class _NewRouteButton extends StatelessWidget {
  const _NewRouteButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        // Top-right but inset left of the close button so they do not overlap.
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 12, right: 64),
          child: Material(
            color: Colors.black.withValues(alpha: 0.6),
            shape: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextButton.icon(
                key: const Key('map_new_route'),
                onPressed: onPressed,
                icon: const Icon(
                  Icons.alt_route,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text(
                  'New route',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A scaffold with a close affordance for the picker variant of the full-screen.
class _FullScreenScaffold extends StatelessWidget {
  const _FullScreenScaffold({required this.child, required this.onClose});

  final Widget child;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(child: child),
        _CloseButton(onClose: onClose),
      ],
    );
  }
}

/// The full-screen dismiss affordance (close button — AC-3). Keyboard-reachable
/// + screen-reader labelled (NFR-3 / TC-232).
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Material(
            color: Colors.black.withValues(alpha: 0.6),
            shape: const CircleBorder(),
            child: IconButton(
              key: const Key('map_full_screen_close'),
              tooltip: 'Close full-screen map',
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: onClose,
            ),
          ),
        ),
      ),
    );
  }
}

/// The top-left route readout (re-homed from the removed standalone Map tab).
/// A compact, translucent dark card reading ONLY [RoutePosition] (no engine,
/// no plugin, no device location — pure visualizer, AC-12 / NFR-2). Lines:
///   1. `Next: {next.name} in {distanceToNextKm} km` — or `Arrived at
///      {destination.name}` once `next == null` (completed; AC-10).
///   2. `{distanceToDestinationKm} km to {destination.name}`.
///   3. `{percentOfCountry}% of Vietnam`.
/// Each line is wrapped in [Semantics] for screen-reader recovery (NFR-3).
class _RouteReadout extends StatelessWidget {
  const _RouteReadout({
    required this.position,
    this.countryPercent,
    this.roadLengthKm,
  });

  final RoutePosition position;

  /// route-planner-v2 (ADR-0005 decision 3 / AC-8): the full-chain % computed by
  /// the cubit, shown alongside the resolver's route %. `null` on the legacy
  /// full-chain path (where `percentOfCountry` already IS the country %).
  final double? countryPercent;

  /// route-real-road (#4): the DRAWN ROAD sub-path length (km). When present, the
  /// "km to end" readout reflects the real road (remaining road km), so the
  /// number matches what is drawn — not the chain-centre distance. `null` on the
  /// legacy/no-road path (then the chain distance-to-destination is shown).
  final double? roadLengthKm;

  @override
  Widget build(BuildContext context) {
    final next = position.next;
    final destinationName = position.destination.name;
    final line1 = next == null
        ? 'Arrived at $destinationName'
        : 'Next: ${next.name} in ${position.distanceToNextKm.round()} km';
    final roadRemainingKm = roadLengthKm == null
        ? position.distanceToDestinationKm
        : roadLengthKm! * (1 - position.fractionAlongRoute);
    final line2 = '${roadRemainingKm.round()} km to $destinationName';
    // AC-8: show BOTH percentages — route % (resolver, over the sub-chain) and
    // country % (cubit, over the full chain). On the legacy path countryPercent
    // is null and percentOfCountry already IS the country %, so show just it.
    final line3 = countryPercent == null
        ? '${position.percentOfCountry.toStringAsFixed(1)}% of Vietnam'
        : '${position.percentOfCountry.toStringAsFixed(1)}% of route · '
              '${countryPercent!.toStringAsFixed(1)}% of Vietnam';
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Container(
              key: const Key('map_route_readout'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Semantics(
                    label: line1,
                    child: Text(
                      line1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Semantics(
                    label: line2,
                    child: Text(
                      line2,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Semantics(
                    label: line3,
                    child: Text(
                      line3,
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The bottom-left legend: a small translucent card explaining the map symbols
/// — current position (orange dot), checkpoint/stop (teal dot), the route line,
/// and the idle trace, where RED SOLID = voluntary idle and RED DASHED =
/// lock/sleep idle (AC-9's non-colour cue, restated in words). The pattern +
/// the text convey the cause WITHOUT relying on colour alone — the NFR-3
/// colour-blind aid. Anchored bottom-left so it clears the CC BY-SA base-map
/// attribution (bottom-right) and the close button (top-right).
class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            key: const Key('map_legend'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const <Widget>[
                Text(
                  'Legend',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                _LegendRow(
                  swatch: _DotSwatch(color: Color(0xFFE65100)),
                  text: 'Current position',
                ),
                _LegendRow(
                  swatch: _DotSwatch(color: Color(0xFF26A69A)),
                  text: 'Checkpoint / stop',
                ),
                _LegendRow(
                  swatch: _LineSwatch(color: kBaseRoadColor, dashed: false),
                  text: 'Route',
                ),
                _LegendRow(
                  swatch: _LineSwatch(color: kIdleRed, dashed: false),
                  text: 'Idle — voluntary pause (solid)',
                ),
                _LegendRow(
                  swatch: _LineSwatch(color: kIdleRed, dashed: true),
                  text: 'Idle — lock / sleep (dashed)',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One legend entry: a symbol swatch + its meaning.
class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.swatch, required this.text});

  final Widget swatch;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(width: 22, child: Center(child: swatch)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// A small filled dot swatch (current position / checkpoint).
class _DotSwatch extends StatelessWidget {
  const _DotSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }
}

/// A short line swatch — solid or dashed — mirroring the map's stroke patterns
/// so the legend's solid-vs-dashed cue matches the rendered idle trace (AC-9).
class _LineSwatch extends StatelessWidget {
  const _LineSwatch({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 6,
      child: CustomPaint(
        painter: _LineSwatchPainter(color: color, dashed: dashed),
      ),
    );
  }
}

class _LineSwatchPainter extends CustomPainter {
  _LineSwatchPainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    const dash = 4.0;
    const gap = 3.0;
    var x = 0.0;
    while (x < size.width) {
      final end = (x + dash).clamp(0.0, size.width);
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_LineSwatchPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dashed != dashed;
}

/// The compact minimap card dimensions (MOBA-style HUD): portrait so Vietnam's
/// tall S-shape fits. Roughly 150 × 190, with a 16px inset from the corner.
const double kMinimapWidth = 150;
const double kMinimapHeight = 190;
const double kMinimapMargin = 16;

/// A floating, MOBA-style minimap card anchored bottom-right of the journey
/// tab. Compact (≈150×190), rounded, bordered, with a drop shadow so it reads
/// as a HUD element over the full-bleed scene. The whole card is one tap
/// target (opens the full-screen map — AC-2) and stays keyboard-reachable +
/// screen-reader labelled (NFR-3 / TC-232).
class _MinimapCard extends StatelessWidget {
  const _MinimapCard({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        // Centre-right edge (Kevin's preference): clear of the distance counter
        // (top-right), PiP button (bottom-left) and reduce-motion indicator
        // (top-left); vertically centred down the right side.
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.all(kMinimapMargin),
          child: Semantics(
            button: true,
            label:
                'Minimap of your journey across Vietnam. Activate to open '
                'full-screen.',
            child: Material(
              color: kCompactMapBackground,
              elevation: 6,
              shadowColor: Colors.black54,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                // Keyboard-reachable + labelled via the wrapping Semantics.
                onTap: onTap,
                child: Container(
                  width: kMinimapWidth,
                  height: kMinimapHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.85),
                      width: 2,
                    ),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small expand affordance in the minimap's corner. The wide "Tap to expand"
/// text won't fit at ~150px, so a compact fullscreen icon stands in; the
/// screen-reader label lives on the card's [Semantics] (NFR-3 / TC-232).
class _ExpandHint extends StatelessWidget {
  const _ExpandHint();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.open_in_full, color: Colors.white, size: 16),
        ),
      ),
    );
  }
}

/// The inline route-planner card (shown inline when no route is active). Hosts
/// the route-planner-v2 picker → review flow (#8/#9). Confirm is the only
/// mutation (AC-6); cancel from the picker simply re-shows the picker.
///
/// The journey tab is a full-bleed scene with the overlay riding on top in a
/// `Stack`, so the route-less planner anchors itself as a centred, width-
/// constrained card — it floats over the scene the way the minimap does once a
/// route exists.
class _InlinePlannerCard extends StatelessWidget {
  const _InlinePlannerCard({
    required this.chain,
    required this.geography,
    required this.onConfirmed,
    this.road,
  });

  final ProvinceChain chain;
  final ProvinceGeography geography;
  final RoadPath? road;
  final void Function(ResolvedRoute resolved) onConfirmed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            margin: const EdgeInsets.all(24),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              child: RoutePlannerFlow(
                chain: chain,
                geography: geography,
                road: road,
                onConfirmed: onConfirmed,
                // Inline (no route yet): cancelling the picker is inert — the
                // planner re-shows the picker on its own back action; here the
                // top-level cancel simply has nothing to pop, so it is a no-op.
                onCancelled: () {},
                // vehicle-picker AC-13: skippable, pre-seeded route-start
                // vehicle control — present only when a SettingsCubit is mounted
                // (else omitted, degrading gracefully).
                vehiclePicker: RouteStartVehiclePicker.maybeFor(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// vehicle-picker AC-12/AC-13: the SKIPPABLE, pre-seeded route-start vehicle
/// control surfaced on the `RoutePlannerFlow` review step. It reads + writes the
/// SINGLE `SettingsCubit` preference (AC-11), pre-seeding from the saved value
/// (falling back to the engine display default `motorbike` when "no preference"
/// — AC-12) and writing back via `SettingsCubit.setVehicle` (AC-13). Cosmetic-
/// only (ADR-0007): the route engine/resolver never sees the vehicle.
class RouteStartVehiclePicker extends StatelessWidget {
  /// Creates the route-start vehicle control.
  const RouteStartVehiclePicker({super.key});

  /// Returns the route-start picker ONLY when a [SettingsCubit] is present in
  /// [context]'s tree (so there is somewhere to persist the pick — AC-11 single
  /// source), else `null`. The route-start picker is SKIPPABLE per AC-13, so
  /// omitting it where no settings store is mounted is spec-consistent — and it
  /// mirrors the journey seam's defensive `ProviderNotFoundException` handling,
  /// so a host that mounts the map/route flow without a `SettingsCubit` (e.g.
  /// route-only widget tests) degrades gracefully instead of crashing.
  static Widget? maybeFor(BuildContext context) {
    try {
      context.read<SettingsCubit>();
    } on ProviderNotFoundException {
      return null;
    }
    return const RouteStartVehiclePicker();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, AppSettings>(
      builder: (BuildContext context, AppSettings settings) {
        return VehiclePicker(
          key: const Key('route-start-vehicle-picker'),
          selected: settings.vehiclePreference ?? TravelMode.motorbike,
          onSelected: context.read<SettingsCubit>().setVehicle,
        );
      },
    );
  }
}

/// The completion celebration + summary (re-homed from `RouteMapScreen`):
/// provinces crossed + total route distance, with an explicit "start a new
/// journey" action — no auto-advance. The overlay does NOT block completion
/// (AC-10).
class _CompletionCelebration extends StatelessWidget {
  const _CompletionCelebration({
    required this.position,
    required this.onStartNew,
    this.countryPercent,
    this.roadLengthKm,
  });

  final RoutePosition position;
  final VoidCallback onStartNew;

  /// route-planner-v2 (AC-8): the full-chain % shown alongside the route %.
  final double? countryPercent;

  /// route-real-road (#4): the drawn road sub-path length (km) — the total shown
  /// on arrival reflects the real road, not the chain-centre distance.
  final double? roadLengthKm;

  @override
  Widget build(BuildContext context) {
    final crossed = position.passed.map((p) => p.name).join(' → ');
    final total = (roadLengthKm ?? position.distanceToDestinationKm)
        .toStringAsFixed(0);
    final percent = countryPercent == null
        ? '${position.percentOfCountry.toStringAsFixed(1)}% of Vietnam'
        : '${position.percentOfCountry.toStringAsFixed(1)}% of route · '
              '${countryPercent!.toStringAsFixed(1)}% of Vietnam';
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
              '$total km · $percent',
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
