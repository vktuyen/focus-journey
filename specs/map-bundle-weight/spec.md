# Map bundle weight — ship only the runtime GeoJSON, not the source SVGs

**Status:** shipped (2026-07-15, quick-change — macOS build-verified)
**Owner:** Kevin (Tuyen Vo)
**Last updated:** 2026-07-15
**Lane:** quick-change (small, low-risk config fix)

## Problem
`pubspec.yaml` bundles the whole `assets/map/` directory (2.9 MB), but the app only loads the 200 KB
`vietnam_provinces_2025.geojson` at runtime. The four source SVGs (2.7 MB) ship as dead weight in the app.

## Outcome
The app bundles only the runtime GeoJSON; the SVG source-of-record (input to `tool/svg_to_geojson.py`) stays
in the repo but is excluded from the app bundle.

## Scope
### In
- Narrow the `pubspec.yaml` map-asset declaration from the `assets/map/` directory glob to the single file
  `assets/map/vietnam_provinces_2025.geojson`.

### Out
- No code/logic change; no change to what the app loads at runtime.
- No file deletion — the SVGs + conversion tool remain in the repo as source-of-record.

## Acceptance criteria
- [x] AC-1: `pubspec.yaml` declares `assets/map/vietnam_provinces_2025.geojson` (a single file), not the `assets/map/` directory — so the 4 source SVGs are NOT copied into the built app bundle.
- [x] AC-2: The SVG source files and `tool/svg_to_geojson.py` remain present in the repo (not deleted).
- [x] AC-3: The app still builds and loads the base map from the bundled GeoJSON — the `base_map_repository` real-bundle guard test stays green and the map suite shows no regression.

## Related
- Shipped feature: [specs/vietnam-map-fidelity/](../vietnam-map-fidelity/) (introduced `assets/map/`).
