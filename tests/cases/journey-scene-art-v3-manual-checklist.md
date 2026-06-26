# Manual run checklist — journey-scene-art-v3

Per-OS / human-driven verification of the `journey-scene-art-v3` cases that **cannot** be a deterministic
Dart unit/widget/integration test because they are a **human art-direction / cohesion judgement** (the
emotional payload of this slice IS the look), an **art-direction spike + fallback-ladder sign-off**, a
**real on-device performance measurement** (≥30fps on both surfaces with the higher-resolution cohesive set
loaded), or a **privacy audit**. Follow this during `/execute-tests` and record the verdict per case (and
per OS where a per-OS split applies).

- Authoritative scenarios: [journey-scene-art-v3.md](journey-scene-art-v3.md) (TC-301..TC-319 + the TC-M*
  legs below).
- Automated companions live under `src/focus_journey/test/` (widget) and `src/focus_journey/integration_test/`
  (e2e) against the **mock** activity + window/visibility path — see "Automated companions" below.
- Shares the scene + PiP with `journey-scene-v2` / `journey-pov` — the real-OS occlusion plumbing this
  checklist relies on is the same one verified in
  [journey-scene-v2-manual-checklist.md](journey-scene-v2-manual-checklist.md) and
  [journey-pov-manual-checklist.md](journey-pov-manual-checklist.md); here we only confirm the **re-sourced
  art** reads correctly on it.

## How this maps to automation

| TC (this checklist) | Verification here | Automated companion (mock path) |
|----|-------------------|---------------------|
| TC-M-SPIKE | **Manual [REVIEW]** — stylized-flat cohesion + craft sign-off (the hard gate of AC-1, and the look legs of AC-3/AC-4/AC-5/AC-6): the chosen family reads as **one designed, higher-craft stylized-flat trip across Vietnam** (not an asset-pack patchwork, not photoreal); the **beach/coast band** reads as a real cohesive coastline (AC-5 look); the **side-view animals** read as in-family side-profile creatures, not floating badge-faces (AC-6 look); the art still reads well at the **sized-down PiP** (AC-4 look); the wholesale re-source reads cohesive (AC-3 look). **No asset lands before this sign-off** (AC-1 gate). | spike-artifact + no-pre-sign-off-change process check TC-301; wholesale-membership TC-303; both-surfaces wiring TC-304; beach band TC-305; animal reachability TC-306; re-baselined frames TC-313/TC-314 |
| TC-M-FALLBACK | **Manual [REVIEW]** — fallback-ladder sign-off (AC-2): if the first candidate family could not cover beach/coast + animals cohesively, the recorded fallback rung (switch family → original flat vectors → procedural/drop) was the right call, and any rung-2/3 use is a **dated, explicit, signed-off deviation** — no silent category drop. | recorded fallback rung + deviation sign-off check TC-302 |
| TC-M-NF1 | **Manual / device [DEVICE]** — sustained **≥30fps on both surfaces** (full window + sized-down PiP) with the **higher-resolution** cohesive set + the net-new beach/animal kinds loaded while `active` (NFR-1). | static bounded-pool / no-per-frame-alloc proxy re-run with the higher-res set: TC-308 + inherited journey-view/journey-scene-v2 guards |
| TC-M-PRIV | **Manual privacy audit [AUDIT]** — `/privacy-audit` PASS: the re-source adds **no** new OS signal/input/screen/location read and changes no journey truth — it swaps only static image assets (NFR-2). **Gating ship-blocker.** | static reinforcement only: separation invariant TC-315 + cosmetic-only engine counters TC-312 — does NOT replace the audit |
| **Windows runtime legs** | **DEFERRED — required before any Windows release** | parity authored + reviewed now |

> All other TCs (TC-301..TC-319) are **automated** against the mock path and are **NOT** in this checklist
> (their human-judgement / device / audit legs are the TC-M* rows above).

## Status (recorded at authoring, 2026-06-25)

- **TC-M-SPIKE — DONE.** Kevin **signed off the art-direction spike + cohesion (AC-1/AC-2 artifacts)** on
  **2026-06-25**. The spike record, per-asset licence list, side-by-side comparison, and the hybrid
  rung-1+rung-2 decision are committed in `src/focus_journey/assets/CREDITS.md`
  ("journey-scene-art-v3 — SHIPPED cohesive re-source"). The manifest replacement post-dates the sign-off
  (AC-1 gate honoured). A craft-pass recommendation (subtle shading on the rung-2 original-flat vectors) is
  noted in CREDITS for a future polish slice; it does not gate this slice's ship.
- **TC-M-FALLBACK — DONE.** The **rung-2 deviation** (original flat vectors for vehicles/people/animals/
  beach/bands, because no single CC0 family covers side-view animals + beach + side-view vehicles cohesively)
  was **signed off by Kevin 2026-06-25**, recorded in CREDITS with the coverage matrix — no silent category
  drop.
- **TC-M-NF1 — CARRY.** On-device ≥30fps on both surfaces with the higher-resolution set is **not yet
  measured** — carried to the pre-public-release on-device pass (precedent: journey-view / journey-scene-v2 /
  journey-pov fps NFRs).
- **TC-M-PRIV — CARRY (gating).** `/privacy-audit` PASS is the **gating ship-blocker** and must be run on this
  slice before ship; not yet recorded here.

## Conventions / tolerance

- **Art cohesion (TC-M-SPIKE) is a REVIEW GATE, not pass/fail math.** Judge against the spec art direction:
  **higher-craft stylized flat**, cohesive across road/sky/vehicles/parallax/people/city **and** beach/coast
  **and** side-view animals, recoloured to the journey palette, **not** a photoreal outlier and **not** an
  asset-pack patchwork. The beach/coast **band** must read as a real coastline; the **animals** must read as
  side-profile full-body creatures (not badge faces); the art must still read well **shrunk to the PiP**. A
  cohesion fail **blocks ship for the art** even if every asset is CREDITS-recorded (TC-311) and renders.
- **No asset lands before the spike sign-off (AC-1 hard gate).** The checkable process artifact is the spike
  record + licence list + comparison + a **dated** human sign-off, and that the `JourneyAssets` manifest
  replacement **post-dates** the sign-off (TC-301). The cohesion/craft judgement itself is this review gate.
- **Fallback-ladder rightness (TC-M-FALLBACK) is a REVIEW GATE.** The recorded rung + (for rung 2/3) the
  dated deviation sign-off is the checkable artifact (TC-302); whether the chosen rung was the *right* call
  is the human judgement here.
- **fps measurement (TC-M-NF1).** Use Flutter DevTools / the performance overlay / `traceAction` frame-timing
  on-device with the **higher-resolution** cohesive set + the net-new beach/animal kinds loaded, on **both**
  surfaces (full window AND the sized-down PiP). Record device + OS.
- **Offline-verifiable (privacy).** During TC-M-PRIV confirm **no** network egress from the app (Little
  Snitch / `nettop` on macOS, Resource Monitor on Windows). Any outbound connection is a **Fail**.

## Per-OS preconditions

- [ ] Build/run a **real** per-OS build (macOS `.app`, Windows `.exe`) with the **real** window + occlusion
      backend. Use the mock **activity** source to drive `active`/`idle` + the travel `mode`.
- [ ] The PiP reachable (enter compact / PiP per `mini-window`) so the re-sourced art can be confirmed on a
      real frameless always-on-top PiP + main window at once.
- [ ] OS reduce-motion toggle accessible (to spot-check AC-15 on-device alongside the automated TC-317).
- [ ] Note the OS version tested (record below).

OS versions under test — macOS: `__________`   Windows: `__________`

---

## Cases

Legend per cell: `[ ]` Pass `[ ]` Fail `[ ]` Blocked (check exactly one).

### TC-M-SPIKE — Stylized-flat cohesion + craft sign-off (the AC-1 gate; AC-3/4/5/6 look legs) (P0, [REVIEW])
Covers the AC-1 hard gate + the look legs of AC-3 (wholesale cohesion), AC-4 (PiP-size look), AC-5 (beach
band look), AC-6 (animal side-view cohesion). Automated mechanical legs: TC-301/TC-303/TC-304/TC-305/TC-306/
TC-313/TC-314.

Steps (reviewer judgement, with `active` + the re-sourced set loaded, across modes + a long scroll):
1. Does the scene read as **one designed, higher-craft stylized-flat trip across Vietnam** — road, sky,
   vehicles, parallax bands, people/city all cohesive — and **not** an asset-pack patchwork or photoreal?
2. Does the **beach/coast band** read as a real cohesive coastline (sea/sand horizon), cohesive with the
   mountains/hills bands, as it cycles in by scroll phase?
3. Do the **side-view animals** read as in-family side-profile full-body creatures (not floating badge-faces,
   not placeholders)?
4. Does the art still read well **shrunk down to the PiP** (composition + silhouettes legible at PiP size)?
5. Confirm the spike artifact (candidate family record + per-asset licence list + side-by-side comparison)
   exists and the **manifest replacement post-dates the dated human sign-off** (AC-1 gate — TC-301 checks the
   process; this confirms the judgement).

Expect: a cohesive higher-craft stylized-flat trip incl. a real-reading beach band + side-view animals,
legible at PiP size, all landed only AFTER sign-off. A cohesion fail **blocks ship for the art**.

- Review verdict (source/content-level, no per-OS split): Pass [x] (Kevin, 2026-06-25)  Fail [ ]  Blocked [ ]
- Reviewer / date: `Kevin (Tuyen Vo) / 2026-06-25`
- Note: a craft-pass (shading on the rung-2 original-flat vectors) is recommended for a future polish slice;
  recorded in CREDITS. Does not block this slice.

### TC-M-FALLBACK — Covering-family fallback-ladder sign-off (AC-2) (P1, [REVIEW])
Covers AC-2. Automated mechanical leg: TC-302 (recorded rung + deviation sign-off check).

Steps (reviewer judgement):
1. Confirm the recorded fallback rung in CREDITS follows the decided ladder — (1) switch to a covering CC0
   family → (2) original flat vectors matched to style → (3) procedural/drop only as last resort.
2. Confirm any **rung-2/3** use is a **dated, explicit, signed-off deviation** (no silent category drop), and
   judge that the chosen rung was the right call (e.g. original flat vectors for the categories no single CC0
   family covers cohesively).

Expect: the recorded rung is the right call and any rung-2/3 use is signed off. A silent category drop fails.

- Review verdict (no per-OS split): Pass [x] (Kevin, 2026-06-25)  Fail [ ]  Blocked [ ]
- Reviewer / date: `Kevin (Tuyen Vo) / 2026-06-25` — hybrid rung-1 (scenery/sky family switch to Background
  Elements Remastered) + rung-2 (original flat vectors for vehicles/people/animals/beach/bands), recorded in
  CREDITS with the coverage matrix.

### TC-M-NF1 — Sustained ≥30fps on BOTH surfaces with the higher-resolution set (P1, device, [DEVICE])
Covers NFR-1. Deterministic proxy: TC-308 (bounded-pool plateau) + inherited bounded-pool / no-per-frame-alloc
guards re-run with the higher-resolution re-sourced set loaded.

Steps:
1. With mock activity = `active` and the full higher-resolution cohesive set + net-new beach/animal kinds
   loaded, drive a representative journey (long enough to cycle the beach band + a full spawn cycle).
2. Run a sustained window on the **full** window surface and on the **sized-down PiP** surface, under
   representative load.
3. Capture frame build/raster times (DevTools / performance overlay / `traceAction`).

Expect: each surface holds **≥30fps** on the reference machine under the full scene while `active`
(target ~60fps steady, ≥30fps floor; no sustained jank) despite the resolution lift. Record device + OS.

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]  (CARRY — not yet measured)
- Windows (DEFERRED — required before any Windows release): Pass [ ]  Fail [ ]  Blocked [ ]

---

## Privacy audit (TC-M-PRIV) — P0, audit, not automated, [AUDIT]

Covers NFR-2. **Ship-blocker (gating).** Static reinforcement: TC-315 (separation invariant — scene +
siblings import only dart:*/flame/*/TravelMode) + TC-312 (cosmetic-only engine counters byte-for-byte /
dependency direction). These do **NOT** replace the audit.

Steps (run `/privacy-audit`, i.e. `privacy-guardian`, over the slice):
1. Confirm the re-source adds **no** new OS signal, input, screen, clipboard, files, mouse-position,
   location, or other-app data read — it swaps **only static image assets** and keys off the existing
   `applyState` values.
2. Confirm the scene + its siblings still import only `dart:*`, `package:flame/*`, and `TravelMode` — no
   `flutter_bloc`, `JourneyEngine`, `ActivityPlugin`, `MethodChannel`/platform channel, or OS read (the only
   Flutter surface remains the asset bundle/manifest via `JourneySprites`).
3. Confirm any new transitive dependency introduced by the re-source introduces **no** capability to capture
   input / screen / clipboard / files / network / location.
4. Confirm no network call on any path (fully local/offline) — verify offline as above.

Expect: **no** API or dependency adds a new user-data surface; the audit **passes**. A contradiction
**fails this NFR and blocks ship** regardless of every other pass. Re-run on any change to the slice's
source or its dependency set.

- Audit verdict (no per-OS split — source-level): Pass [ ]  Fail [ ]  Blocked [ ]  (CARRY — gating, run before ship)
- Auditor / date: `__________`

---

## Deferred — Windows on-device verification

By decision (precedent: journey-scene-v2, mini-window NFR-9, journey-view fps, journey-pov), the Windows
**runtime** legs are **DEFERRED — required before any Windows release**, while the re-source + its Windows
parity are authored, code-reviewed, and privacy-audited **now**.

- [ ] TC-M-NF1 (Windows) — ≥30fps both surfaces with the higher-resolution set loaded — **DEFERRED**

Record the Windows verdicts here when the on-device Windows pass is performed before a Windows release.

---

## Automated companions (run before/with the manual pass)

From `src/focus_journey/` (Flutter is fvm-pinned to 3.38.10 — always prefix `fvm`):

```bash
# Deterministic widget cases (no device): wholesale-membership (TC-303), beach band
# cycle + no-geography (TC-305), animal reachability (TC-306), even spacing with new
# kinds (TC-307), bounded pool (TC-308), higher-res dims + CREDITS completeness
# (TC-309/TC-311), manifest-only loading (TC-310), re-baselined frames (TC-313/TC-314),
# placeholder degradation (TC-316), reduce-motion (TC-317), idle/paused parks (TC-318),
# separation + cosmetic-only engine counters (TC-315/TC-312), plus the Part-A churn repairs.
fvm flutter test test/

# Two-surface wiring (TC-304) + headline long-journey smoke (TC-319) on the shared game
# (needs a device target; mock path, no real OS occlusion).
fvm flutter test integration_test/journey_scene_art_v3_smoke_test.dart -d macos
fvm flutter test integration_test/journey_scene_art_v3_smoke_test.dart -d windows
```

Note: `integration_test` files do NOT run under plain `fvm flutter test` (no device); they need
`-d macos` / `-d windows`. The deterministic widget tests under `src/focus_journey/test/` run under plain
`fvm flutter test`.
