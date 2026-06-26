/// Presentation layer. The Cubit that turns the engine's `JourneyProgress`
/// aggregate (segments + cumulative distance) + the user's [RouteSelection] /
/// resolved [RoutePosition] into a projected [MapViewState] for the map surface
/// (inline overlay + full-screen).
///
/// SEPARATION / PRIVACY INVARIANT (AC-12 / NFR-2 / TC-226/TC-227/TC-228/TC-230) —
/// TRUE BY CONSTRUCTION: this cubit holds **no** `JourneyEngine` reference, **no**
/// `ActivityPlugin`, **no** `MethodChannel`, and **no** geolocation/GPS. It
/// consumes two read-only inputs:
///   - a plain [JourneyProgress] value object via [updateFromSnapshot] (the same
///     aggregate the ticker already forwards to stats — segments + cumulative
///     distance), and
///   - the route [RouteViewState] via [updateFromRoute] (the resolved position +
///     the active selection, from the unchanged [RouteProgressCubit]).
/// It therefore *cannot* read OS signals, mutate engine state, re-classify idle,
/// or accrue distance — it only PROJECTS given data onto the static
/// [ProvinceGeography]. It is a read-only consumer; toggling it writes nothing
/// back (TC-226).
///
/// DISTANCE/SEGMENT SOURCE SEAM (for tests): drive [updateFromSnapshot] with a
/// scripted [JourneyProgress] and [updateFromRoute] with a scripted
/// [RouteViewState] — no real engine, no timers, no network.
library;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../journey/domain/activity_segment.dart';
import '../../journey/domain/journey_progress.dart';
import '../domain/geo_polyline.dart';
import '../domain/idle_trace_mapper.dart';
import '../domain/province_geography.dart';
import '../domain/route_polyline_projector.dart';
import '../domain/route_position.dart';
import '../domain/route_selection.dart';
import 'map_view_state.dart';
import 'route_view_state.dart';

/// Emits [MapViewState] snapshots for the map surface.
class MapCubit extends Cubit<MapViewState> {
  /// Creates the cubit over the injected static [geography] (the single
  /// geography model — AC-5). Optionally seed with a restored [initialSelection]
  /// so the base road is present before the first tick.
  MapCubit({
    required ProvinceGeography geography,
    RouteSelection? initialSelection,
  }) : _geography = geography,
       super(const MapViewState.initial()) {
    if (initialSelection != null) {
      _selection = initialSelection;
      _recompute();
    }
  }

  final ProvinceGeography _geography;

  RouteSelection? _selection;
  RoutePosition? _position;
  double? _countryPercent;
  List<ActivitySegment> _segments = const <ActivitySegment>[];
  RoutePolylineProjector? _projector;

  /// route-planner-v2 (ADR-0005): the active route's DERIVED sub-chain geography,
  /// supplied by the route view state. The projector runs over THIS so the
  /// polyline + red trace draw the authored sub-path (AC-7), not the full spine.
  /// `null` on the legacy full-chain path → falls back to the injected
  /// [_geography]. The projector is the unchanged [RoutePolylineProjector].
  ProvinceGeography? _routeGeography;

  /// Receives the engine's latest [JourneyProgress] aggregate (segments +
  /// cumulative distance — the only thing this slice reads from the engine).
  /// Re-projects and emits. Pure read; never mutates the snapshot (AC-12).
  void updateFromSnapshot(JourneyProgress snapshot) {
    _segments = snapshot.segments;
    _recompute();
  }

  /// Receives the route slice's latest [RouteViewState] (selection + resolved
  /// position) from the unchanged [RouteProgressCubit]. Re-projects and emits.
  void updateFromRoute(RouteViewState route) {
    final newSelection = route.selection;
    // route-planner-v2: use the route's derived sub-chain geography when present
    // (v2 authored route), else the injected full geography (legacy path).
    final newGeography = route.subGeography ?? _geography;
    // Rebuild the projector only when the route identity changes (start /
    // direction / offset / sub-geography) — NOT on a mere distance tick — so the
    // static route geometry is not re-projected per frame (NFR-1 / TC-229).
    if (newSelection?.start != _selection?.start ||
        newSelection?.direction != _selection?.direction ||
        newSelection?.routeStartOffsetKm != _selection?.routeStartOffsetKm ||
        !identical(newGeography, _routeGeography)) {
      _projector = null;
    }
    _selection = newSelection;
    _routeGeography = newGeography;
    _position = route.position;
    _countryPercent = route.countryPercent;
    _recompute();
  }

  /// Projects the current inputs into a [MapViewState] and emits. No-op
  /// (stays at the pre-selection default) when no route is active.
  void _recompute() {
    final selection = _selection;
    final position = _position;
    if (selection == null || position == null) {
      emit(const MapViewState.initial());
      return;
    }

    // Build (or reuse) the route projector over the active route geography (the
    // derived sub-chain for v2, else the full geography — AC-7). Cached so the
    // static base polyline is projected once per route, not per tick.
    final projector = _projector ??= RoutePolylineProjector(
      selection: selection,
      geography: _routeGeography ?? _geography,
    );

    // The marker keys off the resolved `routeDistanceKm` (the SAME math
    // route-progress uses — AC-5/TC-211), never raw cumulative (TC-212).
    final marker = projector.coordinateAt(position.routeDistanceKm);

    // The red trace maps the current-route idle segments (Decision C). Segments
    // are absolute-cumulative-km; re-base by the route offset + clip to the
    // current route (TC-214). Empty for a zero-idle route (AC-7). The mapper
    // READS the segments as-is — no re-classification, no accrual (AC-12).
    final idleStretches = IdleTraceMapper.resolve(
      segments: _segments,
      routeStartOffsetKm: selection.routeStartOffsetKm,
      projector: projector,
    );

    emit(
      MapViewState(
        selection: selection,
        position: position,
        countryPercent: _countryPercent,
        baseRoutePolyline: GeoPolyline(projector.baseRoutePolyline),
        orderedNodes: projector.orderedNodes,
        markerPosition: marker,
        idleStretches: idleStretches,
      ),
    );
  }
}
