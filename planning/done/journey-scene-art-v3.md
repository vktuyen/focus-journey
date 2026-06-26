# Journey scene art v3 — hi-res cohesive scenery re-source (incl. beach + animals)

**Promoted from backlog:** 2026-06-25
**Target:** visual-polish epic · Wave 1 (closes journey-scene-v2 AC-8 beach/animals gap)
**Spec:** [specs/journey-scene-art-v3/](../../specs/journey-scene-art-v3/)

## Goal
Full cohesive re-source of the journey scene to one higher-craft, stylized-flat, CC0/license-clean pack family
across road/sky/vehicles/parallax/people/city — adding the previously-missing beach/coast + side-view animals
as first-class spawn-rotation kinds — with the pure-view invariant, even-spacing (AC-7), ≥30fps, and privacy
all preserved.

## Phase ledger
The **single** status tracker — one row per phase, updated in place after each phase command.
Each row carries the date + a one-line note + verdict, so a fresh session (`/status`) can resume
from this table alone. Do not keep a separate status log; the ledger IS the log.

| ✓ | Phase | Command | Date | Verdict / note |
|---|-------|---------|------|----------------|
| [x] | 2 · Spec | `/new-feature` → review & approve `spec.md` | 2026-06-25 | **APPROVED.** ACs framed (AC-1..17 + NFR-1..3); 3 open questions resolved (beach=band · general rotation · strict PNG-res). Test cases written `tests/cases/journey-scene-art-v3.md` (19 automatable + 4 manual, AC-traced). |
| [x] | 3 · Build | `/implement` (includes self-review pass) | 2026-06-25 | **DONE.** Spike signed off (AC-1, hybrid rungs 1+2). Wholesale re-source landed: `JourneyAssets.all` 31→32 (4 v1 `objects/*` kinds retired per AC-3; +5 net-new: ship, coast band, 4 animals); beach drawn as scroll-phase backdrop band (`backdropThemeIndexFor`); all replacements strictly higher-res. Tests: TC-301..319 automated + 5 churned tests repaired; **full suite green (+984)**; `analyze` + `dart format` clean. Self-review (flutter-code-reviewer): 0 blocking after fixing one `dart format` line-length at `journey_game.dart:378`; rest suggestion/nit. |
| [x] | 4 · Review | `/review-code` | 2026-06-25 | verdict: **ready** (P1 resolved in-loop). Initial review: changes-requested on 1×P1 (no P0) — bundled-but-unmanifested PNGs. **Fixed (Kevin: wire them in):** wired the 9 orphans (palm/woman/woman_point/house alts as pooled kinds; hills_large+peak_a/b/c as highland bands) AND the 5 `scenery/sky/*` (sun/moon/clouds now rendered — sun/moon arc by cosmetic `timeOfDayHours`, clouds by scroll phase). `JourneyAssets.all` 32→**46**; spawn stride 7→11 (gcd fix, all 21 kinds reachable + runtime assert). Added non-vacuous `bundledJourneyPng_isSubsetOf_manifest` guard. **Delta re-review: ready** (no P0/P1/P2). `analyze` clean, format clean, **309/309 journey tests green**. **`/privacy-audit`: PASS** (art-v3 added zero deps/capabilities; `flutter_map`/`latlong2` are map-experience's — carried to that slice). | |
| [x] | 5 · Test | `/execute-tests` | 2026-06-25 | verdict: **green** — 465/465 (unit/widget 154, journey-feature regression 309, art-v3 integration smoke 2 standalone `-d macos`). 0 fail / 0 skip. fvm Flutter 3.38.10, macOS. All 17 ACs + 3 NFRs ticked `[x]`. Report: `tests/_runner/reports/journey-scene-art-v3/20260625-160430/summary.md`. Mechanical flake patched (integration default-targeted unsigned iOS → re-ran `-d macos`, no source edit). |
| [x] | 6 · Ship | `/ship` | 2026-06-25 | **SHIPPED** (dev build, macOS-verified). Spec `Status: shipped`; green report machine-checked (`verdict: green`, 465/465). Pre-public/Windows carries: NFR-1 on-device ≥30fps (TC-M-NF1), NFR-2 runtime-egress (TC-M-PRIV); P2 polish (AC-7 seam comment, net-new degradation-injection test). |

**Current phase:** ✅ SHIPPED 2026-06-25 (dev build, macOS-verified)   **Next command:** — (closed; pick the next `visual-polish` slice: `journey-dynamic-curve` then `journey-cockpit-lean`).

## What shipped
A full cohesive **art re-source** of the journey Flame scene (pure-view, zero journey-logic change), landed on both surfaces (full window + PiP, one `JourneyGame`):
- **Hybrid art direction (AC-2 rungs 1+2, Kevin signed off):** rung-1 Kenney *Background Elements Remastered* (CC0, 2× res) for scenery/sky; rung-2 original flat vectors for the 6 vehicles, people, animals, and the beach band.
- **Closed the journey-scene-v2 AC-8 gaps:** **beach/coast** now renders as a scroll-phase backdrop band from a real asset; **4 side-view animals** (water buffalo / dog / chicken / bird) are first-class pooled `SideObjectKind`s in the spawn rotation. The long-missing **ship** vehicle skin shipped too.
- **Sky is no longer procedural:** sun/moon arc across the sky by the cosmetic `timeOfDayHours`; clouds drift by scroll phase (both pure functions of existing inputs — no clock/geo).
- **`JourneyAssets.all` 32 → 46**, every replacement strictly higher-res (AC-9), every path CC0/permissive with a CREDITS row (AC-11), scene loads only manifest paths (AC-10), locked by a new `bundled ⊆ manifest` guard test.
- **17 ACs + 3 NFRs all green;** 465/465 automated tests; `/review-code` ready · `/privacy-audit` PASS.
- Green report: [`tests/_runner/reports/journey-scene-art-v3/20260625-160430/`](../../tests/_runner/reports/journey-scene-art-v3/20260625-160430/summary.md) (`verdict: green`).

## What we'd do differently
- **The orphan-asset trap was real and recurred twice.** `/source-assets` staged more PNGs (9 + 5 sky) than the manifest wired up; the first `/review-code` caught 9, and the guard-test author then surfaced 5 more. **Lesson:** the `bundled ⊆ manifest` invariant should have had a guard test from the *first* asset slice — it now exists and will catch this for every future re-source. The curator staging step should reconcile against the manifest before handoff.
- **The enum-stride coprimality bug** (`gcd(7,21)=7` would have stranded 18 of 21 spawn kinds) was a silent-scenery-loss landmine introduced by growing the kind set. The runtime `assert(gcd(stride, length)==1)` added here should be considered a standing pattern for any rotation-by-stride picker.
- **Rung-2 craft-flatness:** the original-flat vehicles/people/animals read flatter than the Remastered scenery (curator-flagged, Kevin accepted). A craft-polish pass on the rung-2 originals (soft shading) remains an optional future tidy-up — not gating, but the cohesion ceiling is set by it.
- On-device ≥30fps (TC-M-NF1) and runtime-egress (TC-M-PRIV) remain manual pre-public/Windows-release legs, consistent with every prior slice.

## Decisions made along the way
- **Re-source scope = FULL** (Kevin, 2026-06-25): one higher-craft cohesive pack family, replace scene +
  scenery + vehicles wholesale (over gap-fill). Golden re-baseline cost accepted.
- **Spike-miss fallback = SWITCH PACK FAMILY** (Kevin, 2026-06-25): prefer a different covering CC0 family over
  procedural-approximation/drop. Ladder: switch family → original flat vectors → approximate/drop (signed-off
  deviation). Encoded in spec AC-2.
- **No ADR expected** — additive through the existing `journey_assets` manifest + `journey_sprites` loader.
- **3 open questions** carried into approval/build: (1) beach as pooled `SideObjectKind` vs parallax band;
  (2) beach frequency / no-geographic-gating default; (3) "higher-resolution" PNG-dimension contract + tie-break.
  See spec `## Open questions`.
- **AC-1 art-direction spike SIGNED OFF (Kevin, 2026-06-25).** Spike landed on a **hybrid (AC-2 ladder rungs
  1+2)**: rung-1 = Kenney *Background Elements Remastered* (CC0, 2× res) for scenery/sky; **rung-2 = original
  flat vectors** for all 6 vehicles (incl. net-new **ship**), people, **4 net-new side-view animals**
  (buffalo/dog/chicken/bird — full-body profiles, not badge faces), and the net-new **beach/coast band**. The
  **rung-2 deviation is explicitly approved** (recorded per AC-2). Candidates staged in
  `assets/journey/_staging_v3/` with draft CREDITS rows + `_CONTACT_SHEET.png`; implementer promotes them into
  the live tree. Known follow-up: rung-2 originals read flatter than rung-1 scenery — optional craft-polish
  pass deferred (not gating).
</content>
