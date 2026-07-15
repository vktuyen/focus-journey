# Vietnam map fidelity — the current 34-province base map

**Status:** shipped (2026-07-15, dev build — macOS-verified; NFR-1 on-device fps + NFR-3 real screen-reader + Windows runtime carried to the manual checklist; AC-5 straight-segment sea-crossings carried to `province-chain-2026`)
**Owner:** Kevin (Tuyen Vo)
**Last updated:** 2026-07-15
**Wave:** refine-app-ui-ux (slice 1 of the Vietnam-2026 pair; sibling: `province-chain-2026`)

## Problem
Today the in-app map frequently renders as checkpoints and a route floating on a blank grey canvas — the OSM
tiles often fail to load, and the offline fallback is a flat background. The one screen that should always say
"this is Vietnam" says nothing, which breaks the app's ambient sense of place and undercuts the local-only
trust story. It must instead render an **accurate map of Vietnam's current (2026) 34 provinces**, always — even
offline — with the journey drawn on top.

## User & outcome
- **Focused individual:** opens the map and immediately sees a recognisable Vietnam with all current provinces;
  the journey (route, stops, current position) reads clearly on top. Works identically offline.
- **Privacy-skeptical teammate:** the map is a bundled static asset — visible proof it needs no network and no
  location to draw the country.
- Observable success: the recognisable 34-province Vietnam renders with no network; checkpoints/route sit on
  their true geographic locations; overlays stay legible; no new egress or location read is introduced.

## Scope
### In
- Render Vietnam's **current 34-unit (2026) administrative base map** — accurate coastline + merged province
  borders — as an **always-on, offline, bundled** base layer, in BOTH the full-screen map and the compact
  minimap.
- Overlay the existing journey (route polyline, checkpoint pins, current-position marker, red idle-trace) on
  the base, **georeferenced** from real lat/long (equirectangular bounds N24/S8 · W101.8/E110.3).
- Use the sourced asset `assets/map/vietnam_provinces_2025_base.svg` (Wikimedia, CC BY-SA 3.0). Surface the
  **required CC BY-SA attribution** in an in-app credits/about line.
- Decide (ADR) how the asset is rendered in `flutter_map` given its equirectangular projection differs from
  flutter_map's default Web-Mercator — and whether the OSM `TileLayer` is kept (optional) or dropped.

### Out
- **Rebuilding the journey's province/route DATA MODEL onto the 34 units** — that is the sibling slice
  `province-chain-2026` (this slice keeps the shipped 13-stop chain; it only changes the *base map* it's drawn on).
- No engine/accrual change; no distance/stats-split change (BR-6); no live GPS/location.
- No new persistence tech.

## Constraints & assumptions
- **Offline-first:** the base must render with zero network. The bundled SVG is the source of truth; OSM tiles
  (if retained) are strictly optional and never required for the map to read as Vietnam.
- **Privacy (BR-1/BR-11):** a bundled static asset adds no new egress and no location read; if OSM tiles are
  dropped, the app's only egress goes to zero (re-audit).
- **Preserve shipped geometry:** ADR-0004(b)'s canonical-km distance→polyline projection and every shipped
  marker/idle-trace must keep working — the base map goes *under* the existing overlay layers.
- **Licence:** CC BY-SA 3.0 (attribution + share-alike) — an in-app credit is mandatory (unlike the CC0 art).
- **Asset caveat:** the SVG is a coloured choropleth with province labels baked into the geometry
  (fills/borders entangled); flattening to a clean single-tone "location-map" look needs a manual asset pass.

## Acceptance criteria

- [x] AC-1: Given the machine has no network connection (OSM tiles unreachable), when the full-screen map is shown, then the recognisable current 34-province Vietnam base renders from the bundled asset — never a blank/grey canvas or an empty-tile placeholder.
- [x] AC-2: Given the machine has no network connection, when the compact (~150px) minimap is shown, then the same 34-province Vietnam base renders from the bundled asset — never a blank background or empty-tile placeholder.
- [x] AC-3: Given the base is displayed, when its geometry is inspected, then it shows the current 34 merged provincial units (no pre-2025 internal borders inside the merged units, e.g. within Gia Lai, Đắk Lắk, or Lâm Đồng).
- [x] AC-4: Given the base is displayed, when the coastline is inspected, then the recognisable S-shape is present — the Red River delta in the north, the concave central coast, the Mekong delta, and the Cà Mau southern point — rather than a stylized blob.
- [x] AC-5: Given the journey overlay is drawn on the base, when the route polyline is rendered, then it reads as a continuous south-to-north line from the southern tip (~8.6°N) to the northern border (~22.8°N), and every checkpoint **vertex** sits on the landmass (13/13). _(Amended 2026-07-15, review option A: the shipped **straight-line segments** between checkpoints may cross coastal bays on the now-accurate coastline — route geometry that hugs the coast is owned by `province-chain-2026`; carried as a known limitation on manual TC-M-GEO. This slice owns the base map, not the route path.)_
- [x] AC-6: Given the 13 checkpoints are drawn on the base, when spot-checked against named cities, then each pin sits at its true georeferenced lat/long location on the landmass (never in the sea) under the equirectangular bounds N24/S8 · W101.8/E110.3.
- [x] AC-7: Given the current-position marker is drawn on the base, when the journey advances, then the marker sits at its true georeferenced location along the route on the landmass, consistent with the route direction.
- [x] AC-8: Given the base fills are rendered, when the idle-trace (solid=voluntary, dashed=lock-sleep), checkpoint pins, and route polyline are drawn over it, then each stays clearly distinguishable against the base on BOTH the full map and the minimap — distinguished by more than colour alone (shape/stroke/dash), so the solid vs dashed idle-trace distinction survives.
- [x] AC-9: Given the app is running, when the map (or an about/credits surface) is viewed, then the required CC BY-SA 3.0 attribution for the Wikimedia `vietnam_provinces_2025_base.svg` asset is visibly present in-app.
- [x] AC-10: Given the base renders in any mode (full map or minimap, online or offline), when network and platform calls are observed, then no new outbound request is issued for the base layer and no location/GPS API is read (BR-1/BR-11).
- [x] AC-11: Given the base layer is added under the existing overlays, when the shipped journey is rendered, then ADR-0004(b)'s canonical-km distance→polyline projection and every shipped marker/idle-trace behave unchanged (the base is purely additive and sits beneath the overlay layers) — regression guard.

### Non-functional
- [ ] NFR-1 Performance: The bundled base renders without visible jank on both the full-screen map and the ~150px minimap, and introduces no per-frame regression to the shipped overlays (base geometry is decimated/cached as needed to keep the minimap cheap). _(Memoized conversion + cached decimated minimap in code; on-device fps TC-M-NF1 carried — no automated timing measurement.)_
- [x] NFR-2 Security/Privacy: The base is a bundled static asset that adds no new network egress and no location/GPS read; BR-1 and BR-11 remain intact, and if the optional OSM `TileLayer` is dropped the app's only egress goes to zero (re-run `/privacy-audit`). _(privacy-audit PASS, 2026-07-15 — OSM tiles dropped; app now has ZERO network egress. AC-10 also confirmed.)_
- [ ] NFR-3 Accessibility: Overlays remain legible against the base by shape/stroke as well as colour (not colour-alone), and any map controls are reachable via keyboard and exposed to screen readers. _(Deterministic semantics/keyboard + solid-vs-dashed shape distinction tested; real screen-reader / colour-blind perception TC-M-A11Y carried.)_

## Open questions — RESOLVED 2026-07-15 (see [ADR-0008](../../docs/architecture/decisions/0008-vietnam-base-map-bundled-geojson-offline.md))
- [x] **Render path:** convert the SVG province paths to lat/long **GeoJSON** (inverse of the documented equirectangular projection) and draw as a `flutter_map` **`PolygonLayer`** under the existing overlays — correct reprojection, keeps ADR-0004(b) projector + markers, per-province polygons addressable.
- [x] **OSM tiles:** **dropped** — the bundled base is offline-safe; egress → 0. Amends ADR-0004(a). Attribution shifts to the in-app CC BY-SA credit (AC-9). Re-run `/privacy-audit`.
- [x] **Map look:** **flatten** the choropleth to a single-tone land + thin borders (clean "location-map" look, app palette). Per-province fills reintroducible later without changing the layer model.

## Related
- Backlog framing + design reviews (v1→v3 artifact): [planning/backlog/vietnam-map-fidelity.md](../../planning/backlog/vietnam-map-fidelity.md) _(consumed on promotion)_
- Sibling slice + 34-unit dataset: [planning/backlog/province-chain-2026.md](../../planning/backlog/province-chain-2026.md)
- Domain rules: [docs/domain/business-rules.md](../../docs/domain/business-rules.md) — BR-1, BR-11, BR-6
- Architecture: [docs/architecture/](../../docs/architecture/) — ADR-0004 (OSM tiles + canonical-km projection)
