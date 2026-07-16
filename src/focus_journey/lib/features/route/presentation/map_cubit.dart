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
import '../domain/province.dart';
import '../domain/province_geography.dart';
import '../domain/road_route.dart';
import '../domain/route_curve.dart';
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

  /// The active plan's user-marked stops (route-real-road / AC-4), forwarded from
  /// the route view state. Unioned with the endpoints to form the emphasized set.
  List<String> _markedStopIds = const <String>[];

  /// The route drawn along the REAL BUNDLED ROAD (route-real-road / AC-2),
  /// forwarded from the route view state. When present it is the authoritative
  /// drawn geometry (bypassing the chain projector/spline) AND the geometry the
  /// current-position marker + red idle trace ride. `null` on the legacy/no-road
  /// path (the map then falls back to the chain projector).
  RoadRoute? _roadRoute;

  /// The ordered waypoint provinces (start, stops…, end) aligned with
  /// `_roadRoute.waypointCoordinates` — the ONLY markers drawn (AC-3).
  List<Province> _waypoints = const <Province>[];

  /// The smoothed (curved) road for the current route, computed ONCE per route
  /// alongside [_projector] and reused across ticks (NFR-1 — never re-splined per
  /// frame). Reset to `null` whenever the projector is rebuilt (route identity
  /// change), then lazily recomputed in [_recompute].
  GeoPolyline? _smoothedRoad;

  /// The emphasized node-id set for the current route, computed ONCE per route
  /// alongside [_projector]: { start id, end id } ∪ marked-stop ids (AC-2/AC-3).
  Set<String>? _emphasizedNodeIds;

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
        !identical(newGeography, _routeGeography) ||
        !_sameIds(route.markedStopIds, _markedStopIds)) {
      // Route identity changed → drop the cached projector AND its derived
      // per-route geometry (smoothed road + emphasized ids) so they recompute
      // once; a mere distance tick keeps them (NFR-1 / TC-229).
      _projector = null;
      _smoothedRoad = null;
      _emphasizedNodeIds = null;
    }
    _selection = newSelection;
    _routeGeography = newGeography;
    _position = route.position;
    _countryPercent = route.countryPercent;
    _markedStopIds = route.markedStopIds;
    // route-real-road: the drawn road sub-path + its ordered waypoints, built once
    // per route by the route cubit (NFR-1). When present, the map draws THIS.
    _roadRoute = route.roadRoute;
    _waypoints = route.waypoints;
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

    // route-real-road (AC-2/AC-3): when a road route is present, the map follows
    // the REAL ROAD — the drawn line is the bundled highway sub-path, the marker
    // rides that road by the resolved (road) progress fraction, and the red idle
    // trace maps onto the road. Markers are ONLY the waypoints (start/end/stops);
    // there are NO per-province dots.
    final roadRoute = _roadRoute;
    if (roadRoute != null && !roadRoute.isEmpty) {
      final marker = roadRoute.coordinateAtFraction(position.fractionAlongRoute);
      final idleStretches = IdleTraceMapper.resolve(
        segments: _segments,
        routeStartOffsetKm: selection.routeStartOffsetKm,
        projector: roadRoute,
      );
      emit(
        MapViewState(
          selection: selection,
          position: position,
          countryPercent: _countryPercent,
          baseRoutePolyline: roadRoute.polyline,
          smoothedRoutePolyline: roadRoute.polyline,
          orderedNodes: _waypoints,
          emphasizedNodeIds: <String>{
            for (final w in _waypoints) w.id,
          },
          roadRoute: roadRoute,
          waypoints: _waypoints,
          markerPosition: marker,
          idleStretches: idleStretches,
        ),
      );
      return;
    }

    // Build (or reuse) the route projector over the active route geography (the
    // derived sub-chain for v2, else the full geography — AC-7). Cached so the
    // static base polyline is projected once per route, not per tick.
    final projector = _projector ??= RoutePolylineProjector(
      selection: selection,
      geography: _routeGeography ?? _geography,
    );

    // Per-route geometry, computed ONCE and cached (invalidated on route change
    // in updateFromRoute) so it is never re-derived per tick/frame (NFR-1):
    //  - the smoothed curved road (route-real-road / AC-1), and
    //  - the emphasized node ids { start, end } ∪ marked stops (AC-2/AC-3).
    final smoothed = _smoothedRoad ??= GeoPolyline(
      smoothCurve(projector.baseRoutePolyline),
    );
    final ordered = projector.orderedNodes;
    final emphasized = _emphasizedNodeIds ??= <String>{
      if (ordered.isNotEmpty) ordered.first.id,
      if (ordered.isNotEmpty) ordered.last.id,
      ..._markedStopIds,
    };

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
        smoothedRoutePolyline: smoothed,
        orderedNodes: ordered,
        emphasizedNodeIds: emphasized,
        markerPosition: marker,
        idleStretches: idleStretches,
      ),
    );
  }

  /// Order-insensitive id-set equality (marked-stop lists are small).
  static bool _sameIds(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    return a.toSet().containsAll(b) && b.toSet().containsAll(a);
  }
}
