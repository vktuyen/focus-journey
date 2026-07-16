// Shared fixtures + doubles for the map-experience widget & integration layer.
//
// map-experience is a PURE VISUALIZER: it reads the route-progress position math
// (`routeDistanceKm`) and the idle-accounting distance-keyed segment record, and
// renders them onto a real-Vietnam province polyline with idle spans painted red.
// These fixtures key off the route-progress worked-example FIXTURE chain (segments
// [60,170,300,310,600], total 1440 km), extended here with a per-province static
// lat/long so the projector can build geometry. Tests assert against STRUCTURE
// (polylines / markers / attribution / semantics) and the injected snapshot
// values, never against literal pixels.
//
// OFFLINE BY CONSTRUCTION (ADR-0008). ADR-0008(c) DROPPED the OSM `TileLayer`, so
// there is NO network seam left to fake: the base map is a bundled, static
// [BaseMapGeometry] drawn as a `PolygonLayer`. [buildFixtureBaseMap] supplies a
// deterministic geometry (a land ring generously enclosing the fixture chain +
// a few province-outline rings) so a widget/integration test renders the base
// with zero network, zero assets, zero timers — a real tile/network fetch is now
// structurally impossible (AC-10 / NFR-2).
//
// No timers, no DateTime.now(), no real I/O, no network — every double here is
// deterministic.

import 'package:focus_journey/features/journey/domain/activity_segment.dart';
import 'package:focus_journey/features/journey/domain/journey_progress.dart';
import 'package:focus_journey/features/journey/domain/journey_state.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/route/domain/base_map_geometry.dart';
import 'package:focus_journey/features/route/domain/geo_polyline.dart';
import 'package:focus_journey/features/route/domain/idle_trace_mapper.dart';
import 'package:focus_journey/features/route/domain/journey_direction.dart';
import 'package:focus_journey/features/route/domain/province.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/domain/route_curve.dart';
import 'package:focus_journey/features/route/domain/route_polyline_projector.dart';
import 'package:focus_journey/features/route/domain/route_progress_resolver.dart';
import 'package:focus_journey/features/route/domain/route_selection.dart';
import 'package:focus_journey/features/route/presentation/map_view_state.dart';

/// Float tolerance for distance / coordinate assertions (±1e-6).
const double kTol = 1e-6;

/// The route-progress worked-example fixture chain (south tip → north tip).
/// Cumulative-from-Mũi: 0 / 60 / 230 / 530 / 840 / 1440.
ProvinceChain buildFixtureChain() => ProvinceChain(
  nodes: const <Province>[
    Province(id: 'mui', name: 'Mũi Cà Mau'),
    Province(id: 'can_tho', name: 'Cần Thơ'),
    Province(id: 'da_lat', name: 'Đà Lạt'),
    Province(id: 'da_nang', name: 'Đà Nẵng'),
    Province(id: 'ha_noi', name: 'Hà Nội'),
    Province(id: 'ha_giang', name: 'Hà Giang'),
  ],
  segmentsKm: const <double>[60, 170, 300, 310, 600],
);

/// The fixture geography: a real-ish Vietnam lat/long for each fixture node, all
/// inside the production bbox so [ProvinceGeography]'s constructor accepts them.
/// The S-shape is non-colinear, so the road traces the country (AC-4).
ProvinceGeography buildFixtureGeography(ProvinceChain chain) =>
    ProvinceGeography(
      chain: chain,
      coordinates: const <String, GeoCoordinate>{
        'mui': GeoCoordinate(latitude: 8.62, longitude: 104.72),
        'can_tho': GeoCoordinate(latitude: 10.04, longitude: 105.78),
        'da_lat': GeoCoordinate(latitude: 11.94, longitude: 108.44),
        'da_nang': GeoCoordinate(latitude: 16.05, longitude: 108.20),
        'ha_noi': GeoCoordinate(latitude: 21.03, longitude: 105.85),
        'ha_giang': GeoCoordinate(latitude: 22.82, longitude: 104.98),
      },
    );

/// Looks up a fixture node by its stable id.
Province nodeById(ProvinceChain chain, String id) =>
    chain.nodes.firstWhere((p) => p.id == id);

/// A validated selection over [chain].
RouteSelection selectionFor(
  ProvinceChain chain,
  String startId,
  JourneyDirection direction, {
  double offset = 0,
}) => RouteSelection.create(
  start: nodeById(chain, startId),
  direction: direction,
  routeStartOffsetKm: offset,
  chain: chain,
);

/// An idle [ActivitySegment] spanning `[fromKm, toKm)` (absolute cumulative km)
/// with the given [cause]. The visualizer reads these as-is.
ActivitySegment idleSegment(
  double fromKm,
  double toKm, {
  SegmentCause cause = SegmentCause.voluntary,
}) => ActivitySegment(
  fromKm: fromKm,
  toKm: toKm,
  elapsed: const Duration(minutes: 10),
  classification: SegmentClassification.idle,
  cause: cause,
);

/// An active [ActivitySegment] spanning `[fromKm, toKm)`. Never painted red.
ActivitySegment activeSegment(double fromKm, double toKm) => ActivitySegment(
  fromKm: fromKm,
  toKm: toKm,
  elapsed: const Duration(minutes: 10),
  classification: SegmentClassification.active,
  cause: SegmentCause.none,
);

/// Builds a [JourneyProgress] aggregate carrying [segments] (the only field the
/// map slice reads) + a cumulative [distanceKm]. Mirrors the engine's snapshot.
JourneyProgress progressWith({
  required List<ActivitySegment> segments,
  double distanceKm = 0,
}) => JourneyProgress(
  distanceKm: distanceKm,
  activeTimeToday: Duration.zero,
  rawActiveTime: Duration.zero,
  idleTimeToday: Duration.zero,
  state: JourneyState.active,
  mode: TravelMode.motorbike,
  storedDate: DateTime(2026, 6, 24),
  segments: segments,
);

/// Resolves a [MapViewState] directly (the value object the surface renders),
/// using the REAL route-progress resolver + the REAL projector + the REAL idle
/// mapper — so a widget test exercises the production projection path without a
/// cubit or any engine. [routeDistanceKm] is the per-route distance (= cumulative
/// − offset). [segments] are absolute-cumulative-km idle/active spans.
/// [markedStopIds] seeds the user-marked-stop emphasis (route-real-road / AC-4);
/// the emphasized set is always { start, end } ∪ these ids (AC-2/AC-3).
MapViewState resolveMapState({
  required ProvinceChain chain,
  required ProvinceGeography geography,
  required RouteSelection selection,
  required double routeDistanceKm,
  List<ActivitySegment> segments = const <ActivitySegment>[],
  List<String> markedStopIds = const <String>[],
}) {
  final position = RouteProgressResolver.resolve(
    routeDistanceKm: routeDistanceKm,
    selection: selection,
    chain: chain,
  );
  final projector = RoutePolylineProjector(
    selection: selection,
    geography: geography,
  );
  final marker = projector.coordinateAt(position.routeDistanceKm);
  final stretches = mapIdleStretches(
    segments: segments,
    selection: selection,
    projector: projector,
  );
  final ordered = projector.orderedNodes;
  return MapViewState(
    selection: selection,
    position: position,
    baseRoutePolyline: GeoPolyline(projector.baseRoutePolyline),
    smoothedRoutePolyline: GeoPolyline(smoothCurve(projector.baseRoutePolyline)),
    orderedNodes: ordered,
    emphasizedNodeIds: <String>{
      if (ordered.isNotEmpty) ordered.first.id,
      if (ordered.isNotEmpty) ordered.last.id,
      ...markedStopIds,
    },
    markerPosition: marker,
    idleStretches: stretches,
  );
}

/// Thin re-export wrapper so fixtures don't need to import the mapper directly in
/// every test — the production IdleTraceMapper is the single source of truth.
List<IdleStretch> mapIdleStretches({
  required List<ActivitySegment> segments,
  required RouteSelection selection,
  required RoutePolylineProjector projector,
}) => IdleTraceMapper.resolve(
  segments: segments,
  routeStartOffsetKm: selection.routeStartOffsetKm,
  projector: projector,
);

/// A deterministic fake bundled base-map [BaseMapGeometry] for the widget +
/// integration layer (vietnam-map-fidelity / ADR-0008). Stands in for the parsed
/// GeoJSON asset so a test renders the offline base with NO asset load, NO
/// network, NO timers.
///
/// The single land ring is a rectangle generously enclosing the fixture chain's
/// coordinates (lat 8.62..22.82, lon 104.72..108.44), so every checkpoint, the
/// route polyline, and the current-position marker fall ON the landmass — never
/// in the sea (AC-5/6/7). Three province-outline rings give the base its thin
/// unit borders (AC-3). This is app-shipped reference geometry, never a device
/// read (NFR-2).
BaseMapGeometry buildFixtureBaseMap() => BaseMapGeometry(
  landRings: const <List<GeoCoordinate>>[
    <GeoCoordinate>[
      GeoCoordinate(latitude: 8.0, longitude: 103.0),
      GeoCoordinate(latitude: 8.0, longitude: 109.8),
      GeoCoordinate(latitude: 23.5, longitude: 109.8),
      GeoCoordinate(latitude: 23.5, longitude: 103.0),
      GeoCoordinate(latitude: 8.0, longitude: 103.0),
    ],
  ],
  provinceRings: const <List<GeoCoordinate>>[
    <GeoCoordinate>[
      GeoCoordinate(latitude: 9.0, longitude: 104.0),
      GeoCoordinate(latitude: 9.0, longitude: 106.0),
      GeoCoordinate(latitude: 11.0, longitude: 106.0),
      GeoCoordinate(latitude: 11.0, longitude: 104.0),
      GeoCoordinate(latitude: 9.0, longitude: 104.0),
    ],
    <GeoCoordinate>[
      GeoCoordinate(latitude: 15.0, longitude: 107.0),
      GeoCoordinate(latitude: 15.0, longitude: 109.0),
      GeoCoordinate(latitude: 17.0, longitude: 109.0),
      GeoCoordinate(latitude: 17.0, longitude: 107.0),
      GeoCoordinate(latitude: 15.0, longitude: 107.0),
    ],
    <GeoCoordinate>[
      GeoCoordinate(latitude: 20.0, longitude: 104.0),
      GeoCoordinate(latitude: 20.0, longitude: 106.0),
      GeoCoordinate(latitude: 22.5, longitude: 106.0),
      GeoCoordinate(latitude: 22.5, longitude: 104.0),
      GeoCoordinate(latitude: 20.0, longitude: 104.0),
    ],
  ],
);
