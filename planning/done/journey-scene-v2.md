# Journey scene v2 — Flame scene fidelity & motion

**Promoted from backlog:** 2026-06-24
**Target:** Wave 2
**Shipped:** 2026-06-24 (dev build)
**Spec:** [specs/journey-scene-v2/](../../specs/journey-scene-v2/) (Status: shipped)
**Green report:** [tests/_runner/reports/journey-scene-v2/20260624-212024/](../../tests/_runner/reports/journey-scene-v2/20260624-212024/summary.md) (`verdict: green`, 642/642)

## Goal
The Flame journey scene reads as a real, calm trip — winding road, ×3-slower visual scroll (same journey
speed), richer scenery, even spacing — and keeps animating when visible-but-unfocused while still pausing
when hidden. Improvements flow to the mini-window PiP for free.

## Phase ledger

| ✓ | Phase | Command | Date | Verdict / note |
|---|-------|---------|------|----------------|
| [x] | 2 · Spec | `/new-feature` → review & approve `spec.md` | 2026-06-24 | **APPROVED.** 10 AC + 3 NFR (POV #2 split → `journey-pov`). Decisions: (a) #5 rule CONFIRMED — relaxes mini-window NFR-1 · (b) occlusion spike = first build task · (c) ~0.33×, reduced-motion overrides · (d) segmented heading-offset road. |
| [x] | 3 · Build | `/implement` (incl. self-review) | 2026-06-24 | **DONE.** Occlusion spike + `WindowVisibilityController` seam; Flame rework: 0.33× cosmetic scroll (engine truth untouched), occlusion-gated animation (per-surface/ADR-0003), segmented winding road (O(1)), even arc-length spacing, 28 CC0 sprites, reduce-motion override, idle parks. Self-review B1 (O(distance)→O(1)) fixed + nits. |
| [x] | 4 · Review | `/review-code` | 2026-06-24 | **READY** (no Blocking). Independently confirmed B1 fix, pure-view invariant, occlusion-not-focus logic, asset safety. **`/privacy-audit`: PASS.** Follow-ups carried (S1/AC-8 guard/TC-009/S2/S5). |
| [x] | 5 · Test | `/execute-tests` | 2026-06-24 | **green.** 641 unit/widget + 1 macOS integration = **642/642**, no flakes. Test-hardening pass first (AC-7 real arc-length, AC-8 reverse-credit guard, TC-009 named families). Report `20260624-212024`. |
| [x] | 6 · Ship | `/ship` | 2026-06-24 | **SHIPPED (dev build).** Gate passed: all ACs `[x]`, no P0/P1 unimplemented, green report verified (postdates last commit). Spec → shipped; archived. Public-release caveats carried (below). |

**Current phase:** ✅ Shipped (Wave 2 · S1a)

## What shipped
- **#3 decoupled scroll** — rendered scroll is a cosmetic ~0.33× playback rate; engine `distanceKm`/progress
  byte-for-byte unchanged (one-way dependency proven by a static separation test). v1 constant pinned
  (`kV1CruiseSpeed=320`), factor `0.33` → `kV2CruiseSpeed≈105.6`.
- **#5 visibility** — new `lib/features/window_visibility/` seam: animate when the shown surface is visible
  (even if unfocused), pause when hidden/minimized/occluded. **macOS = true occlusion** (`NSWindow.occlusionState`);
  **Windows = fallback** (pause on minimized/hidden/cloaked only — accepted per Decision b). Relaxes
  mini-window NFR-1 (occlusion, not focus). Reuses one `JourneyGame` across both surfaces (ADR-0003).
- **#1 winding road** (segmented heading-offset, O(1) closed form), **#12 even arc-length spacing**,
  **#11 richer scenery** (28 CC0 Kenney sprites — mountains/forest/countryside/city/sky/people, all in
  `CREDITS.md`), reduce-motion override, idle parks preserved. **638→642 tests**, `/privacy-audit` PASS.
- Bonus: all improvements flow to the mini-window PiP for free (shared scene instance).

## What we'd do differently / carried before PUBLIC release
- **AC-8 beach/coast + side-view animals OMITTED** — no license-clean cohesive (Kenney-family) asset exists;
  beach approximated procedurally. **Needs TC-M4 human content sign-off**, or a future asset pass that relaxes
  the cohesion rule / finds another CC0 source. (Kevin chose to ship the dev build now, 2026-06-24.)
- **On-device legs not runnable in this env:** real per-OS occlusion (TC-M1/2/3), ≥30fps both surfaces
  (TC-M-NF1, NFR-1), TC-M-PRIV runtime privacy. Automated guards (pooling/no-alloc, O(1) geometry) pass.
- **Windows occlusion is fallback-only** — a PiP fully covered by another window keeps animating on Windows
  (no public API for it); revisit if a reliable signal appears.
- **Non-blocking code follow-ups:** S2 (`dispose()` native-`stop` contract drift, no live leak) →
  `flutter-native-plugin-engineer`; S5 (pause the loop entirely under reduce-motion vs zero-velocity per-frame
  work) → `flutter-app-developer`; harden `_prefix`↔`_headings` sync assert in `road_geometry.dart`.

## Decisions made along the way
- 2026-06-24: Captured (Phase 0, size L); **#2 POV carved out** → [journey-pov](../backlog/journey-pov.md) `[blocked by: journey-scene-v2]`.
- 2026-06-24: Approved — #5 visibility rule confirmed (relaxes mini-window NFR-1); ~0.33× with reduce-motion override; segmented road geometry (no spline → no new ADR).
- 2026-06-24: Build/review/test/ship same day. Self-review B1 (road-geometry cost) fixed O(1); test-hardening pass closed AC-7/AC-8/TC-009 weak assertions before the green run.
