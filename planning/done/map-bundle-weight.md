# Map bundle weight — ship only the runtime GeoJSON

**Promoted:** 2026-07-15 (quick-change lane)
**Shipped:** 2026-07-15 (macOS build-verified)
**Spec:** [specs/map-bundle-weight/](../../specs/map-bundle-weight/)
**Green report:** [tests/_runner/reports/map-bundle-weight/20260715-210543/](../../tests/_runner/reports/map-bundle-weight/20260715-210543/summary.md) — verdict `green`, 446 pass

## Goal
Stop bundling the 2.7 MB of source SVGs into the app; ship only the 200 KB runtime GeoJSON.

## Phase ledger — QUICK-CHANGE
| ✓ | Phase | Command | Date | Verdict / note |
|---|-------|---------|------|----------------|
| [x] | 2 · Spec (inline stub) | `/quick-change` | 2026-07-15 | 3 ACs; approved. |
| [x] | 3 · Implement + self-review | — | 2026-07-15 | pubspec `assets/map/` dir glob → single `vietnam_provinces_2025.geojson`. Config-only; self-reviewed inline (no Blocking). |
| [x] | 4 · Review | — | 2026-07-15 | Self-review only (one-line asset-scope change; no system-signal surface → no privacy audit). |
| [x] | 5 · Test | — | 2026-07-15 | **green** — build ✓; bundle contains only the GeoJSON (SVGs excluded); 446 in-scope tests pass incl. the real-bundle guard. Report `20260715-210543`. |
| [x] | 6 · Ship | — | 2026-07-15 | ✅ Shipped. AC-1..3 `[x]`. |

## What changed
`pubspec.yaml` now declares the single file `assets/map/vietnam_provinces_2025.geojson` instead of the whole
`assets/map/` directory — the app bundle drops the 4 source SVGs (~2.7 MB dead weight), keeping only the
200 KB GeoJSON the app actually loads. The SVGs + `tool/svg_to_geojson.py` stay in the repo as the
source-of-record for the conversion.

## Verified
Built `.app` `flutter_assets/assets/map/` contains only the GeoJSON (AC-1); SVG sources + tool still in repo
(AC-2); build succeeds + base-map real-bundle guard + map suite green, no regression (AC-3).
