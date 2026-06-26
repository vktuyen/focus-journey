# Manual run checklist — journey-cockpit-lean

Per-OS / human-driven verification of the `journey-cockpit-lean` cases that **cannot** be a deterministic
Dart unit/widget/integration test because they need a **human feel / motion-comfort judgement** (the cockpit
reads as an embodied lean into the turn yet stays a calm companion — no nausea-grade roll, no snap — and does
not obscure essential readouts), a **real on-device performance measurement** (≥30fps on both surfaces with
the lean active), a **real OS window** (a real frameless always-on-top PiP rendering the leaning cockpit with
no exposed corners), or are a **privacy audit**. Follow this during `/execute-tests` and record the verdict
per case **per OS** where a per-OS split applies.

- Authoritative scenarios: [journey-cockpit-lean.md](journey-cockpit-lean.md) (TC-501..TC-518 + the TC-M*
  legs below).
- Automated companions live under `src/focus_journey/test/` (unit/widget/golden) and
  `src/focus_journey/integration_test/` (e2e) against the deterministic `appliedLeanAngle` + curve seams and
  the **mock** activity + window/visibility path — see "Automated companions" below.
- Extends the shipped `journey-pov` cockpit and is tuned against the shipped `journey-dynamic-curve`; it shares
  the scene + PiP — the real-OS PiP plumbing this checklist relies on is the same one verified in
  [journey-pov-manual-checklist.md](journey-pov-manual-checklist.md) /
  [journey-dynamic-curve-manual-checklist.md](journey-dynamic-curve-manual-checklist.md); here we only confirm
  the **leaning cockpit** rides it correctly (rolls into the turn, covers the band with no exposed corners,
  holds fps, world does not tilt).

## How this maps to automation

| TC (this checklist) | Verification here | Automated companion |
|----|-------------------|---------------------|
| TC-M-FEEL | **Manual [VISUAL]** — feel + motion-comfort + accessibility: the cockpit reads as an **embodied lean into the turn** (a real drive corners, not a static photo) yet stays a **calm companion** (gentle roll, never snaps/lurches, no nausea-grade swing, comfortable all session); the **world (road/scenery/horizon) does NOT tilt** (only the frame rolls); the lean does **not** obscure the road read or the "Paused — idle" overlay (AC-3/AC-4 feel gate + AC-9 perceptual + NFR-3 visual) | monotonic+clamp TC-503/TC-504; no-snap TC-505; world-not-tilted TC-510; golden TC-516 |
| TC-M-PIP | **Manual [VISUAL]/[REAL-OS]** — on a real frameless always-on-top PiP the leaning cockpit renders correctly, still **fully covers the cockpit band** at the sized-down size (no exposed un-painted corners at peak lean), and does not break the PiP's frameless/always-on-top behaviour or its occlusion/visibility pause (AC-13 real leg) | band-coverage bound TC-514; both-surfaces smoke TC-518 |
| TC-M-NF1 | **Manual / device [DEVICE]** — sustained **≥30fps on both surfaces** (full window + sized-down PiP) with the lean active while `active` (NFR-1) | constant per-frame angle update + no-alloc TC-517 + inherited bounded-pool guards |
| TC-M-PRIV | **Manual privacy audit [AUDIT]** — `/privacy-audit` PASS: the lean adds no new OS signal/input/screen/location read, only a canvas transform driven by the existing in-scene curve sample (NFR-2) | static reinforcement only: separation imports TC-512 + signal-source TC-511 + determinism TC-506 — does NOT replace the audit |
| **Windows runtime legs** | **DEFERRED — required before any Windows release** | parity authored + reviewed now |

> All other TCs (TC-501..TC-518) are **automated** against the deterministic seams + mock path and are **NOT**
> in this checklist (their on-device / qualitative / real-OS legs are the TC-M* rows above).

## Conventions / tolerance

- **Build the REAL backend, NOT the mock, for the PiP leg.** Run a real per-OS build with the **real** window
  backend (do **not** pass the `mock-window` flag for TC-M-PIP). Use the **mock activity** source to
  deterministically flip `active`/`idle`, drive `mode`, and toggle `reduceMotion` while keeping the **real**
  window backend.
- **TC-M-FEEL is a REVIEW GATE, not pass/fail math.** Judge against the spec art direction + the Kevin
  2026-06-25 sign-off: the cockpit must **visibly lean into the turn** (an embodied drive, not a static photo
  pasted over the scene) **and** stay bounded — **gentle and eased**, never a barrel-roll or a snap, no motion
  discomfort, comfortable to leave on-screen for a whole work session; and the **world must not tilt** (only
  the cockpit frame rolls — the road / scenery / horizon stay level). The automated clamp (≈3° ceiling) +
  per-frame cap (≈0.2°/frame) (TC-504/TC-505) is the numeric stand-in; this is the human confirmation. A "too
  aggressive / nauseating", "snaps / lurches", "tilts the world", or "obscures the road / overlay" verdict
  **blocks ship** even if every numeric case passes.
- **No automated proxy for the real-OS PiP side.** TC-514 proves the band-coverage *geometry* (rotated cockpit
  covers the band, no exposed corners) at representative sizes; it does **not** prove the leaning cockpit looks
  correct on a live frameless always-on-top PiP — that is TC-M-PIP.
- **fps measurement (TC-M-NF1).** Use Flutter DevTools / the performance overlay / `traceAction` frame-timing
  on-device with the lean active, on **both** surfaces (full window AND the sized-down PiP). Manual spot-check
  acceptable where automated frame-timing is impractical — record device + OS. (Deferral precedent:
  journey-view / journey-scene-v2 / journey-pov / journey-dynamic-curve fps NFR.)
- **Offline-verifiable (privacy).** During TC-M-PRIV confirm **no** network egress (Little Snitch / `nettop`
  on macOS, Resource Monitor on Windows). Any outbound connection is a **Fail**.

## Per-OS preconditions

- [ ] Build/run a **real** per-OS build (macOS `.app`, Windows `.exe`) with the **real** window backend
      (NOT the mock-window path). Use the mock **activity** source to drive state, mode, and reduce-motion.
- [ ] The PiP reachable (enter compact / PiP per `mini-window`) so the leaning cockpit can be confirmed on a
      real frameless always-on-top PiP + main window.
- [ ] OS/app reduce-motion toggle accessible (to spot-check the lean hard-zeros to level on-device alongside
      automated TC-507).
- [ ] A cockpit mode (`car` / `motorbike`) and a curving stretch reachable so the lean is exercised.
- [ ] Note the OS version tested (record below).

OS versions under test — macOS: `__________`   Windows: `__________`

---

## Cases

Legend per cell: `[ ]` Pass `[ ]` Fail `[ ]` Blocked (check exactly one per OS).

### TC-M-FEEL — Embodied lean into the turn yet calm; world not tilted; readouts not obscured (P0, [VISUAL])
Covers AC-3 / AC-4 feel gate + AC-9 perceptual + NFR-3 visual leg. Automated numeric legs: TC-503/TC-504
(monotonic + clamp), TC-505 (no snap), TC-510 (world not tilted), golden TC-516.

Steps (reviewer judgement, `active` + curving road + `car`/`motorbike`):
1. As the road sweeps into a **bend**, does the cockpit **visibly roll INTO the turn** (left bend → frame leans
   into the left turn, right bend → into the right) so cornering reads as a physical, embodied drive — not a
   static photo pasted over a moving scene?
2. Does the lean stay a **calm companion** — gentle, eased, **never snaps or lurches**, never a barrel-roll, no
   nausea-grade swing, comfortable to leave on-screen for a whole work session (no motion discomfort)?
3. Does the cockpit **roll back to level** as the road straightens, and on a clearly **straight** stretch hold
   dead level?
4. Does **only the cockpit frame roll** — the road, scenery, horizon and sky stay **level** (the world is not
   tilted / re-projected)?
5. Does the lean leave the **road read and the "Paused — idle" overlay** fully visible and **unrotated** — it
   does not crowd, cover, or rotate any essential readout (NFR-3)?
6. (Reduce-motion spot-check) With reduce-motion ON, does the cockpit hold **dead level** (no tilt at all, even
   into a bend)?

Expect: a visibly embodied lean into the turn that still reads calm + comfortable, rolling back on straights,
with the world held level and readouts unobscured. A "too aggressive / nauseating", "snaps / lurches", "tilts
the world", or "obscures the road / overlay" verdict **blocks ship** even if every numeric case passes.

- Review verdict (feel/content-level, no per-OS split): Pass [ ]  Fail [ ]  Blocked [ ]
- Reviewer / date: `__________`

### TC-M-PIP — Leaning cockpit correct on a real frameless always-on-top PiP, covers the band, no exposed corners (P0, [VISUAL]/[REAL-OS])
Covers AC-13 real leg. Automated band-coverage leg: TC-514; both-surfaces smoke: TC-518.

Steps (real backend, mock activity to drive `active`/`idle` + `mode` + `reduceMotion`):
1. Drive `active` + `car`/`motorbike` into a bend. Enter the compact PiP (frameless, always-on-top). Confirm
   the **leaning cockpit renders** in the PiP and reads as rolling **into** the turn at the sized-down size.
2. Watch a full sweep cycle at the PiP: confirm the **rotated cockpit frame still fully covers the cockpit
   band** at **peak lean** — **no** exposed un-painted canvas corners, no sliver of scene revealed where the
   cockpit should be.
3. Confirm the **same** lean also reads correctly on the **full window** surface, and that the world (road /
   scenery / horizon) is **not** tilted on either surface.
4. Confirm the lean did not break the PiP's frameless / always-on-top behaviour or its occlusion/visibility
   pause (inherited from mini-window / journey-pov — the lean adds no new motion source).

Expect: the leaning cockpit renders correctly + covers the band with no exposed corners on a real PiP and full
window, with the world held level. An exposed un-painted corner at peak lean, or a broken PiP behaviour,
blocks ship.

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (DEFERRED — required before any Windows release): Pass [ ]  Fail [ ]  Blocked [ ]

### TC-M-NF1 — Sustained ≥30fps on BOTH surfaces with the lean active (P1, device, [DEVICE])
Covers NFR-1. Deterministic proxy: TC-517 (constant per-frame angle-update + no-alloc) + inherited
bounded-pool / no-per-frame-alloc guards re-run with the lean active.

Steps:
1. With mock activity = `active`, `car`/`motorbike`, the lean active on a curving stretch, run a sustained
   window on the **full** window surface and on the **sized-down PiP** surface (both where the surface model
   allows simultaneous render).
2. Capture frame build/raster times (DevTools / performance overlay / `traceAction`).
3. Confirm no per-frame hitch from the per-frame angle update or the cockpit rotation transform, and no
   allocation spike as the session scrolls for a long time.

Expect: each surface holds **≥30fps** on the reference machine with the lean active while `active` (target
~60fps steady, ≥30fps floor; no sustained jank, no per-frame allocation spike from the angle update / rotation).
Record device + OS. (On-device fps deferral mirrors journey-view / journey-scene-v2 / journey-pov /
journey-dynamic-curve perf NFRs.)

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (DEFERRED — required before any Windows release): Pass [ ]  Fail [ ]  Blocked [ ]

---

## Privacy audit (TC-M-PRIV) — P0, audit, not automated, [AUDIT]

Covers NFR-2. **Ship-blocker.** Static reinforcement: TC-512 (separation imports — cockpit + scene siblings
import only dart:*/flame/*/TravelMode) + TC-511 (lean signal sourced solely from the in-scene curve sample) +
TC-506 (deterministic, no clock/Random) + the inherited journey-pov / journey-dynamic-curve separation. These
do **NOT** replace the audit.

Steps (run `/privacy-audit`, i.e. `privacy-guardian`, over the slice):
1. Confirm the lean adds **no** new OS signal, input, screen, clipboard, files, mouse-position, location, or
   other-app data read — it adds **only** a canvas transform driven by the existing in-scene curve sample (a
   pure function of the shared scroll phase).
2. Confirm `cockpit_painter.dart` / `journey_game.dart` (and any new lean-angle source) still import only
   `dart:*`, `package:flame/*`, and `TravelMode` — no `flutter_bloc`, `JourneyEngine`, `ActivityPlugin`,
   `MethodChannel`/platform channel, or OS read.
3. Confirm any new transitive dependency introduced by the slice introduces **no** capability to capture input
   / screen / clipboard / files / network / location (the slice should add none — it is a transform).
4. Confirm no network call on any path (fully local/offline) — verify offline as above.

Expect: **no** API or dependency adds a new user-data surface; the audit **passes**. A contradiction **fails
this NFR and blocks ship** regardless of every other pass. Re-run on any change to the slice's source or its
dependency set.

- Audit verdict (no per-OS split — source-level): Pass [ ]  Fail [ ]  Blocked [ ]
- Auditor / date: `__________`

---

## Deferred — Windows on-device verification

By decision (precedent: journey-scene-v2, journey-pov, journey-dynamic-curve, mini-window NFR-9, journey-view
fps), the Windows **runtime** legs are **DEFERRED — required before any Windows release**, while the lean + its
Windows parity are authored, code-reviewed, and privacy-audited **now**. The deferred Windows legs are the
"Windows" rows above:

- [ ] TC-M-PIP (Windows) — leaning cockpit correct on a real Windows frameless always-on-top PiP; covers the
      band with no exposed corners at peak lean — **DEFERRED**
- [ ] TC-M-NF1 (Windows) — ≥30fps both surfaces with the lean active — **DEFERRED**

Record the Windows verdicts here when the on-device Windows pass is performed before a Windows release.

---

## Automated companions (run before/with the manual pass)

From `src/focus_journey/` (Flutter is fvm-pinned to 3.38.10 — always prefix `fvm`):

```bash
# Deterministic unit / widget / golden cases (no device): signed-into-turn + sign-flip guard, monotonic vs
# clamp, per-frame no-snap cap, replay determinism, reduce-motion hard zero, straight-road zero, mode-gating +
# non-cockpit byte-for-byte, world-not-tilted scene equality, signal-source + separation static, cosmetic-only
# engine equality, rotated placeholder, leaning-cockpit golden, no-alloc hot-path guard.
fvm flutter test test/

# Lean on both surfaces + bend/reduce-motion/straight/walk headline smoke (needs a device target; mock path).
fvm flutter test integration_test/ -d macos --dart-define=mock-window=true --dart-define=mock-activity=true
fvm flutter test integration_test/ -d windows --dart-define=mock-window=true --dart-define=mock-activity=true
```

Note: `integration_test` files do NOT run under plain `fvm flutter test` (no device); they need
`-d macos` / `-d windows`. The deterministic unit/widget/golden tests under `src/focus_journey/test/` run
under plain `fvm flutter test`. The exact mock-path flag names (`mock-window` / `mock-activity`) follow the
existing convention; confirm against the implemented DI seam.
