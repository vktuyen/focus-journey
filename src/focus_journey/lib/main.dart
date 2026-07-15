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
///
/// journey-reset (AC-4): the DI graph is split into two layers. [FocusJourneyApp]
/// is the STABLE root — it owns the long-lived native window/tray/visibility
/// controllers, the persistence seams, and the aggregating [LocalDataResetService]
/// + its [FactoryResetCubit], all of which SURVIVE a Factory reset. The
/// reconstructable in-memory graph (engine, ticker, and the journey/route/map/
/// stats/settings/shell/launch-gate Blocs) lives in [_JourneyRuntime], keyed by a
/// `_generation` counter: a Factory reset re-reads the (now-empty) persistence and
/// bumps the counter, so Flutter tears the whole runtime down and rebuilds it to a
/// ZERO state — routing back through the bootstrap path so no stale value can
/// re-persist on the next autosave (TC-706).
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
import 'features/mini_window/data/shared_preferences_hide_to_tray_hint_repository.dart';
import 'features/mini_window/domain/hide_to_tray_hint_repository.dart';
import 'features/mini_window/domain/tray_controller.dart';
import 'features/mini_window/domain/tray_state.dart';
import 'features/mini_window/domain/window_mode.dart';
import 'features/mini_window/domain/window_mode_controller.dart';
import 'features/mini_window/presentation/app_shell.dart';
import 'features/mini_window/presentation/app_shell_cubit.dart';
import 'features/mini_window/presentation/journey_tray_mapper.dart';
import 'features/reset/data/reset_service_factory.dart';
import 'features/reset/domain/local_data_reset_service.dart';
import 'features/reset/presentation/factory_reset_cubit.dart';
import 'features/reset/presentation/launch_gate_cubit.dart';
import 'features/reset/presentation/launch_prompt.dart';
import 'features/window_visibility/data/window_visibility_factory.dart';
import 'features/window_visibility/domain/window_visibility_controller.dart';
import 'features/route/data/base_map_repository.dart';
import 'features/route/data/shared_preferences_route_repository.dart';
import 'features/route/domain/base_map_geometry.dart';
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

  // vietnam-map-fidelity (ADR-0008): load + parse the bundled offline Vietnam
  // 34-province base map ONCE at startup (a bundled static asset — no network,
  // no location; AC-10). Parse failure must never block launch, so fall back to
  // the empty base (the map degrades to overlays-on-sea rather than crashing).
  final baseMap = await _loadBaseMap();

  // Register the local-notifier dep (privacy-clean — local OS toasts only, no
  // network). `setup` is required before any toast is shown. launch_at_startup
  // is configured in FocusJourneyApp.initState with the executable path.
  await localNotifier.setup(appName: 'Vietnam Focus Journey');

  // --- Persistence seams. All share the ONE prefs instance (so a wipe over any
  // instance is visible to every other). journey-reset (AC-3): each concrete
  // repo is a `LocalDataStore`, so the aggregating reset service can clear it.
  final routeRepository = SharedPreferencesRouteRepository(
    prefs,
    vietnamProvinceChain,
    vietnamProvinceGeography,
  );
  final settingsRepository = SharedPreferencesSettingsRepository(prefs);
  final historyRepository = SharedPreferencesHistoryRepository(prefs);
  final earnedBadgesRepository = SharedPreferencesEarnedBadgesRepository(prefs);
  final hideToTrayHintRepository = SharedPreferencesHideToTrayHintRepository(
    prefs,
  );

  // journey-reset (AC-3 / TC-704/TC-705): THE single aggregating wipe seam over
  // EVERY persisted store, built by the ONE shared factory that the drift-guard
  // test (TC-705) also consumes — so the production registry and the asserted
  // canonical key set can never silently diverge. A new persisted key added in
  // a later wave must be registered in `buildResetService` or Factory reset
  // silently misses it (and the drift guard fails).
  final resetService = buildResetService(prefs);

  // --- mini-window slice (ADR-0003): the single-window two-mode shell + tray.
  // These native backends are created ONCE and survive a Factory reset re-init
  // (they are NOT part of the reconstructable in-memory graph). `window.setup()`
  // must run BEFORE runApp so the close intercept + min sizes are registered.
  final window = MiniWindowFactory.createWindowModeController(prefs);
  await window.setup();
  final tray = MiniWindowFactory.createTrayController();
  await tray.init();
  final windowVisibility = WindowVisibilityFactory.create();
  await windowVisibility.start();

  runApp(
    FocusJourneyApp(
      baseMap: baseMap,
      routeRepository: routeRepository,
      settingsRepository: settingsRepository,
      historyRepository: historyRepository,
      earnedBadgesRepository: earnedBadgesRepository,
      hideToTrayHintRepository: hideToTrayHintRepository,
      resetService: resetService,
      windowController: window,
      windowVisibility: windowVisibility,
      trayController: tray,
    ),
  );
}

/// Loads the bundled Vietnam base-map geometry (ADR-0008). A parse/read failure
/// must never block launch, so it degrades to the empty base (overlays render
/// over the themed sea) rather than crashing the app.
Future<BaseMapGeometry> _loadBaseMap() async {
  try {
    return await AssetBaseMapRepository().load();
  } catch (error, stack) {
    // Degrade to the empty base rather than crash, but never SILENTLY: a
    // missing/renamed/malformed bundled asset otherwise reproduces a blank sea
    // (AC-1/AC-2) with no signal. Log it with context so the regression is
    // diagnosable (a pubspec/manifest drift shows up here, not just on screen).
    debugPrint(
      'Failed to load bundled base map "$kBaseMapAssetPath"; falling back to '
      'the empty base (overlays render over the sea). Error: $error\n$stack',
    );
    return BaseMapGeometry.empty();
  }
}

/// Root of the Vietnam Focus Journey app. The STABLE composition layer: it owns
/// the long-lived native controllers, the persistence seams, and the Factory
/// reset seam — all of which survive a Factory reset — and hosts the
/// reconstructable [_JourneyRuntime] keyed by a `_generation` counter (AC-4).
class FocusJourneyApp extends StatefulWidget {
  /// Creates the app root with the injected persistence + native seams.
  const FocusJourneyApp({
    required this.baseMap,
    required this.routeRepository,
    required this.settingsRepository,
    required this.historyRepository,
    required this.earnedBadgesRepository,
    required this.hideToTrayHintRepository,
    required this.resetService,
    required this.windowController,
    required this.windowVisibility,
    required this.trayController,
    super.key,
  });

  /// The bundled Vietnam base-map geometry (vietnam-map-fidelity / ADR-0008).
  /// A long-lived static asset loaded once at startup and passed down to the map
  /// surfaces; it survives a Factory reset (it is not part of the
  /// reconstructable in-memory graph).
  final BaseMapGeometry baseMap;

  /// The route persistence seam (used to re-read state after a reset too).
  final RouteRepository routeRepository;

  /// The settings persistence seam.
  final SettingsRepository settingsRepository;

  /// The bounded per-day history persistence seam.
  final HistoryRepository historyRepository;

  /// The earned-badge persistence seam.
  final EarnedBadgesRepository earnedBadgesRepository;

  /// The one-time hide-to-tray hint persistence seam (AC-17).
  final HideToTrayHintRepository hideToTrayHintRepository;

  /// journey-reset (AC-3): the aggregating wipe seam over every store.
  final LocalDataResetService resetService;

  /// The single-window controller seam (full ⇄ compact, hide-to-tray, quit).
  final WindowModeController windowController;

  /// journey-scene-v2 #5: the per-surface OS occlusion/visibility seam.
  final WindowVisibilityController windowVisibility;

  /// The tray/menu-bar controller seam (icon/menu + action stream).
  final TrayController trayController;

  @override
  State<FocusJourneyApp> createState() => _FocusJourneyAppState();
}

class _FocusJourneyAppState extends State<FocusJourneyApp> {
  final Clock _clock = const SystemClock();

  // The restored persisted state seeding the current runtime. Re-read from the
  // (now-empty) persistence after a Factory reset, then the generation is bumped
  // to rebuild the runtime from it (AC-4/AC-5).
  RoutePlan? _savedPlan;
  AppSettings? _savedSettings;
  bool _hintAlreadyShown = false;

  /// Bumped on each Factory reset so the keyed [_JourneyRuntime] is torn down and
  /// rebuilt to a zero state (AC-4).
  int _generation = 0;

  /// Whether the initial persisted-state load has completed (first-run only —
  /// avoids a UI flash before the restored route/settings are known).
  bool _loaded = false;

  late final FactoryResetCubit _resetCubit;

  @override
  void initState() {
    super.initState();
    // Configure launch-at-startup with the running executable (read no OS state
    // here — the SettingsCubit reads/sets via the StartupController interface).
    launchAtStartup.setup(
      appName: 'Vietnam Focus Journey',
      appPath: _executablePath(),
    );
    // journey-reset (AC-3/AC-4): the Factory reset action clears all data via the
    // service, then re-initialises the in-memory graph via `_reinitialise` —
    // this cubit lives ABOVE the reconstructed runtime, so it survives the bump.
    _resetCubit = FactoryResetCubit(
      service: widget.resetService,
      onQuiesce: _quiesce,
      onReinitialise: _reinitialise,
    );
    _loadPersistedState(firstRun: true);
  }

  /// Loads the persisted state that seeds a runtime (first-run bootstrap).
  /// Replaces `main()`'s inline loads. `_loaded` gates a one-frame splash so the
  /// first paint is never a flash of an un-restored route.
  Future<void> _loadPersistedState({required bool firstRun}) async {
    final plan = await widget.routeRepository.loadPlan();
    final settings = await widget.settingsRepository.load();
    final hint = await widget.hideToTrayHintRepository.hasShownHint();
    if (!mounted) {
      return;
    }
    setState(() {
      _savedPlan = plan;
      _savedSettings = settings;
      _hintAlreadyShown = hint;
      _loaded = true;
      if (!firstRun) {
        _generation++;
      }
    });
  }

  /// journey-reset (AC-4 step 1): tear down the LIVE in-memory graph before the
  /// disk is cleared. Unmounting the keyed `_JourneyRuntime` disposes the ticker
  /// + closes the Blocs, so no old autosave can re-persist stale state during the
  /// wipe. Awaiting `endOfFrame` guarantees the dispose has actually run before
  /// the caller proceeds to clear the disk.
  Future<void> _quiesce() async {
    if (!mounted) {
      return;
    }
    setState(() => _loaded = false);
    await WidgetsBinding.instance.endOfFrame;
  }

  /// journey-reset (AC-4 step 3): rebuild the graph to a ZERO state from the
  /// now-empty persistence (the bootstrap path). Bumps `_generation` so even if
  /// Flutter tried to reuse the element, a fresh runtime State is forced.
  Future<void> _reinitialise() => _loadPersistedState(firstRun: false);

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
    _resetCubit.close();
    // Tear down the native seams once, at true app end (NOT on a reset re-init).
    widget.windowController.dispose();
    widget.windowVisibility.dispose();
    widget.trayController.dispose();
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
      home: !_loaded
          ? const _BootstrapSplash()
          : BlocProvider<FactoryResetCubit>.value(
              value: _resetCubit,
              // Keyed by generation: a Factory reset bumps it, so the runtime
              // (engine, ticker, Blocs, shared scene) is disposed + rebuilt to a
              // zero state (AC-4). The FactoryResetCubit above survives the bump.
              child: _JourneyRuntime(
                key: ValueKey<int>(_generation),
                clock: _clock,
                baseMap: widget.baseMap,
                routeRepository: widget.routeRepository,
                settingsRepository: widget.settingsRepository,
                historyRepository: widget.historyRepository,
                earnedBadgesRepository: widget.earnedBadgesRepository,
                hideToTrayHintRepository: widget.hideToTrayHintRepository,
                windowController: widget.windowController,
                windowVisibility: widget.windowVisibility,
                trayController: widget.trayController,
                savedPlan: _savedPlan,
                savedSettings: _savedSettings,
                hintAlreadyShown: _hintAlreadyShown,
              ),
            ),
    );
  }
}

/// A minimal splash shown only during the initial persisted-state load (a frame
/// or two) so the first render is never a flash of an un-restored route.
class _BootstrapSplash extends StatelessWidget {
  const _BootstrapSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.shrink());
  }
}

/// The reconstructable in-memory graph (AC-4): engine, ticker, and the
/// journey/route/map/stats/settings/shell/launch-gate Blocs, plus the mini-window
/// wiring. Rebuilt from scratch (new instances, zero state) whenever its key
/// changes on a Factory reset. The native controllers are injected (owned by the
/// stable [FocusJourneyApp]); this widget NEVER disposes them.
class _JourneyRuntime extends StatefulWidget {
  const _JourneyRuntime({
    required this.clock,
    required this.baseMap,
    required this.routeRepository,
    required this.settingsRepository,
    required this.historyRepository,
    required this.earnedBadgesRepository,
    required this.hideToTrayHintRepository,
    required this.windowController,
    required this.windowVisibility,
    required this.trayController,
    required this.savedPlan,
    required this.savedSettings,
    required this.hintAlreadyShown,
    super.key,
  });

  final Clock clock;
  final BaseMapGeometry baseMap;
  final RouteRepository routeRepository;
  final SettingsRepository settingsRepository;
  final HistoryRepository historyRepository;
  final EarnedBadgesRepository earnedBadgesRepository;
  final HideToTrayHintRepository hideToTrayHintRepository;
  final WindowModeController windowController;
  final WindowVisibilityController windowVisibility;
  final TrayController trayController;
  final RoutePlan? savedPlan;
  final AppSettings? savedSettings;
  final bool hintAlreadyShown;

  @override
  State<_JourneyRuntime> createState() => _JourneyRuntimeState();
}

class _JourneyRuntimeState extends State<_JourneyRuntime> {
  late final ActivityPlugin _activityPlugin;
  late final JourneyCubit _cubit;
  late final RouteProgressCubit _routeCubit;
  late final MapCubit _mapCubit;
  late final StatsCubit _statsCubit;
  late final SettingsCubit _settingsCubit;
  late final AppShellCubit _shellCubit;
  late final LaunchGateCubit _launchGateCubit;

  // mini-window slice subscriptions (tray actions, journey→tray, close→hint).
  StreamSubscription<TrayAction>? _trayActionsSub;
  StreamSubscription<JourneyViewState>? _journeyToTraySub;
  StreamSubscription<WindowMode>? _modeToTraySub;
  StreamSubscription<void>? _hiddenToTraySub;

  // Engine + ticker are mutable so the idle-threshold seam can rebuild them
  // (preserving progress) without touching engine/ticker code (AC-8).
  late JourneyEngine _engine;
  late ActivityTicker _ticker;

  Clock get _clock => widget.clock;

  @override
  void initState() {
    super.initState();
    _activityPlugin = ActivityPluginFactory.create(
      mockSeed: ActivityPluginFactory.useMock
          ? MockActivitySource(idleSeconds: 0, screenLocked: false)
          : null,
    );

    _cubit = JourneyCubit();
    // route-planner-v2 (ADR-0005): the route cubit holds the FULL chain +
    // geography and derives the active plan's SUB-CHAIN. A restored active/
    // completed plan seeds it (AC-12). After a Factory reset, savedPlan is null.
    _routeCubit = RouteProgressCubit(
      chain: vietnamProvinceChain,
      geography: vietnamProvinceGeography,
      repository: widget.routeRepository,
      initialPlan: widget.savedPlan,
    );
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
      applyIdleThreshold: _applyIdleThreshold,
      onSettingsChanged: _statsCubit.updateSettings,
      initialSettings: widget.savedSettings,
    );
    _statsCubit.updateSettings(_settingsCubit.state);

    // journey-reset (AC-6/AC-7): the launch gate is seeded from the persisted
    // route lifecycle. An `active` route → show the Resume/Start over prompt;
    // otherwise (fresh, post-reset, completed, abandoned) → proceed, no prompt.
    _launchGateCubit = LaunchGateCubit(lifecycle: widget.savedPlan?.lifecycle);

    // Feed route position to stats on the route cubit's stream (plain snapshot).
    _routeCubit.stream.listen(_onRouteChanged);
    _mapCubit.updateFromRoute(_routeCubit.state);

    // Restore stats from persisted stores + the engine's restored snapshot.
    _statsCubit.load(_engine.toProgress());
    _mapCubit.updateFromSnapshot(_engine.toProgress());

    _ticker.start();
    _wireMiniWindow();
  }

  /// Wires the mini-window slice (ADR-0003): the mode cubit, tray action routing,
  /// journey→tray reflection, the close-to-tray hint, and the Quit flush hook.
  /// The window/tray controllers are injected (owned by [FocusJourneyApp]); this
  /// method adds NO journey/engine logic — it only (re-)wires, and its
  /// subscriptions are cancelled in [dispose] so a reset rebuild re-subscribes
  /// cleanly (the controller streams are broadcast).
  void _wireMiniWindow() {
    _shellCubit = AppShellCubit(
      controller: widget.windowController,
      hintAlreadyShown: widget.hintAlreadyShown,
    );

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

    _pushJourneyToTray(_cubit.state);
    _journeyToTraySub = _cubit.stream.listen(_pushJourneyToTray);

    widget.trayController.setMode(widget.windowController.mode);
    _modeToTraySub = widget.windowController.modeChanges.listen(
      widget.trayController.setMode,
    );

    _hiddenToTraySub = widget.windowController.hiddenToTray.listen((_) {
      final shouldPersist = _shellCubit.onHiddenToTray();
      if (shouldPersist) {
        widget.hideToTrayHintRepository.markHintShown();
      }
    });

    // Quit flush hook (AC-16) — replaces any previously registered hook, so a
    // reset rebuild does not stack callbacks.
    widget.windowController.onBeforeQuit(_flushOnQuit);
  }

  void _pushJourneyToTray(JourneyViewState s) {
    widget.trayController.setState(JourneyTrayMapper.stateFor(s));
    widget.trayController.setStatusLine(JourneyTrayMapper.statusLineFor(s));
  }

  void _guardTransition(String action, Future<void> future) {
    future.catchError((Object error, StackTrace stack) {
      debugPrint('Window transition "$action" failed: $error');
    });
  }

  Future<void> _flushOnQuit() async {
    try {
      await _statsCubit.onTick(_engine.toProgress());
    } catch (_) {
      // Never let a flush failure block the user's Quit.
    }
  }

  void _onRouteChanged(RouteViewState state) {
    _mapCubit.updateFromRoute(state);
    final position = state.position;
    _statsCubit.updateRoute(
      position == null
          ? const RouteProgressSnapshot.none()
          : RouteProgressSnapshot(
              percentOfCountry: position.percentOfCountry,
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
      onSnapshot: (JourneyProgress snapshot) {
        _statsCubit.onTick(snapshot);
        _mapCubit.updateFromSnapshot(snapshot);
      },
      log: (String message) => debugPrint(message),
    );
  }

  /// The settings→engine idle-threshold seam (AC-8): rebuild the engine with the
  /// new threshold, preserving its current progress, and restart the ticker.
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

  @override
  void dispose() {
    _trayActionsSub?.cancel();
    _journeyToTraySub?.cancel();
    _modeToTraySub?.cancel();
    _hiddenToTraySub?.cancel();
    _shellCubit.close();
    _launchGateCubit.close();
    // NOTE: the native window/tray/visibility controllers are owned by
    // FocusJourneyApp and are NOT disposed here (a reset rebuild reuses them).
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
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<JourneyCubit>.value(value: _cubit),
        BlocProvider<RouteProgressCubit>.value(value: _routeCubit),
        BlocProvider<MapCubit>.value(value: _mapCubit),
        BlocProvider<StatsCubit>.value(value: _statsCubit),
        BlocProvider<SettingsCubit>.value(value: _settingsCubit),
        BlocProvider<AppShellCubit>.value(value: _shellCubit),
        BlocProvider<LaunchGateCubit>.value(value: _launchGateCubit),
      ],
      // The single-window two-mode shell (ADR-0003): it owns the ONE shared
      // JourneyGame and switches between the full UI and the compact PiP.
      child: AppShell(
        clock: _clock,
        controller: widget.windowController,
        visibility: widget.windowVisibility,
        fullBuilder: (JourneyGame sharedGame) {
          // journey-reset (AC-6): the launch gate runs BEFORE entering the
          // journey. When an `active` route exists, show the Resume vs Start over
          // prompt; otherwise fall through to the onboarding gate (AC-5/AC-7).
          return BlocBuilder<LaunchGateCubit, bool>(
            builder: (context, showPrompt) {
              if (showPrompt) {
                return LaunchPrompt(
                  chain: vietnamProvinceChain,
                  geography: vietnamProvinceGeography,
                );
              }
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
                    baseMap: widget.baseMap,
                    sharedGame: sharedGame,
                  );
                },
              );
            },
          );
        },
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
    required this.baseMap,
    required this.sharedGame,
  });

  final Clock clock;
  final ProvinceChain chain;
  final ProvinceGeography geography;
  final BaseMapGeometry baseMap;
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
          Stack(
            children: <Widget>[
              Positioned.fill(
                child: JourneyScreen(
                  clock: widget.clock,
                  sharedGame: widget.sharedGame,
                ),
              ),
              InlineMapOverlay(
                chain: widget.chain,
                geography: widget.geography,
                baseMap: widget.baseMap,
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
