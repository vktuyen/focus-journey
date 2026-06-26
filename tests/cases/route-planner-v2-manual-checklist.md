# Manual run checklist — route-planner-v2

Per-OS, human-driven verification of the `route-planner-v2` cases that **cannot** be a deterministic Dart
unit/widget/integration test because they need a **real on-device performance measurement** (NFR-1 — the
picker / auto-insert / review screen render and re-render with no visible jank on macOS and Windows), a
**real screen-reader / keyboard accessibility judgement** (NFR-3 — the picker, the review screen and its
editing controls, and the abandon confirm dialog), or are the **gating privacy audit + runtime egress
inspection** (NFR-2 — route selection + auto-insert must add **zero** new location/tracking surface). Follow
this during `/execute-tests` and record the verdict per case **per OS**.

- Authoritative scenarios: [route-planner-v2.md](route-planner-v2.md) (TC-301..TC-340 + the TC-M* legs below).
- Spec: [specs/route-planner-v2/spec.md](../../specs/route-planner-v2/spec.md) — NFR-2 is **CRITICAL — gating**.
- Sibling manual checklist (format/precedent): [map-experience-manual-checklist.md](map-experience-manual-checklist.md).
- Automated companions live under `src/focus_journey/test/` (unit/widget/golden) and
  `src/focus_journey/integration_test/` (integration) against **fake distance source / faked repository**
  paths — see "Automated companions" below.

## How this maps to automation

| TC (this checklist) | Verification here | Automated companion (fake path) |
|----|-------------------|---------------------|
| TC-M-A11Y | **Manual / device [AT]** — real screen reader + full keyboard operation of the picker, the review screen (incl. remove/skip controls + total-distance readout), and the abandon confirm dialog (NFR-3 real leg) | TC-339 (Semantics labels + keyboard focus/activation across all three surfaces) |
| TC-M-NF1 | **Manual / device [DEVICE]** — picker / auto-insert re-resolution / review-screen edits render with no visible jank on macOS + Windows (NFR-1) | TC-340 (pure-domain re-resolve is allocation-bounded + sub-frame; no network/disk) |
| TC-M-PRIV | **Manual privacy audit + runtime egress [AUDIT]** — `/privacy-audit` PASS; selection/auto-insert/review/abandon make **no** network call at all; no GPS/location surface; no new identifier or location trail (NFR-2, **gating**) | static reinforcement: TC-337 (no location/GPS API; geography is the static `map-experience` model), TC-338 (planning paths make zero network calls) — does **NOT** replace the audit |
| **Windows runtime legs** | **DEFERRED — required before any Windows release** | logic + parity authored, reviewed, audited now on the fake path |

> All other TCs (TC-301..TC-340) are **automated** against the fake distance source / faked
> `shared_preferences`/JSON repository / static-inspection paths and are **NOT** in this checklist (their
> device / AT / audit legs are the TC-M* rows above).

## Conventions / tolerance

- **Build the REAL desktop build per OS** (macOS `.app`, Windows `.exe`). For driving journey/route state
  during the manual run you may use the **mock activity source** to deterministically produce active/idle
  and reach a known route position; route selection / planning / abandon are pure UI flows requiring no
  network.
- **No new network call is expected from this slice at all.** `map-experience` introduced the only outbound
  traffic (anonymous OSM tile GETs). Route selection, auto-insert, the review screen, and abandon must
  trigger **zero** outbound traffic of their own. Any outbound connection attributable to the picker /
  auto-insert / review / abandon flow (i.e. not an OSM tile GET) is a **Fail** for TC-M-PRIV.
- **Egress monitoring is mandatory for TC-M-PRIV.** Run a network monitor (Little Snitch / `nettop` on
  macOS; Resource Monitor / a proxy on Windows). Exercise the whole flow — open picker, pick start + end,
  mark a stop, view/edit the review screen, confirm start, then abandon + start a new route — and confirm
  **no** request leaves the machine that is attributable to this slice (only `map-experience`'s tile GETs
  may appear, and only because the map overlay is on screen).
- **No device-location read anywhere.** Confirm the picker offers only the curated ~10–15 static spine
  checkpoints; it never pre-selects, suggests, or sorts by the user's actual location, and never reads GPS.

## Per-OS preconditions

- [ ] Build/run a **real** per-OS build (macOS `.app`, Windows `.exe`). Use the mock **activity** source to
      drive route state to a known `routeDistanceKm`.
- [ ] A network monitor running (Little Snitch / `nettop` macOS; Resource Monitor / proxy Windows) for
      TC-M-PRIV egress inspection.
- [ ] A screen reader available (VoiceOver on macOS; Narrator on Windows) for TC-M-A11Y.
- [ ] Keyboard-only operation possible (no mouse) for the TC-M-A11Y keyboard legs.
- [ ] Note the OS version tested (record below).

OS versions under test — macOS: `__________`   Windows: `__________`

---

## Cases

Legend per cell: `[ ]` Pass `[ ]` Fail `[ ]` Blocked (check exactly one per OS).

### TC-M-A11Y — Picker + review screen + abandon dialog are keyboard-operable and screen-reader labelled (P1, [AT])
Covers NFR-3 (real-AT + keyboard leg). Automated leg: TC-339.

Steps (VoiceOver on macOS / Narrator on Windows, then keyboard-only):
1. With the screen reader on, open the **picker** → confirm each selectable checkpoint (start + end) is
   announced with a meaningful accessible name and is reachable by Tab; confirm the disabled
   start==end option is announced as unavailable (TC-303).
2. Resolve a route and open the **review screen** → confirm the ordered route, each remove/skip control,
   and the **total-distance readout** are announced meaningfully; operate a remove/skip control with the
   keyboard and confirm the re-resolved route + distance are re-announced.
3. Trigger an abandon with progress → confirm the **confirm guard dialog** is announced, its confirm and
   cancel actions expose accessible names, and both are reachable + activatable by keyboard (Enter to
   confirm, Esc/Escape to cancel).
4. Keyboard-only pass: complete the entire flow (pick start + end, mark a stop, review + edit, confirm
   start, then abandon + start a new route) using **only** Tab / Enter / Esc — no mouse.

Expect: a screen-reader + keyboard-only user can find, understand, and operate every control on the picker,
the review screen (incl. editing + distance readout), and the abandon dialog — no mouse-only path.

- macOS (VoiceOver + keyboard): Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (Narrator + keyboard, DEFERRED — required before any Windows release): Pass [ ]  Fail [ ]  Blocked [ ]

### TC-M-NF1 — Picker / auto-insert / review screen render + re-render with no visible jank (P1, device, [DEVICE])
Covers NFR-1. Deterministic guard: TC-340.

Steps:
1. Open the picker and select start + end at the **extreme ends** of the curated spine (longest route,
   most auto-inserted intermediates).
2. On the review screen, repeatedly **remove and re-add / skip** intermediates and watch each re-resolve
   redraw → confirm each edit updates the ordered route + total distance **instantly** with no visible
   stutter or spinner.
3. Capture frame build/raster times (DevTools / performance overlay) during picker open, route resolve,
   and a burst of review-screen edits.
4. Repeat on the reference machine per OS.

Expect: the picker, auto-insert resolution, and every review-screen re-resolution render responsively with
**no visible jank** (target ~60fps, no dropped-frame run a user would notice); auto-insert / re-resolution
for the ~10–15-checkpoint spine completes effectively instantly (well within a frame) and never blocks on
network or disk. Record device + OS. (On-device fps deferral mirrors `map-experience` TC-M-NF1.)

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (DEFERRED — required before any Windows release): Pass [ ]  Fail [ ]  Blocked [ ]

---

## Privacy audit + runtime egress (TC-M-PRIV) — P0, audit, not automated, [AUDIT] — **CRITICAL, GATING**

Covers NFR-2 (the gating concern). **Ship-blocker.** Static reinforcement: TC-337 (no device-location/GPS
API; selection + auto-insert read only the static `map-experience` geography) + TC-338 (selection /
auto-insert / review / abandon make zero network calls). These do **NOT** replace the audit. Typing/picking
real provinces is the most location-*suggestive* interaction the product has shipped — the audit must
confirm it adds **zero** tracking.

Steps (run `/privacy-audit`, i.e. `privacy-guardian`, over the slice **and** inspect real egress):
1. Confirm the picker + auto-insert read **only** `map-experience`'s static province reference geography
   (lat/long + adjacency) — app-supplied constant/asset, **never** the user's position. No
   `geolocator`/`location`/CoreLocation/geocoding/location platform channel anywhere in the slice.
2. Confirm route selection emits **no** new identifier and **no** location trail — the persisted route
   descriptor is the authored checkpoint list + offset + lifecycle state (static reference IDs + a
   distance scalar), not a record of where the user physically is.
3. **Runtime egress inspection:** with a network monitor running, exercise the full flow (open picker,
   pick start + end, mark a stop, review + edit, confirm start, then abandon + start a new route) →
   confirm the **only** outbound traffic is `map-experience`'s anonymous OSM tile GETs (present only
   because the map overlay is on screen). The selection / auto-insert / review / abandon flow itself
   makes **no** network call — no request attributable to this slice leaves the machine.
4. Confirm the slice adds **no** new dependency that reads input / screen / clipboard / files / location.

Expect: **no** API or dependency adds a user-data tracking surface; the planning flow is fully offline; the
audit **passes**. A contradiction **fails NFR-2 and blocks ship** regardless of every other pass. Re-run on
any change to the slice's source or its dependency set.

- Audit verdict (no per-OS split — source-level): Pass [ ]  Fail [ ]  Blocked [ ]
- Runtime egress verdict (per OS exercised): macOS Pass [ ]  Fail [ ]  Blocked [ ]   Windows Pass [ ]  Fail [ ]  Blocked [ ]
- Auditor / date: `__________`

---

## Deferred — Windows on-device verification

By decision (precedent: `map-experience` NFR legs, `mini-window` NFR-9, `journey-view` / `journey-scene-v2`
fps), the Windows **runtime** legs are **DEFERRED — required before any Windows release**, while the Windows
behaviour + parity are authored, code-reviewed, and privacy-audited **now** on the fake/static paths:

- [ ] TC-M-A11Y (Windows / Narrator + keyboard) — picker/review/abandon operable — **DEFERRED**
- [ ] TC-M-NF1 (Windows) — no-jank picker/auto-insert/review render — **DEFERRED**
- [ ] TC-M-PRIV (Windows runtime egress) — no slice-attributable request leaves the machine — **DEFERRED**

Record the Windows verdicts here when the on-device Windows pass is performed before a Windows release.

---

## Automated companions (run before/with the manual pass)

From `src/focus_journey/` (Flutter is fvm-pinned to 3.38.10 — always prefix `fvm`):

```bash
# Deterministic unit/widget/golden cases (no device, no network):
#   sub-path resolution + spine order (TC-301..305), auto-insert + extend-span (TC-306..309),
#   review screen + edit re-resolve (TC-310..313), zero-side-effect snapshot (TC-314..316),
#   confirm stamps one offset + pure-fn position (TC-317..319),
#   route-relative completion + both %s (TC-320..323),
#   abandon guard + new offset + never-reset + not-completion (TC-324..330),
#   no idle-trace bleed (TC-331..333), persistence/restart (TC-334..336),
#   static privacy + zero-network (TC-337/338), semantics + keyboard (TC-339), hot-path guard (TC-340).
fvm flutter test test/

# Integration: Bloc↔picker/review wiring, confirm/abandon lifecycle, restart restoration, no-write guards
# (needs a device target; fake distance source + faked repository).
fvm flutter test integration_test/ -d macos --dart-define=mock-activity=true
fvm flutter test integration_test/ -d windows --dart-define=mock-activity=true
```

Note: `integration_test` files do NOT run under plain `fvm flutter test` (no device); they need
`-d macos` / `-d windows`. The deterministic unit/widget/golden tests under `src/focus_journey/test/` run
under plain `fvm flutter test`. Confirm the exact fake distance-source / faked-repository injection seam and
any mock flag names against the implemented DI (follow the existing `mock-activity` / `mock-window`
convention).
