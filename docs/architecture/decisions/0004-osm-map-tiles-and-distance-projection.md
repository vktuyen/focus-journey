# ADR-0004: OSM map tiles (first network egress) + canonical-km distance→polyline projection

- Status: accepted
- Date: 2026-06-24
- Deciders: Kevin (Tuyen Vo) / system-architect

## Context

> This ADR **supersedes** ADR-0002's deferral line ("Deferred to v2: `flutter_map` + `latlong2`")
> by activating that dependency, and supersedes the v1 "no network / no live tiles / custom-painted map"
> stance recorded in `docs/architecture/overview.md` and the `route-progress` spec (neither of which was a
> standalone accepted ADR). It does **not** supersede ADR-0002's stack choice or ADR-0003's single-window model.

The `map-experience` slice folds the standalone Map tab into the journey tab and renders the country on a
**real-geography** map. This forces two coupled decisions that change the product's technical shape:

1. **Network.** The product has been **fully offline to date** — every shipped spec asserts "no network,
   fully local/offline." Rendering real geography via `flutter_map` (`^8.3.0`) + `latlong2` (`^0.9.1`) over
   OpenStreetMap (OSM) tiles introduces the product's **first outbound network call** (anonymous tile GETs).
   The v1 posture ("no live tiles, custom-painted map") therefore needs an explicit supersession record, plus
   a privacy guarantee that this egress carries no user data — because `map-experience` is the most
   location-suggestive surface the product has shipped, gated by the privacy-skeptical reviewer.

2. **Distance → geometry projection.** Idle segments and the current-position marker are **distance-keyed**
   (`routeDistanceKm`), but the map road is **2-D geometry**. Province checkpoints now carry real lat/long,
   so a distance scalar must be projected onto the polyline. The constraint: the curated `segmentsKm` chain
   is the engine's **locked ~2000 km total** and the single canonical distance axis (AC-5). Re-deriving
   distances from geodesic (lat/long) leg lengths would change the total and break the engine contract.

## Decision

### (a) Adopt `flutter_map` + `latlong2` + OSM tiles as the map base — accepting the first network egress.

- `flutter_map ^8.3.0` + `latlong2 ^0.9.1` render OSM raster tiles as the journey-tab map base (Map tab removed).
- **The only egress is anonymous tile GETs:** the tile URL carries `{z}/{x}/{y}` plus a static user-agent — **no
  user data, no identifiers, no location, no idle data**. This preserves the privacy promise by construction.
- **Visible OSM attribution** is shown, per OSM tile-usage policy.
- **Offline-first fallback:** with no connectivity the map degrades gracefully (last-cached tiles if available,
  otherwise a static/blank base) and the province road, markers, and red idle trace still render — the journey
  tab never breaks or blocks on a failed tile fetch.
- This activates the dependency ADR-0002 deferred and supersedes the overview's no-network / custom-painted-map
  narrative (see ITEM 2 overview update).

### (b) Decision A — canonical-km distance→polyline projection.

The curated `ProvinceChain.segmentsKm` chain (the engine's locked ~2000 km total) **remains the single
canonical distance axis.** Province checkpoints are placed at their **real lat/long**, and a `routeDistanceKm`
is projected onto geometry by:

1. locating which chain leg the cumulative-from-origin distance falls in,
2. computing `fraction = kmIntoSegment / segmentKm`,
3. **linearly interpolating lat/long** between that leg's two checkpoint coordinates by that fraction.

This is implemented as a new pure-domain function, `RoutePolylineProjector.coordinateAt` (framework-free,
deterministic, unit-tested), consuming the **same `routeDistanceKm` scalar** the `route-progress`
`RouteProgressResolver` computes. The resolver produces no coordinate; the projector is the single
distance→coordinate function, so there is one shared distance axis and one geography model.

This is the **single geography model** that `route-planner-v2` (#9 waypoint auto-insert) will consume.

## Consequences

- **(a) Easier / preserved:** real geography without a backend; the privacy promise (aggregate idle duration
  by route distance; static reference lat/long, never device location; no GPS/keystrokes/screen/clipboard/files)
  is unchanged because the tile request carries no user data. **Harder / obligations:** the product is no longer
  strictly offline — tile fetch failure, caching, OSM usage-policy compliance, and visible attribution become
  standing obligations; desktop (macOS/Windows) tile rendering must hold; `/privacy-audit` must stay PASS.
- **(b) Easier / preserved:** AC-5's single distance axis and the engine's locked ~2000 km total are preserved;
  the marker and red trace key off the exact same km math, so they stay mutually consistent; the projector is
  deterministic and unit-testable. **Trade-off accepted (by design):** a leg's on-map visual length (the
  geodesic gap between its two cities) intentionally **differs** from that leg's km proportion — the chain km
  are stylised flavour distances, not GIS survey lengths.

## Alternatives considered

### (a) Bundled offline tiles only (no network at all)
Rejected: keeping strict offline would require shipping a static raster of Vietnam at multiple zoom levels
(large binary, stale, no pan/zoom fidelity). Anonymous OSM GETs with an offline fallback give live geography
with zero added tracking surface, which is the smaller cost.

### (b) Re-derive distances from geodesic lat/long leg lengths
Rejected: deriving each leg's km from the great-circle distance between its cities would change the chain total
away from the engine's locked ~2000 km, breaking the `JourneyEngine` contract and AC-5's single distance axis.
The canonical-km axis with linear in-leg interpolation keeps the engine authoritative.

### (b) A second distance function on the map side
Rejected: introducing an independent map-side position computation would create a second source of truth for
"where am I on the route," risking drift from the resolver. Reusing the same `routeDistanceKm` scalar through one
projector keeps a single geography model for `route-planner-v2` to consume.
