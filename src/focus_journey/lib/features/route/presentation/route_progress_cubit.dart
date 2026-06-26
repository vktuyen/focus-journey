/// Presentation layer. The Cubit that turns the engine's cumulative `distanceKm`
/// scalar + the user's authored route into a resolved [RouteViewState] for the
/// map screen.
///
/// SEPARATION / PRIVACY INVARIANT (AC-16/AC-17 / route-planner-v2 NFR-2) — TRUE
/// BY CONSTRUCTION: this cubit holds **no** `JourneyEngine` reference. It consumes
/// a plain `double` cumulative distance via [updateFromDistance] (fed by the
/// app-service ticker on the same cadence as the journey view). It therefore
/// *cannot* read OS signals, cannot touch a platform channel, cannot read device
/// location, and cannot mutate engine state — it only maps a given scalar onto the
/// chain via the pure [RouteProgressResolver]. It imports neither `ActivityPlugin`
/// nor any `MethodChannel`.
///
/// ## route-planner-v2 (ADR-0005)
/// The v2 authored route is a derived contiguous SUB-CHAIN of the curated spine
/// ([RoutePlan] → [ResolvedRoute]). The cubit is constructed with the **full**
/// chain + geography, derives the active plan's sub-chain via [RoutePlanner], and
/// runs the **unchanged** [RouteProgressResolver] over the SUB-CHAIN (AC-7). It
/// computes **country %** = `(canonicalOriginKm + effectiveDistance) ÷
/// fullChainTotalKm` itself (ADR-0005 decision 3 — the presentation layer owns it,
/// since it holds the full chain) alongside the resolver's route % (AC-8).
///
/// **Backward-compat:** when seeded with a legacy [RouteSelection]
/// (`initialSelection`) the cubit resolves over the injected `chain` exactly as
/// the shipped route-progress build did — so the shipped cubit tests pass
/// unchanged. The new plan-centric flow is opt-in via [confirmRoute] /
/// [abandonAndStartNew] / `initialPlan`.
///
/// DISTANCE-SOURCE SEAM (for tests): drive [updateFromDistance] directly with a
/// scripted cumulative value — no real engine, no timers.
library;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/journey_direction.dart';
import '../domain/province.dart';
import '../domain/province_chain.dart';
import '../domain/province_geography.dart';
import '../domain/route_plan.dart';
import '../domain/route_planner.dart';
import '../domain/route_position.dart';
import '../domain/route_progress_resolver.dart';
import '../domain/route_repository.dart';
import '../domain/route_selection.dart';
import 'route_view_state.dart';

/// Emits [RouteViewState] snapshots for the map screen.
class RouteProgressCubit extends Cubit<RouteViewState> {
  /// Creates the cubit with the injected [chain] geometry and [repository]
  /// persistence seam.
  ///
  /// - [initialSelection] seeds the legacy (route-progress) restore path:
  ///   resolution runs over [chain] directly (shipped behaviour, unchanged).
  /// - [initialPlan] + [geography] seed the v2 restore path: the plan's sub-chain
  ///   is derived and resolution runs over IT (AC-7/AC-12). When a plan is
  ///   supplied, [geography] is required to rebuild the sub-geography.
  RouteProgressCubit({
    required ProvinceChain chain,
    required RouteRepository repository,
    ProvinceGeography? geography,
    RouteSelection? initialSelection,
    RoutePlan? initialPlan,
  }) : _chain = chain,
       _geography = geography,
       _repository = repository,
       super(const RouteViewState.initial()) {
    if (initialPlan != null && !initialPlan.isAbandoned) {
      // Adopt a restored ACTIVE or COMPLETED plan onto its sub-chain (a completed
      // plan still shows arrival on its sub-chain). An abandoned plan is never the
      // active route, so it is not adopted (the runtime abandon path never writes
      // that lifecycle — see `abandonAndStartNew`); it falls through to no route.
      _adoptPlan(initialPlan);
      _emitResolved();
    } else if (initialSelection != null) {
      _selection = initialSelection;
      _emitResolved();
    }
  }

  final ProvinceChain _chain;
  final ProvinceGeography? _geography;
  final RouteRepository _repository;

  /// The internal per-sub-chain resolver/projector input (AC-7). For a legacy
  /// selection this is the selection over [_chain]; for a v2 plan it is derived
  /// (sub-chain tip + implied direction).
  RouteSelection? _selection;

  /// The active plan (v2) — `null` on the legacy path.
  RoutePlan? _plan;

  /// The active plan's derived sub-chain bundle (v2) — `null` on the legacy path.
  /// When set, the resolver runs over `_resolved.subChain` (AC-7).
  ResolvedRoute? _resolved;

  double _cumulativeDistanceKm = 0;

  /// The chain the resolver runs over: the derived sub-chain for a v2 plan, else
  /// the injected full chain (legacy path).
  ProvinceChain get _routeChain => _resolved?.subChain ?? _chain;

  /// Receives the engine's latest cumulative `distanceKm` (a plain scalar — the
  /// only thing this slice reads from the engine; AC-16). Re-resolves and emits.
  void updateFromDistance(double cumulativeDistanceKm) {
    _cumulativeDistanceKm = cumulativeDistanceKm;
    _emitResolved();
  }

  /// Confirms a reviewed v2 route (AC-6/AC-7): the ONLY mutation a review cycle
  /// performs. Stamps exactly one [routeStartOffsetKm] (= the current cumulative
  /// `distanceKm`, route-progress decision 1) and begins travel over the
  /// [resolved] sub-chain. Persists the new active [RoutePlan].
  ///
  /// [currentCumulativeKm] overrides the captured offset (defaults to the last
  /// value seen via [updateFromDistance]) — the engine's lifetime cumulative.
  Future<void> confirmRoute(
    ResolvedRoute resolved, {
    double? currentCumulativeKm,
  }) async {
    final offset = currentCumulativeKm ?? _cumulativeDistanceKm;
    if (currentCumulativeKm != null) {
      _cumulativeDistanceKm = currentCumulativeKm;
    }
    final plan = RoutePlan.fromResolved(resolved, routeStartOffsetKm: offset);
    _plan = plan;
    _resolved = resolved;
    _selection = plan.toSelection(resolved);
    _emitResolved();
    await _repository.savePlan(plan);
  }

  /// Abandons the current route and starts a fresh one over [resolved] (AC-10).
  ///
  /// Stamps a NEW [routeStartOffsetKm] (= the engine's current cumulative
  /// `distanceKm`) so the new route restarts at `routeDistanceKm = 0`, and
  /// **never** resets the engine's cumulative (no engine reset API — AC-10).
  /// Persists the new active plan.
  ///
  /// The abandon CONFIRM GUARD (AC-9 — "you'll lose progress") is a presentation
  /// concern (the dialog) — this method is the post-confirm mutation. Callers must
  /// only invoke it after the guard is confirmed; cancelling the guard simply
  /// never calls this, leaving everything untouched.
  ///
  /// **The prior plan is DISCARDED, not marked/persisted.** There is a single
  /// active-plan slot and no abandoned-history surface (ADR-0005 decision 5), so
  /// `confirmRoute` below simply overwrites that slot with the new route. This
  /// slice therefore **never writes** `RouteLifecycle.abandoned` at runtime — that
  /// enum value is RESERVED for forward-compatible JSON round-trip / value-object
  /// completeness only (the ADR is being amended to match this discard behaviour).
  /// AC-10 (abandoned ≠ completed, no celebration) holds structurally: the new
  /// active plan never carries a `completed` lifecycle, and the discarded plan
  /// never had completion latched, so the arrival celebration never fires on the
  /// abandon path.
  ///
  /// **No-bleed (AC-11) holds BY CONSTRUCTION — the engine's idle/active segments
  /// are NOT pruned.** Because the new offset = the abandon-instant cumulative,
  /// `IdleTraceMapper` re-bases every prior-route segment to `≤ 0` and clips it
  /// out of the new route's `[0, routeLengthKm]` window — so the new route paints
  /// only its own segments without any segment store being mutated. (The engine's
  /// cumulative — the lifetime total — is never reset; only the offset moves
  /// forward.)
  Future<void> abandonAndStartNew(
    ResolvedRoute resolved, {
    double? currentCumulativeKm,
  }) async {
    // No engine reset, ever — abandon = a new offset over the never-reset
    // cumulative (AC-10). The prior plan is dropped from the active slot by the
    // confirmRoute overwrite below (no abandoned-history surface — ADR-0005
    // decision 5); the engine's segments are NOT pruned (no-bleed is by
    // construction via IdleTraceMapper's re-base + clip — AC-11).
    await confirmRoute(resolved, currentCumulativeKm: currentCumulativeKm);
  }

  /// Whether the active route has progress to lose — drives the AC-9 abandon
  /// confirm guard (`routeDistanceKm > 0` and not completed). Computed from the
  /// last resolved view state so the dialog gate matches what the user sees.
  bool get hasProgressToLose {
    final position = state.position;
    if (position == null) {
      return false;
    }
    return !position.isCompleted && position.routeDistanceKm > 0;
  }

  /// LEGACY start path (route-progress): starts a route over the FULL [chain]
  /// from [start] heading [direction], capturing the current cumulative as the
  /// offset. Retained so the shipped cubit tests + any legacy caller keep working
  /// unchanged. New v2 callers use [confirmRoute].
  Future<void> startNewRoute(
    Province start,
    JourneyDirection direction, {
    double? currentCumulativeKm,
  }) async {
    final offset = currentCumulativeKm ?? _cumulativeDistanceKm;
    if (currentCumulativeKm != null) {
      _cumulativeDistanceKm = currentCumulativeKm;
    }
    final selection = RouteSelection.create(
      start: start,
      direction: direction,
      routeStartOffsetKm: offset,
      chain: _chain,
    );
    // Reset any v2 plan state — this is the legacy full-chain path.
    _plan = null;
    _resolved = null;
    _selection = selection;
    _emitResolved();
    await _repository.save(selection);
  }

  /// Adopts [plan] as the active v2 route: derives its sub-chain (requires the
  /// injected full [_geography]) and the internal selection over that sub-chain.
  void _adoptPlan(RoutePlan plan) {
    final geography = _geography;
    if (geography == null) {
      // Defensive: a plan was supplied without geography — fall back to no route
      // rather than crash (the data layer already validated the plan on load).
      return;
    }
    final resolved = plan.toResolved(_chain, geography);
    _plan = plan;
    _resolved = resolved;
    _selection = plan.toSelection(resolved);
  }

  /// Resolves the current selection against the current cumulative distance and
  /// emits. No-op (stays at the pre-selection default) when no route is active.
  void _emitResolved() {
    final selection = _selection;
    if (selection == null) {
      emit(
        RouteViewState(
          selection: null,
          subGeography: null,
          position: null,
          countryPercent: null,
          cumulativeDistanceKm: _cumulativeDistanceKm,
        ),
      );
      return;
    }
    final routeChain = _routeChain;
    final routeDistanceKm =
        _cumulativeDistanceKm - selection.routeStartOffsetKm;
    final position = RouteProgressResolver.resolve(
      routeDistanceKm: routeDistanceKm,
      selection: selection,
      chain: routeChain,
    );

    // Country % (ADR-0005 decision 3) = (canonicalOriginKm + effectiveDistance)
    // ÷ full-chain total, clamped [0,100]. The presentation layer owns it (it
    // holds the full chain). For the legacy path the sub-path IS the full chain,
    // so canonicalOriginKm is 0 and effectiveDistance/total == the resolver's own
    // percentOfCountry — i.e. nothing changes for legacy callers.
    final countryPercent = _computeCountryPercent(position.routeDistanceKm);

    // Latch completion: on the v2 path, flip the plan lifecycle to completed; on
    // the legacy path, latch the selection's completed flag (shipped behaviour).
    if (position.isCompleted) {
      _latchCompletion(selection, position, countryPercent);
      return;
    }

    emit(
      RouteViewState(
        selection: selection,
        subGeography: _resolved?.subGeography,
        position: position,
        countryPercent: countryPercent,
        cumulativeDistanceKm: _cumulativeDistanceKm,
      ),
    );
  }

  /// Latches completion exactly once so it survives a restart (AC-8 / AC-12) and
  /// stays terminal (route-progress AC-13). On the v2 path the persisted [RoutePlan]
  /// lifecycle flips to `completed`; on the legacy path the [RouteSelection]
  /// `completed` flag is set (shipped behaviour, unchanged).
  void _latchCompletion(
    RouteSelection selection,
    RoutePosition position,
    double? countryPercent,
  ) {
    final plan = _plan;
    if (plan != null) {
      // v2 path.
      if (!plan.isCompleted) {
        final completedPlan = plan.copyWith(
          lifecycle: RouteLifecycle.completed,
        );
        _plan = completedPlan;
        _selection = selection.copyWith(completed: true);
        emit(
          RouteViewState(
            selection: _selection,
            subGeography: _resolved?.subGeography,
            position: position,
            countryPercent: countryPercent,
            cumulativeDistanceKm: _cumulativeDistanceKm,
          ),
        );
        _repository.savePlan(completedPlan);
        return;
      }
      emit(
        RouteViewState(
          selection: selection,
          subGeography: _resolved?.subGeography,
          position: position,
          countryPercent: countryPercent,
          cumulativeDistanceKm: _cumulativeDistanceKm,
        ),
      );
      return;
    }
    // Legacy path (shipped behaviour, unchanged): latch the selection flag.
    if (!selection.completed) {
      final completedSelection = selection.copyWith(completed: true);
      _selection = completedSelection;
      emit(
        RouteViewState(
          selection: completedSelection,
          subGeography: null,
          position: position,
          countryPercent: countryPercent,
          cumulativeDistanceKm: _cumulativeDistanceKm,
        ),
      );
      _repository.save(completedSelection);
      return;
    }
    emit(
      RouteViewState(
        selection: selection,
        subGeography: null,
        position: position,
        countryPercent: countryPercent,
        cumulativeDistanceKm: _cumulativeDistanceKm,
      ),
    );
  }

  /// Country % over the FULL chain (ADR-0005 decision 3). `null` on the legacy
  /// path (no plan/resolved) — the resolver's `percentOfCountry` already IS the
  /// full-chain % there (it ran over the full chain), so there is no second %.
  double? _computeCountryPercent(double effectiveRouteDistanceKm) {
    final resolved = _resolved;
    if (resolved == null) {
      return null;
    }
    final total = _chain.totalChainKm;
    if (total <= 0) {
      return 0;
    }
    final covered = resolved.canonicalOriginKm + effectiveRouteDistanceKm;
    final percent = (covered / total) * 100;
    return percent.clamp(0.0, 100.0).toDouble();
  }
}
