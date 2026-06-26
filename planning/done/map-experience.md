# Map experience

**Promoted from backlog:** 2026-06-24
**Target:** Wave 2 (v2)
**Shipped:** 2026-06-25 (dev build, macOS-verified)
**Spec:** [specs/map-experience/](../../specs/map-experience/) · **Status:** shipped
**Green test report:** [tests/_runner/reports/map-experience/20260625-004844/](../../tests/_runner/reports/map-experience/20260625-004844/) (verdict green, 730/730)

## Goal
The journey tab carries an inline map (full-screen on tap, no separate Map tab) that follows real Vietnam
province geography and paints the current route's idle segments red — a pure visualizer that adds zero
tracking surface.

## Phase ledger
The **single** status tracker — one row per phase, updated in place after each phase command.

| ✓ | Phase | Command | Date | Verdict / note |
|---|-------|---------|------|----------------|
| [x] | 2 · Spec | `/new-feature` → review & approve `spec.md` | 2026-06-24 | **approved** by Kevin; 12 functional ACs + 3 NFRs; AC-9/AC-10 proposed decisions accepted. Test cases designed in `tests/cases/map-experience.md`. |
| [x] | 3 · Build | `/implement` (includes self-review pass) | 2026-06-24 | **built + self-reviewed.** New geography model + km-axis polyline projector + idle-trace mapper (pure Dart) + MapCubit + MapView (flutter_map/OSM, offline fallback) + inline overlay/full-screen on journey tab; Map tab removed. 90 new tests (67 unit + 23 widget/integration). `flutter analyze` clean, `dart format` clean, **`flutter test` +728 green**. Self-review: 0 blockers; fixed visible OSM attribution (AC-11), redundant buildWhen, dead window-guard assertion, added AC-3 back-dismiss. |
| [x] | 4 · Review | `/review-code` | 2026-06-25 | verdict: **ready** (after fixes). Initial pass: changes-requested + privacy violations-found (no P0/code bug — gated by docs/copy). **All findings closed:** onboarding "no network" copy reworded (truthful OSM-tile disclosure); **ADR-0004** written (OSM/network supersession + Decision A) + `overview.md`/ADR-0002 updated; AC-5 reworded to the shared `routeDistanceKm` axis; TC-229 NFR-1 caching test added; orphaned `route_map_screen.dart` + test deleted, referencing tests reconciled. **Privacy re-audit: PASS.** `analyze` clean, full suite **+726 green (3/3 stable)**. |
| [x] | 5 · Test | `/execute-tests` | 2026-06-25 | verdict: **green** — 730/730 (726 unit/widget + coverage; 4 integration on macOS **device**), 0 failed, 0 flaky. Report: `tests/_runner/reports/map-experience/20260625-004844/`. P0 ACs AC-1…10/AC-12 + NFR-2 ticked `[x]`; AC-11/NFR-1/NFR-3 on-device legs carried to manual checklist (not failures). |
| [x] | 6 · Ship | `/ship` | 2026-06-25 | **shipped (dev build, macOS-verified).** Green report machine-checked (verdict green, 730/730). 12/15 ACs ticked; AC-11/NFR-1/NFR-3 are on-device-only legs carried as pre-public-release items (Kevin confirmed dev-build ship, matching `journey-scene-v2`/`mini-window` precedent). spec `Status: shipped`. |

**Current phase:** ✅ SHIPPED (dev build) 2026-06-25.

## What shipped
- **Map folded into the journey** — the standalone Map tab is gone; the journey tab carries an inline map
  overlay that opens **full-screen on tap** in the same window (ADR-0003), dismissible via close / back / Esc.
  The start-picker + completion-celebration were re-homed from the deleted `RouteMapScreen` into `map_surface.dart`.
- **Real Vietnam geography** — a new pure-Dart geography model (`province_geography.dart`: real lat/long for
  all 13 chain provinces, Mũi Cà Mau ⇄ Hà Giang) + `route_polyline_projector.dart` (the km-axis → lat/long
  projection, **Decision A**). This is the **single geography model** `route-planner-v2` will consume.
- **Red idle trace (#7)** — `idle_trace_mapper.dart` re-bases `idle-accounting`'s distance-keyed segments by
  `routeStartOffsetKm`, clips to the current route, and renders them red (voluntary = solid, lock/sleep =
  dashed — non-colour cue, AC-9); active spans not red; zero-idle → no red; survives restart.
- **Map tiles** — `flutter_map ^8.3.0` + `latlong2 ^0.9.1` + OSM tiles with visible attribution and a
  graceful offline fallback (province road + markers + red trace still render; journey tab never breaks).
  The product's **first outbound network call** — recorded in **ADR-0004** (supersedes the v1 no-network
  stance + ADR-0002 deferral); onboarding privacy copy reworded to disclose anonymous tiles truthfully.
- **Pure visualizer** — `JourneyEngine` / ticker / `ActivityPlugin` untouched; no idle re-classification,
  no distance accrual; no device-location/GPS; `/privacy-audit` **PASS**.
- **Tests:** ~91 new (geography, projector edges, idle mapper, MapCubit incl. TC-229 caching guard, MapView,
  map surface, integration wiring). Full suite **730/730 green** (4 integration on the macOS device).

## What we'd do differently
- **Decide the distance→geometry reconciliation at spec time, not review time.** Decision A (curated km
  stays the canonical axis; per-leg lat/long lerp) was left as an open question and surfaced as a review P1
  (AC-5 wording + an owed ADR). Settling it in the spec would have avoided the docs/copy review churn.
- **Treat "first network call" as a doc/copy task up-front.** The only review/privacy blockers were the
  stale "fully offline / no network" claims in onboarding + `overview.md`. A feature that adds a network
  dependency should bundle the ADR + onboarding-copy update into `/implement`, not discover it at the gate.
- **AC-5 was written aspirationally** ("reuses position math / no second function") vs the real invariant
  (shared `routeDistanceKm` axis; the projector IS a new distance→coordinate function). Phrase ACs against
  the actual seam.

## Carried to pre-public-release (NOT shipped-blocking for the dev build)
- **AC-11** real OSM tile round-trip + real offline/airplane-mode — manual TC-M1/TC-M2 (only the fake-provider
  fallback logic + attribution-present are automated).
- **NFR-1** ≥30 fps on macOS + Windows incl. inline↔full-screen — manual TC-M-NF1 (deterministic
  caching/hot-path guard TC-229 is automated).
- **NFR-3** colour-blind perception (TC-M3) + real screen-reader (TC-M4) — manual (non-colour cue + keyboard
  reach are automated via TC-216/TC-223).
- **NFR-2** runtime egress confirmation (TC-M-PRIV) — packet-capture that only anonymous OSM tile GETs leave
  the machine (static audit + dependency scan are PASS).
- **Windows** runtime never verified (macOS-only dev verification); `flutter_map` desktop tile render/cache/perf
  on Windows is unconfirmed.
- **Non-gating cleanup:** `route_map_painter.dart` is now production-orphaned (only the deleted screen used
  it; still covered by the separation static test) — candidate deletion.

## Decisions made along the way
- Captured as a **single item (size L)**, not an epic — Phase 0 `/capture-idea` 2026-06-24.
- Absorbs the retired `map-geographic` candidate (real geography via `flutter_map` + OSM).
- **ADR-0004** (`docs/architecture/decisions/0004-osm-map-tiles-and-distance-projection.md`) records both
  (a) the OSM/`flutter_map` network supersession and (b) **Decision A** (curated `segmentsKm` stays the
  canonical distance axis; checkpoints at real lat/long; `routeDistanceKm` projects by per-leg lat/long lerp).
  Supersedes ADR-0002's deferral + the overview's no-network narrative.
- **S-3 (idle-accounting carry-forward) resolved without new persistence:** the restored trace rides the
  already-persisted `JourneyProgress.segments`; the open idle span is zero-width (`fromKm==toKm`) so losing
  `idleSince` is invisible on the map. Confirmed sound for AC-8 by both review passes.
- New runtime deps: `flutter_map ^8.3.0` + `latlong2 ^0.9.1`.
- **Provides** the single province-geography model that `route-planner-v2` (#9 waypoint auto-insert) consumes next.
