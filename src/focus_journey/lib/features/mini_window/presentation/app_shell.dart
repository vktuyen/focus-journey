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

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../journey/domain/clock.dart';
import '../../journey/presentation/game/journey_game.dart';
import '../../journey/presentation/journey_cubit.dart';
import '../../journey/presentation/journey_view_state.dart';
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
    this.gameFactory,
    super.key,
  });

  /// Cosmetic tint clock only (never an activity decision — AC-12).
  final Clock clock;

  /// The window controller seam (mode transitions + frameless drag).
  final WindowModeController controller;

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

  AppLifecycleState _lifecycle = AppLifecycleState.resumed;
  JourneyViewState _lastJourney = const JourneyViewState.initial();
  WindowMode _mode = WindowMode.full;

  @override
  void initState() {
    super.initState();
    _game = widget.gameFactory?.call() ?? JourneyGame();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _lifecycle = state;
    _syncGamePauseState();
  }

  @override
  void dispose() {
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
  void _applyToScene(BuildContext context, JourneyViewState s) {
    _lastJourney = s;
    _game.applyState(
      moving: s.motion == JourneyMotion.moving,
      mode: s.mode,
      reduceMotion: MediaQuery.of(context).disableAnimations,
      timeOfDayHours: _hourFromClock(),
    );
    _syncGamePauseState();
  }

  /// NFR-1: resume only when moving AND foregrounded; pause otherwise so a
  /// parked or backgrounded scene consumes no per-frame work. (Mode does not
  /// gate this: exactly one subtree hosts the live scene at a time, and the
  /// other window is hidden, so a single resume/pause decision suffices.)
  void _syncGamePauseState() {
    final bool foregrounded = _lifecycle == AppLifecycleState.resumed;
    final bool moving = _lastJourney.motion == JourneyMotion.moving;
    if (foregrounded && moving) {
      _game.resumeEngine();
    } else {
      _game.pauseEngine();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppShellCubit, AppShellState>(
      listenWhen: (prev, next) => prev.mode != next.mode,
      listener: (context, state) => setState(() => _mode = state.mode),
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
