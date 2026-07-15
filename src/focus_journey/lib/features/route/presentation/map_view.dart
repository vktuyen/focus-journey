/// Presentation layer. The shared real-geography map surface used BOTH inline on
/// the journey tab and full-screen: a `flutter_map` [FlutterMap] whose base is
/// the bundled, offline Vietnam 34-province [PolygonLayer] (vietnam-map-fidelity
/// / ADR-0008 — always renders, even with no network), with the shipped overlays
/// drawn ON TOP: a base-road [PolylineLayer] (projected real geography), a red
/// overlay for idle stretches (solid=voluntary / dashed=lock-sleep —
/// AC-8/NFR-3), and a [MarkerLayer] for checkpoint pins + the current-position
/// marker. An in-app CC BY-SA 3.0 attribution credits the bundled base (AC-9).
///
/// SEPARATION / PRIVACY INVARIANT (NFR-2 / AC-10): reads ONLY the injected
/// [MapViewState] + the STATIC bundled [BaseMapGeometry]. It imports NO
/// `ActivityPlugin`, NO `MethodChannel`, NO geolocation/GPS, makes NO
/// active-vs-idle decision, and accrues NO distance. ADR-0008(c) DROPPED the OSM
/// `TileLayer`, so the surface issues ZERO network egress — the base is a
/// bundled static asset. `flutter_map` renders the static polygons + overlays
/// only; its camera/marker is never read back as the user's position.
///
/// OFFLINE-FIRST (AC-1/AC-2): the base is a bundled asset, so it renders with no
/// network and can never be a blank/grey canvas or an empty-tile placeholder.
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../journey/domain/activity_segment.dart';
import '../domain/base_map_geometry.dart';
import 'base_map_layer.dart';
import 'lat_lng_mapper.dart';
import 'map_view_state.dart';

/// The required in-app attribution for the bundled Wikimedia base map. The base
/// is CC BY-SA 3.0 (share-alike), so this credit is MANDATORY (AC-9) — unlike
/// the CC0 scenery art. The shipped GeoJSON is a DERIVATIVE (reprojected,
/// flattened, and simplified from the source SVG), so the credit states it was
/// "modified" to satisfy CC BY-SA's attribution + share-alike terms. Kept here
/// as the single source of the string (also surfaced on the onboarding privacy
/// card so a journey-tab user who never opens the full map still sees it).
const String kBaseMapAttribution =
    'Base map: Vietnam administrative divisions 2025 by TUBS / PIkne — '
    'modified (reprojected & simplified), CC BY-SA 3.0, via Wikimedia Commons';

/// The single "drifted off" red the idle trace uses (AC-8: one colour; the cause
/// is conveyed by the stroke PATTERN, not a second hue).
const Color kIdleRed = Color(0xFFD32F2F);

/// The base-road colour (a calm slate so the red trace reads clearly on top of
/// the land fill).
const Color kBaseRoadColor = Color(0xFF37474F);

/// The compact minimap background — the themed sea tone behind the bundled land
/// polygons (the sea is the app's own background — ADR-0008(b)). Shared with the
/// minimap card frame in `map_surface.dart`.
const Color kCompactMapBackground = kSeaBackground;

/// The shared map surface. Renders the bundled offline Vietnam base (34-province
/// [PolygonLayer]) UNDER the projected base road, the red idle trace, the
/// checkpoint pins, and the current-position marker. No tiles, no network.
class MapView extends StatelessWidget {
  /// Creates the map surface from a resolved [state] over the bundled
  /// [baseMap] geometry.
  ///
  /// [baseMap] is the parsed, cached [BaseMapGeometry] loaded from the bundled
  /// GeoJSON (injected via the composition root). When `null` / empty, no base
  /// layer is drawn (back-compat for hosts that inject none). [compact] selects
  /// the cheaper decimated geometry for the ~150px minimap (NFR-1) and hides the
  /// per-checkpoint labels/attribution so it stays uncluttered.
  const MapView({
    required this.state,
    this.baseMap,
    this.compact = false,
    super.key,
  });

  /// The resolved map view state (base road, marker, idle stretches).
  final MapViewState state;

  /// The bundled base-map geometry drawn beneath the overlays (AC-1/AC-2). When
  /// `null`, the base layer is omitted (legacy/route-only hosts).
  final BaseMapGeometry? baseMap;

  /// Whether this is the compact minimap surface.
  ///
  /// `false` (default) for the full-screen surface — full-resolution base,
  /// per-checkpoint labels, and the CC BY-SA attribution pill (AC-9). `true`
  /// for the compact minimap (the floating HUD on the journey tab): the cheaper
  /// decimated base + bare dots so the minimap stays glanceable and
  /// overflow-safe at ~150px. Neither mode makes any network call (AC-10).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final basePoints = toLatLngs(state.baseRoutePolyline.points);
    final base = baseMap;
    final map = FlutterMap(
      options: MapOptions(
        // Fit the whole route into view; falls back to a Vietnam-centred default
        // when there is no route yet (the picker is shown over this).
        initialCameraFit: basePoints.length >= 2
            ? CameraFit.coordinates(
                coordinates: basePoints,
                padding: EdgeInsets.all(compact ? 12 : 48),
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
        // The bundled Vietnam base FIRST so every overlay draws on top of it
        // (z-order: base beneath, overlays above — AC-11).
        if (base != null) ...buildBaseMapLayers(base, compact: compact),
        _baseRoadLayer(basePoints),
        ..._idleTraceLayers(),
        _markerLayer(),
        // In-app CC BY-SA credit for the bundled base (AC-9) — full-screen only
        // (the minimap surfaces it via the shared credit on the full map).
        if (!compact) _attribution(),
      ],
    );
    // The sea is the app's own themed background behind the land polygons
    // (ADR-0008(b)); paint it on BOTH surfaces so any area outside the landmass
    // reads as sea, never a blank canvas.
    return ColoredBox(color: kSeaBackground, child: map);
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
  /// On the FULL-SCREEN surface ([compact] == false) each checkpoint also gets
  /// a legible province-name label under its pin and a desktop hover [Tooltip]
  /// naming the stop — so the route's stops are identifiable on the base map.
  /// The compact minimap ([compact] == true) keeps bare dots (no labels /
  /// tooltips) so it stays uncluttered at ~150px (minimap unchanged).
  MarkerLayer _markerLayer() {
    final checkpoints = state.checkpointCoordinates;
    final labelled = !compact;
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

  /// The required in-app CC BY-SA 3.0 credit for the bundled Wikimedia base
  /// (AC-9). The base is share-alike, so the credit is MANDATORY (unlike the CC0
  /// art). Rendered inline (no expand button) so [kBaseMapAttribution] is
  /// legible; a small translucent pill anchored bottom-right that wraps
  /// gracefully in narrow surfaces (no overflow).
  Widget _attribution() {
    return const _BaseMapAttribution();
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
/// the land fill. Screen-reader recoverable via [Semantics] (NFR-3). The dot sits at
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
        // Legible-over-land-fill province name label.
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

/// An always-visible, overflow-safe CC BY-SA 3.0 attribution pill for the
/// bundled Wikimedia base map (AC-9). The [kBaseMapAttribution] text is rendered
/// directly (no tap to reveal), anchored bottom-right and constrained so it
/// wraps rather than overflowing on a narrow surface. Share-alike → mandatory.
class _BaseMapAttribution extends StatelessWidget {
  const _BaseMapAttribution();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  kBaseMapAttribution,
                  style: TextStyle(color: Colors.white, fontSize: 11),
                  softWrap: true,
                ),
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
