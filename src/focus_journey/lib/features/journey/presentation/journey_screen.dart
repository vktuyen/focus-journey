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

import '../../stats/domain/app_settings.dart';
import '../../stats/presentation/settings_cubit.dart';
import '../../stats/presentation/vehicle_picker.dart';
import '../domain/clock.dart';
import '../domain/travel_mode.dart';
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

  /// Drives the scene from the current journey state, applying the COSMETIC
  /// vehicle-preference override at this presentation seam (ADR-0007 / AC-3/AC-4):
  /// the displayed mode is `vehiclePreference ?? engineMode`, resolved here —
  /// at/above `JourneyViewState`, NOT in the engine and NOT in `JourneyCubit`
  /// (which stays a pure engine reader). The scene still takes ONE `mode:` value
  /// via `applyState`, so the cockpit-vs-side-view branch + sprite resolve off
  /// the one overridden value (AC-1/AC-2), with no per-frame cost (NFR-1).
  void _applyToScene(BuildContext context, JourneyViewState s) {
    _game.applyState(
      moving: s.motion == JourneyMotion.moving,
      // Shared override seam (ADR-0007): vehiclePreference ?? engineMode. Uses
      // the SAME helper as AppShell's production driver so the two cannot drift.
      mode: composeDisplayedMode(context, s.mode),
      reduceMotion: MediaQuery.of(context).disableAnimations,
      timeOfDayHours: _hourFromClock(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.of(context).disableAnimations;
    // Whether a SettingsCubit is in the tree. When absent (standalone callers /
    // existing tests with no settings provider), the override is purely additive
    // (preference null → follow engine mode, AC-4) and the picker affordance is
    // omitted — the engine/cubit never depend on it (AC-9/AC-10).
    final bool hasSettings = hasSettingsCubit(context);
    final Widget content = BlocBuilder<JourneyCubit, JourneyViewState>(
      builder: (BuildContext context, JourneyViewState s) {
        // The cosmetic displayed mode = vehiclePreference ?? engineMode, read at
        // this presentation seam (ADR-0007). The journey-screen affordance + the
        // debug switcher reflect this composed value so the UI matches the scene.
        final TravelMode? preference = hasSettings
            ? context.watch<SettingsCubit>().state.vehiclePreference
            : null;
        final TravelMode displayedMode = preference ?? s.mode;
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

            // Persistent vehicle-picker affordance (vehicle-picker AC-14 /
            // Resolved decision 6): a small icon button showing the current
            // vehicle; tapping opens the same icon picker, writing through the
            // ONE SettingsCubit preference. Placed top-right BELOW the distance
            // counter so it is clear of the occupied corners (reduce-motion
            // top-left, distance top-right header, PiP bottom-left, minimap
            // bottom-right) and the top-center dev dropdown. Only when a
            // SettingsCubit is available (else there is nowhere to persist).
            if (hasSettings) _VehicleAffordance(displayedMode: displayedMode),
          ],
        );
      },
    );
    // When the shell owns the shared game it is the single applyState driver
    // (AC-9); this screen then only renders. When standalone, drive the scene
    // here within the listener (synchronous with the state change) so motion
    // resumes within one frame (TC-005), not a post-frame delay. We listen to
    // BOTH cubits so a vehicle-preference change re-applies the composed mode
    // within ≤1 frame (AC-1), exactly like a journey-state change.
    if (!_ownsGame) {
      return Scaffold(body: content);
    }
    // The journey-state listener always drives the scene (composing the override
    // when a SettingsCubit is present). The shared VehiclePreferenceListener ALSO
    // re-applies the composed mode within ≤1 frame on a live pick (AC-1) —
    // exactly like a journey-state change, with no engine-side wiring, and a
    // no-op when no SettingsCubit is mounted (same helper AppShell uses).
    return Scaffold(
      body: BlocListener<JourneyCubit, JourneyViewState>(
        listener: _applyToScene,
        child: VehiclePreferenceListener(
          onPreferenceChanged: (BuildContext ctx) =>
              _applyToScene(ctx, ctx.read<JourneyCubit>().state),
          child: content,
        ),
      ),
    );
  }
}

/// The persistent journey-screen vehicle affordance (vehicle-picker AC-14): a
/// small icon button showing the [displayedMode]'s glyph; tapping opens the
/// shared [VehiclePicker] bottom sheet, which writes through the ONE
/// `SettingsCubit` preference (AC-11). Top-right, below the distance counter.
class _VehicleAffordance extends StatelessWidget {
  const _VehicleAffordance({required this.displayedMode});

  /// The currently displayed (composed) mode — drives the affordance's glyph and
  /// pre-seeds the opened picker.
  final TravelMode displayedMode;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        // Top-right, pushed down so it sits clear of the distance counter header.
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 64, right: 16),
          child: Material(
            color: Colors.black.withValues(alpha: 0.55),
            shape: const CircleBorder(),
            child: IconButton(
              key: const Key('journey-vehicle-affordance'),
              tooltip: 'Choose your vehicle (${vehicleLabel(displayedMode)})',
              icon: ImageIcon(
                AssetImage(vehicleIconAsset(displayedMode)),
                color: Colors.white,
              ),
              onPressed: () => _openPicker(context),
            ),
          ),
        ),
      ),
    );
  }

  void _openPicker(BuildContext context) {
    // Capture the cubit from the journey-screen context (the picker sheet is
    // mounted on the root navigator and may not inherit the provider).
    final SettingsCubit settings = context.read<SettingsCubit>();
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: BlocProvider<SettingsCubit>.value(
            value: settings,
            child: BlocBuilder<SettingsCubit, AppSettings>(
              builder: (BuildContext context, AppSettings s) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Choose your vehicle',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      VehiclePicker(
                        key: const Key('journey-vehicle-picker'),
                        selected:
                            s.vehiclePreference ?? TravelMode.motorbike,
                        onSelected: settings.setVehicle,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
