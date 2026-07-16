# Test report — map-bundle-weight

verdict: green
run_at: 2026-07-15T14:05:43Z
lane: quick-change
runner: fvm flutter build macos --debug + fvm flutter test (in-scope: test/features/route/ + onboarding)

## Result
- Build: `fvm flutter build macos --debug` ✓ built.
- In-scope suite: **446 passed / 0 failed** (`All tests passed!`, exit 0), incl. the base_map_repository real-bundle guard test.

## AC verification
- AC-1 ✓ — built app bundle `flutter_assets/assets/map/` contains ONLY `vietnam_provinces_2025.geojson`; the 4 source SVGs are excluded (verified by inspecting the built .app).
- AC-2 ✓ — 4 SVG sources + `tool/svg_to_geojson.py` still present in the repo (not deleted).
- AC-3 ✓ — app builds and the base_map_repository real-bundle guard loads the bundled GeoJSON; map suite green, no regression.

## Notes
- Config-only change (pubspec asset declaration narrowed from the `assets/map/` dir glob to the single GeoJSON). No code/logic change; no system-signal surface (no privacy audit needed).
