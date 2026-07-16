/// Presentation layer. The immutable value object the [MapCubit] emits and the
/// map surface (inline + full-screen) renders.
///
/// SEPARATION / PRIVACY INVARIANT (AC-12 / NFR-2 / TC-227/TC-230): imports ONLY
/// pure-Dart domain types + `equatable`. Holds NO activity logic, NO idle
/// seconds, NO lock query, NO distance accrual, NO device location — it is a
/// read-only snapshot derived purely from the engine's `JourneyProgress`
/// aggregate (segments + cumulative distance) and the user's route selection,
/// projected onto the static [ProvinceGeography] reference data.
library;

import 'package:equatable/equatable.dart';

import '../domain/geo_polyline.dart';
import '../domain/idle_trace_mapper.dart';
import '../domain/province.dart';
import '../domain/province_geography.dart';
import '../domain/road_route.dart';
import '../domain/route_position.dart';
import '../domain/route_selection.dart';

/// A flattened, immutable view of the map surface.
///
/// When [selection] is `null` there is no active route (the surface shows the
/// start picker). When present, [baseRoutePolyline] is the projected road,
/// [markerPosition] the current-position marker (projected from
/// `routeDistanceKm` — AC-5), and [idleStretches] the current-route red spans
/// (Decision C / AC-6..AC-8). Equality lets the painter skip redundant redraws
/// (NFR-1 / TC-229).
class MapViewState extends Equatable {
  /// Creates a map view state.
  const MapViewState({
    required this.selection,
    required this.position,
    required this.baseRoutePolyline,
    required this.orderedNodes,
    required this.markerPosition,
    required this.idleStretches,
    this.countryPercent,
    this.smoothedRoutePolyline = const GeoPolyline(<GeoCoordinate>[]),
    this.emphasizedNodeIds = const <String>{},
    this.roadRoute,
    this.waypoints = const <Province>[],
  });

  /// The pre-selection default: no route chosen yet, nothing to draw.
  const MapViewState.initial()
    : selection = null,
      position = null,
      baseRoutePolyline = const GeoPolyline(<GeoCoordinate>[]),
      smoothedRoutePolyline = const GeoPolyline(<GeoCoordinate>[]),
      orderedNodes = const <Province>[],
      emphasizedNodeIds = const <String>{},
      roadRoute = null,
      waypoints = const <Province>[],
      markerPosition = null,
      idleStretches = const <IdleStretch>[],
      countryPercent = null;

  /// The active route selection, or `null` when none has been chosen.
  final RouteSelection? selection;

  /// route-planner-v2 (ADR-0005 decision 3 / AC-8): the full-chain % computed by
  /// the route cubit, carried through for the readout. `null` on the legacy path
  /// (the resolver's `percentOfCountry` already IS the country % there).
  final double? countryPercent;

  /// The resolved position along the chain, or `null` when no route is active.
  final RoutePosition? position;

  /// The projected base road (origin → destination), real lat/long (AC-4). The
  /// straight checkpoint chords — also the source of [checkpointCoordinates] so
  /// the pins still sit on the real province centres.
  final GeoPolyline baseRoutePolyline;

  /// The SMOOTHED curved road (route-real-road / AC-1): a denser Catmull-Rom
  /// curve through the same checkpoint coordinates, precomputed once per route by
  /// the [MapCubit] (NFR-1). The map surface strokes THIS as the road. Empty when
  /// the state was built without a cubit (e.g. a direct-construction widget test);
  /// the surface then smooths [baseRoutePolyline] inline as a fallback.
  final GeoPolyline smoothedRoutePolyline;

  /// The route's checkpoints in travel order (origin → destination) — pins.
  final List<Province> orderedNodes;

  /// The node ids that render as the LARGE/highlighted marker (route-real-road /
  /// AC-2/AC-3): { start, end } ∪ user-marked stops. Every other on-route
  /// checkpoint renders as a small grey pass-through dot. Empty before a route is
  /// active.
  final Set<String> emphasizedNodeIds;

  /// The route drawn along the REAL BUNDLED ROAD (route-real-road / AC-2): the
  /// bundled highway sub-path between the snapped waypoints. When present, THIS is
  /// the geometry the map strokes (curves along the coast/road) — the chain
  /// [smoothedRoutePolyline] is bypassed. `null` on the legacy/no-road path.
  final RoadRoute? roadRoute;

  /// The ordered waypoint provinces (start, user stops…, end) — aligned by index
  /// with `roadRoute!.waypointCoordinates`. The ONLY markers drawn (big;
  /// Google-style — AC-3). Empty on the legacy path.
  final List<Province> waypoints;

  /// The drawn road route's length in km — the route-length axis when
  /// [roadRoute] is present (the km readout reflects THIS; route-real-road / #4).
  double? get routeRoadLengthKm => roadRoute?.routeLengthKm;

  /// The current-position marker coordinate, projected from `routeDistanceKm`
  /// (AC-5). `null` when no route is active.
  final GeoCoordinate? markerPosition;

  /// The current-route idle stretches to paint red, each carrying its recorded
  /// cause (Decision C / AC-6/AC-9). Empty for a zero-idle route (AC-7).
  final List<IdleStretch> idleStretches;

  /// Whether a route is active (a selection has been made).
  bool get hasRoute => selection != null && position != null;

  /// Whether the active route has reached its destination (completed; AC-10).
  bool get isCompleted => position?.isCompleted ?? false;

  /// Each [orderedNodes] checkpoint paired with its projected coordinate (the
  /// base polyline shares the same order), so pins draw at the road vertices.
  List<GeoCoordinate> get checkpointCoordinates => baseRoutePolyline.points;

  @override
  List<Object?> get props => <Object?>[
    selection,
    position,
    baseRoutePolyline,
    smoothedRoutePolyline,
    orderedNodes,
    emphasizedNodeIds,
    roadRoute,
    waypoints,
    markerPosition,
    idleStretches,
    countryPercent,
  ];
}
