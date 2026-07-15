# Vietnam map fidelity — the current 34-province base map

**Promoted from backlog:** 2026-07-15
**Shipped:** 2026-07-15 (dev build, macOS-verified)
**Spec:** [specs/vietnam-map-fidelity/](../../specs/vietnam-map-fidelity/)
**Wave:** refine-app-ui-ux (slice 1 of the Vietnam-2026 pair; sibling: `province-chain-2026`)
**Green report:** [tests/_runner/reports/vietnam-map-fidelity/20260715-203858/](../../tests/_runner/reports/vietnam-map-fidelity/20260715-203858/summary.md) — verdict `green`, 1297 pass / 1 skip / 0 fail
**ADR:** [ADR-0008](../../docs/architecture/decisions/0008-vietnam-base-map-bundled-geojson-offline.md) (amends ADR-0004)

## Goal
The in-app map (full-screen + minimap) renders Vietnam's current 34-province (2026) administrative base —
accurate, bundled, offline — with the shipped journey georeferenced on top, and no new egress or location read.

## Phase ledger
| ✓ | Phase | Command | Date | Verdict / note |
|---|-------|---------|------|----------------|
| [x] | 2 · Spec | `/new-feature` | 2026-07-15 | Spec approved; 11 ACs + 3 NFRs; design reviewed (v3 artifact). |
| [x] | 3 · Build | `/implement` | 2026-07-15 | Built per ADR-0008: `tool/svg_to_geojson.py` → `assets/map/vietnam_provinces_2025.geojson`; `equirectangular_projection` + `base_map_geometry` (domain), `base_map_repository` (data), `base_map_layer` (single-tone PolygonLayer under overlays); **OSM TileLayer removed → zero egress**; CC BY-SA credit. 98 new tests. Self-review 1 Blocking (Mũi Cà Mau offshore) fixed + S1/S2/S4/N1. |
| [x] | 4 · Review | `/review-code` | 2026-07-15 | **changes-requested → resolved (option A)** · **`/privacy-audit` PASS** (zero egress). B-1 (AC-5 straight-segments cross bays) waived to `province-chain-2026`; test re-scoped honestly + `skip`-with-reason. S-1/S-2/S-3 fixed. |
| [x] | 5 · Test | `/execute-tests` | 2026-07-15 | **green** — 1297 pass / 1 skip / 0 fail (no regression), 0 flakes. Report `20260715-203858`. |
| [x] | 6 · Ship | `/ship` | 2026-07-15 | ✅ Shipped (dev build, macOS-verified). AC-1..11 + NFR-2 `[x]`; NFR-1/NFR-3 on-device legs + Windows runtime carried. |

## What shipped
- Vietnam's **current 34-province (2026)** administrative base map — accurate coastline + merged province
  borders — as an **always-on, bundled, offline** `flutter_map` `PolygonLayer`, in both the full-screen map
  and the compact minimap, with the shipped journey (route/pins/current/idle-trace) **georeferenced** on top.
- Built from a public-domain-adjacent CC BY-SA Wikimedia SVG, converted to lat/long GeoJSON via
  `tool/svg_to_geojson.py` (inverse equirectangular projection); flattened to a single-tone land + thin
  borders (app palette); **OSM tiles dropped → the app now has ZERO network egress** (a privacy improvement
  over ADR-0004); CC BY-SA attribution surfaced on the map + onboarding card.
- Shipped-behaviour preserved (AC-11): ADR-0004(b)'s canonical-km projection + all markers/idle-trace
  unchanged (base is additive, under the overlays).
- Verified: `/review-code` resolved (option A), `/privacy-audit` **PASS** (zero egress), `/execute-tests`
  **green** (1297/1/0). ADR-0008 authored (amends ADR-0004).

## What we'd do differently / follow-ups (carried)
- **Route geometry hugs the coast → `province-chain-2026`.** On the now-accurate coastline, the shipped
  straight-line segments between checkpoints cross coastal bays (`vinh→ninh_binh`, `hue→vinh`,
  `mui_ca_mau→can_tho`, `nha_trang→quy_nhon`). AC-5 was amended to vertices-on-land (13/13); the dense-segment
  test is `skip`-with-reason. The sibling slice owns the fix (route on land) + re-deriving the nudged Mũi Cà
  Mau coordinate.
- **`provinceUnitCount` = 37 rings** (a few units are multipart mainland+island); automated AC-3 asserts the
  ring count, and the "34 merged units" visual verdict rests on the manual TC-M-GEOM leg.
- **CC BY-SA share-alike:** the derived GeoJSON inherits CC BY-SA 3.0 — attribution + share-alike obligations
  recorded in `assets/CREDITS.md`; keep the in-app credit if the asset is redistributed.
- **Carried before public / Windows release:** NFR-1 on-device fps (TC-M-NF1), NFR-3 real screen-reader
  (TC-M-A11Y), TC-M-OFFLINE (real network-down render), TC-M-GEO (visual georef placement), TC-M-GEOM
  (34-unit visual), Windows runtime.

## Decisions (ADR-0008)
- Render path: SVG → lat/long GeoJSON → `flutter_map` `PolygonLayer` under the overlays.
- Map look: flattened choropleth → single-tone land + thin borders.
- OSM tiles: dropped (egress → 0; amends ADR-0004(a)); attribution via in-app CC BY-SA credit.

## Sibling
`province-chain-2026` (backlog) rebuilds the journey province/route DATA MODEL onto the 34 units + fixes the
carried route-hugs-coast geometry — `[blocked by: vietnam-map-fidelity ✅]` (now unblocked). The sourced
34-unit dataset is inlined in that backlog item.
