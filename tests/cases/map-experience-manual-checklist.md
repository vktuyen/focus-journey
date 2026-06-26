# Manual run checklist — map-experience

Per-OS, human-driven verification of the `map-experience` cases that **cannot** be a deterministic Dart
unit/widget/integration test because they need **real network connectivity** (the first outbound call this
product has ever made — real OSM tile fetch + real offline fallback), a **real on-device performance
measurement** (≥30fps on both desktops including the inline↔full-screen transition with live tiles), a
**human perceptual / accessibility judgement** (colour-blind perception of the idle trace; real
screen-reader announcements), or are the **gating privacy audit + runtime egress inspection** (NFR-2 — the
most location-suggestive surface ever shipped must add zero tracking). Follow this during `/execute-tests`
and record the verdict per case **per OS**.

- Authoritative scenarios: [map-experience.md](map-experience.md) (TC-201..TC-232 + the TC-M* legs below).
- Spec: [specs/map-experience/spec.md](../../specs/map-experience/spec.md) — NFR-2 is **CRITICAL — gating**.
- Automated companions live under `src/focus_journey/test/` (unit/widget/golden) and
  `src/focus_journey/integration_test/` (integration) against **fake tile provider / fake distance source**
  paths — see "Automated companions" below.

## How this maps to automation

| TC (this checklist) | Verification here | Automated companion (fake path) |
|----|-------------------|---------------------|
| TC-M1 | **Manual [REAL-NETWORK]** — real OSM tiles fetch + visible attribution over a real connection (AC-11 real leg) | TC-218 (fake tile provider returns tiles + attribution widget present) |
| TC-M2 | **Manual [REAL-NETWORK]** — real offline / airplane-mode fallback; tab never breaks; cached vs blank-base branches (AC-11 real leg) | TC-219 (fake provider scripted to timeout/error, both fallback branches) |
| TC-M3 | **Manual [REVIEW]** — colour-blind perception: idle stretches perceivable & causes distinguishable beyond colour (AC-9/NFR-3 judgement) | TC-216 (same-red + differing stroke style), TC-225 (golden) |
| TC-M4 | **Manual / device [AT]** — real screen reader announces toggle/dismiss + map controls usefully (NFR-3 real leg) | TC-232 (Semantics labels + keyboard focusability) |
| TC-M-NF1 | **Manual / device [DEVICE]** — sustained ≥30fps on macOS+Windows incl. inline↔full-screen transition + max idle-segment count + live tiles (NFR-1) | TC-229 (hot-path no-realloc / shouldRepaint / bounded segments) |
| TC-M-PRIV | **Manual privacy audit + runtime egress [AUDIT]** — `/privacy-audit` PASS; only anonymous tile GETs leave the machine; no GPS/location surface (NFR-2, **gating**) | static reinforcement: TC-230 (no location API), TC-231 (tile URL data-free) — does **NOT** replace the audit |
| **Windows runtime legs** | **DEFERRED — required before any Windows release** | logic + parity authored, reviewed, audited now on the fake path |

> All other TCs (TC-201..TC-232) are **automated** against the fake tile provider / fake distance source /
> static-inspection paths and are **NOT** in this checklist (their real-network / perceptual / device /
> audit legs are the TC-M* rows above).

## Conventions / tolerance

- **Build the REAL backend, NOT a fake.** Run a real per-OS build with the **real** `flutter_map` + OSM tile
  layer (do **not** inject the fake tile provider for these legs — the fake never touches the network and
  would invalidate every case here). For driving journey/route state during the manual run you may use the
  **mock activity source** to deterministically produce active/idle and reach a known route position, while
  keeping the **real** tile/network backend.
- **No automated proxy for the real-network side.** The fake-tile-provider tests prove the
  fallback-selection *logic* and that attribution renders. They do **not** prove a real OSM round-trip
  succeeds, that a real OS network timeout degrades gracefully, or that real offline mode actually hits the
  cached/blank-base branch — that is exactly what TC-M1 / TC-M2 verify once per release per OS.
- **First network call in the product's history.** The app has been fully offline to date. Treat any
  outbound connection **other than** anonymous OSM tile GETs as a **Fail** for TC-M-PRIV.
- **Egress monitoring is mandatory for TC-M-PRIV.** Run a network monitor (Little Snitch / `nettop` on
  macOS; Resource Monitor / a proxy on Windows) and inspect the actual requests. The only egress permitted
  is OSM tile GETs keyed by `{z}/{x}/{y}` with a static user-agent — **no** identifier, location, idle, or
  account data in any request.
- **fps measurement (TC-M-NF1).** Use Flutter DevTools / the performance overlay / `traceAction`
  frame-timing on-device, with the **maximum expected idle-segment count** loaded, exercising the
  **inline↔full-screen transition** and panning/zoom with **live tiles**, on **both** surfaces. Manual
  spot-check acceptable where automated frame-timing is impractical — record device + OS. (Deferral
  precedent: `journey-view` / `journey-scene-v2` fps NFRs.)
- **Colour-blind perception (TC-M3) is a REVIEW GATE, not pass/fail math.** Judge with a colour-blindness
  simulator (deuteranopia / protanopia / tritanopia) or a colour-blind reviewer: are idle stretches
  perceivable as distinct from the active road, and are voluntary vs lock/sleep distinguishable **without
  relying on the red hue**? A fail blocks ship for the AC-9 treatment even if the automated stroke-style
  assertion (TC-216/TC-225) passes.

## Per-OS preconditions

- [ ] Build/run a **real** per-OS build (macOS `.app`, Windows `.exe`) with the **real** `flutter_map` + OSM
      tile backend (NOT the fake tile provider). Use the mock **activity** source to drive route state.
- [ ] A way to toggle real connectivity on/off (Wi-Fi off / airplane mode / pull the cable) for the offline
      legs (TC-M2).
- [ ] A network monitor running (Little Snitch / `nettop` macOS; Resource Monitor / proxy Windows) for
      TC-M-PRIV egress inspection.
- [ ] A colour-blindness simulator or a colour-blind reviewer available for TC-M3.
- [ ] A screen reader available (VoiceOver on macOS; Narrator on Windows) for TC-M4.
- [ ] A route seeded with the **maximum expected idle-segment count** for TC-M-NF1.
- [ ] Note the OS version tested (record below).

OS versions under test — macOS: `__________`   Windows: `__________`

---

## Cases

Legend per cell: `[ ]` Pass `[ ]` Fail `[ ]` Blocked (check exactly one per OS).

### TC-M1 — Real OSM tiles fetch over a real connection, with visible attribution (P0, [REAL-NETWORK])
Covers AC-11 (real-network leg). Automated logic leg: TC-218.

Steps:
1. With connectivity ON and the real tile backend, open the journey tab → confirm map **tiles load** under
   the province road/markers/red trace (inline).
2. Tap to full-screen → confirm tiles load there too and pan/zoom fetches further tiles.
3. Confirm the **OSM attribution** is **visibly shown** on the map in both inline and full-screen.
4. Confirm tiles respect OSM tile-usage policy (sane request volume, static user-agent — cross-check with
   the monitor in TC-M-PRIV).

Expect: real OSM tiles render in both surfaces with visible attribution; the road, markers, and red trace
draw correctly on top.

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (DEFERRED — required before any Windows release): Pass [ ]  Fail [ ]  Blocked [ ]

### TC-M2 — Real offline / airplane-mode fallback; journey tab never breaks (P0, [REAL-NETWORK])
Covers AC-11 (real-network leg). Automated logic leg: TC-219 (both branches).

Steps:
1. **Cached branch:** with tiles previously loaded (cache populated), turn connectivity **OFF**, reopen the
   map → confirm **last-cached tiles** show and the road/markers/red trace still render; the tab does not
   error, hang, or block.
2. **Empty-cache branch:** clear the tile cache (fresh install / cleared cache), with connectivity **OFF**,
   open the map → confirm it degrades to a **static/blank base** on which the province road, markers, and
   red trace **still render**; no thrown error, no infinite spinner.
3. Interact with the rest of the journey tab while offline → confirm it stays fully functional.
4. Turn connectivity back ON → confirm tiles resume loading without a restart.

Expect: a failed/absent tile fetch never breaks or blocks the journey tab; both fallback branches
(cached, blank-base) render the road + markers + red trace.

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (DEFERRED — required before any Windows release): Pass [ ]  Fail [ ]  Blocked [ ]

### TC-M3 — Colour-blind perception of the idle trace + cause distinction (P0, [REVIEW])
Covers AC-9 / NFR-3 (perceptual judgement). Automated legs: TC-216 (stroke style), TC-225 (golden).

Steps (with a colour-blindness simulator across deuteranopia / protanopia / tritanopia, or a colour-blind reviewer):
1. View a route with both voluntary and lock/sleep idle stretches and intervening active road.
2. Judge: are **idle stretches perceivable as distinct** from the active road **without relying on the red
   hue** (i.e. is the stroke/pattern enough)?
3. Judge: can **voluntary vs lock/sleep** be told apart by the non-colour cue (solid vs hatched/dashed)
   under each simulation?

Expect: idle stretches and their causes are recoverable beyond colour alone, for the common colour-vision
deficiencies. A fail blocks ship for the AC-9 treatment even if TC-216/TC-225 pass.

- Review verdict (source/content-level, no per-OS split): Pass [ ]  Fail [ ]  Blocked [ ]
- Reviewer / simulation used / date: `__________`

### TC-M4 — Real screen reader announces the toggle/dismiss and map controls usefully (P1, [AT])
Covers NFR-3 (real-AT leg). Automated leg: TC-232 (Semantics labels + keyboard focusability).

Steps (VoiceOver on macOS / Narrator on Windows):
1. With the screen reader on, navigate to the inline map overlay → confirm the **open-full-screen**
   affordance is announced with a meaningful label and is reachable by keyboard.
2. Open full-screen, then navigate to the **dismiss** affordance → confirm it is announced meaningfully and
   activatable (incl. Esc).
3. Tab through the map controls → confirm they expose meaningful semantics, not visual-only cues.

Expect: a screen-reader user can find, understand, and operate the open/dismiss controls and map controls
purely via the AT.

- macOS (VoiceOver): Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (Narrator, DEFERRED — required before any Windows release): Pass [ ]  Fail [ ]  Blocked [ ]

### TC-M-NF1 — Sustained ≥30fps incl. inline↔full-screen transition + max idle-segment count + live tiles (P1, device, [DEVICE])
Covers NFR-1. Deterministic hot-path guard: TC-229.

Steps:
1. Seed the route with the **maximum expected idle-segment count** and load the real tile backend.
2. Capture frame build/raster times (DevTools / performance overlay / `traceAction`) while: rendering the
   inline overlay, performing the **inline↔full-screen transition** repeatedly, and panning/zooming the
   full-screen map with **live tiles**.
3. Repeat on the reference machine per OS.

Expect: the overlay, road polyline, and red idle trace hold **≥30fps** (target ~60, ≥30 floor; no visible
jank) through render, the inline↔full-screen transition, and tile load, even at the max idle-segment count.
Record device + OS. (On-device fps deferral mirrors `journey-view` / `journey-scene-v2` perf NFRs.)

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (DEFERRED — required before any Windows release): Pass [ ]  Fail [ ]  Blocked [ ]

---

## Privacy audit + runtime egress (TC-M-PRIV) — P0, audit, not automated, [AUDIT] — **CRITICAL, GATING**

Covers NFR-2 (the gating concern). **Ship-blocker.** Static reinforcement: TC-230 (no device-location/GPS
API; province lat/long is static reference data) + TC-231 (tile requests carry no user data). These do
**NOT** replace the audit. This is the most location-suggestive surface the product has ever shipped — the
audit must confirm it adds **zero** tracking.

Steps (run `/privacy-audit`, i.e. `privacy-guardian`, over the slice **and** inspect real egress):
1. Confirm the slice reads **no** device location / GPS / geolocation (no `geolocator`/`location`/
   CoreLocation/geocoding/location platform channel) and visualizes **only** aggregate idle *duration*
   mapped to route *distance* plus **static province reference lat/long**.
2. Confirm province lat/long is **static app-supplied** reference data, **never** the user's position; no
   timestamped per-event or per-location trail is emitted.
3. **Runtime egress inspection:** with a network monitor running, exercise the map (load tiles inline +
   full-screen, pan/zoom) → confirm the **only** outbound traffic is anonymous OSM tile GETs keyed by
   `{z}/{x}/{y}` with a static user-agent — **no** identifier, location, idle/segment data, account/session
   token, or any other payload leaves the machine.
4. Confirm the new `flutter_map`/OSM dependency adds **no** capability to read input / screen / clipboard /
   files beyond fetching public tiles, and that no other path goes to the network.

Expect: **no** API or dependency adds a user-data tracking surface; tile requests are data-free; the audit
**passes**. A contradiction **fails NFR-2 and blocks ship** regardless of every other pass. Re-run on any
change to the slice's source or its dependency set.

- Audit verdict (no per-OS split — source-level): Pass [ ]  Fail [ ]  Blocked [ ]
- Runtime egress verdict (per OS exercised): macOS Pass [ ]  Fail [ ]  Blocked [ ]   Windows Pass [ ]  Fail [ ]  Blocked [ ]
- Auditor / date: `__________`

---

## Deferred — Windows on-device verification

By decision (precedent: `mini-window` NFR-9, `activity-detection`, `journey-view` / `journey-scene-v2` fps),
the Windows **runtime** legs are **DEFERRED — required before any Windows release**, while the Windows
behaviour + parity are authored, code-reviewed, and privacy-audited **now** on the fake/static paths. The
deferred Windows legs are the "Windows" rows above:

- [ ] TC-M1 (Windows) — real OSM tiles + attribution — **DEFERRED**
- [ ] TC-M2 (Windows) — real offline fallback; tab never breaks — **DEFERRED**
- [ ] TC-M4 (Windows / Narrator) — screen-reader announces controls — **DEFERRED**
- [ ] TC-M-NF1 (Windows) — ≥30fps incl. transition + max segments + live tiles — **DEFERRED**
- [ ] TC-M-PRIV (Windows runtime egress) — only anonymous tile GETs leave the machine — **DEFERRED**

Record the Windows verdicts here when the on-device Windows pass is performed before a Windows release.

---

## Automated companions (run before/with the manual pass)

From `src/focus_journey/` (Flutter is fvm-pinned to 3.38.10 — always prefix `fvm`):

```bash
# Deterministic unit/widget/golden cases (no device, no network):
#   distance→polyline mapping (TC-201..208), geography integrity (TC-209/210),
#   marker-via-route-progress (TC-211/212), zero-idle (TC-213), current-route-only (TC-214),
#   cause cue (TC-216/225), overlay states (TC-217), tiles-via-fake-provider + attribution (TC-218),
#   offline fallback branches (TC-219), inline overlay + no Map tab (TC-220/221),
#   tap→full-screen same window + dismiss (TC-222/223), red z-order (TC-224),
#   pure-visualizer static + runtime (TC-227/228), hot-path guard (TC-229),
#   no-location-API + tile-URL-data-free (TC-230/231), semantics + keyboard (TC-232).
fvm flutter test test/

# Integration: Bloc↔overlay wiring, restart restoration, no-write guards (needs a device target; fake tile path).
fvm flutter test integration_test/ -d macos --dart-define=mock-activity=true
fvm flutter test integration_test/ -d windows --dart-define=mock-activity=true
```

Note: `integration_test` files do NOT run under plain `fvm flutter test` (no device); they need
`-d macos` / `-d windows`. The deterministic unit/widget/golden tests under `src/focus_journey/test/` run
under plain `fvm flutter test`. Confirm the exact fake-tile-provider injection seam and any mock flag names
against the implemented DI (follow the existing `mock-activity` / `mock-window` convention).
