/// Presentation layer. The single-window two-mode app shell (ADR-0003 / AC-6,
/// AC-9): it OWNS the ONE shared [JourneyGame] instance and switches the single
/// window between the full main UI and the compact PiP view — the two are never
/// co-visible (mutual exclusion is structural: one window, one scene).
///
/// SHARED SCENE (AC-9): the shell holds exactly one [JourneyGame] and passes it
/// to whichever subtree is the visible mode. Full and compact are rendered
/// mutually exclusively (`if (compact) … else …`), so at most ONE
/// `GameWidget(game: sharedGame)` is mounted at a time; switching mode unmounts
/// the old `GameWidget` and mounts the new one, which RE-ATTACHES the same
/// [JourneyGame] instance (Flame does not re-run `onLoad` on re-attach). The
/// scene is therefore not re-initialised and there is no forked
/// engine/ticker/scene.
///
/// SINGLE applyState DRIVER (AC-9): the shell is the one place that calls
/// `JourneyGame.applyState` from the journey Bloc, so neither subtree forks the
/// scene-driving logic. The compact view and the journey tab only RENDER the
/// shared scene.
///
/// NFR-1 (pause when idle OR not visible): the shell resumes the game's update
/// loop only when (a) the journey is moving, (b) the app is foregrounded, and
/// (c) the window is actually visible (full mode shown, or compact shown) — and
/// pauses it otherwise, so two always-on-top windows never both spin the CPU.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../journey/domain/clock.dart';
import '../../journey/presentation/game/journey_game.dart';
import '../../journey/presentation/journey_cubit.dart';
import '../../journey/presentation/journey_view_state.dart';
import '../../stats/presentation/vehicle_picker.dart';
import '../../window_visibility/domain/surface_visibility.dart';
import '../../window_visibility/domain/window_visibility_controller.dart';
import '../domain/window_mode.dart';
import '../domain/window_mode_controller.dart';
import 'app_shell_cubit.dart';
import 'compact_view.dart';
import 'hide_to_tray_hint.dart';

/// The app shell. [fullBuilder] builds the full main-window UI (tabs etc.),
/// receiving the shared game so the journey tab can render it. The shell drives
/// the shared scene and shows either the full or compact subtree per mode.
class AppShell extends StatefulWidget {
  /// Creates the shell.
  ///
  /// [clock] supplies the cosmetic tint hour for `applyState` (AC-12 — never an
  /// activity decision). [controller] moves the frameless compact window on
  /// drag. [fullBuilder] builds the full UI given the shared [JourneyGame].
  /// [gameFactory] is a test seam for the shared game.
  const AppShell({
    required this.clock,
    required this.controller,
    required this.fullBuilder,
    this.visibility,
    this.gameFactory,
    super.key,
  });

  /// Cosmetic tint clock only (never an activity decision — AC-12).
  final Clock clock;

  /// The window controller seam (mode transitions + frameless drag).
  final WindowModeController controller;

  /// journey-scene-v2 #5: the per-surface OS occlusion/visibility seam. When
  /// provided, the shell PAUSES the shared scene only when the currently-shown
  /// surface is NOT visible (hidden / minimized / occluded) and ANIMATES when it
  /// is visible — even if another app holds focus (AC-3/AC-4/AC-5). When `null`
  /// (existing tests / OS with no reliable occlusion signal), the shell falls
  /// back to [WindowModeController.isWindowVisible] (pause-when-hidden only).
  final WindowVisibilityController? visibility;

  /// Builds the full main-window subtree, given the shared scene to embed.
  final Widget Function(JourneyGame sharedGame) fullBuilder;

  /// Optional factory for the shared game (test seam). Defaults to a real game.
  final JourneyGame Function()? gameFactory;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  /// The ONE shared journey scene for both modes (AC-9).
  late final JourneyGame _game;

  JourneyViewState _lastJourney = const JourneyViewState.initial();
  WindowMode _mode = WindowMode.full;

  /// Whether the single OS window is currently visible on screen. Seeded from
  /// the controller and kept in sync via [WindowModeController.windowVisibilityChanges].
  /// Folded into the pause predicate (B1 / NFR-1): on desktop a close→hide-to-tray
  /// does NOT reliably change [AppLifecycleState], so visibility is a separate,
  /// REQUIRED condition for resuming the scene.
  late bool _windowVisible;
  StreamSubscription<bool>? _visibilitySub;

  /// journey-scene-v2 #5: per-surface occlusion visibility. Seeded from
  /// [AppShell.visibility] (when provided) and followed via its [changes]
  /// stream. The shown surface (main in full mode, pip in compact) gates
  /// animation: visible → animate (even if unfocused — AC-3); not visible →
  /// pause (AC-4). Per-surface (AC-5): the two surfaces are tracked separately.
  late bool _mainSurfaceVisible;
  late bool _pipSurfaceVisible;
  StreamSubscription<SurfaceVisibility>? _occlusionSub;

  @override
  void initState() {
    super.initState();
    _game = widget.gameFactory?.call() ?? JourneyGame();
    WidgetsBinding.instance.addObserver(this);
    // Seed window visibility, then follow its de-duped transitions (B1).
    _windowVisible = widget.controller.isWindowVisible;
    _visibilitySub = widget.controller.windowVisibilityChanges.listen((
      bool visible,
    ) {
      _windowVisible = visible;
      _syncGamePauseState();
    });

    // journey-scene-v2 #5: seed + follow per-surface OS occlusion. Defaults to
    // visible when no controller is wired (errs toward animating).
    final WindowVisibilityController? vis = widget.visibility;
    _mainSurfaceVisible = vis?.isVisible(WindowSurface.main) ?? true;
    _pipSurfaceVisible = vis?.isVisible(WindowSurface.pip) ?? true;
    if (vis != null) {
      // start() is idempotent; the composition root may have already called it.
      unawaited(vis.start());
      _occlusionSub = vis.changes.listen((SurfaceVisibility v) {
        switch (v.surface) {
          case WindowSurface.main:
            _mainSurfaceVisible = v.visible;
          case WindowSurface.pip:
            _pipSurfaceVisible = v.visible;
        }
        _syncGamePauseState();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // journey-scene-v2 #5: focus/lifecycle no longer gates animation (AC-3 keeps
    // a visible-but-unfocused surface scrolling). We still re-evaluate so a
    // platform that signals occlusion via lifecycle stays in sync.
    _syncGamePauseState();
  }

  @override
  void dispose() {
    _visibilitySub?.cancel();
    _occlusionSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _game.pauseEngine();
    super.dispose();
  }

  /// Cosmetic time-of-day in hours [0, 24) from the injected clock (tint only).
  double _hourFromClock() {
    final DateTime now = widget.clock.now();
    return now.hour + now.minute / 60.0 + now.second / 3600.0;
  }

  /// The single applyState driver (AC-9): drive the shared scene from the
  /// journey Bloc state + the current reduce-motion preference.
  ///
  /// vehicle-picker (ADR-0007): this is the PRODUCTION applyState driver for both
  /// surfaces (full window + PiP), so the cosmetic vehicle-preference override is
  /// composed HERE — `composeDisplayedMode` = `vehiclePreference ?? s.mode`,
  /// using the shared seam helper so this path and `JourneyScreen`'s standalone
  /// path cannot drift (AC-1/AC-2/AC-3/AC-6). The engine/`JourneyCubit` are never
  /// touched (AC-9/AC-10); the scene still takes ONE `mode:` value, so the
  /// cockpit-vs-side-view branch + sprite resolve off the one overridden value.
  void _applyToScene(BuildContext context, JourneyViewState s) {
    _lastJourney = s;
    _game.applyState(
      moving: s.motion == JourneyMotion.moving,
      mode: composeDisplayedMode(context, s.mode),
      reduceMotion: MediaQuery.of(context).disableAnimations,
      timeOfDayHours: _hourFromClock(),
    );
    _syncGamePauseState();
  }

  /// journey-scene-v2 #5 (AC-3/AC-4/AC-5) — the animation gate is now OCCLUSION,
  /// not focus. Resume the single game loop when the journey is moving AND the
  /// CURRENTLY-SHOWN surface has pixels on screen; pause otherwise.
  ///
  /// Reconciliation with the single-window two-mode model (ADR-0003): the app is
  /// one window switching full⇄compact, so exactly one surface is "shown" at a
  /// time. We pick that surface's per-surface visibility (main in full, pip in
  /// compact) — this honours the per-surface seam (AC-5: the two are tracked
  /// independently and tests drive them separately) while matching the real
  /// single-window runtime.
  ///
  /// We DELIBERATELY no longer require [AppLifecycleState.resumed] (focus):
  /// AC-3 keeps the scene animating while the surface is visible-but-unfocused
  /// (another app holds keyboard focus). Battery is still protected (AC-4): a
  /// not-visible surface pauses. When no occlusion controller is wired we fall
  /// back to [WindowModeController.isWindowVisible] (pause-when-hidden only).
  void _syncGamePauseState() {
    final bool moving = _lastJourney.motion == JourneyMotion.moving;
    final bool shownVisible = _shownSurfaceVisible();
    if (shownVisible && moving) {
      _game.resumeEngine();
    } else {
      _game.pauseEngine();
    }
  }

  /// Whether the currently-shown surface has pixels on screen. Uses the
  /// per-surface occlusion signal when wired; otherwise the app-state window
  /// visibility (AND-ed: a hidden-to-tray window is never "shown").
  bool _shownSurfaceVisible() {
    if (widget.visibility == null) {
      return _windowVisible;
    }
    final bool perSurface = _mode == WindowMode.compact
        ? _pipSurfaceVisible
        : _mainSurfaceVisible;
    // A hidden-to-tray window has no surface on screen regardless of the OS
    // occlusion reading, so keep the app-state visibility as a floor.
    return perSurface && _windowVisible;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppShellCubit, AppShellState>(
      listenWhen: (prev, next) => prev.mode != next.mode,
      listener: (context, state) {
        setState(() => _mode = state.mode);
        // The shown surface changed (main⇄pip), so re-evaluate the #5 gate.
        // Also re-sync AFTER the frame: switching mode unmounts/remounts the
        // GameWidget (re-attaching the shared game), which Flame may auto-pause;
        // a post-frame sync re-applies the correct pause/resume on the newly
        // shown surface.
        _syncGamePauseState();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _syncGamePauseState();
          }
        });
      },
      child: VehiclePreferenceListener(
        // vehicle-picker AC-1: a live pick re-composes + re-applies the displayed
        // mode within ≤1 frame on BOTH surfaces (full + PiP), re-using the last
        // journey state — no engine-side wiring. Defensive: a no-op when no
        // SettingsCubit is mounted.
        onPreferenceChanged: (BuildContext ctx) => _applyToScene(ctx, _lastJourney),
        child: BlocListener<JourneyCubit, JourneyViewState>(
          // Drive the scene synchronously with the state change (TC-005 parity).
          listener: _applyToScene,
          child: Stack(
            children: <Widget>[
              // Exactly one of the two subtrees hosts the shared GameWidget,
              // selected by mode. Switching reuses the same element (GlobalKey)
              // and the same JourneyGame instance — no scene re-init (AC-9).
              if (_mode == WindowMode.compact)
                CompactView(sharedGame: _game, controller: widget.controller)
              else
                widget.fullBuilder(_game),

              // One-time first-run hide-to-tray hint (AC-17), only meaningful in
              // full mode (close-to-tray returns to no visible window; the user
              // re-opens the full window and sees the hint there).
              if (_mode == WindowMode.full) const _HideToTrayHintOverlay(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders the one-time hide-to-tray hint when the shell cubit flags it (AC-17).
class _HideToTrayHintOverlay extends StatelessWidget {
  const _HideToTrayHintOverlay();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppShellCubit, AppShellState>(
      buildWhen: (prev, next) =>
          prev.showHideToTrayHint != next.showHideToTrayHint,
      builder: (context, state) {
        if (!state.showHideToTrayHint) {
          return const SizedBox.shrink();
        }
        return HideToTrayHint(
          onDismiss: () =>
              context.read<AppShellCubit>().dismissHideToTrayHint(),
        );
      },
    );
  }
}
