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
// THE FAKE TILE PROVIDER IS THE NETWORK SEAM. Every widget here injects a
// [FakeTileProvider] so a test NEVER reaches a real OSM tile server — a real tile
// fetch would be a bug (TC-218/TC-219/TC-231). The provider also records every
// tile URL it is asked for, so TC-231 can assert the request payload is data-free.
//
// No timers, no DateTime.now(), no real I/O, no network — every double here is
// deterministic.

import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:focus_journey/features/journey/domain/activity_segment.dart';
import 'package:focus_journey/features/journey/domain/journey_progress.dart';
import 'package:focus_journey/features/journey/domain/journey_state.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/route/domain/geo_polyline.dart';
import 'package:focus_journey/features/route/domain/idle_trace_mapper.dart';
import 'package:focus_journey/features/route/domain/journey_direction.dart';
import 'package:focus_journey/features/route/domain/province.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
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
MapViewState resolveMapState({
  required ProvinceChain chain,
  required ProvinceGeography geography,
  required RouteSelection selection,
  required double routeDistanceKm,
  List<ActivitySegment> segments = const <ActivitySegment>[],
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
  return MapViewState(
    selection: selection,
    position: position,
    baseRoutePolyline: GeoPolyline(projector.baseRoutePolyline),
    orderedNodes: projector.orderedNodes,
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

/// A fake [TileProvider] that NEVER touches the network. It satisfies tile
/// requests from memory (a 1x1 transparent PNG) or, in [failing] mode, errors —
/// simulating offline. It records every requested tile URL so TC-231 can assert
/// the request payload carries no user data.
///
/// This is the network seam: injecting it guarantees a test makes zero real OSM
/// requests. A test that hits the real network is a bug (RULES).
class FakeTileProvider extends TileProvider {
  FakeTileProvider({this.failing = false});

  /// When true, every tile load fails (simulated offline / no-network — TC-219).
  final bool failing;

  /// Every tile URL this provider was asked to produce, in order. Lets TC-231
  /// assert each request is an anonymous `{z}/{x}/{y}` GET with no user payload.
  final List<String> requestedUrls = <String>[];

  /// Whether any tile request reached this provider at all (proves the map used
  /// the injected seam, not a real network provider).
  bool get wasQueried => requestedUrls.isNotEmpty;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    requestedUrls.add(getTileUrl(coordinates, options));
    if (failing) {
      // Simulated offline: an ImageProvider whose bytes fail to decode. The
      // TileLayer.errorTileCallback swallows it (no rethrow to the journey tab).
      return MemoryImage(Uint8List.fromList(<int>[0, 1, 2, 3]));
    }
    return MemoryImage(TileProvider.transparentImage);
  }
}
