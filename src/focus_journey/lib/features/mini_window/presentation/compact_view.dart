/// Presentation layer. The compact Picture-in-Picture (PiP) view: a sized-down
/// instance of the SHARED journey Flame scene plus a tiny distance + active/idle
/// readout (AC-1/AC-2/AC-4). It is a PURE VIEW of the journey Bloc (AC-10): it
/// reads only `JourneyViewState` (`motion`, `mode`, `distanceKm`) — it makes no
/// `ActivityPlugin` call, reads no idle/lock/OS-input signal, decides no
/// active-vs-idle, and accrues no distance.
///
/// AC-9: it renders the ONE shared [JourneyGame] passed in (owned by the app
/// shell), never constructing a second game/engine/ticker/scene. The body is a
/// frameless drag region (AC-6): dragging it moves the OS window via the
/// [WindowModeController] seam — `window_manager` is NOT imported here.
library;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../journey/presentation/game/journey_game.dart';
import '../../journey/presentation/journey_cubit.dart';
import '../../journey/presentation/journey_overlays.dart';
import '../../journey/presentation/journey_view_state.dart';
import '../domain/window_mode_controller.dart';

/// The compact PiP layout scale applied to the journey overlays so the readout
/// fits the small fixed window (CompactGeometry 280×180).
const double _kCompactScale = 0.62;

/// The compact PiP view. Renders [sharedGame] (the single shared scene) sized
/// down, overlaid with a tiny distance + active/idle readout, inside a frameless
/// drag region wired to [controller].
class CompactView extends StatelessWidget {
  /// Creates the compact view over the shared [sharedGame] and the window
  /// [controller] (for the frameless body-drag move, AC-6).
  const CompactView({
    required this.sharedGame,
    required this.controller,
    super.key,
  });

  /// The ONE shared journey scene (owned by the app shell — AC-9).
  final JourneyGame sharedGame;

  /// The window controller seam used to move the frameless window on drag.
  final WindowModeController controller;

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.of(context).disableAnimations;
    return Material(
      color: Colors.black,
      child: _CompactDragRegion(
        controller: controller,
        child: BlocBuilder<JourneyCubit, JourneyViewState>(
          builder: (BuildContext context, JourneyViewState s) {
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                // The SAME shared Flame scene, sized down (AC-1/AC-9).
                GameWidget<JourneyGame>(game: sharedGame),

                // Reduce-motion: a non-scrolling textual indicator that still
                // conveys active-vs-stopped (NFR-3), matching journey-view.
                if (reduceMotion)
                  ReduceMotionIndicator(
                    moving: s.motion == JourneyMotion.moving,
                    scale: _kCompactScale,
                  ),

                // Tiny distance readout — real, selectable/semantic text, NOT
                // baked into the sprite (NFR-6), equal to the Bloc's distanceKm
                // (AC-4). Same value as the main window at the same instant.
                DistanceCounter(
                  distanceKm: s.distanceKm,
                  scale: _kCompactScale,
                ),

                // "Paused — idle" readout for a real stopped state (AC-2),
                // matching journey-view; first frame stays parked w/o overlay.
                if (s.showPausedOverlay)
                  const PausedOverlay(scale: _kCompactScale),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Wraps the compact body in a pan gesture that moves the frameless OS window
/// via the [WindowModeController] seam (AC-6 "repositioned by dragging its
/// body"), then persists the settled position (AC-8) on drag end. Keeping the
/// `window_manager` package out of presentation: it talks only to the domain
/// controller.
class _CompactDragRegion extends StatelessWidget {
  const _CompactDragRegion({required this.controller, required this.child});

  final WindowModeController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      // Start an OS window-move drag when the body is dragged. The OS owns the
      // move from here; we only need to kick it off on pan start.
      onPanStart: (_) => controller.startDragging(),
      // Persist the new position once the user lets go (AC-8). The OS has
      // already finished moving the window by drag end.
      onPanEnd: (_) => controller.persistCompactPosition(),
      child: child,
    );
  }
}
