# Test cases: journey-reset

Spec: [specs/journey-reset/spec.md](../../specs/journey-reset/spec.md)
Depends on (shipped): [specs/route-planner-v2/spec.md](../../specs/route-planner-v2/spec.md) / ADR-0005 — the `active`/`completed`/`abandoned` route lifecycle, `routeStartOffset` over the never-reset engine `distanceKm`, abandon = new offset (no celebration) · [specs/journey-engine/spec.md](../../specs/journey-engine/spec.md) — the never-reset cumulative `distanceKm`, ticker, injected clock · [specs/local-stats/spec.md](../../specs/local-stats/spec.md) — `stats_history_v1`, streaks, badges · [specs/mini-window/spec.md](../../specs/mini-window/spec.md) — the two `mini_window` keys (compact-window position, hide-to-tray hint).
Sibling cases: [route-planner-v2.md](route-planner-v2.md) · [local-stats.md](local-stats.md) · [mini-window.md](mini-window.md)
Domain rules: [docs/domain/business-rules.md](../../docs/domain/business-rules.md) — BR-1, BR-6, BR-8 (the carve-out), BR-10

## Coverage note

`journey-reset` adds **two user-facing controls and one internal seam** and — critically — **no new
persistence technology, no new engine behaviour, and no new privacy surface** (it only *deletes* local
data). Its correctness is mostly *deterministic logic over a faked `shared_preferences`/JSON repository*:
(a) a single aggregating **reset seam** (`LocalDataResetService`, ADR open at build time) that clears
**every** persisted key and drives a **zero-state in-memory re-init**; (b) a **launch-gate decision** that
maps persisted route lifecycle → prompt / no prompt; and (c) **Start over** reusing the shipped ADR-0005
`abandoned` lifecycle. Almost all of this is unit/widget/integration-automatable against fakes; only the
real relaunch bootstrap, real screen-reader/keyboard, on-device instant-feel, and the privacy audit are
manual.

Per `docs/architecture/overview.md`, executable tests live **inside** the Flutter package:
- **Unit** (`src/focus_journey/test/.../domain|data/`) — the genuinely novel deterministic logic: the
  reset seam's **enumerated key set** (every key incl. both `mini_window` keys is in scope — AC-3) and its
  **key-list-drift guard**; the **zero-state re-init** contract (engine/ticker/Blocs reconstructed so no
  stale value re-persists — AC-4); the **launch-gate decision function** (`active` → prompt; fresh /
  completed / abandoned / post-reset → no prompt — AC-5/6/7); **Start over** stamping a fresh
  `routeStartOffset` over the never-reset cumulative via the ADR-0005 abandon path (AC-9) and touching
  **only** `route_plan_v1` (+ legacy) while lifetime keys are retained (AC-10); the Start-over-vs-Factory-
  reset **asymmetry** (AC-12).
- **Widget** (`src/focus_journey/test/.../presentation/`) — the **destructive confirmation dialog**
  (appears, labelled irreversible, visually distinct from Start over, no touch until confirm — AC-1),
  **safe cancel/dismiss** (AC-2), the launch **Resume vs Start over prompt** (shown for `active`, suppressed
  otherwise — AC-6/5/7), the in-product **asymmetry warning** on the Factory-reset dialog (AC-12), and the
  deterministic a11y surface (semantics + keyboard focus — NFR-3).
- **Integration** (`src/focus_journey/integration_test/`) — the **full wipe → every key gone + no
  re-persist** end-to-end over the faked repository (AC-3, AC-4), **reset → relaunch = onboarding** (AC-5),
  **Resume restores the exact position** (AC-8), the **Start over** round-trip (abandon → author → only
  route keys replaced, lifetime retained → reopen offers Resume on the *new* route — AC-9/10/11), and the
  paired **asymmetry** run (AC-12).
- **Manual / on-device / audit** (TC-M* below) — the **launch-gate bootstrap across a real kill/reopen**
  (TC-M-BOOT), NFR-1 **instant-feel** on macOS/Windows (TC-M-NF1), NFR-3 **real screen-reader + keyboard**
  (TC-M-A11Y), and the **gating** NFR-2 **privacy audit** that the feature only deletes and adds no read /
  network / dependency (TC-M-PRIV).

`tests/cases/` (this file) holds only the human-readable Given/When/Then; no executable test is placed under
the top-level `tests/` tree.

Layer → AC mapping:

| AC / NFR | What it asserts | Covering layer(s) | Cases |
| --- | --- | --- | --- |
| **AC-1** | Factory reset opens an explicit destructive confirmation, labelled irreversible + distinct from Start over; nothing touched pre-confirm | Widget | TC-701, TC-703, TC-722 |
| **AC-2** | Cancel/dismiss the confirmation → all data intact, app state unchanged | Widget + integration | TC-702, TC-702b |
| **AC-3** | Confirm wipes EVERY persisted key incl. both `mini_window` keys — enumerated + drift-guarded (critical) | Unit + integration | TC-704, TC-705, TC-707 |
| **AC-4** | Post-wipe zero-state in-memory re-init — no half-reset, no stale value re-persisted, no phantom journey rehydrated (honesty check) | Unit + integration | TC-706, TC-706b |
| **AC-5** | Post-reset launch = true first-run onboarding, zero stats/badges, window/tray at defaults, prompt suppressed | Integration + widget | TC-707, TC-708, TC-709 |
| **AC-6** | Reopen with an `active` route → Resume vs Start over prompt before entering the journey | Unit + widget | TC-710, TC-720 |
| **AC-7** | Reopen fresh / completed / abandoned / post-reset → no prompt, straight to onboarding/authoring | Unit + widget | TC-709, TC-711, TC-712, TC-713 |
| **AC-8** | Resume restores the identical prior position (route, vehicle, distance) — no loss/drift | Integration + unit | TC-714, TC-715 |
| **AC-9** | Start over abandons the current route via ADR-0005 (fresh offset over never-reset distance) → route authoring | Unit + integration | TC-716, TC-717 |
| **AC-10** | New route replaces ONLY `route_plan_v1` (+ legacy); stats/distance/streaks/badges/settings retained | Unit + integration | TC-718, TC-719 |
| **AC-11** | After Start over, reopen with the new route `active` → launch offers Resume on the NEW route | Integration | TC-720 |
| **AC-12** | Same start stats: Start over keeps cumulative, Factory reset clears it — asymmetry surfaced in-product (BR-8 carve-out) | Unit + widget + integration | TC-721, TC-722 |
| **NFR-1** | Wipe + re-init + launch-gate feel instant (no perceptible stall) | Static guard + **device** | TC-723 + TC-M-NF1 |
| **NFR-2** (CRITICAL gate) | Feature only DELETES local data — no new read, no network, no new input/screen/clipboard/file/location dependency; BR-1 intact | Static inspection + **audit** | TC-724 + TC-M-PRIV |
| **NFR-3** | Both dialogs keyboard-navigable + screen-reader reachable; destructive action clearly labelled + distinguished from Start over | Widget (semantics/keyboard) + **manual AT** | TC-703, TC-725 + TC-M-A11Y |

**Risky / under-covered areas (flagged for `test-script-author` and reviewers):**

1. **The launch-gate bootstrap across a REAL kill/reopen (AC-5/6/7/8/11).** The automated legs drive the
   gate against a *faked* repository within one process (TC-709..TC-713, TC-720). The honest end-to-end —
   quit the app process, reopen, and confirm the gate reads persisted state and routes correctly (active →
   prompt; post-reset → onboarding; new-route → Resume on new) — is the **manual bootstrap leg TC-M-BOOT**.
   This is the flow most likely to differ between the fake and a real `shared_preferences` file on disk.
2. **The no-stale-re-persist honesty check (AC-4) is the subtle one.** After the wipe, if the still-live
   engine/ticker/Blocs are *not* torn down and rebuilt to zero, the very next autosave silently
   re-persists a phantom journey / non-zero distance — a **half-reset that looks like a full reset until the
   next launch**. TC-706/TC-706b must capture the persisted state **after the wipe AND after the next
   autosave tick** and assert it is still empty/zero — not just immediately post-`clear()`. Easy to get
   wrong; assert the *next write*, not only the wipe.
3. **Factory-reset completeness / key-list drift (AC-3).** The wipe must clear **every** key, explicitly
   including the two `mini_window` keys (`compact-window position`, `hide-to-tray hint`) which live outside
   the journey/stats repos and are the most likely to be forgotten. TC-704 enumerates the full set; TC-705
   is a **drift guard** — any persisted key not registered with the reset seam is a bug (a new key added in
   a later wave must be added to the seam or the test fails). Keep this test coupled to the canonical key
   registry, not a hand-copied list.
4. **NFR-2 privacy is the gating concern but *inverted* here — the feature only DELETES.** Static
   inspection (TC-724) can assert no new read / network / input-screen-clipboard-file-location dependency is
   introduced, but the `/privacy-audit` PASS that "a wipe control adds no new surface and genuinely erases"
   is the **audit gate TC-M-PRIV**. A fail here **blocks ship**.
5. **On-device NFR legs (NFR-1 instant-feel, NFR-3 real screen-reader/keyboard).** The deterministic part is
   automatable (TC-723 bounded/in-memory guard; TC-725 Semantics + keyboard focus on both dialogs), but the
   real "no perceptible spinner on reset/reopen" and a real AT user operating both dialogs are manual
   (TC-M-NF1, TC-M-A11Y). Windows runtime legs are **DEFERRED — required before any Windows release**.

## Conventions used by these cases

- **Deterministic by construction for the automated layer.** The reset seam, the launch-gate decision, and
  Start over are exercised against the existing in-memory `shared_preferences`/JSON repository fake (a
  **write-recording** fake that exposes the full key/value map and every write attempt), a scriptable
  distance source exposing a **settable** cumulative `distanceKm`, and the injected clock/ticker. No case
  awaits real time, real disk, or real network.
- **Canonical persisted-key set (assert the set, not literal names).** The keys in scope for the full wipe
  are `app_settings_v1`, `journey_progress_v1`, `route_plan_v1`, legacy `route_selection_v1`,
  `stats_history_v1`, the earned-badges key, and the **two** `mini_window` keys (compact-window position,
  hide-to-tray hint). Cases key off "every registered key" plus an explicit call-out of the two
  `mini_window` keys and the legacy key (the ones most likely to slip). If the production key registry
  changes, the drift-guard case (TC-705) must move with it.
- **Reused upstream contracts (do NOT re-test here).** The ADR-0005 abandon math (new `routeStartOffset`
  over the never-reset cumulative, abandoned ≠ completed, no celebration), route authoring/review, the
  distance→position walk, streak qualification, and badge earning are owned and tested by
  `route-planner-v2` / `route-progress` / `local-stats`. These cases treat them as **given** and assert only
  what `journey-reset` adds: the wipe seam, the zero-state re-init, the launch gate, and that Start over
  *routes through* the shipped abandon path (not a parallel one) while keeping lifetime data.
- **The BR-8 carve-out.** BR-8 guarantees cumulative distance/streak/badges persist across *automatic*
  resets/restarts. A *user-initiated Factory reset* is the deliberate exception that clears them; *Start
  over* is **not** — it keeps them. AC-12 is the observable expression of exactly this asymmetry, and it
  must be **surfaced in-product** so the user is not surprised (TC-722).
- **Tolerances.** Distance / position equality within **±1e-6 km**. Persisted-state / snapshot comparisons
  are **structural / set equality** (AC-3, AC-4, AC-10). "Empty" after a wipe means the repository holds
  **no** in-scope key (not a key mapped to a zero-ish value).
- **Test layer.** Per `docs/architecture/overview.md`: unit/widget/golden under `src/focus_journey/test/`,
  integration under `src/focus_journey/integration_test/`, run with `fvm flutter test` /
  `fvm flutter test integration_test/ -d <os>`. TC-M* legs are **manual / on-device / audit**.

## Cases

### Factory reset — the destructive confirmation gate (AC-1, AC-2)

### Case: Opening Factory reset shows an explicit destructive confirmation and touches no data until confirm
**ID:** TC-701
**Priority:** P0
**Type:** happy-path
**Covers:** AC-1

Given the user is in the Settings tab with an active journey plus lifetime distance, streaks, and badges persisted
When they activate the **Factory reset** action
Then an explicit **destructive confirmation dialog** appears before anything is cleared, and **no** persisted key is touched at that point — the recording repository shows **zero** deletions/writes while the dialog is merely open (the wipe is gated strictly behind an affirmative confirm)

**Notes:** Widget test (`src/focus_journey/test/.../presentation/`) with the write-recording fake. Assert the dialog is shown on activation and that the repository received **zero** clear/write calls until confirm. The wipe itself is TC-704. Complements AC-2 (cancel path).

---

### Case: Cancelling the Factory reset confirmation leaves all local data intact and the app in its current state
**ID:** TC-702
**Priority:** P0
**Type:** negative
**Covers:** AC-2

Given the Factory reset confirmation dialog is open over an app with a full set of persisted data (settings, active journey, stats, streaks, badges, mini-window keys)
When the user chooses **Cancel**
Then the dialog closes, **every** persisted key remains byte-for-byte intact, the in-memory engine/ticker/Blocs are untouched (journey keeps running from the same position), and the app stays exactly where it was — cancel recorded **nothing**

**Notes:** Widget + integration test. Assert a before/after set-equality snapshot of the repository (unchanged) and **zero** clear/write calls across the open→cancel cycle. The destructive path must be reachable only via the affirmative action.

---

### Case: Dismissing the confirmation (Esc / tap-outside) is as safe as an explicit cancel
**ID:** TC-702b
**Priority:** P1
**Type:** edge
**Covers:** AC-2

Given the Factory reset confirmation dialog is open
When the user **dismisses** it without confirming — presses Esc, taps the scrim, or otherwise closes it non-affirmatively
Then it behaves identically to Cancel (TC-702): all local data intact, app state unchanged, zero writes — there is **no** dismissal path that partially or fully wipes

**Notes:** Widget test. Guards the easy bug of a barrier-dismiss or Esc being treated as confirm (or bypassing the guard). Assert every non-affirmative close is inert. Boundary complement to TC-702.

---

### Case: The Factory reset confirmation is labelled irreversible and is visually + textually distinct from Start over
**ID:** TC-703
**Priority:** P0
**Type:** edge
**Covers:** AC-1, NFR-3

Given the Factory reset confirmation dialog
When it is shown
Then it is **clearly labelled irreversible** (destructive wording — clears *all* local data / returns to first-run), its confirm action is visually distinguished as destructive (e.g. destructive styling, not the default/primary affordance), and it is unmistakably **distinct from the non-destructive Start over** flow — a user cannot confuse "wipe everything" with "keep my lifetime stats, just re-author the route"

**Notes:** Widget test. Assert the destructive labelling/styling and that the copy differentiates it from Start over. The in-product *asymmetry* call-out (that lifetime stats will be lost, unlike Start over) is TC-722; the real screen-reader judgement is TC-M-A11Y.

---

### Factory reset — completeness of the wipe (AC-3) & zero-state re-init (AC-4)

### Case: Confirming Factory reset clears EVERY persisted key, including both mini_window keys and the legacy key
**ID:** TC-704
**Priority:** P0
**Type:** happy-path
**Covers:** AC-3

Given a fully-populated repository — `app_settings_v1`, `journey_progress_v1`, `route_plan_v1`, legacy `route_selection_v1`, `stats_history_v1`, the earned-badges key, and **both** `mini_window` keys (compact-window position + hide-to-tray hint) all present
When the user confirms Factory reset
Then **every one** of those keys is gone from the repository afterward — the wipe is complete, not partial; explicitly assert the two `mini_window` keys (which live outside the journey/stats repos) and the legacy `route_selection_v1` are cleared, not just the obvious journey/stats keys

**Notes:** Integration test (`src/focus_journey/integration_test/`) over the faked repository. **The completeness assertion.** Enumerate the full in-scope key set and assert the post-wipe repository contains **none** of them. Call out the two `mini_window` keys + the legacy key by name so a reviewer sees them covered.

---

### Case: Key-list drift guard — the reset seam clears every registered key; an unregistered key fails the test
**ID:** TC-705
**Priority:** P0
**Type:** edge
**Covers:** AC-3

Given the canonical registry of persisted keys the app writes (the single aggregating reset seam / `LocalDataResetService`)
When the reset seam runs
Then it clears **every key in the registry** with **no** per-key omission, and the test is coupled to the registry such that **any newly-added persisted key that is not wired into the seam causes a failure** — guarding against a later wave silently adding a key that survives Factory reset

**Notes:** Unit test (`src/focus_journey/test/.../data/`). The **drift guard** for the "no half-reset" promise. Assert the seam iterates the canonical key set (not a hand-copied literal) and that a synthetic unregistered key is detectably not cleared / the registry is the single source of truth. Flag to the reviewer if the ADR lands on `prefs.clear()` vs per-repo `clear()` — a blunt `prefs.clear()` changes what this test asserts.

---

### Case: After the wipe the engine, ticker, and Blocs are reconstructed to zero — no stale value re-persists on the next save
**ID:** TC-706
**Priority:** P0
**Type:** edge
**Covers:** AC-4

Given a running app with a non-zero in-memory engine (cumulative distance, active journey, ticker running) that has just had Factory reset confirmed
When the app re-initialises and the **next autosave tick fires**
Then the in-memory engine/ticker/Blocs are already reconstructed to a **zero state**, so the next save writes **zero-state (or nothing)** — the repository does **not** get a phantom journey / non-zero distance re-persisted after the wipe (no half-reset that reappears on next launch)

**Notes:** Integration test. **The honesty check for AC-4.** Snapshot the repository **after the wipe AND after the next tick/autosave** and assert it is still empty / zero-state — asserting only immediately post-`clear()` would miss the re-persist bug. Mirrors the "assert the next write, not only the wipe" flag in the coverage note.

---

### Case: No phantom journey is rehydrated — a post-reset in-memory model reports zero, not the pre-reset values
**ID:** TC-706b
**Priority:** P0
**Type:** edge
**Covers:** AC-4

Given Factory reset has just completed in-process
When the freshly reconstructed engine/Bloc state is read (before any user action)
Then it reports **zero** cumulative distance, **no** active route, zero streak/badges, and default settings — the old in-memory instances are torn down and replaced, not merely detached, so nothing rehydrates the pre-reset journey

**Notes:** Unit/integration test. Complements TC-706 by asserting the **in-memory** side (TC-706 asserts the *persisted* side). Guards against holding a stale engine reference that keeps ticking after the wipe.

---

### Post-reset launch (AC-5) & the two mini_window keys → first-run defaults

### Case: The two mini_window keys are cleared so window position + hide-to-tray return to first-run defaults
**ID:** TC-707
**Priority:** P1
**Type:** edge
**Covers:** AC-3, AC-5

Given a customised compact-window position and a set hide-to-tray hint persisted in the two `mini_window` keys before Factory reset
When Factory reset is confirmed and the app re-initialises
Then both `mini_window` keys are gone and the window/tray behaviour falls back to **first-run defaults** (default window placement, default tray/hide behaviour) — the wipe reaches the window/tray state too, not only journey data

**Notes:** Integration test. The AC-5 window/tray half, keyed on the two `mini_window` keys from TC-704. Assert default placement/tray behaviour after reset rather than the pre-reset customisation.

---

### Case: After Factory reset, the next launch shows true first-run onboarding with zero prior stats
**ID:** TC-708
**Priority:** P0
**Type:** happy-path
**Covers:** AC-5

Given Factory reset has completed
When the app is next launched
Then it enters **true first-run onboarding** (choose vehicle, start point, end point) with **zero** prior stats/streaks/badges and window/tray at first-run defaults — indistinguishable from a fresh install

**Notes:** Integration test over the post-wipe repository. Assert the launch lands on onboarding/route-authoring (not a journey) and that stats/streaks/badges read zero. The real kill/reopen version is TC-M-BOOT.

---

### Case: Post-reset launch suppresses the Resume vs Start over prompt (no phantom active route)
**ID:** TC-709
**Priority:** P0
**Type:** edge
**Covers:** AC-5, AC-7

Given Factory reset has completed (no persisted route of any kind)
When the launch flow runs
Then the **Resume vs Start over prompt is not shown** — the gate sees no `active` route and goes straight to onboarding; the prompt must not appear on a wiped state

**Notes:** Unit (gate decision) + widget test. Ties AC-5's "prompt suppressed" to AC-7's "no active → no prompt." Assert the gate decision for the empty/post-reset state is "no prompt → onboarding."

---

### Launch gate — Resume vs Start over prompt (AC-6, AC-7)

### Case: Reopening with an active route shows the Resume vs Start over prompt before entering the journey
**ID:** TC-710
**Priority:** P0
**Type:** happy-path
**Covers:** AC-6

Given a persisted route in the `active` lifecycle state (a journey in progress) at launch
When the launch flow runs
Then a **Resume vs Start over prompt** is shown **before** the app enters the journey — the user is not dropped straight into the running journey nor into onboarding

**Notes:** Unit (gate decision `active` → prompt) + widget (prompt renders both options). Assert the prompt precedes journey entry. Pairs with TC-711/712/713 (the no-prompt states).

---

### Case: A fresh install shows no prompt and goes straight to onboarding
**ID:** TC-711
**Priority:** P0
**Type:** boundary
**Covers:** AC-7

Given a fresh install — no persisted route (and no other persisted data)
When the launch flow runs
Then **no** Resume/Start over prompt appears and the app goes directly to onboarding/route-authoring

**Notes:** Unit + widget test. The fresh-install lower boundary of the gate. Assert gate decision "no route → onboarding, no prompt."

---

### Case: Reopening with a completed route shows no prompt
**ID:** TC-712
**Priority:** P0
**Type:** edge
**Covers:** AC-7

Given a persisted route in the `completed` lifecycle state and **no** `active` route
When the launch flow runs
Then **no** prompt appears — a completed journey is not resumable, so the app proceeds to onboarding/route-authoring for a new route

**Notes:** Unit + widget test. One of the two non-`active` states AC-7 calls out. Assert the gate treats `completed` as "no prompt." Contrast with TC-710 (`active` → prompt).

---

### Case: Reopening with an abandoned route shows no prompt
**ID:** TC-713
**Priority:** P0
**Type:** edge
**Covers:** AC-7

Given a persisted route in the `abandoned` lifecycle state and **no** `active` route
When the launch flow runs
Then **no** prompt appears — an abandoned route (ADR-0005) is terminal and not resumable, so the app proceeds to onboarding/route-authoring

**Notes:** Unit + widget test. The second non-`active` state from AC-7. Assert the gate treats `abandoned` as "no prompt." Guards against an abandoned route being mistaken for a resumable one.

---

### Resume (AC-8)

### Case: Choosing Resume continues the journey from the identical prior position with no loss or drift
**ID:** TC-714
**Priority:** P0
**Type:** happy-path
**Covers:** AC-8

Given an in-progress journey persisted at a known point — route (authored list + `routeStartOffset` + `active` state), vehicle, and cumulative `distanceKm` giving a known `routeDistanceKm` and position
When the user reopens and chooses **Resume**
Then the journey continues from the **identical** prior position — same route, same vehicle, same `routeDistanceKm` and resolved position (within ±1e-6) — with **no** loss and **no** drift, and cumulative lifetime distance is unbroken

**Notes:** Integration test over the faked repository (restore mapping is also unit-testable). Assert the restored position equals the pre-reopen position for the same persisted state; leans on route-planner-v2's restore invariant (do not re-test the position walk, assert it is *reached* unchanged).

---

### Case: Resume does not double-count or drop the sleep/wake gap — position keys off persisted routeDistanceKm, not wall-clock
**ID:** TC-715
**Priority:** P1
**Type:** edge
**Covers:** AC-8

Given an in-progress journey persisted, then the app closed and reopened after a real-time gap (simulated via the injected clock)
When the user chooses Resume
Then the resumed position is derived from the **persisted `routeDistanceKm` / offset**, not from elapsed wall-clock — the closed interval accrues **no** distance (consistent with BR-5 sleep/wake), so Resume shows exactly where the user left off with no phantom forward jump

**Notes:** Integration test with a controlled clock. Guards the drift half of AC-8 across a real gap. Assert the resumed `routeDistanceKm` equals the persisted value regardless of the injected time gap.

---

### Start over (AC-9, AC-10) & Resume-on-new-route (AC-11)

### Case: Start over marks the current route abandoned via the ADR-0005 lifecycle and hands to route authoring
**ID:** TC-716
**Priority:** P0
**Type:** happy-path
**Covers:** AC-9

Given an in-progress `active` route and the engine at a non-zero cumulative `distanceKm = D`, existing lifetime stats/streaks/badges
When the user chooses **Start over** at the launch prompt
Then the current route is marked **`abandoned`** with a **fresh `routeStartOffset` stamped at D** over the never-reset engine distance (per ADR-0005 — abandon = new offset, distinct from completion, no celebration) and the user is handed to **route authoring** to pick a new vehicle/start/end

**Notes:** Unit (offset/lifecycle math) + integration (hand-off to authoring). Assert exactly one new offset == cumulative D and the old route transitions to `abandoned` (not `completed`, no celebration). Reuses route-planner-v2 abandon path — assert it is *used*, not reimplemented (TC-717).

---

### Case: Start over routes through the shipped abandon path — no parallel reset, engine cumulative never reset
**ID:** TC-717
**Priority:** P0
**Type:** edge
**Covers:** AC-9

Given the `journey-reset` Start over source and the shipped ADR-0005 abandon lifecycle
When Start over is exercised and inspected statically
Then Start over invokes the **existing** ADR-0005 abandon lifecycle (new `routeStartOffset` over the never-reset cumulative) rather than a **parallel** reset path, and the engine's lifetime cumulative `distanceKm` is **not** reset by Start over (no engine-reset call exists on this path)

**Notes:** Unit + static-inspection test. The reuse invariant from the spec's "reuse, don't reinvent" constraint. Assert cumulative `distanceKm` is identical before/after Start over and that Start over calls the shared abandon API (no rival offset-stamping/reset code in `journey-reset`).

---

### Case: Completing a Start over replaces ONLY the route keys; stats, distance, streaks, badges, and settings are retained
**ID:** TC-718
**Priority:** P0
**Type:** happy-path
**Covers:** AC-10

Given a Start over in progress with a snapshot of `stats_history_v1`, cumulative lifetime distance, streaks, earned badges, and `app_settings_v1` before authoring
When the user authors and confirms the **new** route
Then **only** `route_plan_v1` (and legacy `route_selection_v1`) is replaced, while `stats_history_v1`, cumulative lifetime distance, streaks, earned badges, and `app_settings_v1` are all **retained byte-for-byte unchanged**

**Notes:** Integration test over the faked repository. **The Start-over retention assertion.** Assert a before/after set-equality snapshot: the two route keys change; every lifetime/settings key is identical. Contrast with the Factory-reset completeness of TC-704.

---

### Case: Start over clears NO lifetime key — negative complement to the wipe
**ID:** TC-719
**Priority:** P0
**Type:** negative
**Covers:** AC-10, AC-12

Given a Start over performed with a full set of lifetime data present
When the abandon + authoring completes
Then **no** lifetime key is deleted — `stats_history_v1`, the earned-badges key, and cumulative distance persist through Start over — confirming Start over is emphatically **not** a wipe (the asymmetry against Factory reset)

**Notes:** Unit/integration test. The negative guard that Start over never accidentally invokes the wipe seam. Assert zero deletions of any lifetime key across a Start over. Pairs with TC-721 (the head-to-head asymmetry).

---

### Case: After a Start over, reopening with the new route active offers Resume on the NEW route
**ID:** TC-720
**Priority:** P1
**Type:** happy-path
**Covers:** AC-11, AC-6

Given a Start over completed so the newly authored route is now the `active` route
When the app is reopened and the launch flow runs
Then the Resume vs Start over prompt appears and **Resume applies to the new route** — resuming continues the new route from its own position, not the abandoned one

**Notes:** Integration test through Start over → reopen. Ties AC-11 to AC-6. Assert the gate sees the new `active` route and that Resume restores the new route (not the abandoned route's list/offset).

---

### Start-over-vs-Factory-reset asymmetry (AC-12, BR-8 carve-out)

### Case: From identical starting stats, Start over preserves cumulative values but Factory reset clears them
**ID:** TC-721
**Priority:** P0
**Type:** edge
**Covers:** AC-12

Given two runs from an **identical** starting state of lifetime stats/streaks/badges + cumulative distance
When run A performs a **Start over** and run B performs a **Factory reset**
Then run A's cumulative distance/streaks/badges **survive unchanged** while run B's are **cleared to zero** — the observable BR-8 carve-out asymmetry (automatic-style Start over keeps them; user-initiated Factory reset is the deliberate exception that wipes them)

**Notes:** Integration test — the paired head-to-head. Assert the same starting snapshot yields retained lifetime data after Start over and empty lifetime data after Factory reset. The single clearest expression of AC-12; the in-product surfacing is TC-722.

---

### Case: The asymmetry is surfaced in-product so the user is not surprised (Factory reset warns it wipes lifetime stats, unlike Start over)
**ID:** TC-722
**Priority:** P1
**Type:** edge
**Covers:** AC-12, AC-1

Given the Factory reset confirmation dialog and the Start over affordance
When each is presented to the user
Then the Factory reset confirmation **explicitly communicates that lifetime distance/streaks/badges will be lost** (the BR-8 carve-out), whereas Start over communicates that those are **kept** — the asymmetry is surfaced in-product, not hidden, so the user is not surprised by which control preserves progress

**Notes:** Widget test. Encodes the "documented + surfaced" half of AC-12 / the spec's BR-8 carve-out constraint. Assert the Factory-reset copy names the lifetime-data loss and that Start over's copy/labelling implies retention. If product finalises exact wording (open question in the spec), align the assertion to it. Real AT legibility is TC-M-A11Y.

---

### Non-functional

### Case: Wipe + in-memory re-init + launch-gate decision are bounded in-memory/local operations with no blocking I/O on the hot path
**ID:** TC-723
**Priority:** P1
**Type:** nfr
**Covers:** NFR-1

Given the reset seam, the in-memory re-init, and the launch-gate decision
When each is inspected and run against the fakes
Then the wipe is a bounded clear over a small known key set, the re-init reconstructs a zero-state engine/Bloc without a network/remote round-trip, and the gate decision is a small pure read of persisted lifecycle state — each completes effectively instantly with **no** blocking network/disk stall on the confirm or reopen path (the deterministic guard behind NFR-1's "feels instant")

**Notes:** Static inspection + micro-timing test (`src/focus_journey/test/`). The deterministic part of NFR-1; the real "no perceptible spinner on reset/reopen" on macOS/Windows is on-device only — TC-M-NF1. Assert no remote/network call on the reset or launch-gate path.

---

### Case: The feature only DELETES local data — it introduces no new read, no network, and no new input/screen/clipboard/file/location dependency
**ID:** TC-724
**Priority:** P0
**Type:** edge
**Covers:** NFR-2

Given all `journey-reset` source (the Settings Factory reset action, the reset seam, the launch gate, the Start over hand-off) and its dependency set
When inspected statically
Then the slice performs **only deletions of existing local data** and re-reads of already-persisted state — it adds **no** new read of system idle/keystrokes/screen/clipboard/files/GPS/location, **no** network surface, and **no** new dependency that reads any of those — leaving BR-1 intact and adding **no** cloud/backup/export of the cleared data

**Notes:** Static-inspection case (`src/focus_journey/test/`, grep over imports + manifest). The automatable subset of the gating NFR-2. Assert no new privacy-relevant API/dependency appears vs the pre-feature baseline and that the reset path makes zero network calls. The `/privacy-audit` PASS is the gate TC-M-PRIV.

---

### Case: Both dialogs are keyboard-reachable and screen-reader labelled, with the destructive action distinguished
**ID:** TC-725
**Priority:** P1
**Type:** edge
**Covers:** NFR-3

Given the **Factory reset confirmation dialog** and the launch **Resume vs Start over prompt**
When the widget tree's semantics and keyboard focus traversal are inspected
Then every interactive element on both dialogs is **keyboard-reachable** (focusable + activatable via Tab/Enter, with Esc/cancel where applicable — no mouse-only path) and carries **meaningful semantic labels** (confirm/cancel, Resume/Start over, and the destructive Factory reset action expose accessible names), and the **destructive Factory reset action is clearly labelled and distinguished** from the non-destructive Start over — not relying on colour/visual-only cues

**Notes:** Widget test (`src/focus_journey/test/.../presentation/`) asserting `Semantics` labels + keyboard focusability/activation on both dialogs, and that the destructive action is programmatically distinguishable. The deterministic part of NFR-3. The **real screen-reader announcement quality + full keyboard-only operation** is the manual AT leg TC-M-A11Y.

---

## Manual / on-device / audit legs (TC-M*)

These are the cases whose only honest verification is a **real relaunch**, an **on-device measurement**, a
**real screen reader/keyboard**, or the **gating privacy audit** — they cannot be a deterministic Dart test.
Run during `/execute-tests` and record the verdict **per OS** where applicable. `Windows` runtime legs are
**DEFERRED — required before any Windows release** (precedent: `route-planner-v2`, `map-experience`,
`mini-window`).

### TC-M-BOOT — Launch-gate bootstrap across a real kill/reopen (P0, device, [DEVICE])
Covers AC-5, AC-6, AC-7, AC-8, AC-11 (real relaunch leg). Automated companions: TC-708..TC-714, TC-720.

Steps (real desktop build; use the mock activity source only to reach a known route position):
1. Reach a known in-progress `active` route position, **quit the app process**, reopen → confirm the
   **Resume vs Start over prompt** appears and Resume restores the **exact** prior position (AC-6, AC-8).
2. From the prompt choose **Start over**, author + confirm a new route, quit, reopen → confirm the prompt
   offers **Resume on the NEW route** and the abandoned route is gone (AC-11).
3. Perform **Factory reset** in Settings, confirm, quit, reopen → confirm **true first-run onboarding**,
   zero stats/streaks/badges, window/tray at defaults, and **no prompt** (AC-5, AC-7).
4. Reach a `completed` and (separately) an `abandoned` route, quit, reopen → confirm **no prompt** in each
   (AC-7).

Expect: the gate reads the on-disk `shared_preferences` state correctly across a genuine process restart and
routes to prompt / onboarding exactly as the faked-repo automated legs predict. Record device + OS.

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (DEFERRED — required before any Windows release): Pass [ ]  Fail [ ]  Blocked [ ]

### TC-M-NF1 — Factory reset + reopen feel instant, no perceptible stall (P1, device, [DEVICE])
Covers NFR-1. Deterministic guard: TC-723.

Steps: confirm Factory reset on a fully-populated app and observe the reset→onboarding transition; separately
observe the launch-gate decision on reopen with an `active` route. Capture frame/latency during both.

Expect: no perceptible spinner/stall on the reset confirmation or on reopen — the wipe + re-init + gate
decision complete within a frame or two, feeling instant. Record device + OS.

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (DEFERRED — required before any Windows release): Pass [ ]  Fail [ ]  Blocked [ ]

### TC-M-A11Y — Both dialogs keyboard-operable + screen-reader labelled, destructive action clear (P1, [AT])
Covers NFR-3 (real-AT + keyboard leg). Automated leg: TC-725.

Steps (VoiceOver on macOS / Narrator on Windows, then keyboard-only):
1. With the screen reader on, open the **Factory reset** confirmation → confirm it is announced as
   **destructive/irreversible** and distinct from Start over, and confirm/cancel are announced + reachable
   by Tab, activatable by Enter, dismissable by Esc.
2. Trigger the launch **Resume vs Start over prompt** → confirm both options are announced with meaningful
   names and are keyboard-reachable/activatable.
3. Keyboard-only pass: operate both dialogs (confirm a reset, and choose Resume / Start over) using **only**
   Tab / Enter / Esc — no mouse.

Expect: a screen-reader + keyboard-only user can find, understand, and operate both dialogs, and can tell the
destructive Factory reset apart from the non-destructive Start over.

- macOS (VoiceOver + keyboard): Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (Narrator + keyboard, DEFERRED — required before any Windows release): Pass [ ]  Fail [ ]  Blocked [ ]

### TC-M-PRIV — Privacy audit: the feature only deletes and adds no new surface (P0, audit, [AUDIT]) — **CRITICAL, GATING**
Covers NFR-2 (the gating concern). **Ship-blocker.** Static reinforcement: TC-724.

Steps (run `/privacy-audit`, i.e. `privacy-guardian`, over the slice, and inspect real egress):
1. Confirm the Factory reset / reset seam / launch gate / Start over paths perform **only deletions** and
   re-reads of already-persisted local state — **no** new read of idle/keystroke/screen/clipboard/file/
   location, **no** new dependency adding any such surface (BR-1 intact).
2. **Runtime egress inspection:** with a network monitor running, perform Factory reset, Start over, Resume,
   and a relaunch → confirm **no** outbound request is attributable to this slice (no cloud/backup/export of
   the cleared data; the only permissible traffic is `map-experience`'s OSM tile GETs when the map is on
   screen).
3. Confirm the wipe **genuinely erases** — no residual copy of the cleared data is written elsewhere
   (no export, no backup file, no cache surviving the wipe).

Expect: the audit **passes** — a wipe control that adds no read/network/dependency and truly erases. A
contradiction **fails NFR-2 and blocks ship** regardless of every other pass. Re-run on any change to the
slice's source or dependency set.

- Audit verdict (source-level, no per-OS split): Pass [ ]  Fail [ ]  Blocked [ ]
- Runtime egress verdict (per OS): macOS Pass [ ]  Fail [ ]  Blocked [ ]   Windows Pass [ ]  Fail [ ]  Blocked [ ] (DEFERRED)
- Auditor / date: `__________`

---

## Coverage table (AC / NFR → covering case IDs)

| Item | Description | Covered by |
|---|---|---|
| AC-1 | Factory reset opens explicit destructive confirmation, distinct from Start over; nothing touched pre-confirm | TC-701, TC-703, TC-722 |
| AC-2 | Cancel/dismiss the confirmation → all data intact, app unchanged | TC-702, TC-702b |
| AC-3 | Confirm wipes EVERY persisted key incl. both `mini_window` keys + legacy key; drift-guarded | TC-704, TC-705, TC-707 |
| AC-4 | Post-wipe zero-state re-init — no half-reset, no stale re-persist, no phantom journey | TC-706, TC-706b |
| AC-5 | Post-reset launch = true first-run onboarding, zero stats, window/tray defaults, prompt suppressed | TC-707, TC-708, TC-709, TC-M-BOOT |
| AC-6 | Reopen with `active` route → Resume vs Start over prompt before journey | TC-710, TC-720, TC-M-BOOT |
| AC-7 | Reopen fresh / completed / abandoned / post-reset → no prompt → onboarding/authoring | TC-709, TC-711, TC-712, TC-713, TC-M-BOOT |
| AC-8 | Resume restores identical prior position — no loss/drift | TC-714, TC-715, TC-M-BOOT |
| AC-9 | Start over abandons current route via ADR-0005 (fresh offset over never-reset distance) → authoring | TC-716, TC-717 |
| AC-10 | New route replaces ONLY route keys; stats/distance/streaks/badges/settings retained | TC-718, TC-719 |
| AC-11 | After Start over, reopen with new route `active` → Resume on the NEW route | TC-720, TC-M-BOOT |
| AC-12 | Same start stats: Start over keeps cumulative, Factory reset clears them — asymmetry surfaced in-product | TC-719, TC-721, TC-722 |
| NFR-1 | Wipe + re-init + gate feel instant, no perceptible stall | TC-723 (deterministic), TC-M-NF1 (on-device) |
| NFR-2 (CRITICAL gate) | Feature only DELETES; no new read/network/dependency; BR-1 intact; genuinely erases | TC-724 (static), TC-M-PRIV (audit + runtime egress) |
| NFR-3 | Both dialogs keyboard-navigable + screen-reader reachable; destructive action distinguished | TC-703, TC-725 (deterministic), TC-M-A11Y (manual AT) |

Every AC (AC-1..AC-12) and every NFR (NFR-1..NFR-3) maps to at least one case. No AC is orphaned. The TC-M*
manual / on-device / audit legs are listed inline above (this feature has no separate companion checklist —
its manual surface is small: one bootstrap relaunch, one instant-feel, one AT, and the gating privacy audit).
