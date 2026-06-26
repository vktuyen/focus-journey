# Manual run checklist — mini-window

Per-OS, human-driven verification of the `mini-window` cases that **cannot** be a deterministic Dart
unit/widget/integration test because they need a **real OS window** (real always-on-top stacking over a
different focused app, frameless drag, dock hide, a real menu-bar/tray icon and menu), a **real on-device
performance measurement**, or are a **privacy audit**. Follow this during `/execute-tests` and record the
verdict per case **per OS**.

- Authoritative scenarios: [mini-window.md](mini-window.md) (TC-001..TC-026 + the TC-M* legs below).
- Coverage matrix + layer reality: [specs/mini-window/test-plan.md](../../specs/mini-window/test-plan.md).
- Decision driving the spike-gate triad: [ADR-0003](../../docs/architecture/decisions/0003-mini-window-single-window-two-mode.md).
- Automated companions live under `src/focus_journey/test/` (widget) and
  `src/focus_journey/integration_test/` (e2e) against the **mock window/tray path** — see "Automated
  companions" below.

## How this maps to automation

| TC (this checklist) | Verification here | Automated companion (mock path) |
|----|-------------------|---------------------|
| TC-M1 | **Manual [REAL-OS]** — frameless body drag → reposition (macOS spike-gate (a)) | geometry persistence/restore + clamp: TC-019-POS / TC-019-CLAMP (mock window) |
| TC-M2 | **Manual [REAL-OS]** — PiP stays above a **different focused app** (macOS spike-gate (b)) | enter-compact transition model: TC-006 (mock window) |
| TC-M2-AOT | **Manual [REAL-OS]** — always-on-top off/on changes real stacking order (P2) | `alwaysOnTop` flag + recorded call: TC-014-AOT (mock window) |
| TC-M3 | **Manual [REAL-OS]** — real close-intercept hides + tray icon updates + menu actions work | close-to-tray model + tray model + menu actions: TC-014 / TC-011 / TC-012 / TC-018 (mock) |
| TC-M4 | **Manual [REAL-OS]** — tray menu keyboard / screen-reader reachable (NFR-6 real leg) | readout-text-in-semantics half: TC-021 leg (a) (widget) |
| TC-M-NF2 | **Manual / device [DEFERRED]** — sustained ~60 fps / no added jank with PiP + main (NFR-2) | unit-level no-jank-on-toggle within TC-003 |
| TC-M-PRIV | **Manual privacy audit** — `/privacy-audit` zero-new-surface release gate (NFR-4 / NFR-5) | static reinforcement only: TC-010 / TC-023 / TC-025 — does NOT replace the audit |
| **Windows runtime legs** | **DEFERRED — required before any Windows release** (NFR-9) | parity authored + reviewed now: TC-023 (static) |

> All other TCs (TC-001..TC-005, TC-007, TC-008, TC-009, TC-010, TC-013, TC-013-STATUS, TC-015, TC-016,
> TC-017, TC-019-POS, TC-019-CLAMP, TC-020, TC-021, TC-021-RM, TC-022, TC-023, TC-024, TC-025, TC-026) are
> **automated** against the mock window/tray path and are **NOT** in this checklist.

## The macOS spike-gate triad (ADR-0003 — run BEFORE `/implement` proceeds)

ADR-0003 requires proving the macOS triad on **one real window** with the **real** backend (the mock path
cannot prove OS stacking) before committing to implementation: **(a)** `startDragging` works after
`setAsFrameless` / hidden title bar (→ **TC-M1**); **(b)** the window stays **above a different focused
app** (→ **TC-M2**); **(c)** close-button intercept (`setPreventClose` + `hide()`) keeps the process alive
with the tray still updating (→ **TC-M3**). Record the spike verdict here; a Fail on any leg gates
`/implement`.

## Conventions / tolerance

- **Build the REAL backend, NOT the mock.** Run a real per-OS build (do **not** pass the
  `mock-window` / `--mock-activity` flags for the real-OS legs — the mock never touches the OS window or
  tray and would invalidate every case here). For driving journey state during the manual run, use the
  **mock activity source** so you can deterministically flip active/idle, while keeping the **real** window
  + tray backend. (Real activity capture is separately covered by `activity-detection`.)
- **No automated proxy for the real-OS side.** The mock window/tray fakes prove the controller logic and
  the resulting state model. They do **not** prove the OS actually floated the window above another app,
  that the frameless body dragged, that the dock hid the main window, or that a real tray icon/menu
  rendered and responded — that is exactly what this checklist verifies once per release per OS.
- **Offline-verifiable (privacy).** During TC-M-PRIV / the runs, confirm **no** network egress from the
  app (Little Snitch / `nettop` on macOS, Resource Monitor on Windows). Any outbound connection is a
  **Fail** for the privacy/no-network promise.
- **fps measurement (TC-M-NF2).** Use Flutter DevTools / the performance overlay / `traceAction`
  frame-timing on-device; manual spot-check acceptable where automated frame-timing is impractical —
  record device + OS.

## Per-OS preconditions

- [ ] Build/run a **real** per-OS build (macOS `.app`, Windows `.exe`) with the **real** window + tray
      backend (NOT the mock-window path). Use the mock **activity** source to drive state.
- [ ] A **second application** open and focusable (e.g. an IDE, browser, or full-screen app) to test
      always-on-top stacking over a *different focused app* (TC-M2).
- [ ] OS tray / menu-bar visible and the app's tray icon permitted to appear (macOS menu bar not hiding
      items; Windows tray overflow checked). If the OS hides the icon globally, record the affected leg as
      **Blocked**, not Fail.
- [ ] For a11y (TC-M4): VoiceOver (macOS) / Narrator (Windows) available, and keyboard menu navigation
      enabled per-OS.
- [ ] Note the OS version tested (record below).

OS versions under test — macOS: `macOS 25.5.0 (Darwin)` — re-verified 2026-06-24   Windows: `__________`

---

## Cases

Legend per cell: `[ ]` Pass `[ ]` Fail `[ ]` Blocked (check exactly one per OS).

### TC-M1 — Frameless PiP body drags to a new position (macOS spike-gate (a)) (P0, [REAL-OS])
Covers AC-6 (frameless drag) / AC-8 (real drag that produces the persisted position). Automated mock leg:
TC-019-POS / TC-019-CLAMP (geometry persistence + clamp).

Steps:
1. From full mode, invoke **Enter compact / PiP**. Confirm the compact view has **no OS title bar / frame**.
2. Click-drag the **body** of the compact view to a new on-screen position.
3. Quit (tray → Quit) and relaunch.

Expect: the frameless body **drags** the window (no title bar needed), and after relaunch the PiP reopens
at the **last dragged position** (size unchanged — fixed compact size). An off-screen drag near a screen
edge that is then unplugged should clamp back on restore (cross-check the automated TC-019-CLAMP).

> NOTE (2026-06-24): the compact PiP now carries an **expand / restore control** (top-right
> `Icons.open_in_full` button — "Back to full window") layered ABOVE the body drag region. On the real
> macOS run, dragging the BODY (away from the top-right corner) still moves the frameless window
> (verified: window moved by the exact drag delta), while a tap on the corner control restores full and
> does NOT initiate a window-move. See TC-M3 for the verified expand-from-compact result.

- macOS: Pass [x] (body drag moves frameless window, verified 2026-06-24)  Fail [ ]  Blocked [ ]
- Windows (DEFERRED — required before any Windows release): Pass [ ]  Fail [ ]  Blocked [ ]

### TC-M2 — PiP stays above a DIFFERENT focused application (macOS spike-gate (b)) (P0, [REAL-OS])
Covers AC-6 (always-on-top over other apps — the spec's headline "floats above a different focused app").
Automated mock leg: TC-006 (enter-compact transition model).

Steps:
1. Enter compact mode; position the PiP in a corner.
2. Open and **focus a different application** (IDE / browser / document) over that corner; type into it.
3. Optionally make the other app full-screen / occupy the Space.

Expect: the compact PiP **remains visible on top of** the focused other app — it is not covered. With the
mock activity source flipping `active`, the compact road **scrolls** while you work in the other app and
**parks** when you flip to `idle`. (macOS `NSWindow` level / Spaces vs full-screen apps is the finicky part
ADR-0003 calls out — record carefully.)

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (DEFERRED — required before any Windows release): Pass [ ]  Fail [ ]  Blocked [ ]

### TC-M2-AOT — Always-on-top OFF lets a focused app cover the PiP; ON restores floating (P2, [REAL-OS])
Covers AC-7 (P2 toggle — real stacking effect). Automated mock leg: TC-014-AOT (`alwaysOnTop` flag + call).

Steps:
1. In compact mode (always-on-top ON by default), turn the always-on-top toggle **OFF**.
2. Focus a different app over the PiP → it **may now cover** the PiP.
3. Turn the toggle **ON** again → the PiP returns to floating above others.

Expect: stacking order observably follows the toggle. (P2 — not required to ship; skip if the toggle is
not implemented this slice and mark **Blocked — not implemented (P2)**.)

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (DEFERRED): Pass [ ]  Fail [ ]  Blocked [ ]

### TC-M3 — Real close-intercept hides to tray, keeps tracking, tray icon updates + menu actions work (macOS spike-gate (c)) (P0, [REAL-OS])
Covers AC-11 / AC-12 / AC-15 / AC-16 / AC-18 real-OS legs. Automated mock legs: TC-011 / TC-012 / TC-014 /
TC-016 / TC-018.

Steps:
1. With the app tracking (mock activity = `active`), click the main window's **close button**.
2. Confirm the main window **hides** (not quits) and the **menu-bar / tray icon remains**. Confirm the PiP
   is **not** auto-shown (neither window visible).
3. Leave it running a while with mock `active`; confirm tracking **keeps accruing** (distance advances —
   re-open via Show app and check the counter moved).
4. Flip the mock activity to `idle`/`active` and confirm the **tray icon variant / tooltip** changes to
   reflect state (active vs idle/paused).
5. Open the tray menu; invoke **Show app** (main restores, continuous state, no reset); enter compact via
   **Enter compact / PiP**; finally **Quit** and confirm the process **fully exits** (and that the close
   button alone never fully exited it).

Expect: close = hide-to-tray (process alive, tracking continues, PiP not auto-shown); tray icon reflects
live state; all three menu actions perform their effect; **Quit** is the only full-exit path; on Quit the
latest state is persisted (relaunch shows the accrued distance — cross-check TC-017).

> RE-VERIFIED 2026-06-24 (real macOS .app, real window+tray backend, mock activity) — three regressions
> (two found by Kevin, plus the close→hide-to-tray one found during this run and approved for fix) were
> fixed and re-tested end-to-end via synthetic HID events + keyboard menu navigation against the running
> app:
>
> - **Menu-bar icon → menu opens AND item clicks fire (was BROKEN).** Root cause: the tray context menu was
>   being rebuilt on EVERY journey tick (the live "X.X km" status line was a menu item). `tray_manager`'s
>   `setContextMenu` regenerates fresh menu-item ids each call, while the natively-displayed menu kept its
>   build-time ids, so the Dart click router (`Menu.getMenuItemById(id)`) could no longer resolve the
>   clicked id and `onTrayMenuItemClick` silently no-op'd. FIX: the menu is now rebuilt ONLY on a structure
>   change (`init` / `setMode`); the live distance readout moved to the tooltip. Verified the menu now
>   builds exactly once at launch and item ids stay stable.
> - **Show app** (from compact) → restores the FULL framed window (900x700). Verified: `onTrayMenuItemClick
>   key=show_app` → action stream → `showApp()` → `exitFull()`; window observed at 900x700.
> - **Enter compact / PiP** → window collapses to the fixed compact size. Verified: window observed at
>   280x180; menu then correctly rebuilt with "Enter compact" disabled in compact mode.
> - **NEW expand control in the compact PiP** (BUG-1): with no in-PiP control the user was stranded in
>   compact. A top-right `Icons.open_in_full` button ("Back to full window") now restores full. Verified:
>   a click on the corner control returned the window from 280x180 to 900x700; the body drag (center) still
>   moved the frameless window, so the control is NOT swallowed by the drag region.
> - **Quit** → process fully exits (verified: `key=quit` → `TrayAction.quit` → process gone) and is the
>   only full-exit path.
>
> - **Close button → hide-to-tray, process stays alive, tracking continues (was a 3rd regression; now
>   FIXED + verified).** On the real run the close (red traffic-light) button had been TERMINATING the
>   process instead of hiding. Root cause was NOT the engine's merged platform/UI thread (that hypothesis
>   was tested and DISPROVEN — disabling it changed nothing) and NOT the Dart intercept (instrumentation
>   confirmed `setPreventClose(true)` set, `onWindowClose` fired, `isPreventClose()`==true, `hideToTray()`
>   /`windowManager.hide()` ran). The cause was `AppDelegate.applicationShouldTerminateAfterLastWindowClosed`
>   returning `true` in `macos/Runner/AppDelegate.swift`: once `hide()` left no visible window, macOS
>   terminated the app. FIX: return `false` (a hide-to-tray app must survive its window being closed/hidden).
>   Verified end-to-end with merged-thread mode at its DEFAULT (no Info.plist change needed):
>   - Click close → window **hides** (windows count 0), **process stays ALIVE**, **tray icon remains** (PiP
>     not auto-shown).
>   - **Tracking keeps accruing while hidden** (mock active): the tray tooltip distance advanced
>     3.4 → 4.1 → 4.4 km, then later 7.4 → 7.7 km, while the window was hidden.
>   - **Tray "Show app"** restored the full window (900x700) from the hidden state.
>   - **Tray "Quit"** (even from the hidden state) **fully exits** the process — still the only tray
>     full-exit path. The standard macOS app-menu "Quit focus_journey" / Cmd-Q also still fully exits.
>   - Re-confirmed (no regression from this change): tray Enter compact → 280x180; PiP expand control →
>     900x700; the Flame scene renders/animates (distance kept incrementing) with no exceptions in the log.

- macOS: Pass [x] (close→hide-to-tray + keeps-tracking; tray Show app / Enter compact / Quit; expand-from-compact — all verified 2026-06-24)  Fail [ ]  Blocked [ ]
- Windows (DEFERRED — required before any Windows release): Pass [ ]  Fail [ ]  Blocked [ ]

> PRE-EXISTING OBSERVATION (not introduced by this fix, flagged for awareness): the macOS app-menu "Quit" /
> Cmd-Q calls `NSApp.terminate` directly and does NOT route through the slice's `WindowModeController.quit()`,
> so the `onBeforeQuit` flush hook (AC-16) runs only on the **tray** Quit, not on Cmd-Q. This was true before
> this change (Cmd-Q always bypassed the tray-Quit flush) and is unchanged by it.

### TC-M4 — Tray menu actions are keyboard / screen-reader reachable (NFR-6 real leg) (P1, [REAL-OS])
Covers NFR-6 (tray-menu a11y real leg). Automated mock leg: TC-021 (readout-text-in-semantics half).

Steps:
1. With a screen reader on (VoiceOver / Narrator), open the menu-bar / tray menu via the per-OS keyboard
   convention.
2. Navigate to **Show app**, **Enter compact / PiP**, **Quit** by keyboard; activate one by keyboard.
3. With the compact view visible, confirm the screen reader announces the distance + active/idle **readout
   text** (not silence — it must be real text, per TC-021 leg a).

Expect: every tray menu item is reachable and operable by keyboard/screen reader per OS conventions, and
the PiP readout is announced as text.

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (DEFERRED): Pass [ ]  Fail [ ]  Blocked [ ]

### TC-M-NF2 — Sustained smooth compact scene, no added jank (NFR-2) (P1, device, [DEFERRED])
Covers NFR-2. Unit-level no-jank-on-toggle is asserted within TC-003.

Steps:
1. Enter compact mode with mock `active`; run a sustained window while also rendering the main scene where
   applicable, under representative load.
2. Capture frame build/raster times (DevTools / performance overlay / `traceAction`).
3. Toggle mock `active ↔ idle` repeatedly; watch for a frame-time spike at the transition.

Expect: the compact scene holds ~60 fps steady-state with a ≥30 fps floor under load, and the
active↔idle toggle introduces no visible stutter / dropped-frame spike. Record device + OS. (On-device fps
deferral mirrors `journey-view`'s perf NFR.)

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (DEFERRED — required before any Windows release): Pass [ ]  Fail [ ]  Blocked [ ]

---

## Privacy audit (TC-M-PRIV) — P0, audit, not automated

Covers NFR-4 (headline) + NFR-5. **Ship-blocker.** Static reinforcement: TC-010 (PiP reads only Bloc
state, no OS-user signal), TC-023 (parity / interface shape), TC-025 (dependency capability). These do
**NOT** replace the audit.

Steps (run `/privacy-audit`, i.e. `privacy-guardian`, over the slice):
1. Confirm all mini-window + tray code (Dart + macOS/Windows backends + mock) touches **only the app's own
   window** (geometry, visibility, always-on-top, frameless drag) and **a status icon/menu** — and reads
   **NONE** of: keystrokes / key contents, screen/display contents, clipboard, files, mouse-position
   history/coordinates, or **other apps'** window titles.
2. Confirm the PiP consumes **only** the journey Bloc's `state` / `mode` / `distanceKm` and makes no
   `ActivityPlugin` / `getSystemIdleSeconds()` / `isScreenLocked()` / idle-lock platform-channel call.
3. Confirm the new deps (`window_manager`, `tray_manager`, transitive `screen_retriever`, native libs)
   introduce **no** capability to capture input content / screen / clipboard / files / network / other
   apps' window titles (`screen_retriever` cleared as transitive in activity-detection — display geometry
   only). Any disqualifying dep is rejected.
4. Confirm no network call on any path (fully local/offline) — verify offline as above.

Expect: **no** API or dependency adds a new user-data surface; the audit **passes**. A contradiction
**fails this NFR and blocks ship** regardless of every other pass. Re-run on any change to the slice's
source or its dependency set.

- Audit verdict (no per-OS split — source-level): Pass [ ]  Fail [ ]  Blocked [ ]
- Auditor / date: `__________`

---

## Deferred — Windows on-device verification (NFR-9)

By decision (precedent: `activity-detection` L3, `journey-view` fps), the Windows **runtime** legs are
**DEFERRED — required before any Windows release**, while the Windows backend + parity are authored,
code-reviewed, and privacy-audited **now** (automated/static TC-023). The deferred Windows legs are the
"Windows" rows above:

- [ ] TC-M1 (Windows) — frameless drag + position restore — **DEFERRED**
- [ ] TC-M2 (Windows) — system-tray PiP stays above a focused app — **DEFERRED**
- [ ] TC-M2-AOT (Windows) — always-on-top toggle stacking (P2) — **DEFERRED**
- [ ] TC-M3 (Windows) — close-to-tray keeps tracking + system-tray icon/menu — **DEFERRED**
- [ ] TC-M4 (Windows) — tray menu keyboard/screen-reader reachable — **DEFERRED**
- [ ] TC-M-NF2 (Windows) — sustained fps / no jank — **DEFERRED**

Record the Windows verdicts here when the on-device Windows pass is performed before a Windows release.

---

## Automated companions (run before/with the manual pass)

From `src/focus_journey/` (Flutter is fvm-pinned to 3.38.10 — always prefix `fvm`):

```bash
# Deterministic mock-path cases (no device): compact scene, transitions, tray model, geometry, clamp, NFR-1.
fvm flutter test test/

# Mock-window/tray transition + wiring + headline smoke (needs a device target; mock path, no real OS window).
fvm flutter test integration_test/ -d macos --dart-define=mock-window=true --dart-define=mock-activity=true
fvm flutter test integration_test/ -d windows --dart-define=mock-window=true --dart-define=mock-activity=true
```

Note: `integration_test` files do NOT run under plain `fvm flutter test` (no device); they need
`-d macos` / `-d windows`. The deterministic unit/widget tests under `src/focus_journey/test/` run under
plain `fvm flutter test`. The exact mock-path flag name (`mock-window`) is the convention analogous to
`--mock-activity`; confirm against the implemented DI seam (NFR-8 / TC-024).
