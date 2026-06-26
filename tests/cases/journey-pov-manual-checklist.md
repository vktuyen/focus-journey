# Manual run checklist — journey-pov

Per-OS / human-driven verification of the `journey-pov` cases that **cannot** be a deterministic Dart
unit/widget/integration test because they need a **real OS window** (a real frameless always-on-top PiP
rendering the cockpit + still pausing on real occlusion), a **real on-device performance measurement**
(≥30fps on both surfaces with both cockpits loaded), a **human art-cohesion / accessibility judgement**
(the cockpit reads as cohesive stylized-flat, gauges read decorative, no rider hands, distinct
car-vs-motorbike silhouette, road readable through the windshield), or are a **privacy audit**. Follow this
during `/execute-tests` and record the verdict per case **per OS** where a per-OS split applies.

- Authoritative scenarios: [journey-pov.md](journey-pov.md) (TC-201..TC-221 + the TC-M* legs below).
- Automated companions live under `src/focus_journey/test/` (widget/golden) and
  `src/focus_journey/integration_test/` (e2e) against the **mock** activity + window/visibility path — see
  "Automated companions" below.
- Shares the scene + PiP with `journey-scene-v2` — the real-OS occlusion plumbing this checklist relies on
  is the same one verified in [journey-scene-v2-manual-checklist.md](journey-scene-v2-manual-checklist.md)
  (TC-M1/TC-M3); here we only confirm the **cockpit overlay** rides it correctly.

## How this maps to automation

| TC (this checklist) | Verification here | Automated companion (mock path) |
|----|-------------------|---------------------|
| TC-M-PIP | **Manual [REAL-OS]** — on a real frameless always-on-top PiP, the cockpit renders correctly (scaled, road readable) AND does not break frameless/always-on-top behaviour nor occlusion/visibility pause (AC-11/AC-12 real legs) | cockpit on both surfaces scaled: TC-209; no per-frame work / pause-unbroken logic: TC-210; mock-path both-surfaces smoke: TC-221 |
| TC-M4-ART | **Manual [REVIEW]** — stylized-flat art cohesion + accessibility: cockpit reads as the Kenney flat family (not photoreal), gauges decorative (no numbers), no rider hands, distinct car-vs-motorbike silhouette (not colour-alone), road readable through windshield / over handlebars, "Paused — idle" overlay not obscured (AC-16 gate + AC-2/AC-4/AC-5 visual + NFR-3 visual) | framing ratio TC-205; goldens TC-211/TC-212; gauges-not-data-driven TC-202; no-hands TC-204; asset⇄CREDITS TC-219 |
| TC-M-NF1 | **Manual / device [DEVICE]** — sustained ≥30fps on **both** surfaces with **both** cockpits loaded while `active` (NFR-1) | static hot-path guard TC-220 + inherited bounded-pool / no-per-frame-alloc guards re-run with the cockpit loaded |
| TC-M-PRIV | **Manual privacy audit [AUDIT]** — `/privacy-audit` PASS: cockpit adds no new OS signal/input/screen/location read, only static image assets (NFR-2) | static reinforcement only: separation invariant TC-214 + dependency direction TC-214/TC-215 — does NOT replace the audit |
| **Windows runtime legs** | **DEFERRED — required before any Windows release** | parity authored + reviewed now |

> All other TCs (TC-201..TC-221) are **automated** against the mock activity + window/visibility path and
> are **NOT** in this checklist (their real-OS / qualitative / device legs are the TC-M* rows above).

## Conventions / tolerance

- **Build the REAL backend, NOT the mock, for the PiP leg.** Run a real per-OS build with the **real**
  window + occlusion backend (do **not** pass the `mock-window` flag for TC-M-PIP — the mock never touches
  the OS window or occlusion API). Use the **mock activity** source to deterministically flip
  `active`/`idle` and to drive `mode = car` / `motorbike` while keeping the **real** window backend.
- **No automated proxy for the real-OS side.** The injected-visibility fakes (TC-209/TC-210/TC-221) prove
  the cockpit-on-both-surfaces, no-per-frame-work, and pause/animate *logic* + the resulting render. They
  do **not** prove the cockpit looks correct on a live frameless always-on-top PiP or that real OS
  occlusion still pauses it with the cockpit composited — that is exactly TC-M-PIP.
- **Art cohesion (TC-M4-ART) is a REVIEW GATE, not pass/fail math.** Judge against the spec art direction:
  **stylized flat**, cohesive with the existing Kenney-flat scene + tray glyphs, recoloured to the journey
  palette, **not** a photoreal outlier; gauges purely decorative (no numeric speed/fuel); **no** rider
  hands; a car-vs-motorbike silhouette distinct **without relying on colour**. A fail here **blocks ship**
  for the cockpit art even if every asset is CREDITS-recorded (TC-219) and renders.
- **fps measurement (TC-M-NF1).** Use Flutter DevTools / the performance overlay / `traceAction`
  frame-timing on-device, with **both** cockpits' assets loaded, on **both** surfaces (full window AND the
  sized-down PiP). Manual spot-check acceptable where automated frame-timing is impractical — record
  device + OS. (Deferral precedent: journey-view / journey-scene-v2 fps NFR.)
- **Offline-verifiable (privacy).** During TC-M-PRIV confirm **no** network egress from the app (Little
  Snitch / `nettop` on macOS, Resource Monitor on Windows). Any outbound connection is a **Fail**.

## Per-OS preconditions

- [ ] Build/run a **real** per-OS build (macOS `.app`, Windows `.exe`) with the **real** window +
      occlusion backend (NOT the mock-window path). Use the mock **activity** source to drive state + mode.
- [ ] The PiP reachable (enter compact / PiP per `mini-window`) so the cockpit can be confirmed on a real
      frameless always-on-top PiP + main window.
- [ ] A **second application** open and focusable to cover/occlude the PiP for the pause-unbroken leg.
- [ ] OS reduce-motion toggle accessible (to spot-check AC-14 on-device alongside the automated TC-217).
- [ ] Note the OS version tested (record below).

OS versions under test — macOS: `__________`   Windows: `__________`

---

## Cases

Legend per cell: `[ ]` Pass `[ ]` Fail `[ ]` Blocked (check exactly one per OS).

### TC-M-PIP — Cockpit correct on a real frameless always-on-top PiP; frameless/always-on-top + occlusion pause unbroken (P0, [REAL-OS])
Covers AC-11 / AC-12 real legs. Automated logic legs: TC-209 (both surfaces scaled), TC-210 (no per-frame work / pause-unbroken logic), TC-221 (mock-path smoke).

Steps (real backend, mock activity to drive `mode` + `active`/`idle`):
1. Drive `mode = car`. Enter the compact PiP (frameless, always-on-top). Confirm the **car cockpit**
   renders in the PiP, **scaled** to the PiP size (occupies the same ≈30–40% lower fraction), with the road
   still readable above it.
2. Switch `mode = motorbike` → confirm the **motorbike cockpit** appears in the PiP, scaled, road readable.
3. Confirm the PiP is still **frameless** and **always-on-top** with the cockpit composited (the cockpit did
   not add a frame / break the stay-on-top).
4. Fully cover / minimize / hide-to-tray the PiP with a focused other app → confirm the surface **pauses**
   (no CPU spin on a hidden surface with the cockpit loaded). Re-reveal → resumes.
5. Confirm the full window surface also shows the cockpit correctly at full size.

Expect: the cockpit renders correctly + scaled on a real PiP and full window; the PiP stays
frameless/always-on-top; the static cockpit does **not** defeat the occlusion/visibility pause (battery
guarantee holds). A cockpit that breaks any of these blocks ship.

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (DEFERRED — required before any Windows release): Pass [ ]  Fail [ ]  Blocked [ ]

### TC-M4-ART — Stylized-flat art cohesion + accessibility review gate (P0, [REVIEW])
Covers AC-16 gate + AC-2/AC-4/AC-5 visual legs + NFR-3 visual leg. Automated numeric/structural legs:
TC-205 (framing), TC-211/TC-212 (goldens), TC-202 (gauges not data-driven), TC-204 (no-hands), TC-219 (asset⇄CREDITS).

Steps (reviewer judgement, with `active` + cockpit loaded, both car and motorbike):
1. Does the cockpit read as the **same flat / illustrated family** as the existing Kenney-flat scene + tray
   glyphs — recoloured to the journey palette — and **not** as a photoreal outlier?
2. Do the speedometer / fuel glyphs read as **decorative** (no live numeric speed/fuel readout; at most a
   parked-vs-running pose off the `moving` flag)?
3. Confirm **no** rider hands / gloves are drawn, and the cockpit still reads as **first-person** without
   them.
4. Is the **car-vs-motorbike silhouette distinct** so the mode is conveyed **without relying on colour
   alone** (NFR-3)?
5. Does the road read **clearly** through the windshield (car) / over the handlebars (motorbike) — the
   cockpit sits in the lower ≈30–40% and does **not** crowd or obscure the road, horizon, or the
   "Paused — idle" overlay (no focus trap, no obscured essential readout)?

Expect: a cohesive stylized-flat cockpit, decorative gauges, no hands, distinct silhouettes, road + overlay
fully readable. A cohesion or accessibility fail **blocks ship for the cockpit art** even if TC-219 passes.

- Review verdict (source/content-level, no per-OS split): Pass [ ]  Fail [ ]  Blocked [ ]
- Reviewer / date: `__________`

### TC-M-NF1 — Sustained ≥30fps on BOTH surfaces with both cockpits loaded (P1, device, [DEVICE])
Covers NFR-1. Deterministic proxy: TC-220 (static hot-path guard) + inherited bounded-pool / no-per-frame-alloc guards re-run with the cockpit loaded.

Steps:
1. With mock activity = `active` and both cockpits' assets loaded, drive `mode = car` then `motorbike`.
2. Run a sustained window on the **full** window surface and on the **sized-down PiP** surface (both where
   the surface model allows simultaneous render), under representative load.
3. Capture frame build/raster times (DevTools / performance overlay / `traceAction`).

Expect: each surface holds **≥30fps** on the reference machine under the full scene + cockpit while
`active` (target ~60fps steady, ≥30fps floor; no sustained jank). Record device + OS. (On-device fps
deferral mirrors journey-view / journey-scene-v2 perf NFRs.)

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (DEFERRED — required before any Windows release): Pass [ ]  Fail [ ]  Blocked [ ]

---

## Privacy audit (TC-M-PRIV) — P0, audit, not automated, [AUDIT]

Covers NFR-2. **Ship-blocker.** Static reinforcement: TC-214 (separation invariant — scene + siblings
import only dart:*/flame/*/TravelMode) + TC-215 (engine counters byte-for-byte unchanged / dependency
direction) + the inherited journey-view / journey-scene-v2 separation. These do **NOT** replace the audit.

Steps (run `/privacy-audit`, i.e. `privacy-guardian`, over the slice):
1. Confirm the cockpit adds **no** new OS signal, input, screen, clipboard, files, mouse-position, location,
   or other-app data read — it adds **only static image assets** and keys off the existing `applyState`
   `mode` value.
2. Confirm the scene + its siblings still import only `dart:*`, `package:flame/*`, and `TravelMode` — no
   `flutter_bloc`, `JourneyEngine`, `ActivityPlugin`, `MethodChannel`/platform channel, or OS read (the
   only Flutter surface remains the asset bundle/manifest via `JourneySprites`).
3. Confirm any new transitive dependency introduced by the cockpit art/loading introduces **no** capability
   to capture input / screen / clipboard / files / network / location.
4. Confirm no network call on any path (fully local/offline) — verify offline as above.

Expect: **no** API or dependency adds a new user-data surface; the audit **passes**. A contradiction
**fails this NFR and blocks ship** regardless of every other pass. Re-run on any change to the slice's
source or its dependency set.

- Audit verdict (no per-OS split — source-level): Pass [ ]  Fail [ ]  Blocked [ ]
- Auditor / date: `__________`

---

## Deferred — Windows on-device verification

By decision (precedent: journey-scene-v2, mini-window NFR-9, journey-view fps), the Windows **runtime**
legs are **DEFERRED — required before any Windows release**, while the cockpit + its Windows parity are
authored, code-reviewed, and privacy-audited **now**. The deferred Windows legs are the "Windows" rows
above:

- [ ] TC-M-PIP (Windows) — cockpit correct on a real Windows frameless always-on-top PiP; occlusion pause
      unbroken — **DEFERRED**
- [ ] TC-M-NF1 (Windows) — ≥30fps both surfaces with both cockpits loaded — **DEFERRED**

Record the Windows verdicts here when the on-device Windows pass is performed before a Windows release.

---

## Automated companions (run before/with the manual pass)

From `src/focus_journey/` (Flutter is fvm-pinned to 3.38.10 — always prefix `fvm`):

```bash
# Deterministic widget/golden cases (no device): cockpit-active seam, gauges-not-data-driven,
# framing ratio, mode-gating, clean revert/restore, cosmetic-only engine equality, placeholder,
# reduce-motion no-new-motion, parks, asset⇄CREDITS cross-check, NFR-1 hot-path guard, goldens.
fvm flutter test test/

# Cockpit on both surfaces scaled + PiP pause-unbroken + headline both-surfaces smoke
# (needs a device target; mock path, no real OS occlusion).
fvm flutter test integration_test/ -d macos --dart-define=mock-window=true --dart-define=mock-activity=true
fvm flutter test integration_test/ -d windows --dart-define=mock-window=true --dart-define=mock-activity=true
```

Note: `integration_test` files do NOT run under plain `fvm flutter test` (no device); they need
`-d macos` / `-d windows`. The deterministic widget/golden tests under `src/focus_journey/test/` run under
plain `fvm flutter test`. The exact mock-path flag names (`mock-window` / `mock-activity`) follow the
existing convention; confirm against the implemented DI seam.
