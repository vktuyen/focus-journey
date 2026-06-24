/// Presentation layer. The plain-Flutter overlays layered over the Flame
/// [JourneyGame] scene: the live distance counter, the "Paused — idle" message,
/// and the reduce-motion textual indicator.
///
/// These are extracted from `journey_screen.dart` so BOTH the full journey
/// screen and the compact PiP view (mini-window slice) reuse the SAME overlay
/// widgets over the SAME shared scene — there is no forked overlay/scene
/// (AC-9). They are pure views of [JourneyViewState] (AC-10): they read state,
/// never decide active-vs-idle and never accrue distance.
///
/// All text here is REAL Flutter text in the semantics tree (NOT baked into a
/// sprite), so screen readers and reduce-motion users perceive journey state
/// (journey-view message-readability NFR / mini-window NFR-6).
library;

import 'package:flutter/material.dart';

/// The generic stopped-state overlay copy (resolved: no threshold value).
const String kPausedOverlayText = 'Paused — idle';

/// The "Paused — idle" overlay. Plain Flutter text (NOT a sprite) with a legible
/// contrast pill so screen readers and motion-sensitive users perceive it.
///
/// [scale] shrinks the padding + font for the compact PiP while keeping the
/// exact same text + semantics (AC-2/AC-4).
class PausedOverlay extends StatelessWidget {
  /// Creates the paused overlay. [scale] < 1 renders a compact variant.
  const PausedOverlay({this.scale = 1.0, super.key});

  /// Layout scale (1.0 = full screen, < 1 = compact PiP).
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Semantics(
        liveRegion: true,
        label: kPausedOverlayText,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 20 * scale,
            vertical: 12 * scale,
          ),
          decoration: BoxDecoration(
            // High-contrast backdrop so the text is legible over any tint
            // (accessibility — message readability).
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(12 * scale),
          ),
          child: Text(
            kPausedOverlayText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22 * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// The live distance counter, layered over the scene (resolved: plain widget).
///
/// [scale] shrinks the chrome for the compact PiP; the value shown is always the
/// Bloc's `distanceKm` (AC-4 — the view computes no distance of its own).
class DistanceCounter extends StatelessWidget {
  /// Creates the distance counter for [distanceKm].
  const DistanceCounter({
    required this.distanceKm,
    this.scale = 1.0,
    super.key,
  });

  /// The cumulative distance (km) from the journey Bloc.
  final double distanceKm;

  /// Layout scale (1.0 = full screen, < 1 = compact PiP).
  final double scale;

  @override
  Widget build(BuildContext context) {
    final String text = '${distanceKm.toStringAsFixed(1)} km';
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: EdgeInsets.all(16 * scale),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 14 * scale,
              vertical: 8 * scale,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(10 * scale),
            ),
            child: Semantics(
              label: 'Distance travelled $text',
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18 * scale,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A static, non-scrolling indicator of active-vs-stopped shown only under
/// reduce-motion, where the scene suppresses scroll (TC-019 / NFR-3). Still
/// conveys state via text + colour, and is present in the semantics tree.
class ReduceMotionIndicator extends StatelessWidget {
  /// Creates the indicator. [moving] picks the "Travelling"/"Stopped" copy.
  const ReduceMotionIndicator({
    required this.moving,
    this.scale = 1.0,
    super.key,
  });

  /// Whether the journey is travelling (`true`) or parked (`false`).
  final bool moving;

  /// Layout scale (1.0 = full screen, < 1 = compact PiP).
  final double scale;

  @override
  Widget build(BuildContext context) {
    final String label = moving ? 'Travelling' : 'Stopped';
    final Color colour = moving ? Colors.greenAccent : Colors.orangeAccent;
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: EdgeInsets.all(16 * scale),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 14 * scale,
              vertical: 8 * scale,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(10 * scale),
            ),
            child: Semantics(
              label: 'Journey status: $label',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.circle, size: 12 * scale, color: colour),
                  SizedBox(width: 8 * scale),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16 * scale,
                      fontWeight: FontWeight.w600,
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
