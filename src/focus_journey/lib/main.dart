/// App entry point. Composition root: builds the DI graph (activity plugin →
/// engine → cubits → ticker, plus the route-progress and stats/settings stores)
/// and shows the nav shell, gated by the first-run onboarding screen.
///
/// SEPARATION NOTE: the `ActivityPlugin` and `JourneyEngine` are wired here (the
/// app-service seam) and driven by the `ActivityTicker`. The journey/map/stats
/// screens receive ONLY their Cubits' view state — they never see the plugin or
/// the engine's activity logic (AC-9/AC-10/TC-026).
///
/// STATS WIRING CHOICE (local-stats AC-1..AC-19): the stats slice is a PURE
/// AGGREGATE CONSUMER, mirroring the route slice's `double` distance seam. The
/// `ActivityTicker` forwards the engine's `toProgress()` aggregate snapshot (a
/// plain value object — no engine reference) to `StatsCubit.onTick` via its
/// injectable `onSnapshot` sink, added exactly as `onDistance` was. The stats
/// cubit also receives the route position as a plain `RouteProgressSnapshot`. No
/// engine/ticker tick or accrual logic was changed.
///
/// IDLE-THRESHOLD SEAM (local-stats AC-8): the engine's threshold is a
/// construction-time knob (final). The settings→engine seam rebuilds the engine
/// (preserving its progress via `toProgress()`/`restore()`) and restarts the
/// ticker with the new threshold on the next tick — NO engine code change.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/activity/data/activity_plugin_factory.dart';
import 'features/activity/data/mock_activity_source.dart';
import 'features/activity/domain/activity_plugin.dart';
import 'features/journey/domain/clock.dart';
import 'features/journey/domain/journey_engine.dart';
import 'features/journey/domain/journey_progress.dart';
import 'features/journey/presentation/activity_ticker.dart';
import 'features/journey/presentation/game/journey_game.dart';
import 'features/journey/presentation/journey_cubit.dart';
import 'features/journey/presentation/journey_screen.dart';
import 'features/journey/presentation/journey_view_state.dart';
import 'features/mini_window/data/mini_window_factory.dart';
import 'features/mini_window/domain/hide_to_tray_hint_repository.dart';
import 'features/mini_window/domain/tray_controller.dart';
import 'features/mini_window/domain/tray_state.dart';
import 'features/mini_window/domain/window_mode.dart';
import 'features/mini_window/domain/window_mode_controller.dart';
import 'features/mini_window/presentation/app_shell.dart';
import 'features/mini_window/presentation/app_shell_cubit.dart';
import 'features/mini_window/presentation/journey_tray_mapper.dart';
import 'features/window_visibility/data/window_visibility_factory.dart';
import 'features/window_visibility/domain/window_visibility_controller.dart';
import 'features/route/data/shared_preferences_route_repository.dart';
import 'features/route/domain/province_chain.dart';
import 'features/route/domain/province_geography.dart';
import 'features/route/domain/route_plan.dart';
import 'features/route/domain/route_repository.dart';
import 'features/route/presentation/map_cubit.dart';
import 'features/route/presentation/map_surface.dart';
import 'features/route/presentation/route_progress_cubit.dart';
import 'features/route/presentation/route_view_state.dart';
import 'features/stats/data/launch_at_startup_controller.dart';
import 'features/stats/data/local_notifier_notifier.dart';
import 'features/stats/data/shared_preferences_earned_badges_repository.dart';
import 'features/stats/data/shared_preferences_history_repository.dart';
import 'features/stats/data/shared_preferences_settings_repository.dart';
import 'features/stats/domain/app_settings.dart';
import 'features/stats/domain/route_progress_snapshot.dart';
import 'features/stats/domain/stats_repositories.dart';
import 'features/stats/presentation/badges_screen.dart';
import 'features/stats/presentation/onboarding_screen.dart';
import 'features/stats/presentation/settings_cubit.dart';
import 'features/stats/presentation/settings_screen.dart';
import 'features/stats/presentation/stats_cubit.dart';
import 'features/stats/presentation/stats_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Build SharedPreferences once at startup so loads/saves are done over one
  // instance (mirrors the established repository wiring intent).
  final prefs = await SharedPreferences.getInstance();

  // Register the local-notifier dep (privacy-clean — local OS toasts only, no
  // network). `setup` is required before any toast is shown. launch_at_startup
  // is configured in FocusJourneyApp.initState with the executable path.
  // TODO(local-stats): for a Windows MSIX-packaged build, pass the MSIX
  // identity to launch_at_startup.setup(packageName: ...). The v1 unsigned
  // macOS/Windows builds use the resolved executable path, which is sufficient.
  await localNotifier.setup(appName: 'Vietnam Focus Journey');

  final routeRepository = SharedPreferencesRouteRepository(
    prefs,
    vietnamProvinceChain,
    vietnamProvinceGeography,
  );
  // route-planner-v2 (ADR-0005 / AC-12): restore the authored RoutePlan via the
  // existing seam. A legacy v1 RouteSelection blob is migrated forward to a plan
  // (full start→tip sub-path) by loadPlan, so an in-flight v1 route survives the
  // upgrade. An only-active (or restored-completed) plan seeds the route cubit.
  final savedPlan = await routeRepository.loadPlan();

  final settingsRepository = SharedPreferencesSettingsRepository(prefs);
  final historyRepository = SharedPreferencesHistoryRepository(prefs);
  final earnedBadgesRepository = SharedPreferencesEarnedBadgesRepository(prefs);
  final savedSettings = await settingsRepository.load();

  // --- mini-window slice (ADR-0003): the single-window two-mode shell + tray.
  // Build the native window + tray backends via the DI seam (respects
  // --mock-window). `window.setup()` must run BEFORE runApp so the close
  // intercept + min sizes are registered (close→hide-to-tray, AC-15/16).
  final window = MiniWindowFactory.createWindowModeController(prefs);
  await window.setup();
  final tray = MiniWindowFactory.createTrayController();
  await tray.init();
  // journey-scene-v2 #5: the per-surface OS occlusion seam. start() begins
  // observing the app's OWN window visibility (no other-app/input data). The
  // shell pauses the shared scene only when the shown surface is not visible
  // and keeps animating when it is visible-but-unfocused (AC-3/AC-4/AC-5).
  final windowVisibility = WindowVisibilityFactory.create();
  await windowVisibility.start();
  final hideToTrayHintRepository =
      MiniWindowFactory.createHideToTrayHintRepository(prefs);
  final hintAlreadyShown = await hideToTrayHintRepository.hasShownHint();

  runApp(
    FocusJourneyApp(
      routeRepository: routeRepository,
      savedPlan: savedPlan,
      settingsRepository: settingsRepository,
      historyRepository: historyRepository,
      earnedBadgesRepository: earnedBadgesRepository,
      savedSettings: savedSettings,
      windowController: window,
      windowVisibility: windowVisibility,
      trayController: tray,
      hideToTrayHintRepository: hideToTrayHintRepository,
      hintAlreadyShown: hintAlreadyShown,
    ),
  );
}

/// Root of the Vietnam Focus Journey app. Stateful so it owns the lifecycle of
/// the injected engine/cubits/ticker and disposes them cleanly.
class FocusJourneyApp extends StatefulWidget {
  /// Creates the app root with the injected persistence seams + restored state.
  const FocusJourneyApp({
    required this.routeRepository,
    required this.settingsRepository,
    required this.historyRepository,
    required this.earnedBadgesRepository,
    required this.windowController,
    required this.windowVisibility,
    required this.trayController,
    required this.hideToTrayHintRepository,
    this.savedPlan,
    this.savedSettings,
    this.hintAlreadyShown = false,
    super.key,
  });

  /// The route persistence seam.
  final RouteRepository routeRepository;

  /// The settings persistence seam.
  final SettingsRepository settingsRepository;

  /// The bounded per-day history persistence seam.
  final HistoryRepository historyRepository;

  /// The earned-badge persistence seam.
  final EarnedBadgesRepository earnedBadgesRepository;

  /// The single-window controller seam (full ⇄ compact, hide-to-tray, quit).
  final WindowModeController windowController;

  /// journey-scene-v2 #5: the per-surface OS occlusion/visibility seam. Drives
  /// the shared scene's animate-when-visible / pause-when-hidden behaviour.
  final WindowVisibilityController windowVisibility;

  /// The tray/menu-bar controller seam (icon/menu + action stream).
  final TrayController trayController;

  /// The one-time hide-to-tray hint persistence seam (AC-17).
  final HideToTrayHintRepository hideToTrayHintRepository;

  /// The restored authored route plan (v2 — ADR-0005), or `null` for a fresh
  /// start. A legacy v1 selection blob is already migrated forward to a plan by
  /// the repository's `loadPlan` (AC-12).
  final RoutePlan? savedPlan;

  /// The restored settings, or `null` for defaults.
  final AppSettings? savedSettings;

  /// Whether the one-time hide-to-tray hint has already been shown (AC-17).
  final bool hintAlreadyShown;

  @override
  State<FocusJourneyApp> createState() => _FocusJourneyAppState();
}

class _FocusJourneyAppState extends State<FocusJourneyApp> {
  // --- Composition root: build the DI graph once. ---
  late final Clock _clock;
  late final ActivityPlugin _activityPlugin;
  late final JourneyCubit _cubit;
  late final RouteProgressCubit _routeCubit;
  late final MapCubit _mapCubit;
  late final StatsCubit _statsCubit;
  late final SettingsCubit _settingsCubit;
  late final AppShellCubit _shellCubit;

  // mini-window slice subscriptions (tray actions, journey→tray, close→hint).
  StreamSubscription<TrayAction>? _trayActionsSub;
  StreamSubscription<JourneyViewState>? _journeyToTraySub;
  StreamSubscription<WindowMode>? _modeToTraySub;
  StreamSubscription<void>? _hiddenToTraySub;

  // Engine + ticker are mutable so the idle-threshold seam can rebuild them
  // (preserving progress) without touching engine/ticker code (AC-8).
  late JourneyEngine _engine;
  late ActivityTicker _ticker;

  @override
  void initState() {
    super.initState();
    _clock = const SystemClock();
    // Configure launch-at-startup with the running executable (read no OS state
    // here — the SettingsCubit reads/sets via the StartupController interface).
    launchAtStartup.setup(
      appName: 'Vietnam Focus Journey',
      appPath: _executablePath(),
    );

    _activityPlugin = ActivityPluginFactory.create(
      mockSeed: ActivityPluginFactory.useMock
          ? MockActivitySource(idleSeconds: 0, screenLocked: false)
          : null,
    );

    _cubit = JourneyCubit();
    // route-planner-v2 (ADR-0005): the route cubit holds the FULL chain +
    // geography and derives the active plan's SUB-CHAIN, running the unchanged
    // resolver over it (AC-7) and computing country % itself (decision 3). A
    // restored active/completed plan seeds it (AC-12).
    _routeCubit = RouteProgressCubit(
      chain: vietnamProvinceChain,
      geography: vietnamProvinceGeography,
      repository: widget.routeRepository,
      initialPlan: widget.savedPlan,
    );
    // map-experience: the map slice's projection cubit. A PURE read-only
    // consumer (AC-12) — it holds no engine/plugin reference. It is fed the
    // SAME `JourneyProgress` aggregate the ticker already forwards to stats
    // (segments + cumulative distance) and the route cubit's resolved state. The
    // full geography is the fallback; a v2 route supplies its sub-geography via
    // the route view state (AC-7).
    _mapCubit = MapCubit(geography: vietnamProvinceGeography);
    _statsCubit = StatsCubit(
      clock: _clock,
      historyRepository: widget.historyRepository,
      earnedBadgesRepository: widget.earnedBadgesRepository,
      notifier: const LocalNotifierNotifier(),
    );

    final initialThreshold =
        widget.savedSettings?.idleThreshold ?? AppSettings.defaultIdleThreshold;
    _buildEngineAndTicker(initialThreshold);

    _settingsCubit = SettingsCubit(
      repository: widget.settingsRepository,
      startupController: const LaunchAtStartupController(),
      // Settings → engine seam: rebuild the engine with the new threshold.
      applyIdleThreshold: _applyIdleThreshold,
      // Keep the stats cubit's notification gating in sync with settings.
      onSettingsChanged: _statsCubit.updateSettings,
      initialSettings: widget.savedSettings,
    );
    _statsCubit.updateSettings(_settingsCubit.state);

    // Feed route position to stats on the route cubit's stream (plain snapshot
    // — no cubit reference crosses the seam, TC-026).
    _routeCubit.stream.listen(_onRouteChanged);
    // route-planner-v2 / map-experience (AC-12): seed the map projection cubit
    // with the route cubit's CURRENT (restored) view state — the constructor
    // emitted it before the listener above was attached, so push it once now so a
    // restored route's base road + (sub-)geography + red trace are present on
    // launch. For a restored plan this carries the sub-geography (AC-7).
    _mapCubit.updateFromRoute(_routeCubit.state);

    // Restore stats from persisted stores + the engine's restored snapshot
    // (records an app-closed-across-midnight prior day before zeroing, AC-19).
    _statsCubit.load(_engine.toProgress());

    // map-experience (AC-8 / TC-215): seed the map projection cubit with the
    // engine's RESTORED snapshot so the current-route red trace is present
    // immediately on launch (before the first tick), not only after the first
    // tick arrives. The engine restores its persisted `segments` on construction
    // (JourneyProgress.segments), so this is the restored trace.
    _mapCubit.updateFromSnapshot(_engine.toProgress());

    _ticker.start();

    _wireMiniWindow();
  }

  /// Wires the mini-window slice (ADR-0003): the mode cubit, the tray action
  /// routing, the journey→tray reflection, the close-to-tray hint, and the
  /// Quit flush hook. The window/tray controllers are built in `main()` and
  /// injected; this method adds NO journey/engine logic — it only wires.
  void _wireMiniWindow() {
    _shellCubit = AppShellCubit(
      controller: widget.windowController,
      hintAlreadyShown: widget.hintAlreadyShown,
    );

    // Route tray menu actions → the window controller (AC-12). The tray holds
    // no window logic itself; the mapping lives here. Each transition is guarded
    // (S1): the controller now rethrows on failure (after driving itself to a
    // consistent state), so we log rather than leak an unhandled future.
    _trayActionsSub = widget.trayController.actions.listen((action) {
      switch (action) {
        case TrayAction.showApp:
          _guardTransition('showApp', widget.windowController.showApp());
        case TrayAction.enterCompact:
          _guardTransition(
            'enterCompact',
            widget.windowController.enterCompact(),
          );
        case TrayAction.quit:
          _guardTransition('quit', widget.windowController.quit());
      }
    });

    // Reflect journey state on the tray icon/tooltip + status line (AC-11/13).
    // Seed once from the current state, then update on every change.
    _pushJourneyToTray(_cubit.state);
    _journeyToTraySub = _cubit.stream.listen(_pushJourneyToTray);

    // Reflect the current window mode on the tray menu (AC-14). Seed + follow.
    widget.trayController.setMode(widget.windowController.mode);
    _modeToTraySub = widget.windowController.modeChanges.listen(
      widget.trayController.setMode,
    );

    // First-run hide-to-tray hint (AC-17): on the first close-to-tray only,
    // surface the one-time hint and persist the "shown" flag.
    _hiddenToTraySub = widget.windowController.hiddenToTray.listen((_) {
      final shouldPersist = _shellCubit.onHiddenToTray();
      if (shouldPersist) {
        widget.hideToTrayHintRepository.markHintShown();
      }
    });

    // Quit flush hook (AC-16): persist the latest journey/stats/route state via
    // the existing repository save paths before the process is destroyed. This
    // reuses the shipped persistence — no new persistence is invented here.
    widget.windowController.onBeforeQuit(_flushOnQuit);
  }

  /// Reflects [s] on the tray surface (icon/tooltip + status line).
  void _pushJourneyToTray(JourneyViewState s) {
    widget.trayController.setState(JourneyTrayMapper.stateFor(s));
    widget.trayController.setStatusLine(JourneyTrayMapper.statusLineFor(s));
  }

  /// Guards a fire-and-forget window transition (S1): the controller now
  /// rethrows on failure (after driving itself to a consistent state), so log
  /// the failure rather than let it become an unhandled future or silently
  /// desync the UI.
  void _guardTransition(String action, Future<void> future) {
    future.catchError((Object error, StackTrace stack) {
      debugPrint('Window transition "$action" failed: $error');
    });
  }

  /// Flushes the latest persisted state before Quit (AC-16). Reuses the shipped
  /// repositories' save paths and engine snapshot — it invents NO persistence.
  /// The route selection is already persisted by the route cubit on change, and
  /// the stats cubit persists per-day history on every `onTick`; here we push
  /// the engine's freshest aggregate snapshot through that SAME `onTick` path so
  /// the latest journey aggregate is saved before the process is destroyed, and
  /// await its returned future so the write completes before Quit proceeds.
  Future<void> _flushOnQuit() async {
    try {
      await _statsCubit.onTick(_engine.toProgress());
    } catch (_) {
      // Never let a flush failure block the user's Quit.
    }
  }

  void _onRouteChanged(RouteViewState state) {
    // map-experience: feed the route selection + resolved position to the map
    // projection cubit (read-only — AC-12). Keyed off the same route stream the
    // stats slice consumes; no engine reference crosses the seam.
    _mapCubit.updateFromRoute(state);
    final position = state.position;
    _statsCubit.updateRoute(
      position == null
          ? const RouteProgressSnapshot.none()
          : RouteProgressSnapshot(
              percentOfCountry: position.percentOfCountry,
              // `passed` includes the origin; provinces *crossed* is that minus
              // 1, clamped at the list length so it can never go negative.
              provincesPassed: (position.passed.length - 1).clamp(
                0,
                position.passed.length,
              ),
              completed: position.isCompleted,
            ),
    );
  }

  /// Builds (or rebuilds) the engine + ticker with [threshold], wiring the
  /// distance sink to route-progress and the snapshot sink to stats.
  void _buildEngineAndTicker(Duration threshold) {
    _engine = JourneyEngine(
      clock: _clock,
      activityPlugin: _activityPlugin,
      kmPerActiveHour: vietnamProvinceChain.totalChainKm / 8,
      threshold: threshold,
      grace: threshold < const Duration(minutes: 5)
          ? threshold
          : const Duration(minutes: 5),
    );
    _ticker = ActivityTicker(
      engine: _engine,
      clock: _clock,
      cubit: _cubit,
      onDistance: _routeCubit.updateFromDistance,
      // Stats + map sink: forward the engine's aggregate snapshot once per tick,
      // mirroring the onDistance pattern (only a value object crosses, AC-1).
      // map-experience reads the snapshot's `segments` for the red idle trace
      // (Decision C) — a pure read, no engine reference (AC-12).
      onSnapshot: (JourneyProgress snapshot) {
        _statsCubit.onTick(snapshot);
        _mapCubit.updateFromSnapshot(snapshot);
      },
      log: (String message) => debugPrint(message),
    );
  }

  /// The settings→engine idle-threshold seam (AC-8): rebuild the engine with the
  /// new threshold, preserving its current progress via `toProgress()` /
  /// `restore()`, and restart the ticker so the next tick classifies idle using
  /// the new value — without changing any engine/ticker logic.
  void _applyIdleThreshold(Duration threshold) {
    if (_engine.threshold == threshold) {
      return;
    }
    final snapshot = _engine.toProgress();
    final wasRunning = _ticker.isRunning;
    _ticker.dispose();
    _buildEngineAndTicker(threshold);
    _engine.restore(snapshot);
    if (wasRunning) {
      _ticker.start();
    }
  }

  static String _executablePath() {
    // The running executable path for launch_at_startup registration. On
    // unsupported platforms this could throw; fall back to an empty string so
    // wiring never crashes (the SettingsCubit handles a failed OS read).
    try {
      return Platform.resolvedExecutable;
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    _trayActionsSub?.cancel();
    _journeyToTraySub?.cancel();
    _modeToTraySub?.cancel();
    _hiddenToTraySub?.cancel();
    _shellCubit.close();
    // Tear down the native window + tray seams (mocks are no-ops on real OS).
    widget.windowController.dispose();
    widget.windowVisibility.dispose();
    widget.trayController.dispose();
    _ticker.dispose();
    _cubit.close();
    _routeCubit.close();
    _mapCubit.close();
    _statsCubit.close();
    _settingsCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vietnam Focus Journey',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<JourneyCubit>.value(value: _cubit),
          BlocProvider<RouteProgressCubit>.value(value: _routeCubit),
          BlocProvider<MapCubit>.value(value: _mapCubit),
          BlocProvider<StatsCubit>.value(value: _statsCubit),
          BlocProvider<SettingsCubit>.value(value: _settingsCubit),
          BlocProvider<AppShellCubit>.value(value: _shellCubit),
        ],
        // The single-window two-mode shell (ADR-0003): it owns the ONE shared
        // JourneyGame and switches between the full UI and the compact PiP. Its
        // `fullBuilder` builds the existing onboarding-gated tab UI, embedding
        // the shared scene in the journey tab (AC-9).
        child: AppShell(
          clock: _clock,
          controller: widget.windowController,
          visibility: widget.windowVisibility,
          fullBuilder: (JourneyGame sharedGame) {
            return BlocBuilder<SettingsCubit, AppSettings>(
              buildWhen: (prev, next) =>
                  prev.onboardingSeen != next.onboardingSeen,
              builder: (context, settings) {
                if (!settings.onboardingSeen) {
                  // First-run gate: show onboarding until completed (AC-20).
                  return OnboardingScreen(
                    onComplete: () =>
                        context.read<SettingsCubit>().markOnboardingSeen(),
                  );
                }
                return _HomeTabs(
                  clock: _clock,
                  chain: vietnamProvinceChain,
                  geography: vietnamProvinceGeography,
                  sharedGame: sharedGame,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// A lightweight tab shell — journey, map, stats, badges, settings — matching
/// the existing minimal `NavigationBar` style (no over-built navigation).
///
/// The journey tab renders the [sharedGame] (the single shared scene owned by
/// the app shell, AC-9) and carries the compact / PiP control (AC-6) that asks
/// the [AppShellCubit] to enter compact mode.
class _HomeTabs extends StatefulWidget {
  const _HomeTabs({
    required this.clock,
    required this.chain,
    required this.geography,
    required this.sharedGame,
  });

  final Clock clock;
  final ProvinceChain chain;
  final ProvinceGeography geography;
  final JourneyGame sharedGame;

  @override
  State<_HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<_HomeTabs> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          // The journey tab binds to the shared scene + carries the PiP control.
          // The Flame scene fills the whole tab; the map rides on top as a
          // small MOBA-style minimap floating bottom-right (map-experience
          // AC-1: no standalone Map tab — the map lives here, full-screen on
          // tap). The reduce-motion indicator (top-left), distance counter
          // (top-right), and PiP button (bottom-left) keep the other corners,
          // so the minimap's bottom-right corner is clear.
          Stack(
            children: <Widget>[
              // The Flame journey scene fills the whole tab.
              Positioned.fill(
                child: JourneyScreen(
                  clock: widget.clock,
                  sharedGame: widget.sharedGame,
                ),
              ),
              // The minimap floats bottom-right (AC-1/AC-2) — the overlay
              // anchors itself; tap opens the full-screen map.
              InlineMapOverlay(
                chain: widget.chain,
                geography: widget.geography,
              ),
              const _CompactPipButton(),
            ],
          ),
          const StatsScreen(),
          const BadgesScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.directions_bike),
            label: 'Journey',
          ),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Stats'),
          NavigationDestination(
            icon: Icon(Icons.emoji_events),
            label: 'Badges',
          ),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

/// The compact / PiP control in the main window (AC-6): collapses to the
/// compact view via the [AppShellCubit]. A small icon button over the scene.
class _CompactPipButton extends StatelessWidget {
  const _CompactPipButton();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        // Bottom-left so it never overlaps the reduce-motion indicator
        // (top-left) or the distance counter (top-right).
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Material(
            color: Colors.black.withValues(alpha: 0.55),
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Compact view (Picture-in-Picture)',
              icon: const Icon(
                Icons.picture_in_picture_alt,
                color: Colors.white,
              ),
              onPressed: () {
                // Guarded (S1): enterCompact may rethrow; log rather than leak
                // an unhandled future.
                context.read<AppShellCubit>().enterCompact().catchError((
                  Object error,
                  StackTrace stack,
                ) {
                  debugPrint('enterCompact (PiP button) failed: $error');
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}
