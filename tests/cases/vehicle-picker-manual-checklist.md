# Manual run checklist — vehicle-picker

Per-OS / human-driven verification of the `vehicle-picker` cases that **cannot** be a deterministic Dart
unit/widget/integration test because they need a **human art-cohesion / accessibility judgement** (the six
per-mode icons read as one cohesive set, distinct, legible without colour alone), a **real OS accessibility
pass** (keyboard-only operation + a live VoiceOver/Narrator announcement of each mode), a **real on-device
performance measurement** (≥30fps on both surfaces with a preference set / the displayed mode overridden), or
are a **privacy audit**. Follow this during `/execute-tests` and record the verdict per case **per OS** where a
per-OS split applies.

- Authoritative scenarios: [vehicle-picker.md](vehicle-picker.md) (TC-601..TC-618 + the TC-M* legs below).
- Automated companions live under `src/focus_journey/test/` (unit/Cubit/widget/static) and
  `src/focus_journey/integration_test/` (e2e) against the **in-memory repository** + **mock** activity / window
  path — see "Automated companions" below.
- Shares the persistence pattern with `local-stats` (`SettingsCubit` / `AppSettings` / `SettingsRepository`) and
  the scene seams with `journey-pov` (`isCockpitActive` / `currentVehicleAsset`) / `journey-cockpit-lean`
  (separation-static guards). The real-OS PiP plumbing the on-device leg rides is the same one verified in
  [journey-pov-manual-checklist.md](journey-pov-manual-checklist.md) / [mini-window-manual-checklist.md](mini-window-manual-checklist.md).

## How this maps to automation

| TC (this checklist) | Verification here | Automated companion |
|----|-------------------|---------------------|
| TC-M-ART | **Manual [VISUAL]/[REVIEW]** — the six per-mode icons read as **one cohesive set** in the journey art family (not a mismatched outlier), each mode's icon/silhouette is **distinct**, and the chosen-vs-available state is legible **without relying on colour alone** (AC-14 gate + NFR-3 visual) | distinct-icon-per-mode TC-614, asset⇄CREDITS TC-615, semantics labels TC-617 |
| TC-M-A11Y | **Manual [REAL-OS]** — picker is reachable + operable with the **keyboard alone**, and a real **VoiceOver (macOS) / Narrator (Windows)** pass announces each option's per-mode name; no focus trap, no obscured journey readout (NFR-3 real leg) | widget semantics + focus-reachability TC-617 |
| TC-M-NF1 | **Manual / device [DEVICE]** — sustained **≥30fps on both surfaces** (full window + sized-down PiP) with a preference set / displayed mode overridden while `active` (NFR-1) | O(1)-composition / no-new-per-frame-cost guard TC-616 + inherited bounded-pool / no-alloc guards |
| TC-M-PRIV | **Manual privacy audit [AUDIT]** — `/privacy-audit` PASS: picker stores only a local cosmetic `TravelMode?`, reads no OS/activity/screen/location signal, no network, no new dependency / platform channel (NFR-2) | static reinforcement only: firewall TC-610 + AC-9 engine-import inspection TC-609 — does NOT replace the audit |
| **Windows runtime legs** | **DEFERRED — required before any Windows release** | parity authored + reviewed now |

> All other TCs (TC-601..TC-618) are **automated** against the in-memory repository + mock activity/window path and
> are **NOT** in this checklist (their qualitative / real-a11y / device legs are the TC-M* rows above).

## Conventions / tolerance

- **Build the REAL backend, NOT the mock, for the a11y + device + privacy legs.** Run a real per-OS build with the
  **real** window backend and the **real** assistive-tech stack (do **not** pass the mock-window flag). Use the mock
  **activity** source only to deterministically flip `active`/`idle` while keeping the real window + a11y backend.
- **Art cohesion (TC-M-ART) is a REVIEW GATE, not pass/fail math.** Judge against the spec art direction: the six
  icons read as **one cohesive set** in the existing journey art family (Kenney-flat / journey palette), each mode's
  icon/silhouette **distinct**, and the chosen-vs-available state conveyed by the **icon + label**, never by colour
  alone. A cohesion or not-colour-alone fail **blocks ship for the picker art** even if every icon is CREDITS-recorded
  (TC-615) and distinct (TC-614).
- **a11y (TC-M-A11Y).** Operate the picker with the **keyboard only** (no pointer): Tab/Shift-Tab to reach it, arrow/
  Enter/Space to select, and confirm focus can leave (no trap). Turn on the real screen reader and confirm each of the
  six options announces its **mode name** ("Walk", "Run", "Bicycle", "Motorbike", "Car", "Ship"). Confirm the picker
  does not obscure the journey readouts / "Paused — idle" overlay.
- **fps measurement (TC-M-NF1).** Use Flutter DevTools / the performance overlay / `traceAction` frame-timing
  on-device, with a `vehiclePreference` set (displayed mode overridden), on **both** surfaces (full window AND the
  sized-down PiP). Manual spot-check acceptable where automated frame-timing is impractical — record device + OS.
  (Deferral precedent: journey-pov / journey-cockpit-lean fps NFR.)
- **Offline-verifiable (privacy).** During TC-M-PRIV confirm **no** network egress from the app (Little Snitch /
  `nettop` on macOS, Resource Monitor on Windows). Any outbound connection is a **Fail**.

## Per-OS preconditions

- [ ] Build/run a **real** per-OS build (macOS `.app`, Windows `.exe`) with the **real** window + a11y backend
      (NOT the mock-window path). Use the mock **activity** source to drive state/mode where needed.
- [ ] The PiP reachable (enter compact / PiP per `mini-window`) so fps can be confirmed on a real frameless
      always-on-top PiP + main window with a preference set.
- [ ] The OS screen reader available (VoiceOver on macOS, Narrator on Windows) for TC-M-A11Y.
- [ ] Note the OS version tested (record below).

OS versions under test — macOS: `__________`   Windows: `__________`

---

## Cases

Legend per cell: `[ ]` Pass `[ ]` Fail `[ ]` Blocked (check exactly one per OS).

### TC-M-ART — Icon cohesion + not-colour-alone review gate (P0, [VISUAL]/[REVIEW])
Covers AC-14 gate + NFR-3 visual leg. Automated structural legs: TC-614 (distinct icon per mode), TC-615 (asset⇄CREDITS), TC-617 (semantics labels).

Steps (reviewer judgement, picker open with all six options):
1. Do the six per-mode icons (walk / run / bicycle / motorbike / car / ship) read as the **same flat / illustrated
   family** as the existing journey scene + tray glyphs — recoloured to the journey palette — and **not** as a
   mismatched outlier set?
2. Is each mode's icon/silhouette **distinct** so the modes are individually recognisable at a glance?
3. Is the **chosen-vs-available** state legible **without relying on colour alone** (the icon + a text label carry
   it — e.g. a shape/weight/selection ring, not just a colour change)?
4. Does the picker sit cleanly in the Settings row and the journey affordance without crowding / obscuring the
   journey readouts or the "Paused — idle" overlay?

Expect: a cohesive, distinct, colour-independent icon set. A cohesion or not-colour-alone fail **blocks ship for the
picker art** even if TC-614/TC-615 pass.

- Review verdict (source/content-level, no per-OS split): Pass [ ]  Fail [ ]  Blocked [ ]
- Reviewer / date: `__________`

### TC-M-A11Y — Keyboard-only operation + real screen-reader per-mode announcement (P0, [REAL-OS])
Covers NFR-3 real leg. Automated widget leg: TC-617 (per-mode semantics labels + focus-reachability + no focus trap).

Steps (real backend, real screen reader):
1. With **no pointer**, Tab/Shift-Tab to reach the persistent picker; confirm it takes focus and the focus order is
   sensible.
2. Select each of the six modes using the keyboard (arrow / Enter / Space); confirm the displayed vehicle changes
   and the choice persists.
3. Confirm focus can **leave** the picker (no focus trap).
4. Turn on VoiceOver (macOS) / Narrator (Windows); focus each of the six options and confirm it **announces the mode
   name** ("Walk", "Run", "Bicycle", "Motorbike", "Car", "Ship").
5. Repeat the reach + announce for the route-start picker on the `RoutePlannerFlow` review/confirm step.
6. Confirm the picker does not obscure essential journey readouts.

Expect: fully keyboard-operable, each option announced by its mode name, no focus trap, readouts unobscured. A
keyboard-unreachable picker or an unlabelled/colour-only option is a **Fail**.

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (DEFERRED — required before any Windows release): Pass [ ]  Fail [ ]  Blocked [ ]

### TC-M-NF1 — Sustained ≥30fps on BOTH surfaces with a preference set (P1, device, [DEVICE])
Covers NFR-1. Deterministic proxy: TC-616 (O(1) composition above the view state, no new per-frame cost in `JourneyGame`) + inherited bounded-pool / no-per-frame-alloc guards.

Steps:
1. Set a `vehiclePreference` (e.g. `car`) so the displayed mode is overridden; drive mock activity = `active`.
2. Run a sustained window on the **full** window surface and on the **sized-down PiP** surface, under
   representative load, with the override resolved.
3. Capture frame build/raster times (DevTools / performance overlay / `traceAction`).

Expect: each surface holds **≥30fps** on the reference machine with the override active while `active` (target
~60fps steady, ≥30fps floor; no sustained jank). Record device + OS. (On-device fps deferral mirrors journey-pov /
journey-cockpit-lean perf NFRs.)

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (DEFERRED — required before any Windows release): Pass [ ]  Fail [ ]  Blocked [ ]

---

## Privacy audit (TC-M-PRIV) — P0, audit, not automated, [AUDIT]

Covers NFR-2. **Ship-blocker.** Static reinforcement: TC-610 (firewall — engine references neither the preference
nor the settings store) + TC-609 (engine-import inspection / JourneyCubit pure reader). These do **NOT** replace
the audit.

Steps (run `/privacy-audit`, i.e. `privacy-guardian`, over the slice):
1. Confirm the picker stores **only** a local cosmetic `TravelMode?` (`AppSettings.vehiclePreference`) via the
   existing `shared_preferences` settings store — it reads **no** OS / activity / screen / clipboard / files /
   mouse-position / location signal.
2. Confirm the slice adds **no** new dependency and **no** new platform channel / `MethodChannel`.
3. Confirm any new transitive dependency introduced by the picker icon assets / loading introduces **no** capability
   to capture input / screen / clipboard / files / network / location.
4. Confirm no network call on any path (fully local/offline) — verify offline as above.

Expect: **no** API or dependency adds a new user-data surface; the audit **passes**. A contradiction **fails this
NFR and blocks ship** regardless of every other pass. Re-run on any change to the slice's source or its dependency
set.

- Audit verdict (no per-OS split — source-level): Pass [ ]  Fail [ ]  Blocked [ ]
- Auditor / date: `__________`

---

## Deferred — Windows on-device verification

By decision (precedent: journey-pov, journey-cockpit-lean, mini-window), the Windows **runtime** legs are
**DEFERRED — required before any Windows release**, while the picker + its Windows parity are authored,
code-reviewed, and privacy-audited **now**. The deferred Windows legs are the "Windows" rows above:

- [ ] TC-M-A11Y (Windows) — keyboard-only operation + Narrator per-mode announcement — **DEFERRED**
- [ ] TC-M-NF1 (Windows) — ≥30fps both surfaces with a preference set — **DEFERRED**

Record the Windows verdicts here when the on-device Windows pass is performed before a Windows release.

---

## Automated companions (run before/with the manual pass)

From `src/focus_journey/` (Flutter is fvm-pinned to 3.38.10 — always prefix `fvm`):

```bash
# Deterministic unit/Cubit/widget/static cases (no device): setVehicle emit+persist, restore-before-apply,
# absent/corrupt fallback, precedence both directions, engine byte-for-byte equality across all six picks,
# JourneyCubit pure-reader, the firewall import-inspection, distinct-icon-per-mode, asset⇄CREDITS, semantics labels,
# NFR-1 no-per-frame-cost guard.
fvm flutter test test/

# Two-entry-points-one-source + route-start propagation + restart-restore smoke (needs a device target; mock path).
fvm flutter test integration_test/ -d macos --dart-define=mock-window=true --dart-define=mock-activity=true
fvm flutter test integration_test/ -d windows --dart-define=mock-window=true --dart-define=mock-activity=true
```

Note: `integration_test` files do NOT run under plain `fvm flutter test` (no device); they need `-d macos` /
`-d windows`. The deterministic unit/Cubit/widget/static tests under `src/focus_journey/test/` run under plain
`fvm flutter test`. The exact mock-path flag names (`mock-window` / `mock-activity`) follow the existing convention;
confirm against the implemented DI seam.
</content>
