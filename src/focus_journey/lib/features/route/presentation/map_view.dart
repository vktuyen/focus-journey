/// Presentation layer. The shared real-geography map surface used BOTH inline on
/// the journey tab and full-screen: a `flutter_map` [FlutterMap] with an OSM
/// [TileLayer] (attribution shown — AC-11), a base-road [PolylineLayer]
/// (projected real geography — AC-4), a red overlay for idle stretches
/// (solid=voluntary / dashed=lock-sleep — AC-6/AC-9/NFR-3), and a [MarkerLayer]
/// for checkpoint pins + the current-position marker (AC-5/AC-10).
///
/// SEPARATION / PRIVACY INVARIANT (AC-12 / NFR-2 / TC-227/TC-230/TC-231): reads
/// ONLY the injected [MapViewState] (derived purely from the engine's aggregate
/// snapshot + the route selection, projected onto STATIC [ProvinceGeography]
/// reference data). It imports NO `ActivityPlugin`, NO `MethodChannel`, NO
/// geolocation/GPS, makes NO active-vs-idle decision, and accrues NO distance.
/// The ONLY network egress is anonymous OSM tile GETs keyed by `{z}/{x}/{y}`
/// (plus the required static User-Agent) — no user id, no location, no idle data
/// (TC-231). `flutter_map` is used for static tile display + the static overlay
/// only; its camera/marker is never read back as the user's position.
///
/// OFFLINE FALLBACK (AC-11 / TC-218/TC-219): a failed tile fetch is swallowed by
/// [TileLayer.errorTileCallback] + an [TileLayer.errorImage]; the map's solid
/// background remains, and the province road / markers / red trace still render
/// on top — no exception bubbles to the journey tab.
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../journey/domain/activity_segment.dart';
import 'lat_lng_mapper.dart';
import 'map_view_state.dart';

/// The OSM tile URL template — a standard anonymous `{z}/{x}/{y}` endpoint. No
/// user identifier, location, or session token is interpolated (TC-231).
const String kOsmTileUrlTemplate =
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// The package user-agent OSM tile policy requires (a static app identifier, not
/// user data). Sent as the only non-coordinate part of a tile request (TC-231).
const String kMapUserAgentPackageName = 'com.focusjourney.app';

/// The single "drifted off" red the idle trace uses (AC-9: one colour; the cause
/// is conveyed by the stroke PATTERN, not a second hue).
const Color kIdleRed = Color(0xFFD32F2F);

/// The base-road colour (a calm slate so the red trace reads clearly on top).
const Color kBaseRoadColor = Color(0xFF37474F);

/// The flat background painted behind the compact minimap (no live tiles). A
/// muted blue-grey "land" tone so the slate road + red idle trace read clearly.
const Color kCompactMapBackground = Color(0xFFCAD5DC);

/// The shared map surface. Renders the projected base road, the red idle trace,
/// the checkpoint pins, and the current-position marker over an OSM tile base.
class MapView extends StatelessWidget {
  /// Creates the map surface from a resolved [state].
  ///
  /// [tileProvider] is an injectable seam (default: `flutter_map`'s
  /// `NetworkTileProvider`) so tests can drive a fake success / timeout / error
  /// provider with no real network (TC-218/TC-219/TC-231).
  const MapView({
    required this.state,
    this.tileProvider,
    this.showTiles = true,
    super.key,
  });

  /// The resolved map view state (base road, marker, idle stretches).
  final MapViewState state;

  /// Optional tile-provider override (test seam). `null` → OSM network tiles.
  final TileProvider? tileProvider;

  /// Whether to render the live OSM [TileLayer] + its attribution pill.
  ///
  /// `true` (default) for the full-screen surface — live tiles + the required
  /// '© OpenStreetMap contributors' attribution (AC-11). `false` for the
  /// compact minimap (the floating HUD on the journey tab): the polylines,
  /// markers, and red idle trace are painted over a flat themed background, so
  /// the minimap is glanceable, stays overflow-safe at ~150px, AND makes NO
  /// tile network calls at all (strictly fewer GETs — better for NFR-2). The
  /// OSM tiles + attribution are reserved for the full-screen view, where they
  /// are legible.
  final bool showTiles;

  @override
  Widget build(BuildContext context) {
    final basePoints = toLatLngs(state.baseRoutePolyline.points);
    final map = FlutterMap(
      options: MapOptions(
        // Fit the whole route into view; falls back to a Vietnam-centred default
        // when there is no route yet (the picker is shown over this).
        initialCameraFit: basePoints.length >= 2
            ? CameraFit.coordinates(
                coordinates: basePoints,
                padding: EdgeInsets.all(showTiles ? 48 : 12),
              )
            : null,
        initialCenter: basePoints.isNotEmpty
            ? basePoints.first
            : const LatLng(16.0, 107.5),
        initialZoom: 5.5,
        // No GPS / location interaction; pan + zoom only (NFR-2).
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom,
        ),
      ),
      children: <Widget>[
        if (showTiles) _osmTileLayer(),
        _baseRoadLayer(basePoints),
        ..._idleTraceLayers(),
        _markerLayer(),
        if (showTiles) _attribution(),
      ],
    );
    // In compact (minimap) mode there is no tile base, so paint the route over a
    // flat themed background — keeps the polylines/markers/red trace legible.
    if (!showTiles) {
      return ColoredBox(color: kCompactMapBackground, child: map);
    }
    return map;
  }

  /// The OSM tile layer with a graceful offline fallback (AC-11): a failed tile
  /// fetch is swallowed (no rethrow) and an error tile is shown over the map's
  /// solid background, so the road/markers/red still render and the tab never
  /// breaks (TC-219).
  TileLayer _osmTileLayer() {
    return TileLayer(
      urlTemplate: kOsmTileUrlTemplate,
      userAgentPackageName: kMapUserAgentPackageName,
      tileProvider: tileProvider,
      // Offline fallback: keep the (possibly stale) tile on error instead of a
      // blank flash, and never rethrow (TC-219).
      errorTileCallback: (tile, error, stackTrace) {
        // Intentionally swallowed: a tile fetch failure must not bubble to the
        // journey tab (AC-11). The base background + overlay remain visible.
      },
      evictErrorTileStrategy: EvictErrorTileStrategy.none,
    );
  }

  /// The base road: the projected province polyline (real lat/long, AC-4).
  PolylineLayer<Object> _baseRoadLayer(List<LatLng> points) {
    return PolylineLayer<Object>(
      polylines: <Polyline<Object>>[
        if (points.length >= 2)
          Polyline<Object>(
            points: points,
            strokeWidth: 4,
            color: kBaseRoadColor,
          ),
      ],
    );
  }

  /// The red idle trace, one polyline per current-route idle stretch. Voluntary
  /// idle = SOLID red; lock/sleep = DASHED red (AC-9 non-colour cue / NFR-3) —
  /// same colour, distinct pattern (TC-216/TC-225). A zero-idle route yields an
  /// empty layer (AC-7 / TC-213).
  List<Widget> _idleTraceLayers() {
    if (state.idleStretches.isEmpty) {
      return const <Widget>[];
    }
    return <Widget>[
      Semantics(
        label:
            'Idle stretches where the journey paused, traced in red. Solid '
            'lines are voluntary pauses; dashed lines are screen-lock or sleep '
            'pauses.',
        child: PolylineLayer<Object>(
          polylines: <Polyline<Object>>[
            for (final stretch in state.idleStretches)
              if (stretch.polyline.points.length >= 2)
                Polyline<Object>(
                  points: toLatLngs(stretch.polyline.points),
                  strokeWidth: 6,
                  color: kIdleRed,
                  pattern: stretch.cause == SegmentCause.lockSleep
                      ? StrokePattern.dashed(segments: const <double>[12, 8])
                      : const StrokePattern.solid(),
                ),
          ],
        ),
      ),
    ];
  }

  /// The checkpoint pins + the current-position marker. The marker is projected
  /// from `routeDistanceKm` (AC-5); at km=0 it sits on the start pin (AC-10).
  ///
  /// On the FULL-SCREEN surface ([showTiles] == true) each checkpoint also gets
  /// a legible province-name label under its pin and a desktop hover [Tooltip]
  /// naming the stop — so the route's stops are identifiable on the real map.
  /// The compact minimap ([showTiles] == false) keeps bare dots (no labels /
  /// tooltips) so it stays uncluttered at ~150px (minimap unchanged).
  MarkerLayer _markerLayer() {
    final checkpoints = state.checkpointCoordinates;
    final labelled = showTiles;
    final markers = <Marker>[
      for (var i = 0; i < checkpoints.length; i++)
        Marker(
          point: toLatLng(checkpoints[i]),
          // A labelled checkpoint needs extra room beneath the dot for the
          // province name; a bare minimap dot stays compact.
          width: labelled ? 120 : 16,
          height: labelled ? 44 : 16,
          // Anchor at the top so the dot stays on the road vertex and the label
          // hangs below it (labelled mode only).
          alignment: labelled ? Alignment.topCenter : Alignment.center,
          // Full-screen: a labelled + hover-tooltipped checkpoint. Minimap:
          // a bare dot with only its Semantics label (unchanged — no tooltip,
          // no name label, stays uncluttered at ~150px).
          child: i < state.orderedNodes.length
              ? (labelled
                    ? _CheckpointMarker(name: state.orderedNodes[i].name)
                    : Semantics(
                        label: 'Checkpoint ${state.orderedNodes[i].name}',
                        child: const _CheckpointPin(),
                      ))
              : Semantics(label: 'Checkpoint', child: const _CheckpointPin()),
        ),
      if (state.markerPosition != null)
        Marker(
          point: toLatLng(state.markerPosition!),
          width: 22,
          height: 22,
          child: Semantics(
            label: 'Your current position on the route',
            child: const _CurrentPositionMarker(),
          ),
        ),
    ];
    return MarkerLayer(markers: markers);
  }

  /// Always-visible OSM attribution (AC-11 / TC-218 — required by OSM
  /// tile-usage policy). The attribution text is rendered inline (no expand
  /// button), so '© OpenStreetMap contributors' is legible on BOTH the inline
  /// (IgnorePointer'd) surface and the full-screen surface — unlike
  /// [RichAttributionWidget], whose sources stay collapsed behind an "i" button
  /// that the inline overlay can never reveal. Kept unobtrusive: a small
  /// translucent pill anchored bottom-right that wraps gracefully in narrow
  /// surfaces (no overflow).
  Widget _attribution() {
    return const _OsmAttribution();
  }
}

/// A small checkpoint dot.
class _CheckpointPin extends StatelessWidget {
  const _CheckpointPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF26A69A),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}

/// A full-screen checkpoint: a teal dot, a desktop hover [Tooltip] naming the
/// province, and a legible province-name label hanging below the dot. The label
/// has a translucent dark background + shadow so the text stays readable over
/// OSM tiles. Screen-reader recoverable via [Semantics] (NFR-3). The dot sits at
/// the top so it stays on the road vertex while the label hangs beneath it.
/// (Full-screen only — the compact minimap keeps bare dots, unchanged.)
class _CheckpointMarker extends StatelessWidget {
  const _CheckpointMarker({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final dot = Semantics(
      label: 'Checkpoint $name',
      child: const SizedBox(width: 16, height: 16, child: _CheckpointPin()),
    );
    // Desktop hover tooltip naming the stop (macOS / Windows — NFR-3).
    final hoverable = Tooltip(message: name, child: dot);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        hoverable,
        const SizedBox(height: 2),
        // Legible-over-tiles province name label.
        ExcludeSemantics(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  shadows: <Shadow>[Shadow(color: Colors.black, blurRadius: 2)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// An always-visible, overflow-safe OSM attribution pill (AC-11 / TC-218). The
/// '© OpenStreetMap contributors' text is rendered directly (no tap to reveal),
/// anchored bottom-right and constrained so it wraps rather than overflowing on
/// a narrow inline surface.
class _OsmAttribution extends StatelessWidget {
  const _OsmAttribution();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                '© OpenStreetMap contributors',
                style: TextStyle(color: Colors.white, fontSize: 11),
                softWrap: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The current-position marker (filled orange dot with a ring).
class _CurrentPositionMarker extends StatelessWidget {
  const _CurrentPositionMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE65100),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFF3E0), width: 3),
      ),
    );
  }
}
