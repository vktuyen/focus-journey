# Manual run checklist — journey-dynamic-curve

Per-OS / human-driven verification of the `journey-dynamic-curve` cases that **cannot** be a deterministic
Dart unit/widget/integration test because they need a **real on-device performance measurement** (≥30fps on
both surfaces with the sharper curve), a **human feel / accessibility judgement** (the road reads as a
genuine sweeping F1-like drive yet stays a calm companion — no nausea-grade swings — and the curve does not
obscure essential readouts), a **real OS window** (a real frameless always-on-top PiP rendering the sharper
bend without it swinging off-screen), or are a **privacy audit**. Follow this during `/execute-tests` and
record the verdict per case **per OS** where a per-OS split applies.

- Authoritative scenarios: [journey-dynamic-curve.md](journey-dynamic-curve.md) (TC-401..TC-415 + the TC-M*
  legs below).
- Automated companions live under `src/focus_journey/test/` (unit/widget/golden) and
  `src/focus_journey/integration_test/` (e2e) against the pure geometry + the **mock** activity +
  window/visibility path — see "Automated companions" below.
- Enhances the shipped `journey-scene-v2` curve and shares the scene + PiP — the real-OS PiP plumbing this
  checklist relies on is the same one verified in
  [journey-scene-v2-manual-checklist.md](journey-scene-v2-manual-checklist.md) /
  [journey-pov-manual-checklist.md](journey-pov-manual-checklist.md); here we only confirm the **sharper
  curve** rides it correctly (renders, never swings off-screen, holds fps).

## How this maps to automation

| TC (this checklist) | Verification here | Automated companion |
|----|-------------------|---------------------|
| TC-M-FEEL | **Manual [VISUAL]** — feel + accessibility: the road reads as a genuine **sweeping F1-like drive** (clearly sharper than before) yet stays a **calm companion** (no abrupt chicanes / nausea-grade swings, comfortable all session); scenery still **looks evenly spaced**; the curve does **not** obscure the road / vehicle / "Paused — idle" overlay (AC-1/AC-2/AC-7 feel gate + NFR-3 visual) | sharper-than-baseline TC-401/TC-402; ≤3× + smooth TC-408; spacing TC-405; goldens TC-413/TC-414 |
| TC-M-PIP | **Manual [VISUAL]/[REAL-OS]** — on a real frameless always-on-top PiP the sharper bend renders correctly and **never swings the road off-screen** at the sized-down PiP, and reads as a sweeping curve (AC-11 real leg) | on-screen bound TC-412; both-surfaces smoke TC-415 |
| TC-M-NF1 | **Manual / device [DEVICE]** — sustained **≥30fps on both surfaces** (full window + sized-down PiP) with the sharper curve while `active` (NFR-1) | O(1) integral TC-407 + no-alloc TC-408 + cadence-cost TC-406 + inherited bounded-pool guards |
| TC-M-PRIV | **Manual privacy audit [AUDIT]** — `/privacy-audit` PASS: the curve adds no new OS signal/input/screen/location read, only `dart:math` + the existing shared scroll phase (NFR-2) | static reinforcement only: pure-view imports TC-410 + single-phase TC-403/TC-404 — does NOT replace the audit |
| **Windows runtime legs** | **DEFERRED — required before any Windows release** | parity authored + reviewed now |

> All other TCs (TC-401..TC-415) are **automated** against the pure geometry + mock path and are **NOT** in
> this checklist (their on-device / qualitative / real-OS legs are the TC-M* rows above).

## Conventions / tolerance

- **Build the REAL backend, NOT the mock, for the PiP leg.** Run a real per-OS build with the **real**
  window backend (do **not** pass the `mock-window` flag for TC-M-PIP). Use the **mock activity** source to
  deterministically flip `active`/`idle` and to drive `mode` while keeping the **real** window backend.
- **TC-M-FEEL is a REVIEW GATE, not pass/fail math.** Judge against the spec art direction + the Kevin
  2026-06-25 sign-off: the bend must be **clearly sharper** than the journey-scene-v2 baseline (a real
  *drive*, not a meander) **and** bounded — **sweeping but smooth**, never a literal racetrack chicane, no
  motion discomfort, comfortable to leave on-screen for a whole work session. The automated 2–3× bracket +
  ±2%-width/frame cap (TC-401/TC-408) is the numeric stand-in; this is the human confirmation. A "too tame"
  or "too aggressive / nauseating" verdict **blocks ship** even if every numeric case passes.
- **No automated proxy for the real-OS PiP side.** TC-412 proves the on-screen *bound*
  (`|centreLineOffset| + nearHalf ≤ width/2`) at representative sizes; it does **not** prove the bend looks
  correct on a live frameless always-on-top PiP — that is TC-M-PIP.
- **fps measurement (TC-M-NF1).** Use Flutter DevTools / the performance overlay / `traceAction`
  frame-timing on-device with the sharper curve loaded, on **both** surfaces (full window AND the
  sized-down PiP). Manual spot-check acceptable where automated frame-timing is impractical — record device
  + OS. (Deferral precedent: journey-view / journey-scene-v2 / journey-pov fps NFR.)
- **Offline-verifiable (privacy).** During TC-M-PRIV confirm **no** network egress (Little Snitch /
  `nettop` on macOS, Resource Monitor on Windows). Any outbound connection is a **Fail**.

## Per-OS preconditions

- [ ] Build/run a **real** per-OS build (macOS `.app`, Windows `.exe`) with the **real** window backend
      (NOT the mock-window path). Use the mock **activity** source to drive state + mode.
- [ ] The PiP reachable (enter compact / PiP per `mini-window`) so the sharper curve can be confirmed on a
      real frameless always-on-top PiP + main window.
- [ ] OS reduce-motion toggle accessible (to spot-check the curve freezes on-device alongside automated
      TC-411).
- [ ] Note the OS version tested (record below).

OS versions under test — macOS: `__________`   Windows: `__________`

---

## Cases

Legend per cell: `[ ]` Pass `[ ]` Fail `[ ]` Blocked (check exactly one per OS).

### TC-M-FEEL — Sweeping F1-like but calm; evenly spaced; readouts not obscured (P0, [VISUAL])
Covers AC-1 / AC-2 / AC-7 feel gate + NFR-3 visual leg. Automated numeric legs: TC-401/TC-402 (sharper),
TC-408 (≤3× + smooth), TC-405 (spacing), goldens TC-413/TC-414.

Steps (reviewer judgement, `active` + sharper curve loaded):
1. Does the road now read as a **genuine sweeping drive** — clearly sharper bends than the shipped
   journey-scene-v2 meander (a real *drive*, F1-track-grade sweep)?
2. Does it nonetheless stay a **calm companion** — no abrupt chicanes, no nausea-grade swings, comfortable
   to leave on-screen for a whole work session (no motion discomfort)?
3. Does the bend **sweep over time** as the scene scrolls (animated, not a static fixed bend), and **freeze**
   cleanly when stopped / reduce-motion?
4. Does the roadside scenery still **look evenly spaced** along the now-sharper curve — no clumping, no
   empty stretches?
5. Does the curve leave the **road, vehicle, and "Paused — idle" overlay** fully visible and on-screen — it
   does not crowd or obscure any essential readout (NFR-3)?

Expect: a clearly sharper, animated, sweeping drive that still reads calm + comfortable, evenly spaced
scenery, and unobscured readouts. A "too tame", "too aggressive / nauseating", or "obscures the road /
overlay" verdict **blocks ship** even if every numeric case passes.

- Review verdict (feel/content-level, no per-OS split): Pass [ ]  Fail [ ]  Blocked [ ]
- Reviewer / date: `__________`

### TC-M-PIP — Sharper bend correct on a real frameless always-on-top PiP, never swings off-screen (P0, [VISUAL]/[REAL-OS])
Covers AC-11 real leg. Automated bound leg: TC-412 (on-screen bound); both-surfaces smoke: TC-415.

Steps (real backend, mock activity to drive `active`/`idle` + `mode`):
1. Drive `active`. Enter the compact PiP (frameless, always-on-top). Confirm the **sharper bend renders** in
   the PiP and reads as a **sweeping curve** at the sized-down size.
2. Watch a full sweep cycle: confirm the road **never swings off-screen** at the PiP size (neither road edge
   leaves the viewport at peak bend).
3. Confirm the **same** sharper curve also reads correctly on the **full window** surface at full size.
4. Confirm the sharper curve did not break the PiP's frameless / always-on-top behaviour or its
   occlusion/visibility pause (inherited from mini-window / journey-scene-v2 — the curve adds no new motion
   source).

Expect: the sharper bend renders correctly + reads as a sweep on a real PiP and full window, and **never**
clips the road off-screen at the PiP size. A bend that swings the road off-screen at the PiP blocks ship.

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (DEFERRED — required before any Windows release): Pass [ ]  Fail [ ]  Blocked [ ]

### TC-M-NF1 — Sustained ≥30fps on BOTH surfaces with the sharper curve (P1, device, [DEVICE])
Covers NFR-1. Deterministic proxy: TC-407 (O(1) integral) + TC-408 (no-alloc) + TC-406 (cadence cost) +
inherited bounded-pool / no-per-frame-alloc guards re-run with the sharper curve.

Steps:
1. With mock activity = `active` and the sharper curve loaded, run a sustained window on the **full** window
   surface and on the **sized-down PiP** surface (both where the surface model allows simultaneous render).
2. Capture frame build/raster times (DevTools / performance overlay / `traceAction`).
3. If the arc-length-aware cadence fork (AC-6) was taken, confirm no per-frame hitch from the new spawn math.

Expect: each surface holds **≥30fps** on the reference machine with the sharper curve while `active` (target
~60fps steady, ≥30fps floor; no sustained jank, no per-frame allocation spike from a sharper integral or new
cadence). Record device + OS. (On-device fps deferral mirrors journey-view / journey-scene-v2 / journey-pov
perf NFRs.)

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (DEFERRED — required before any Windows release): Pass [ ]  Fail [ ]  Blocked [ ]

---

## Privacy audit (TC-M-PRIV) — P0, audit, not automated, [AUDIT]

Covers NFR-2. **Ship-blocker.** Static reinforcement: TC-410 (pure-view imports — curve sources import only
dart:*/flame/*/TravelMode) + TC-403/TC-404 (single shared scroll phase, no second clock/timer/Random) + the
inherited journey-view / journey-scene-v2 / journey-pov separation. These do **NOT** replace the audit.

Steps (run `/privacy-audit`, i.e. `privacy-guardian`, over the slice):
1. Confirm the sharper curve adds **no** new OS signal, input, screen, clipboard, files, mouse-position,
   location, or other-app data read — it adds **only** `dart:math` and rides the existing shared scroll
   phase (world distance).
2. Confirm `road_geometry.dart` / `road_painter.dart` / `side_object_pool.dart` (and any new
   arc-length-aware-cadence source) still import only `dart:*`, `package:flame/*`, and `TravelMode` — no
   `flutter_bloc`, `JourneyEngine`, `ActivityPlugin`, `MethodChannel`/platform channel, or OS read.
3. Confirm any new transitive dependency introduced by the slice introduces **no** capability to capture
   input / screen / clipboard / files / network / location.
4. Confirm no network call on any path (fully local/offline) — verify offline as above.

Expect: **no** API or dependency adds a new user-data surface; the audit **passes**. A contradiction
**fails this NFR and blocks ship** regardless of every other pass. Re-run on any change to the slice's
source or its dependency set.

- Audit verdict (no per-OS split — source-level): Pass [ ]  Fail [ ]  Blocked [ ]
- Auditor / date: `__________`

---

## Deferred — Windows on-device verification

By decision (precedent: journey-scene-v2, journey-pov, mini-window NFR-9, journey-view fps), the Windows
**runtime** legs are **DEFERRED — required before any Windows release**, while the sharper curve + its
Windows parity are authored, code-reviewed, and privacy-audited **now**. The deferred Windows legs are the
"Windows" rows above:

- [ ] TC-M-PIP (Windows) — sharper bend correct on a real Windows frameless always-on-top PiP; never swings
      off-screen — **DEFERRED**
- [ ] TC-M-NF1 (Windows) — ≥30fps both surfaces with the sharper curve — **DEFERRED**

Record the Windows verdicts here when the on-device Windows pass is performed before a Windows release.

---

## Automated companions (run before/with the manual pass)

From `src/focus_journey/` (Flutter is fvm-pinned to 3.38.10 — always prefix `fvm`):

```bash
# Deterministic unit / widget / golden cases (no device): peak slope vs baseline, on-screen excursion,
# sweep determinism, arc-length spacing (over liveCentreLinePoints), O(1) integral, per-frame cap,
# cosmetic-only engine equality, pure-view imports, reduce-motion freeze, PiP on-screen bound, goldens.
fvm flutter test test/

# Sharper curve on both surfaces + sweep/freeze headline smoke (needs a device target; mock path).
fvm flutter test integration_test/ -d macos --dart-define=mock-window=true --dart-define=mock-activity=true
fvm flutter test integration_test/ -d windows --dart-define=mock-window=true --dart-define=mock-activity=true
```

Note: `integration_test` files do NOT run under plain `fvm flutter test` (no device); they need
`-d macos` / `-d windows`. The deterministic unit/widget/golden tests under `src/focus_journey/test/` run
under plain `fvm flutter test`. The exact mock-path flag names (`mock-window` / `mock-activity`) follow the
existing convention; confirm against the implemented DI seam.
