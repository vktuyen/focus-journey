# Manual run checklist — journey-scene-v2

Per-OS, human-driven verification of the `journey-scene-v2` cases that **cannot** be a deterministic Dart
unit/widget/integration test because they need a **real OS window** (real per-OS occlusion/visibility
firing for a frameless always-on-top PiP behind another focused app), a **real on-device performance
measurement** (≥30fps on both surfaces), a **human qualitative / content-appropriateness judgement**
("reads as a real winding trip; scenery looks even & cohesive; respectful depiction of Vietnam"), or are a
**privacy audit**. Follow this during `/execute-tests` and record the verdict per case **per OS**.

- Authoritative scenarios: [journey-scene-v2.md](journey-scene-v2.md) (TC-001..TC-013 + the TC-M* legs below).
- Decision driving the spike-gate occlusion work: spec `## Decisions` (b) — per-OS occlusion signal, spike is the first `/implement` task.
- Automated companions live under `src/focus_journey/test/` (widget/golden) and
  `src/focus_journey/integration_test/` (e2e) against the **mock** activity + window/visibility path — see
  "Automated companions" below.

## How this maps to automation

| TC (this checklist) | Verification here | Automated companion (mock path) |
|----|-------------------|---------------------|
| TC-M1 | **Manual [REAL-OS]** — a real per-OS occlusion signal exists & fires for the frameless always-on-top PiP (spec Decision (b) spike) | per-surface animate/pause logic vs injected visibility: TC-004 / TC-005 / TC-006 |
| TC-M2 | **Manual [REAL-OS]** — a **visible-but-unfocused** real surface keeps scrolling while another app holds focus (AC-3 real leg) | TC-004 (injected visible + not-focused) |
| TC-M3 | **Manual [REAL-OS]** — a **hidden/minimized/tray** real surface pauses; per-surface independence with a real PiP + main (AC-4/AC-5 real legs) | TC-005 / TC-006 |
| TC-M4 | **Manual [REVIEW]** — qualitative read + content-appropriateness: winding-road look, even/cohesive scenery, respectful depiction, no realistic/identifiable people (AC-6/AC-7/AC-8 judgement gate) | non-straight-curve + lane-follow TC-007; arc-length spacing variance TC-008; asset⇄CREDITS TC-009; golden TC-012 |
| TC-M-NF1 | **Manual / device [DEVICE]** — sustained ≥30fps on **both** surfaces under the full winding road + richer scenery (NFR-1) | bounded-pool / no-per-frame-alloc hot-path guards inherited from journey-view TC-017/TC-018 |
| TC-M-PRIV | **Manual privacy audit [AUDIT]** — `/privacy-audit` zero-new-surface-beyond-own-occlusion release gate (NFR-2) | static reinforcement only: dependency direction TC-003 + inherited journey-view/mini-window separation — does NOT replace the audit |
| **Windows runtime legs** | **DEFERRED — required before any Windows release** | parity authored + reviewed now; Windows occlusion via visibility/minimize |

> All other TCs (TC-001, TC-002, TC-003, TC-004, TC-005, TC-006, TC-007, TC-008, TC-009, TC-010, TC-011,
> TC-012, TC-013) are **automated** against the mock activity + window/visibility path and are **NOT** in
> this checklist (their real-OS / qualitative legs are the TC-M* rows above).

## The occlusion spike-gate (spec Decision (b) — run as the FIRST `/implement` task)

Decision (b) requires the first `/implement` task to be a build spike proving a concrete, testable
"is this surface visible" API **per OS**, evaluated **per-surface**, working for the frameless
always-on-top PiP, **without regressing `/privacy-audit`** (own-window occlusion only — no
other-app/input data):

- macOS: `NSWindow.occlusionState` (`.visible` flag) — does it fire when the window is fully covered by a
  focused app, minimized, or hidden-to-tray, and clear when re-revealed? (→ **TC-M1** macOS leg.)
- Windows: window visibility / minimize (+ occlusion where available) — same questions. (→ **TC-M1**
  Windows leg, **DEFERRED** to before any Windows release.)

**If the spike finds no reliable signal on a given OS, fall back to the existing pause-when-hidden
behaviour there and FLAG it** (record the fallback verdict at TC-M1 for that OS). A spike that cannot
prove *any* visible/occluded distinction on macOS gates `/implement`.

## Conventions / tolerance

- **Build the REAL backend, NOT the mock.** Run a real per-OS build with the **real** window + occlusion
  backend (do **not** pass the `mock-window` flag for the real-OS legs — the mock never touches the OS
  window or occlusion API and would invalidate every case here). For driving journey state during the
  manual run, use the **mock activity source** so you can deterministically flip `active`/`idle`, while
  keeping the **real** window + occlusion backend.
- **No automated proxy for the real-OS side.** The injected-visibility fakes prove the animate/pause/
  per-surface *logic* and the resulting render. They do **not** prove that macOS/Windows actually reported
  the window as occluded behind a focused app, minimized, or hidden-to-tray — that is exactly what
  TC-M1/TC-M2/TC-M3 verify once per release per OS.
- **Offline-verifiable (privacy).** During TC-M-PRIV / the runs, confirm **no** network egress from the
  app (Little Snitch / `nettop` on macOS, Resource Monitor on Windows). Any outbound connection is a
  **Fail** for the no-network promise.
- **fps measurement (TC-M-NF1).** Use Flutter DevTools / the performance overlay / `traceAction`
  frame-timing on-device, with the **full winding road + the full richer scenery set loaded**, on **both**
  surfaces (full window AND the sized-down PiP, rendered at once where the surface model allows). Manual
  spot-check acceptable where automated frame-timing is impractical — record device + OS. (Deferral
  precedent: `journey-view` fps NFR.)
- **Content-appropriateness (TC-M4) is a REVIEW GATE, not pass/fail math.** Judge against the spec
  constraint: a warm, respectful tour of Vietnam; cohesive single-pack look (supplement only where it
  lacks an asset); **no realistic/identifiable people**; nothing culturally insensitive or off-brand. A
  fail here blocks ship for the asset set even if every asset is CC0 and in CREDITS (TC-009).

## Per-OS preconditions

- [ ] Build/run a **real** per-OS build (macOS `.app`, Windows `.exe`) with the **real** window +
      occlusion backend (NOT the mock-window path). Use the mock **activity** source to drive state.
- [ ] A **second application** open and focusable (IDE / browser / full-screen app) to cover/focus over
      the surface for the visible-but-unfocused (TC-M2) and hidden/occluded (TC-M3) legs.
- [ ] The PiP reachable (enter compact / PiP per `mini-window`) so per-surface independence (TC-M3 / AC-5)
      can be exercised with a real PiP + main.
- [ ] OS reduce-motion toggle accessible (to spot-check AC-9 on-device alongside the automated TC-010).
- [ ] Note the OS version tested (record below).

OS versions under test — macOS: `__________`   Windows: `__________`

---

## Cases

Legend per cell: `[ ]` Pass `[ ]` Fail `[ ]` Blocked (check exactly one per OS).

### TC-M1 — Real per-OS occlusion signal exists and fires for the frameless always-on-top PiP (spike-gate) (P0, [REAL-OS])
Covers AC-3/AC-4/AC-5 real signal + spec Decision (b). Automated logic legs: TC-004 / TC-005 / TC-006.

Steps:
1. With the real backend, enter the compact PiP (frameless, always-on-top). Confirm the occlusion API
   reports it **visible**.
2. Fully cover the PiP with a focused other app (or minimize / hide-to-tray) → confirm the API reports it
   **not visible / occluded**.
3. Re-reveal the PiP → confirm the API reports it **visible** again.
4. Repeat for the **full** window surface.

Expect: a concrete, per-surface visible/occluded distinction is reported by macOS `NSWindow.occlusionState`
(and, before a Windows release, Windows visibility/minimize). If **no** reliable signal exists on an OS,
record the agreed **fallback = pause-when-hidden** there and FLAG it (does not block macOS ship if macOS
works; a macOS no-signal **gates `/implement`**).

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]   — signal found / fallback used: `__________`
- Windows (DEFERRED — required before any Windows release): Pass [ ]  Fail [ ]  Blocked [ ]

### TC-M2 — Visible-but-unfocused surface KEEPS scrolling while another app holds focus (P0, [REAL-OS])
Covers AC-3 (the working-alongside use case — the headline of #5). Automated logic leg: TC-004.

Steps:
1. Enter the PiP; position it in a corner. Drive mock activity = `active`.
2. Open and **focus a different application** over/next to the PiP (so the PiP is visible but NOT focused);
   type into the other app.
3. Watch the PiP road.

Expect: while the PiP is **visible but unfocused**, the road **keeps scrolling** at the slower v2 rate —
it does NOT stall the moment focus leaves (this is the exact defect #5 fixes). Flip mock to `idle` → it
parks; back to `active` → it resumes. Repeat for the full window visible-but-unfocused where applicable.

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (DEFERRED — required before any Windows release): Pass [ ]  Fail [ ]  Blocked [ ]

### TC-M3 — Hidden/minimized/tray surface PAUSES; per-surface independence with a real PiP + main (P0, [REAL-OS])
Covers AC-4 (pause-when-not-visible / battery) + AC-5 (per-surface). Automated logic legs: TC-005 / TC-006.

Steps:
1. With mock activity = `active`, **minimize / hide / hide-to-tray** the surface so it has no pixels on
   screen.
2. Confirm the surface's animation **pauses** (no per-frame work — spot-check CPU does not spin on a
   hidden, nothing-moving surface).
3. With the PiP **visible** and the main window **hidden/minimized** (and then the reverse), confirm the
   **visible** surface scrolls while the **hidden** one does not — on the single shared game.

Expect: a not-visible surface freezes (preserving the mini-window battery guarantee that #5 relaxed only
for visible-but-unfocused); visibility is evaluated **per-surface** so one can scroll while the other is
paused. No CPU spin on a hidden surface.

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (DEFERRED — required before any Windows release): Pass [ ]  Fail [ ]  Blocked [ ]

### TC-M4 — Qualitative read & content-appropriateness review gate (P0, [REVIEW])
Covers AC-6/AC-7/AC-8 judgement. Automated numeric legs: TC-007 (curve), TC-008 (spacing variance),
TC-009 (asset⇄CREDITS), TC-012 (golden).

Steps (reviewer judgement, with `active` + the full scenery loaded):
1. Watch a full scroll cycle on both surfaces. Does the road **read as a real, calm winding trip** across
   Vietnam (curves left/right, trapezoid near→horizon preserved) — not a dead-straight tech demo?
2. Does the scenery look **evenly spaced and cohesive** (no clumping / empty stretches that the ±20%
   numeric bound missed; one coherent art style)?
3. Review every depiction: mountains / beach / city / forest / people / characters / animals — is it a
   **warm, respectful tour**, with **no realistic or identifiable people**, and nothing culturally
   insensitive or off-brand for Vietnam?
4. Cross-check the asset set is CC0/permissive and fully recorded (defer the mechanical check to TC-009).

Expect: the scene reads as the intended calm real trip; scenery is even & cohesive; all depictions are
respectful, on-brand, and contain no realistic/identifiable people. A content-appropriateness fail **blocks
ship for the asset set** even if TC-009 passes.

- Review verdict (source/content-level, no per-OS split): Pass [ ]  Fail [ ]  Blocked [ ]
- Reviewer / date: `__________`

### TC-M-NF1 — Sustained ≥30fps on BOTH surfaces under the full winding road + richer scenery (P1, device, [DEVICE])
Covers NFR-1. Hot-path regression guards inherited from journey-view TC-017/TC-018 (bounded pool / no
per-frame allocation) should be re-run with the richer scenery loaded.

Steps:
1. With mock activity = `active`, load the **full** winding road + the **full** richer scenery set.
2. Run a sustained window on the **full** window surface and on the **sized-down PiP** surface (both where
   the surface model allows simultaneous render), under representative load.
3. Capture frame build/raster times (DevTools / performance overlay / `traceAction`).

Expect: each surface holds **≥30fps** on the reference machine under the full scene while `active` (target
~60fps steady, ≥30fps floor; no sustained jank). Record device + OS. (On-device fps deferral mirrors
`journey-view` / `mini-window` perf NFRs.)

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (DEFERRED — required before any Windows release): Pass [ ]  Fail [ ]  Blocked [ ]

---

## Privacy audit (TC-M-PRIV) — P0, audit, not automated, [AUDIT]

Covers NFR-2. **Ship-blocker.** Static reinforcement: TC-003 (engine reads no rendered-scroll value;
dependency direction) + the inherited `journey-view` TC-026 / `mini-window` TC-019-PRIV separation. These
do **NOT** replace the audit.

Steps (run `/privacy-audit`, i.e. `privacy-guardian`, over the slice):
1. Confirm the rework adds **no** new OS signal about the user **beyond the app's own window
   occlusion/visibility** state (macOS `NSWindow.occlusionState`; Windows visibility/minimize) — and reads
   **NONE** of: keystrokes / key contents, screen/display contents of other apps, clipboard, files,
   mouse-position history, or **other apps'** window titles / focus details beyond "is my own surface
   visible".
2. Confirm the scene still consumes **only** the journey Bloc's `state` / `mode` / `distanceKm` for what it
   renders; the slower scroll (#3) derives from a presentation-layer constant, and richer scenery /
   keep-animating-when-visible derive from Bloc state + own-window visibility — never from watching other
   apps or user input.
3. Confirm the occlusion plumbing reads **own-window** occlusion only (not other-app observation) and any
   new transitive dependency introduces **no** capability to capture input / screen / clipboard / files /
   network / other apps' window titles.
4. Confirm no network call on any path (fully local/offline) — verify offline as above.

Expect: **no** API or dependency adds a new user-data surface beyond own-window occlusion; the audit
**passes**. A contradiction **fails this NFR and blocks ship** regardless of every other pass. Re-run on
any change to the slice's source or its dependency set.

- Audit verdict (no per-OS split — source-level): Pass [ ]  Fail [ ]  Blocked [ ]
- Auditor / date: `__________`

---

## Deferred — Windows on-device verification

By decision (precedent: `mini-window` NFR-9, `activity-detection` L3, `journey-view` fps), the Windows
**runtime** legs are **DEFERRED — required before any Windows release**, while the Windows occlusion
backend + parity are authored, code-reviewed, and privacy-audited **now**. The deferred Windows legs are
the "Windows" rows above:

- [ ] TC-M1 (Windows) — Windows visibility/minimize occlusion signal fires for the PiP — **DEFERRED**
- [ ] TC-M2 (Windows) — visible-but-unfocused surface keeps scrolling over a focused app — **DEFERRED**
- [ ] TC-M3 (Windows) — hidden/minimized/tray surface pauses; per-surface independence — **DEFERRED**
- [ ] TC-M-NF1 (Windows) — ≥30fps both surfaces under the full scene — **DEFERRED**

Record the Windows verdicts here when the on-device Windows pass is performed before a Windows release.

---

## Automated companions (run before/with the manual pass)

From `src/focus_journey/` (Flutter is fvm-pinned to 3.38.10 — always prefix `fvm`):

```bash
# Deterministic widget/golden cases (no device): scroll-rate factor, engine-counter equality,
# dependency-direction (static), winding-road geometry, arc-length spacing variance, asset⇄CREDITS,
# reduce-motion override, idle/paused parks, goldens.
fvm flutter test test/

# Per-surface visibility wiring + headline smoke (needs a device target; mock path, no real OS occlusion).
fvm flutter test integration_test/ -d macos --dart-define=mock-window=true --dart-define=mock-activity=true
fvm flutter test integration_test/ -d windows --dart-define=mock-window=true --dart-define=mock-activity=true
```

Note: `integration_test` files do NOT run under plain `fvm flutter test` (no device); they need
`-d macos` / `-d windows`. The deterministic widget/golden tests under `src/focus_journey/test/` run under
plain `fvm flutter test`. The exact mock-path flag names (`mock-window` / `mock-activity`) follow the
existing convention; confirm against the implemented DI seam (mini-window NFR-8 precedent).
