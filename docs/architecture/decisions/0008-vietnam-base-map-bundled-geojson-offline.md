# ADR-0008: Vietnam base map — bundled GeoJSON province layer, offline-only (drops OSM tiles)

- Status: accepted
- Date: 2026-07-15
- Deciders: Kevin (Tuyen Vo) / system-architect

## Context

> This ADR **amends and partially supersedes ADR-0004(a)** — specifically ADR-0004's "OSM-tile-as-base +
> anonymous tile GET egress" assumption. It does **not** touch ADR-0004(b) (the canonical-km
> distance→polyline projection), which is preserved unchanged. ADR-0004 should be tagged **amended-by-0008**.

The `vietnam-map-fidelity` slice (slice 1 of the Vietnam-2026 pair; sibling `province-chain-2026`) exists
because the shipped map frequently renders as checkpoints and a route floating on a blank grey canvas: the OSM
tiles (ADR-0004) often fail to load and the offline fallback is a flat background. The one screen that should
always say "this is Vietnam" says nothing, undercutting both the ambient sense of place and the local-only
trust story. The map must render an accurate current-Vietnam (2026, 34-province) base **always — even offline**
— with the journey drawn on top.

A base-map asset has been sourced: `assets/map/vietnam_provinces_2025_base.svg` (Wikimedia, TUBS/PIkne,
**CC BY-SA 3.0**). Two forces shape the rendering decision:

1. **Projection mismatch.** The SVG is an **equirectangular (plate-carrée / EPSG:4326) drawing in pixel space**
   (viewBox 1200×2349.176; geographic bounds N24/S8 · W101.8/E110.3). `flutter_map` renders in **Web-Mercator
   (EPSG:3857)** by default. Anchoring the SVG as-is in pixel space would distort latitude and misplace every
   checkpoint/marker relative to the shipped overlays.

2. **Offline-first + privacy.** A bundled asset means the base can render with zero network. That reopens the
   question ADR-0004 answered under a different constraint: if the base no longer needs tiles, is the online
   OSM `TileLayer` — the product's only network egress — still worth keeping? Kevin's answer (locked
   2026-07-15) is no.

Constraint that must survive: ADR-0004(b)'s canonical-km distance→polyline projection and every shipped marker,
pin, and red idle-trace must keep working unchanged — the base map is purely additive and sits **beneath** the
existing overlay layers (AC-11 regression guard).

## Decision

### (a) Render the 34-province base as a bundled, georeferenced GeoJSON `PolygonLayer` in `flutter_map`.

Convert the sourced SVG's province paths to **real lat/long GeoJSON** in a **one-time offline build step**,
using the documented inverse of the asset's equirectangular projection:

```
lat = 24.0 − (py / 2349.176) · 16.0
lon = 101.8 + (px / 1200)    · 8.5
```

Draw the resulting polygons as a `flutter_map` `PolygonLayer` **under** the route polyline, checkpoint pins,
current-position marker, and idle-trace overlays. Because the polygons are georeferenced lat/long geometry (not
a pixel-anchored image), they live in the same coordinate space as the existing overlays and require **no CRS
change** to `flutter_map`.

Rationale: correct reprojection; preserves ADR-0004(b)'s canonical-km distance→polyline projection and every
shipped marker unchanged; and keeps **per-province polygons individually addressable**, which enables
per-province theming/selection for the sibling slice `province-chain-2026`.

### (b) Flatten to a single-tone base.

The sourced asset is a choropleth (per-province pastel fills, labels baked into geometry). Flatten it to **one
calm land colour + thin province borders** — the clean "location-map" look from the v2 design review — matching
the app palette, so the overlays read clearly against it. Per-province fills can be re-introduced later for
selection UI **without changing the layer model** (the polygons are already individually addressable).

### (c) Drop the OSM `TileLayer` entirely.

With the bundled base always sufficient and offline-safe, remove the online tile layer. This takes the app's
**only** network egress to **zero** — a privacy improvement — and retires the tile-fetch / error-fallback /
tile-attribution code path. This is the part that **amends/partially supersedes ADR-0004(a)**.

Consequence — attribution shifts: instead of OSM tile attribution, the app must surface the **CC BY-SA 3.0**
attribution for the bundled Wikimedia base map (TUBS/PIkne) in an in-app credits/about line (share-alike
obligation; AC-9). `/privacy-audit` must be re-run — egress should now be **none**.

## Consequences

- **Easier / gained:** the map always reads as Vietnam, even offline (fixes the blank-grey-canvas defect that
  motivated the slice); network egress goes to **zero** (stronger privacy story than ADR-0004's "anonymous tile
  GET"); per-province polygons unlock the sibling `province-chain-2026` selection/theming work; AC-3's "34
  merged units" claim becomes **programmatically checkable** because we now hold vector polygons (count them /
  assert no pre-2025 internal borders), rather than eyeballing a raster.
- **Preserved:** ADR-0004(b)'s canonical-km distance→polyline projection, `RoutePolylineProjector`,
  `RouteProgressResolver`, `IdleTraceMapper`, and every shipped pin/marker/trace are untouched — the base is
  additive and sits beneath them (AC-11).
- **Harder / new obligations:**
  - **SVG→GeoJSON conversion cost & accuracy risk.** The one-time build step is manual/scripted and must be
    right: the choropleth's fills/borders/labels are entangled in the source geometry, and any error in the
    inverse-projection constants (bounds N24/S8 · W101.8/E110.3, viewBox 1200×2349.176) or in path extraction
    misplaces the coastline relative to the georeferenced overlays. The converted GeoJSON must be validated
    (coastline S-shape per AC-4; checkpoints/route land on the landmass per AC-5/6/7) and is itself a bundled
    artifact to maintain.
  - **Geometry weight / performance.** Full-resolution province polygons must be **decimated/simplified and
    cached** so the ~150px minimap stays cheap and the full map is jank-free (NFR-1). This is a new tuning knob
    that did not exist with raster tiles.
  - **Share-alike attribution is now mandatory** (CC BY-SA 3.0, unlike the CC0 art elsewhere) — an in-app
    credit line is a standing obligation (AC-9), and derivative base assets inherit the share-alike terms.
  - **No live pan-to-anywhere world map.** Dropping tiles means the base is Vietnam-only; there is no zoomed-in
    street-level detail. Acceptable: the product only ever shows Vietnam.
- **Trade-off accepted:** we trade OSM's "infinite detail when online" for "always-correct Vietnam, offline,
  zero egress." Given the defect being fixed and the privacy posture, that is the smaller cost.

## Alternatives considered

### `OverlayImageLayer` + EPSG:4326 CRS (anchor the SVG/PNG as a flat image)
Rejected. Anchoring the equirectangular asset as a single georeferenced image would require switching
`flutter_map`'s CRS to EPSG:4326, which risks disturbing the existing markers/tiles/overlay math and the
ADR-0004(b) projector's assumptions. It also yields a **flat image with no per-province addressing** — killing
the province theming/selection that `province-chain-2026` needs — and a raster's edges soften on zoom.

### `CustomPainter` (draw the map ourselves)
Rejected. Re-implements pan/zoom/gesture handling and throws away `flutter_map`'s layer stack, marker/polyline
machinery, and the integration the shipped overlays already rely on. High cost, high regression surface, no
upside over a `PolygonLayer`.

### Keep the OSM `TileLayer` as an optional online layer under/over the bundled base
Rejected (by Kevin, 2026-07-15). Retaining tiles would keep the product's only network egress alive purely for
marginal online detail the product does not need, and would keep the tile-fetch/fallback/attribution code as a
standing maintenance and privacy-audit burden. Dropping it is strictly simpler and takes egress to zero.

### Re-derive distances from the new polygon geometry
Rejected — same reasoning as ADR-0004(b). The curated `segmentsKm` chain remains the single canonical distance
axis and the engine's locked ~2000 km total; the base map is a visual layer only and must not become a second
source of "where am I on the route."
