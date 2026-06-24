/// Presentation layer. The main journey screen: hosts the Flame [JourneyGame]
/// and drives it from [JourneyCubit] state, with plain-Flutter overlays for the
/// "Paused — idle" message and the live distance counter.
///
/// SEPARATION INVARIANT (AC-9/AC-10/TC-009/TC-010/TC-026): this screen reads
/// ONLY the Cubit's `state` (`JourneyViewState.motion`/`mode`/`distanceKm`). It
/// imports NO `ActivityPlugin`, calls NO `getSystemIdleSeconds`/`isScreenLocked`,
/// touches NO `MethodChannel`, and never mutates journey state. The injected
/// [Clock] is used ONLY to derive the cosmetic day/night tint hour (AC-12) — it
/// is never used for any active-vs-idle decision (that is the engine's job, and
/// the engine has already decided by the time a state reaches this screen).
library;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/clock.dart';
import 'game/journey_game.dart';
import 'journey_cubit.dart';
import 'journey_overlays.dart';
import 'journey_view_state.dart';

export 'journey_overlays.dart' show kPausedOverlayText;

/// The first-person journey screen. Construct the [JourneyGame] once and keep a
/// reference so we can drive it via [JourneyGame.applyState] and suspend it
/// off-screen.
///
/// When [sharedGame] is supplied (mini-window slice / ADR-0003), this screen
/// binds to the ONE shared [JourneyGame] instance owned by the app shell and
/// does NOT manage its lifecycle (the shell pauses/resumes/disposes it so the
/// single scene survives full⇄compact mode switches — AC-9). When `null`
/// (standalone use / existing tests) it owns its own game exactly as before.
class JourneyScreen extends StatefulWidget {
  /// Creates the journey screen.
  ///
  /// [clock] supplies the cosmetic time-of-day hour for the tint only (AC-12).
  /// [gameFactory] lets tests inject a game double; production constructs a real
  /// [JourneyGame]. [sharedGame], when provided, binds to the app shell's single
  /// shared game and disables this screen's lifecycle ownership.
  const JourneyScreen({
    required this.clock,
    this.gameFactory,
    this.sharedGame,
    super.key,
  });

  /// Injected clock — cosmetic tint hour ONLY (never an activity decision).
  final Clock clock;

  /// Optional factory for the Flame game (test seam). Defaults to a real game.
  /// Ignored when [sharedGame] is provided.
  final JourneyGame Function()? gameFactory;

  /// The shared [JourneyGame] owned by the app shell (mini-window slice). When
  /// non-null, this screen renders it but does NOT own its lifecycle.
  final JourneyGame? sharedGame;

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen>
    with WidgetsBindingObserver {
  late final JourneyGame _game;

  /// Whether this screen owns the game's lifecycle. `false` when the shell
  /// passed a [JourneyScreen.sharedGame] — the shell then owns pause/resume.
  bool get _ownsGame => widget.sharedGame == null;

  @override
  void initState() {
    super.initState();
    _game = widget.sharedGame ?? widget.gameFactory?.call() ?? JourneyGame();
    if (_ownsGame) {
      WidgetsBinding.instance.addObserver(this);
      // Resume in case a previous lifecycle left the engine paused (TC-018).
      _game.resumeEngine();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!_ownsGame) {
      return; // shell owns lifecycle for the shared game.
    }
    // Suspend the update loop when the app is not foregrounded; resume when it
    // returns (off-screen suspend — TC-018 / NF perf: no per-frame work hidden).
    switch (state) {
      case AppLifecycleState.resumed:
        _game.resumeEngine();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _game.pauseEngine();
    }
  }

  @override
  void deactivate() {
    // Navigated away / removed from the tree: stop ticking the scene (TC-018).
    if (_ownsGame) {
      _game.pauseEngine();
    }
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    // Re-inserted into the tree: resume from the current Bloc state.
    if (_ownsGame) {
      _game.resumeEngine();
    }
  }

  @override
  void dispose() {
    if (_ownsGame) {
      WidgetsBinding.instance.removeObserver(this);
      _game.pauseEngine();
    }
    super.dispose();
  }

  /// Cosmetic time-of-day in hours [0, 24) derived from the injected clock.
  /// AC-12: tint only — deliberately NOT used for any motion/activity decision.
  double _hourFromClock() {
    final DateTime now = widget.clock.now();
    return now.hour + now.minute / 60.0 + now.second / 3600.0;
  }

  void _applyToScene(BuildContext context, JourneyViewState s) {
    _game.applyState(
      moving: s.motion == JourneyMotion.moving,
      mode: s.mode,
      reduceMotion: MediaQuery.of(context).disableAnimations,
      timeOfDayHours: _hourFromClock(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.of(context).disableAnimations;
    final Widget content = BlocBuilder<JourneyCubit, JourneyViewState>(
      builder: (BuildContext context, JourneyViewState s) {
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // The Flame scene fills the screen.
            GameWidget<JourneyGame>(game: _game),

            // Reduce-motion: the scene suppresses scrolling, so add a
            // textual, non-scrolling indicator that still conveys
            // active-vs-stopped (TC-019). Always in the semantics tree.
            if (reduceMotion)
              ReduceMotionIndicator(moving: s.motion == JourneyMotion.moving),

            // Live distance counter — a plain Flutter widget over the scene
            // (resolved decision: sibling widget, not in the scene).
            DistanceCounter(distanceKm: s.distanceKm),

            // "Paused — idle" overlay — real text in the semantics tree
            // (TC-020/TC-027), shown only for a real stopped state (TC-013).
            if (s.showPausedOverlay) const PausedOverlay(),
          ],
        );
      },
    );
    // When the shell owns the shared game it is the single applyState driver
    // (AC-9); this screen then only renders. When standalone, drive the scene
    // here within the listener (synchronous with the state change) so motion
    // resumes within one frame (TC-005), not a post-frame delay.
    return Scaffold(
      body: _ownsGame
          ? BlocListener<JourneyCubit, JourneyViewState>(
              listener: _applyToScene,
              child: content,
            )
          : content,
    );
  }
}
