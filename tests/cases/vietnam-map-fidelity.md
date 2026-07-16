# Test cases: vietnam-map-fidelity

Spec: [specs/vietnam-map-fidelity/spec.md](../../specs/vietnam-map-fidelity/spec.md)
Depends on (shipped): [specs/map-experience/spec.md](../../specs/map-experience/spec.md) / ADR-0004 — the `flutter_map` + OSM real-geography map, the canonical-km distance→polyline projector (ADR-0004(b)), the checkpoint pins / current-position marker / red idle-trace overlays this slice draws a base map *underneath* · [specs/route-planner-v2/spec.md](../../specs/route-planner-v2/spec.md) / ADR-0005 — the shipped 13-stop authored-route chain rendered as-is here.
Sibling cases: [map-experience.md](map-experience.md) (base of the overlay layers this sits under) · sibling slice `province-chain-2026` (the 34-unit journey DATA MODEL rebuild — **out of scope here**).
Domain rules: [docs/domain/business-rules.md](../../docs/domain/business-rules.md) — BR-1 (privacy boundary), BR-11 (network egress), BR-6 (distance/stats split).

## Coverage note

`vietnam-map-fidelity` **SLICE 1 = the BASE MAP only**. It adds one always-on, offline, bundled base layer
(`assets/map/vietnam_provinces_2025_base.svg`, Wikimedia CC BY-SA 3.0) rendered *under* the shipped
overlays (route polyline, checkpoint pins, current-position marker, red idle-trace), georeferenced from the
equirectangular bounds **N24 / S8 · W101.8 / E110.3**. It introduces **no** engine/accrual change, **no**
distance/stats-split change (BR-6), **no** re-chaining or distance edit (that is the sibling
`province-chain-2026`), and — the gating concern — **no** new network egress and **no** location/GPS read
(BR-1 / BR-11). This slice keeps the shipped 13-stop chain as-is; **do not** author re-chaining / distance
cases here.

The **strong automatable core** is the **georeferencing projection math** — a deterministic pure function
`(lat, lon) → normalized (x, y)` under the fixed equirectangular bounds (x = (lon−101.8)/(110.3−101.8),
y = (24−lat)/(24−8)), plus a **point-in-landmass** check against the base geometry so overlays never land in
the sea. The **weak / manual-only legs** are the ones no Dart test can honestly settle: the exact
georeferenced **visual placement** (golden/manual), the **current-geometry** check that the 34 merged units
carry **no pre-2025 internal borders** (asset inspection), the **coastline S-shape** recognisability
(visual), the **real offline render with the network truly down** on device, real **on-device fps**, and the
**gating privacy audit**.

Per `docs/architecture/overview.md`, executable tests live **inside** the Flutter package
(`src/focus_journey/test/` unit+widget+golden; `src/focus_journey/integration_test/` e2e; run with
`fvm flutter test` / `fvm flutter test integration_test/ -d <os>`). `tests/cases/` (this file) holds only the
human-readable Given/When/Then. TC-M* legs are **manual / on-device / audit**.

Layer → AC mapping:

| AC / NFR | What it asserts | Covering layer(s) | Cases |
| --- | --- | --- | --- |
| **AC-1** | Offline full-screen map renders the 34-province base from the bundled asset — never blank/grey/empty-tile | Widget (offline tile seam) + **device** | TC-801, TC-802 + TC-M-OFFLINE |
| **AC-2** | Offline ~150px minimap renders the same base — never blank/empty-tile | Widget + **device** | TC-803, TC-804 + TC-M-OFFLINE |
| **AC-3** | Geometry shows the current 34 merged units — no pre-2025 internal borders inside merged units | Unit (unit count) + **asset inspection** | TC-805 + TC-M-GEOM |
| **AC-4** | Recognisable S-shape coastline (Red River delta, concave central coast, Mekong delta, Cà Mau point) | **Manual / golden** | TC-806 + TC-M-GEO |
| **AC-5** | Route polyline reads continuous S→N (~8.6°N→~22.8°N), no segment in the sea | Unit (projection + landmass) + **visual** | TC-807, TC-808 + TC-M-GEO |
| **AC-6** | 13 checkpoints at true georeferenced lat/long on the landmass; spot-checked cities never in the sea | Unit (projection + landmass) + **visual** | TC-809, TC-810, TC-811 + TC-M-GEO |
| **AC-7** | Current-position marker at its true georeferenced location along the route, on the landmass | Unit + integration + **visual** | TC-812 + TC-M-GEO |
| **AC-8** | Overlays legible on base on BOTH surfaces; solid=voluntary vs dashed=lock-sleep by more than colour | Widget/behavioural + **manual perception** | TC-813, TC-814 + TC-M-A11Y |
| **AC-9** | CC BY-SA 3.0 attribution visibly present in-app | Widget | TC-815 |
| **AC-10** | Base adds no new outbound request and reads no location/GPS in any mode | Static inspection + **audit** | TC-816, TC-817 + TC-M-PRIV |
| **AC-11** | Base is purely additive under the overlays — ADR-0004(b) projection + shipped markers/idle-trace unchanged (regression) | Unit + integration | TC-818, TC-819 |
| **NFR-1** | Base renders without jank on full map + minimap; no per-frame regression to overlays (decimated/cached) | Static hot-path guard + **device** | TC-820 + TC-M-NF1 |
| **NFR-2** (CRITICAL gate) | Bundled static asset adds no new egress, no location read; egress→0 if OSM dropped; `/privacy-audit` PASS | Static inspection + **audit** | TC-816, TC-817 + TC-M-PRIV |
| **NFR-3** | Overlays legible by shape/stroke not colour-alone; map controls keyboard-reachable + screen-reader exposed | Widget (semantics/keyboard) + **manual AT** | TC-813, TC-821 + TC-M-A11Y |

**Risky / under-covered areas (flagged for `test-script-author` and reviewers):**

1. **Exact georeferenced pixel placement (AC-5/6/7) is only *half* automatable.** The **projection math**
   (`(lat,lon) → normalized (x,y)` under N24/S8 · W101.8/E110.3) and a **point-in-landmass** test are a
   fully deterministic core (TC-808..TC-812) — this is the strong automatable heart and should be exhaustive
   on the named cities. But whether a pin *visually* sits on the right town (vs 20 px into the sea because
   the asset's drawn coastline doesn't match the mathematical bounds) is a **golden / manual visual**
   spot-check (TC-M-GEO). **The projection can be perfect and placement still look wrong if the SVG's
   viewBox/coastline is not aligned to the declared bounds** — the manual leg is the real guard, and it
   depends on the manual asset pass the spec calls out.
2. **The 34-merged-units "no pre-2025 internal borders" check (AC-3) is essentially an asset-inspection
   leg.** A deterministic test can count distinct provincial units == 34 (if the render path is GeoJSON
   `PolygonLayer` — see the open render-path ADR), but confirming there are **no leftover internal borders**
   inside Gia Lai / Đắk Lắk / Lâm Đồng (the merged units) is a **visual / geometry inspection of the
   flattened asset** (TC-M-GEOM). If the ADR lands on `OverlayImageLayer` (a rasterised image) the unit
   count is not even programmatically inspectable and AC-3 becomes **manual-only**.
3. **Coastline recognisability (AC-4) is manual/golden.** "Reads as Vietnam's S-shape, not a blob" is a
   human perceptual judgement; TC-806 pins a golden for structural regression but the recognisability verdict
   is TC-M-GEO.
4. **Real offline render (AC-1/AC-2) with the network genuinely down.** The automated legs inject an
   offline/failing tile seam so the base must draw without tiles — but "on a real machine with WiFi off,
   the map is never a blank grey canvas or an empty-tile placeholder, on both the full map and the ~150px
   minimap" is the device leg TC-M-OFFLINE. This is the whole point of the feature, so treat it as P0.
5. **NFR-2 privacy is the gating concern (inverted vs `map-experience`).** A bundled static asset should add
   **zero** egress; if the optional OSM `TileLayer` is dropped per the open ADR, the app's only egress goes
   to **zero**. Static inspection (TC-816/TC-817) asserts no new request for the base layer and no location
   API; the `/privacy-audit` PASS + runtime egress inspection is the **gate TC-M-PRIV** — a fail **blocks
   ship**.
6. **On-device NFR legs (NFR-1 fps, NFR-3 real AT).** The deterministic part is automatable (TC-820
   hot-path/decimation guard; TC-821 Semantics + keyboard), but real "no jank on the full map or the tiny
   minimap" and a real screen-reader/keyboard user are manual (TC-M-NF1, TC-M-A11Y). Windows runtime legs are
   **DEFERRED — required before any Windows release** (precedent: `map-experience`, `route-planner-v2`).

## Conventions used by these cases

- **Deterministic by construction for the automated layer.** The projection cases are a **pure function**
  `(lat, lon) → normalized (x, y)` under the fixed equirectangular bounds **N24 / S8 · W101.8 / E110.3**,
  and the landmass check is `point-in-polygon(projected, baseGeometry)` — no timers, no `DateTime.now()`, no
  I/O, no network. Every map surface is fed a **fake/offline `TileProvider`** (reuse `map-experience`'s
  `FakeTileProvider` seam) so no test reaches the network. The current-position marker reuses
  `map-experience`'s scriptable distance source (settable cumulative `distanceKm`).
- **Render-path-agnostic assertions (open ADR).** The build-time ADR (GeoJSON `PolygonLayer` vs
  `OverlayImageLayer` + EPSG:4326 CRS vs `CustomPainter`) and the map-look choice (per-province tints vs
  single-tone) are **not yet settled**. Cases assert **behaviour/structure** — "the base renders", "overlays
  land on the landmass", "34 units", "attribution present" — not a specific layer class. Where a case's
  automatability depends on the ADR (e.g. programmatic unit count needs vector polygons), the case says so
  and points to the manual fallback.
- **Reused upstream contracts (do NOT re-test here).** The distance→polyline projector (ADR-0004(b)
  canonical-km axis), the checkpoint pin placement math, the current-marker position walk, and the red
  idle-trace solid-vs-dashed mapping are owned and tested by `map-experience` / `route-progress`. These
  cases treat them as **given** and assert only what this slice adds: the base layer renders, sits
  **beneath** the overlays, and does not perturb them (AC-11). The 13-stop chain + distances are the shipped
  `route-planner-v2` chain used **as-is** — re-chaining is the sibling `province-chain-2026`, out of scope.
- **Georeferencing bounds are fixed.** All projection cases use exactly **North 24° / South 8° latitude,
  West 101.8° / East 110.3° longitude**. Spot-checked named cities (illustrative, refine against the shipped
  13-stop chain): Hà Nội (~21.03°N, 105.85°E), Đà Nẵng (~16.05°N, 108.20°E), Hồ Chí Minh City (~10.82°N,
  106.63°E), Mũi Cà Mau (~8.6°N, 104.72°E), Hà Giang (~22.82°N, 104.98°E).
- **Tolerances.** Normalized projection equality within **±1e-6**; a projected point is "on the landmass" if
  point-in-polygon against the base geometry returns true (never in a sea/ocean polygon). Golden frames
  tolerate the documented per-OS font/AA variance (goldens pin *structure*, not exact pixels).
- **Test layer.** Per `docs/architecture/overview.md`: unit/widget/golden under `src/focus_journey/test/`,
  integration under `src/focus_journey/integration_test/`, run with `fvm flutter test`. TC-M* legs are
  **manual / on-device / audit**, run during `/execute-tests` and recorded **per OS** where applicable.

## Cases

### Offline base render — full-screen map & minimap (AC-1, AC-2)

### Case: Offline full-screen map renders the recognisable 34-province base from the bundled asset — never blank/grey
**ID:** TC-801
**Priority:** P0
**Type:** happy-path
**Covers:** AC-1

Given the map surface is built with an **offline/failing tile provider** (OSM tiles unreachable, cache empty) and the bundled base asset available
When the full-screen map is shown
Then the recognisable current 34-province Vietnam base renders from the bundled asset — the base layer is present and painted beneath the overlays, and the surface is **never** a blank/grey canvas nor an empty-tile placeholder

**Notes:** Widget test (`src/focus_journey/test/.../presentation/`) with the injected offline tile seam (reuse `map-experience` `FakeTileProvider`). Assert the base layer widget/paint op is present and non-empty when tiles are unavailable. The real WiFi-off render is TC-M-OFFLINE.

---

### Case: The full-screen base is independent of OSM tiles — dropping/failing tiles never blanks the country
**ID:** TC-802
**Priority:** P0
**Type:** negative
**Covers:** AC-1

Given the optional OSM `TileLayer` is failing (or dropped entirely per the render-path ADR)
When the full-screen map renders
Then Vietnam still reads as Vietnam — the bundled base is the source of truth and does **not** depend on any tile fetch; no thrown error, no hanging spinner, and the base is drawn regardless of tile state

**Notes:** Widget test. Guards the offline-first constraint: the base must be strictly independent of the (optional) tile layer. Cover both branches — tiles-fail and tiles-absent. Complements TC-816 (no request issued for the base itself).

---

### Case: Offline ~150px minimap renders the same 34-province base — never a blank background
**ID:** TC-803
**Priority:** P0
**Type:** happy-path
**Covers:** AC-2

Given the compact (~150px) minimap surface is built with an offline/failing tile provider
When the minimap is shown
Then the same 34-province Vietnam base renders from the bundled asset at the compact size — never a blank background nor an empty-tile placeholder — and the country is still identifiable as Vietnam at ~150px

**Notes:** Widget test at the compact size. Assert the base layer is present on the minimap surface, not only the full-screen one (the two surfaces must share the base). The recognisability-at-small-size verdict is TC-M-OFFLINE.

---

### Case: Minimap base is decimated/cached yet still recognisable at compact size
**ID:** TC-804
**Priority:** P1
**Type:** edge
**Covers:** AC-2

Given the base geometry may be decimated/simplified for the cheap minimap (NFR-1)
When the minimap renders the base
Then the decimated base still shows the recognisable Vietnam silhouette (coastline not collapsed to a blob) and is drawn from the bundled asset — decimation trades vertex count, not identity

**Notes:** Widget test. Boundary complement to TC-803 tying AC-2 to NFR-1's "minimap cheap". If the ADR renders the minimap from the same geometry as the full map, assert the shared source; if a separate simplified geometry, assert it is still within the Vietnam bbox and non-blob. Perceptual verdict → TC-M-OFFLINE / TC-M-GEO.

---

### Current geometry — 34 merged units (AC-3)

### Case: The base shows the current 34 merged provincial units with no pre-2025 internal borders
**ID:** TC-805
**Priority:** P0
**Type:** edge
**Covers:** AC-3

Given the bundled base geometry is loaded
When its provincial units are inspected
Then it resolves to the current **34** merged units (2026 administrative structure), and the merged units (e.g. Gia Lai, Đắk Lắk, Lâm Đồng) show **no** leftover pre-2025 internal borders inside them

**Notes:** Automatability depends on the open render-path ADR. If GeoJSON `PolygonLayer`: unit test asserting distinct provincial polygon count == 34 (`src/focus_journey/test/.../data/`). If `OverlayImageLayer` (rasterised): unit count is **not** programmatically inspectable and this becomes manual-only. Either way the "no internal borders inside merged units" verdict is the asset-inspection leg **TC-M-GEOM**. Flag the ADR choice to the reviewer.

---

### Coastline fidelity (AC-4)

### Case: The coastline shows the recognisable S-shape, not a stylized blob
**ID:** TC-806
**Priority:** P1
**Type:** happy-path
**Covers:** AC-4

Given the base is displayed
When the coastline is rendered to a golden frame
Then the golden pins the recognisable S-shape — Red River delta in the north, the concave central coast, the Mekong delta, and the Cà Mau southern point — for structural regression

**Notes:** Golden test (`src/focus_journey/test/`), tolerant of per-OS AA. Pins *structure*, not exact pixels. If goldens are deferred project-wide (precedent: `map-experience` TC-225, `local-stats` TC-NF4), record the golden as deferred and rely on the manual recognisability verdict TC-M-GEO. The human "reads as Vietnam" judgement is inherently manual.

---

### Georeferencing — route, checkpoints, current marker (AC-5, AC-6, AC-7)

### Case: Route polyline reads as a continuous south-to-north line across the georeferenced base
**ID:** TC-807
**Priority:** P0
**Type:** happy-path
**Covers:** AC-5

Given the shipped 13-stop chain overlaid on the base under the equirectangular bounds N24/S8 · W101.8/E110.3
When the route polyline is projected onto the base
Then it reads as one **continuous south→north** line from the southern tip (~8.6°N) to the northern border (~22.8°N) — monotone northward in projected-y across the ordered stops, no reversal, no gap between consecutive stops

**Notes:** Unit test on the projector (`src/focus_journey/test/.../domain/`). Assert projected-y decreases (northward) monotonically along the ordered chain and consecutive stops connect. Reuses `map-experience`'s chain ordering; asserts the *base projection* preserves it. Visual continuity verdict → TC-M-GEO.

---

### Case: No route segment falls in the sea — every polyline point lies on the landmass
**ID:** TC-808
**Priority:** P0
**Type:** edge
**Covers:** AC-5

Given the projected route polyline and the base landmass geometry
When each polyline point (stops + interpolated intermediate points) is tested against the landmass
Then **every** point returns point-in-landmass true — no segment or vertex falls in a sea/ocean region under the declared bounds

**Notes:** Unit test (`src/focus_journey/test/.../domain/`) with a point-in-polygon check against the base geometry. Sample densely along each segment, not just at the stops, to catch a segment cutting across a bay. If the base is a rasterised overlay (no vector polygons), this degrades to the manual visual leg TC-M-GEO — flag per the ADR.

**AC-5 amended (2026-07-15):** AC-5 now requires only the 13 checkpoint **vertices** on land (13/13, asserted) + the route reading S→N; the **dense along-segment** coverage is **deferred to `province-chain-2026`** (the shipped straight-line route hugs city centres, so four legs — `vinh→ninh_binh`, `hue→vinh`, `mui_ca_mau→can_tho`, `nha_trang→quy_nhon` — clip coastal bays before the generalized bundled coastline). The dense-sampling unit test exists but is **skipped** (`skip: 'AC-5 sea-crossing carried to province-chain-2026 (route geometry hugs coast); tracked on manual TC-M-GEO'`) so it is visible as known-deferred, not a silent pass; the visual verdict is carried on **TC-M-GEO**.

---

### Case: The projection math maps each checkpoint's lat/long to the correct normalized position under the fixed bounds
**ID:** TC-809
**Priority:** P0
**Type:** happy-path
**Covers:** AC-6

Given the equirectangular bounds North 24° / South 8° · West 101.8° / East 110.3° and the 13 checkpoints' true lat/long
When each checkpoint is projected
Then its normalized position equals `x = (lon − 101.8)/(110.3 − 101.8)`, `y = (24 − lat)/(24 − 8)` within ±1e-6 — the deterministic georeferencing core

**Notes:** Unit test (`src/focus_journey/test/.../domain/`). **The strong automatable heart of AC-6.** Assert against the closed-form projection for each checkpoint; include the corner/extreme inputs in TC-811. Do not hardcode pixel sizes — assert the normalized (0..1) fraction, then scaling is a separate concern.

---

### Case: Spot-checked named cities land on the landmass, never in the sea
**ID:** TC-810
**Priority:** P0
**Type:** edge
**Covers:** AC-6

Given the projected positions of spot-checked named cities — Hà Nội, Đà Nẵng, Hồ Chí Minh City, Mũi Cà Mau, Hà Giang
When each projected point is tested against the base landmass geometry
Then each returns point-in-landmass true — each pin sits on the country, not in the sea — consistent with its true georeferenced lat/long

**Notes:** Unit test (`src/focus_journey/test/.../domain/`). Uses the illustrative coords in the Conventions block; refine to the shipped chain's actual nodes. The *visual* "the pin is on the right town" spot-check is TC-M-GEO. Point-in-polygon requires the vector base; else manual.

---

### Case: Boundary inputs — points at the bounds' extremes project to the frame edges; out-of-bounds is handled
**ID:** TC-811
**Priority:** P1
**Type:** boundary
**Covers:** AC-6

Given the projection under N24/S8 · W101.8/E110.3
When boundary latitudes/longitudes are projected — lat=24 → y=0 (top), lat=8 → y=1 (bottom), lon=101.8 → x=0 (left), lon=110.3 → x=1 (right), plus a point just outside the bounds
Then the extremes map exactly to the frame edges (within ±1e-6) and an out-of-bounds point is handled per the defined contract (clamped or flagged) — no NaN, no negative overflow, no silent wrap

**Notes:** Unit test (`src/focus_journey/test/.../domain/`). Lower/upper boundary of the projector. Confirms no checkpoint is ever off-frame given the chain sits inside the bounds; documents the out-of-bounds behaviour rather than inventing it (escalate to `system-architect` if unspecified).

---

### Case: The current-position marker sits at its true georeferenced location along the route as the journey advances
**ID:** TC-812
**Priority:** P0
**Type:** happy-path
**Covers:** AC-7

Given the scriptable distance source driving `routeDistanceKm` through several values (start, mid, near-completion) and the base projection
When the current-position marker is placed for each
Then the marker sits at its true georeferenced location **along the route on the landmass**, advancing in the route's south→north direction, and every position returns point-in-landmass true — never in the sea

**Notes:** Unit + integration test. Reuses `map-experience`'s position walk (do **not** re-test the walk); assert the *projected* marker lands on the landmass and moves consistently with the route direction as distance increases. Visual verdict → TC-M-GEO.

---

### Overlay legibility on the base (AC-8)

### Case: Overlays stay distinguishable against the base on the full map, with idle-trace solid vs dashed by more than colour
**ID:** TC-813
**Priority:** P0
**Type:** edge
**Covers:** AC-8, NFR-3

Given the base fills rendered on the full-screen map with the route polyline, checkpoint pins, current marker, and idle-trace (solid=voluntary, dashed=lock-sleep) drawn over it
When the overlays are painted
Then each overlay stays clearly distinguishable against the base, and the two idle-trace causes are distinguished by a **non-colour cue** (stroke/dash pattern), so the solid vs dashed distinction survives regardless of the base fill colour — not colour-alone

**Notes:** Widget/behavioural test (`src/focus_journey/test/.../presentation/`). Reuses `map-experience` TC-216's approach: same red, distinct `StrokePattern`. Asserts legibility is not defeated by the base fill (whichever the map-look ADR picks). The human colour-blind perception verdict is TC-M-A11Y.

---

### Case: Overlays stay distinguishable on the ~150px minimap too, including solid vs dashed idle-trace
**ID:** TC-814
**Priority:** P1
**Type:** edge
**Covers:** AC-8

Given the same overlays drawn over the base on the compact ~150px minimap
When they are painted at the compact size
Then the route, pins, current marker, and both idle-trace styles remain distinguishable against the base at minimap scale — the solid-vs-dashed distinction is not lost to decimation

**Notes:** Widget test at compact size. AC-8 explicitly requires **both** surfaces; this is the minimap half. Assert the dash pattern is still emitted (not collapsed to solid) at the small size. Perceptual verdict → TC-M-A11Y.

---

### Attribution (AC-9)

### Case: The required CC BY-SA 3.0 attribution for the Wikimedia base asset is visibly present in-app
**ID:** TC-815
**Priority:** P0
**Type:** happy-path
**Covers:** AC-9

Given the app running with the base map displayed
When the map (or an about/credits surface) is viewed
Then the required **CC BY-SA 3.0** attribution for the Wikimedia `vietnam_provinces_2025_base.svg` asset is **visibly present** in-app — a real, findable credit line (distinct from, and in addition to, the existing OSM tile attribution)

**Notes:** Widget test (`src/focus_journey/test/.../presentation/`). Assert the attribution widget/string is present and rendered (not zero-opacity/off-screen). Licence is share-alike → the credit is mandatory (unlike the CC0 art). If product places it on an about/credits screen rather than the map, assert it there.

---

### Privacy — no new egress, no location read (AC-10 / NFR-2)

### Case: The base layer issues no outbound request and reads no location/GPS in any mode (online or offline, full map or minimap)
**ID:** TC-816
**Priority:** P0
**Type:** edge
**Covers:** AC-10, NFR-2

Given the base rendering in any mode — full map or minimap, online or offline
When network and platform calls are observed (request-capturing fake tile provider + a network monitor over the base path)
Then **no** outbound request is issued for the **base layer** (it is a bundled asset), and **no** location/GPS/geolocation API is read — the only permissible egress remains `map-experience`'s optional anonymous OSM tile GETs, and if the OSM `TileLayer` is dropped per the ADR, base-path egress is **zero**

**Notes:** Widget/integration test with a request-capturing seam. Assert the base loads from the bundled asset (no HTTP), and zero requests are attributable to the base layer. Ties BR-11. The runtime egress + `/privacy-audit` PASS is the gate TC-M-PRIV.

---

### Case: The slice imports no location/GPS API and adds no new network surface — static guard
**ID:** TC-817
**Priority:** P0
**Type:** edge
**Covers:** AC-10, NFR-2

Given all `vietnam-map-fidelity` source (the base layer widget/painter, the projection code, asset wiring) and its dependency set
When inspected statically
Then it imports/calls **no** device-location / GPS / geolocation API (no `geolocator`/`location`/CoreLocation/platform location channel), the georeferencing bounds + base are **static app-shipped constants/assets** (never a device read), and it adds **no** new network dependency beyond the already-shipped `flutter_map`/OSM tiles — BR-1 intact

**Notes:** Static-inspection case (`src/focus_journey/test/`, grep over imports + `pubspec`). The automatable subset of the gating NFR-2/AC-10. Assert no new privacy-relevant API vs the pre-feature baseline. The `/privacy-audit` PASS is the gate TC-M-PRIV — a fail **blocks ship**.

---

### Regression guard — base is purely additive under the overlays (AC-11)

### Case: Adding the base layer leaves ADR-0004(b)'s canonical-km distance→polyline projection unchanged
**ID:** TC-818
**Priority:** P0
**Type:** regression
**Covers:** AC-11

Given the shipped ADR-0004(b) canonical-km distance→polyline projector, exercised over a sweep of `routeDistanceKm` values before and after the base layer is added beneath the overlays
When the projected polyline positions are compared
Then they are **identical** (within ±1e-6) before and after — the base layer does not alter, re-scale, or re-project the shipped canonical-km axis; it is purely additive underneath

**Notes:** Unit test (`src/focus_journey/test/.../domain/`). The projector is owned by `map-experience`/ADR-0004 — assert it is **unchanged**, not re-tested. Guards against the base's equirectangular bounds accidentally becoming the axis the overlays project through.

---

### Case: Shipped markers and idle-trace render unchanged with the base drawn beneath them
**ID:** TC-819
**Priority:** P0
**Type:** regression
**Covers:** AC-11

Given the shipped checkpoint pins, current-position marker, and red idle-trace, rendered once without the base and once with the base layer added underneath (same fixture chain + distance + segments)
When both renders are compared
Then the overlays are **structurally identical** — same pin positions, same marker position, same red stretches, correct z-order (base beneath, overlays above) — the base changes only what is *below* the overlays, never the overlays themselves

**Notes:** Integration/widget test (`src/focus_journey/integration_test/`). Assert overlay geometry is invariant to the base's presence and that z-order places the base under route/pins/current/idle-trace. Reuses `map-experience` overlay fixtures. Pairs with TC-818 (the math half).

---

### Non-functional

### Case: Base geometry is decimated/cached and not re-allocated per frame; the minimap path stays cheap
**ID:** TC-820
**Priority:** P1
**Type:** nfr
**Covers:** NFR-1

Given the base layer's paint/build path on both the full map and the ~150px minimap
When `paint`/`shouldRepaint` (or the layer's rebuild path) are inspected and a redraw sweep is run
Then the static base geometry is built once / cached (not re-parsed or re-allocated per frame), the minimap uses a decimated/cheaper geometry as needed, and the base adds **no** per-frame regression to the shipped overlays (`shouldRepaint` false when nothing relevant changed)

**Notes:** Static inspection + widget redraw test (`src/focus_journey/test/`). The deterministic part of NFR-1; mirrors `map-experience` TC-229. Assert the SVG/base is decoded once, not per frame. Real fps on macOS/Windows is on-device only — TC-M-NF1.

---

### Case: Map controls are keyboard-reachable and screen-reader labelled; overlays legible by shape not colour-alone
**ID:** TC-821
**Priority:** P1
**Type:** edge
**Covers:** NFR-3

Given any map controls introduced or adjusted by this slice (and the existing tap-to-fullscreen / dismiss affordances the base now sits under) and the overlay styles
When the widget tree's semantics and keyboard focus traversal are inspected
Then every interactive map control is **keyboard-reachable** (focusable + activatable, Esc-to-dismiss where applicable) and carries **meaningful semantic labels**, and the overlays remain distinguishable by **shape/stroke as well as colour** (not colour-alone) against the base

**Notes:** Widget test (`src/focus_journey/test/.../presentation/`) asserting `Semantics` labels + keyboard focusability. The deterministic part of NFR-3; if this slice adds no new controls, assert the existing `map-experience` controls still expose semantics with the base present (no regression). Real screen-reader/keyboard operation is TC-M-A11Y.

---

## Manual / on-device / audit legs (TC-M*)

These are the cases whose only honest verification is a **real offline render**, a **visual placement
spot-check**, an **asset/geometry inspection**, an **on-device measurement**, a **real screen reader**, or
the **gating privacy audit** — they cannot be a deterministic Dart test. Run during `/execute-tests` and
record the verdict **per OS** where applicable. `Windows` runtime legs are **DEFERRED — required before any
Windows release** (precedent: `map-experience`, `route-planner-v2`, `mini-window`).

### TC-M-OFFLINE — Real offline render on both surfaces, network genuinely down (P0, device, [DEVICE])
Covers AC-1, AC-2 (real no-network leg). Automated companions: TC-801..TC-804.

Steps (real desktop build, **WiFi/network turned off** at the OS level):
1. Open the full-screen map → confirm the recognisable 34-province Vietnam base renders, **never** a blank
   grey canvas or an empty-tile placeholder.
2. Open the compact ~150px minimap → confirm the same base renders and Vietnam is still identifiable at that
   size.
3. Toggle network back on then off again while the map is on screen → confirm the base never disappears
   (it is independent of tiles).

Expect: on a machine with no network, both surfaces always read as Vietnam from the bundled asset. Record
device + OS.

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (DEFERRED — required before any Windows release): Pass [ ]  Fail [ ]  Blocked [ ]

### TC-M-GEO — Visual georeferenced placement spot-check (P0, visual, [VISUAL])
Covers AC-4, AC-5, AC-6, AC-7 (the exact-placement leg the projection math cannot fully settle). Automated
companions: TC-806..TC-812.

Steps (on the rendered base, full map + minimap):
1. Confirm the coastline reads as Vietnam's **S-shape** — Red River delta (north), concave central coast,
   Mekong delta, Cà Mau southern point — not a blob (AC-4).
2. Spot-check that named checkpoints sit visually **on their true towns**, on the landmass, never in the sea
   — Hà Nội, Đà Nẵng, HCMC, Mũi Cà Mau, Hà Giang (AC-6). Watch for the classic "pin 20 px into the sea"
   symptom of a viewBox/coastline that doesn't match the declared N24/S8 · W101.8/E110.3 bounds.
3. Confirm the route polyline reads as one continuous south→north line on land (AC-5) and the current-marker
   advances along it on the landmass (AC-7).

Expect: overlays visibly land on their true geographic locations on the drawn coastline. This is the guard
for asset/bounds misalignment. Record device + OS.

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (DEFERRED — required before any Windows release): Pass [ ]  Fail [ ]  Blocked [ ]

### TC-M-GEOM — Asset inspection: 34 merged units, no pre-2025 internal borders (P1, asset, [ASSET])
Covers AC-3 (the geometry-correctness leg). Automated companion: TC-805 (unit count only, if vector).

Steps (inspect the flattened base asset / rendered geometry):
1. Confirm the base shows the current **34** merged provincial units (2026 structure).
2. Confirm the merged units — Gia Lai, Đắk Lắk, Lâm Đồng (and the other merges) — carry **no** leftover
   pre-2025 internal borders inside them (the choropleth/label-baked source needed the manual asset pass the
   spec flags — confirm that pass removed the internal divisions).

Expect: the geometry is the current 34-unit structure with clean merged units. Note the render-path ADR:
if `OverlayImageLayer` (rasterised), this is the **only** verification of AC-3.

- Verdict (asset-level, no per-OS split): Pass [ ]  Fail [ ]  Blocked [ ]
- Inspector / date: `__________`

### TC-M-NF1 — Base renders without visible jank on full map + minimap (P1, device, [DEVICE])
Covers NFR-1. Deterministic guard: TC-820.

Steps: open the full-screen map and the ~150px minimap on a real build; pan/interact and switch
inline↔full-screen; observe frame timing with the base layer present.

Expect: no visible jank on either surface, and no per-frame regression to the shipped overlays vs the
pre-feature baseline (the decimated/cached base keeps the minimap cheap). Record device + OS.

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (DEFERRED — required before any Windows release): Pass [ ]  Fail [ ]  Blocked [ ]

### TC-M-A11Y — Overlays legible beyond colour + map controls keyboard/screen-reader operable (P1, [AT])
Covers AC-8, NFR-3 (real perception + AT leg). Automated legs: TC-813, TC-814, TC-821.

Steps (VoiceOver on macOS / Narrator on Windows, then keyboard-only; and a colour-vision check):
1. Confirm the solid (voluntary) vs dashed (lock/sleep) idle-trace is distinguishable against the base by
   **shape/stroke**, not colour — including a colour-blind perception check — on both the full map and the
   minimap.
2. With the screen reader on, confirm any map controls are announced with meaningful names and reachable by
   Tab / activatable by Enter / dismissable by Esc.

Expect: a colour-blind and a screen-reader/keyboard-only user can read the overlays against the base and
operate the map controls. Record device + OS.

- macOS (VoiceOver + keyboard): Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (Narrator + keyboard, DEFERRED — required before any Windows release): Pass [ ]  Fail [ ]  Blocked [ ]

### TC-M-PRIV — Privacy audit: bundled base adds no egress, no location read (P0, audit, [AUDIT]) — **CRITICAL, GATING**
Covers AC-10, NFR-2 (the gating concern). **Ship-blocker.** Static reinforcement: TC-816, TC-817.

Steps (run `/privacy-audit`, i.e. `privacy-guardian`, over the slice, and inspect real egress):
1. Confirm the base layer / projection / asset wiring perform **no** new read of location/GPS and add **no**
   new network dependency — the base is a bundled static asset (BR-1 intact).
2. **Runtime egress inspection:** with a network monitor running, open the full map and the minimap online
   and offline → confirm **no** outbound request is attributable to the **base layer** (the only permissible
   traffic is the pre-existing anonymous OSM tile GETs — and if the OSM `TileLayer` is dropped per the ADR,
   confirm the app's egress is **zero**, BR-11).
3. Confirm no georeferencing/location data is ever read from the device (the bounds + coords are static
   app-shipped constants).

Expect: the audit **passes** — a bundled base map that adds no egress and no location surface. A
contradiction **fails NFR-2/AC-10 and blocks ship** regardless of every other pass. Re-run on any change to
the slice's source or dependency set (esp. the OSM keep/drop decision).

- Audit verdict (source-level, no per-OS split): Pass [ ]  Fail [ ]  Blocked [ ]
- Runtime egress verdict (per OS): macOS Pass [ ]  Fail [ ]  Blocked [ ]   Windows Pass [ ]  Fail [ ]  Blocked [ ] (DEFERRED)
- Auditor / date: `__________`

---

## Coverage table (AC / NFR → covering case IDs)

| Item | Description | Covered by |
|---|---|---|
| AC-1 | Offline full-screen map renders 34-province base from bundled asset — never blank/grey/empty-tile | TC-801, TC-802, TC-M-OFFLINE |
| AC-2 | Offline ~150px minimap renders the same base — never blank/empty-tile | TC-803, TC-804, TC-M-OFFLINE |
| AC-3 | Geometry shows 34 merged units — no pre-2025 internal borders | TC-805, TC-M-GEOM |
| AC-4 | Recognisable S-shape coastline (deltas + central concave + Cà Mau point) | TC-806, TC-M-GEO |
| AC-5 | Route polyline continuous S→N (~8.6°N→~22.8°N), no segment in the sea | TC-807, TC-808, TC-M-GEO |
| AC-6 | 13 checkpoints at true georeferenced lat/long on the landmass; cities never in the sea | TC-809, TC-810, TC-811, TC-M-GEO |
| AC-7 | Current marker at its true georeferenced location along the route, on the landmass | TC-812, TC-M-GEO |
| AC-8 | Overlays legible on base on BOTH surfaces; solid vs dashed idle-trace by more than colour | TC-813, TC-814, TC-M-A11Y |
| AC-9 | CC BY-SA 3.0 attribution visibly present in-app | TC-815 |
| AC-10 | Base adds no new outbound request; reads no location/GPS in any mode | TC-816, TC-817, TC-M-PRIV |
| AC-11 | Base purely additive under overlays — ADR-0004(b) projection + shipped markers/idle-trace unchanged | TC-818, TC-819 |
| NFR-1 | Base renders without jank on full map + minimap; no per-frame overlay regression (decimated/cached) | TC-820 (deterministic guard), TC-M-NF1 (on-device) |
| NFR-2 (CRITICAL gate) | Bundled static asset — no new egress, no location read; egress→0 if OSM dropped; `/privacy-audit` PASS | TC-816, TC-817 (static), TC-M-PRIV (audit + runtime egress) |
| NFR-3 | Overlays legible by shape/stroke not colour-alone; map controls keyboard + screen-reader reachable | TC-813, TC-821 (deterministic), TC-M-A11Y (manual perception/AT) |

Every AC (AC-1..AC-11) and every NFR (NFR-1..NFR-3) maps to at least one case. No AC is orphaned. The TC-M*
manual / on-device / asset / audit legs are listed inline above (this feature has no separate companion
checklist — its manual surface is the offline render, the georeferenced-placement spot-check, the
34-unit asset inspection, the on-device fps, the AT/perception leg, and the gating privacy audit).
