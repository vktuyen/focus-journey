# Test cases: activity-detection

Spec: [specs/activity-detection/spec.md](../../specs/activity-detection/spec.md)
Acceptance criteria: [specs/activity-detection/acceptance-criteria.md](../../specs/activity-detection/acceptance-criteria.md)

## Scope of these cases

These cases verify the **`ActivityPlugin` contract only**: `getSystemIdleSeconds()`,
`isScreenLocked()`, the deterministic mock source, the typed-failure contract, and the privacy
promise. They deliberately do NOT exercise active/idle judgment, the 5-minute threshold/grace,
pause/resume, distance, or UI — those belong to `journey-engine` and are tested there.

## Conventions used by these cases

- **Idle tolerance band:** where a case asserts that reported idle seconds match elapsed
  untouched wall-clock seconds, "within tolerance" means **±2 seconds** unless stated otherwise.
  This accounts for call latency, OS counter granularity, and the gap between the last real input
  and the read.
- **`isScreenLocked()` semantics:** `true` ONLY for an OS **session lock** (login/lock screen
  engaged). A display that is merely asleep / screen-saver-on but the session is **not locked**
  reports `false`. See TC-009.
- **Failure contract (AC-10):** on unavailable/denied OS API, the plugin **throws a typed
  `ActivityPluginException`** (surfaced as a `Future` error from the async methods); it does not
  return a sentinel/garbage value and does not crash the process. The error carries a reason that
  distinguishes "unavailable / denied" from a normal reading. The caller (`journey-engine`) owns
  the fallback policy.
- **Layer note:** "real backend" cases (TC-001..TC-008, TC-010..TC-011) require real OS
  input/idle/lock and are run **per-OS** as Manual or platform integration/e2e — they are NOT
  plain deterministic unit tests. The mock-source and contract-shape cases (TC-012..TC-016) ARE
  deterministic unit tests with no real timers/waits. Privacy cases (TC-017..TC-019) are verified
  by the `privacy-guardian` audit, not by an automated assertion.

## Cases

### Case: Idle seconds climb while machine is untouched — macOS
**ID:** TC-001
**Priority:** P0
**Type:** happy-path
**Covers:** AC-1

Given a macOS build wired to the **real** `ActivityPlugin` backend, with no real user input occurring
When `getSystemIdleSeconds()` is sampled at t0, then again after ~10s and ~20s of leaving the machine completely untouched
Then each successive value is **monotonically non-decreasing**, and each sampled value approximates the elapsed untouched wall-clock seconds since the last real input (within ±2s)

**Notes:** Manual / macOS integration run. Tester must not move mouse, touch trackpad, or press keys during the window. Run on at least one supported macOS version.

---

### Case: Idle seconds climb while machine is untouched — Windows
**ID:** TC-002
**Priority:** P0
**Type:** happy-path
**Covers:** AC-2

Given a Windows build wired to the **real** `ActivityPlugin` backend, with no real user input occurring
When `getSystemIdleSeconds()` is sampled at t0, then again after ~10s and ~20s of leaving the machine completely untouched
Then each successive value is **monotonically non-decreasing**, and each sampled value approximates the elapsed untouched wall-clock seconds since the last real input (within ±2s)

**Notes:** Manual / Windows integration run. Same no-input discipline as TC-001. Run on a supported Windows version.

---

### Case: Idle resets to ~0 on a real key press — macOS
**ID:** TC-003
**Priority:** P0
**Type:** happy-path
**Covers:** AC-3

Given a macOS build on the real backend where `getSystemIdleSeconds()` has climbed to a clearly non-zero value (e.g. ≥10s) after being untouched
When the user presses a key
Then the next `getSystemIdleSeconds()` call returns a value at or near **0** (within ±2s reflecting time since that input)

**Notes:** Manual / macOS. Repeat the assertion with a mouse-move and a mouse-click as the input (see TC-005) to confirm any input type resets the counter.

---

### Case: Idle resets to ~0 on a real key press — Windows
**ID:** TC-004
**Priority:** P0
**Type:** happy-path
**Covers:** AC-3

Given a Windows build on the real backend where `getSystemIdleSeconds()` has climbed to a clearly non-zero value (e.g. ≥10s) after being untouched
When the user presses a key
Then the next `getSystemIdleSeconds()` call returns a value at or near **0** (within ±2s)

**Notes:** Manual / Windows. AC-3 is "both OSes"; TC-003 + TC-004 jointly cover it.

---

### Case: Idle resets to ~0 on mouse movement and click
**ID:** TC-005
**Priority:** P1
**Type:** edge
**Covers:** AC-3

Given either OS on the real backend with `getSystemIdleSeconds()` climbed to ≥10s
When the user moves the mouse (without clicking), then separately performs a click
Then after each input the next `getSystemIdleSeconds()` call returns ~0 (within ±2s) — confirming mouse movement alone, not just clicks/keys, resets the aggregate idle counter

**Notes:** Manual, run per-OS. Guards against a backend that only counts keyboard/click events but ignores raw pointer movement.

---

### Case: Screen-lock reported true when locked, false when unlocked — macOS
**ID:** TC-006
**Priority:** P0
**Type:** happy-path
**Covers:** AC-4

Given a macOS build on the real backend with the session **unlocked**
When `isScreenLocked()` is called, then the session is locked and `isScreenLocked()` is called again, then unlocked and called once more
Then it returns `false` while unlocked, `true` while the session is locked, and `false` again after unlock — reflecting the current OS lock state at call time

**Notes:** Manual / macOS. Use Ctrl-Cmd-Q (or the menu) to lock; requires re-authentication to unlock, so plan the read sequence accordingly (e.g. read on a timer or via the mock-flagged dev harness that logs the value).

---

### Case: Workstation-lock reported true when locked, false when unlocked — Windows
**ID:** TC-007
**Priority:** P0
**Type:** happy-path
**Covers:** AC-5

Given a Windows build on the real backend with the workstation **unlocked**
When `isScreenLocked()` is called, then the workstation is locked (Win+L), then it is called again, then unlocked and called once more
Then it returns `false` while unlocked, `true` while locked, and `false` again after unlock — reflecting the current OS lock state at call time

**Notes:** Manual / Windows. As with TC-006, capture the locked-state read via a logging harness since the screen is occupied by the lock UI.

---

### Case: Lock state is read live at call time, not cached from startup
**ID:** TC-008
**Priority:** P1
**Type:** edge
**Covers:** AC-4, AC-5

Given a real backend on either OS, started while **unlocked**
When the session is locked and then `isScreenLocked()` is polled repeatedly across the lock→unlock transition
Then the returned boolean tracks the *current* state on every call (true during lock, false after unlock) and does not return a stale value frozen at app startup

**Notes:** Manual, per-OS. Guards a backend that reads lock state once at init instead of on each invocation.

---

### Case: Display asleep but session unlocked reports NOT locked
**ID:** TC-009
**Priority:** P1
**Type:** edge
**Covers:** AC-4, AC-5

Given a real backend on either OS with the session **unlocked** and "lock on sleep" disabled (or before the lock-after-sleep delay elapses)
When the display is put to sleep / the screensaver engages but no session lock occurs, and `isScreenLocked()` is called
Then it returns **`false`** — a sleeping/dimmed display that has not engaged the OS session lock is NOT "locked"

**Notes:** Manual, per-OS. Pins the resolved semantics: `isScreenLocked()` == OS session lock only. Ensure the OS setting "require password immediately after sleep" is OFF for this case, otherwise sleep auto-locks and the precondition can't hold.

---

### Case: Large idle value reported after a sleep/wake cycle
**ID:** TC-010
**Priority:** P1
**Type:** edge
**Covers:** AC-9

Given a real backend on either OS, with the machine put to sleep for a known duration (e.g. ≥2 minutes)
When the machine is woken and `getSystemIdleSeconds()` is called **before** any new input
Then it returns a **large** value (clearly not 0) consistent with the elapsed sleep duration, using the standard OS idle API with no dedicated sleep/wake handling code

**Notes:** Manual, per-OS. Assert "large / not 0" (the precise magnitude is OS-dependent); downstream `journey-engine` interprets it. The first input after wake should then reset it (covered by TC-003/TC-004 behaviour).

---

### Case: Same observable contract holds for the chosen implementation (package or custom plugin)
**ID:** TC-011
**Priority:** P1
**Type:** regression
**Covers:** AC-11

Given the spike has resolved to a concrete implementation (an existing pub.dev package OR a custom native plugin) behind the `ActivityPlugin` interface
When the real backend is exercised through the interface across the relevant scenarios (TC-001..TC-009, TC-010)
Then AC-1..AC-5, AC-9, and AC-10 hold **identically** — no scenario passes only because of a specific implementation, and swapping the implementation requires no change to calling code

**Notes:** Manual / per-OS regression checklist. Re-run TC-001..TC-010 + TC-014 against whichever implementation the spike selects. If the implementation changes later, this case must be re-run.

---

### Case: Mock returns exactly the caller-driven idle seconds
**ID:** TC-012
**Priority:** P0
**Type:** happy-path
**Covers:** AC-6

Given the mock `ActivityPlugin` source is selected via direct injection
When a caller sets idle-seconds to 0, then 42, then 9000, and calls `getSystemIdleSeconds()` after each set
Then the plugin returns exactly **0**, **42**, then **9000** — the value the caller drove, with no real OS access, no real timer, and no real wait

**Notes:** Deterministic unit test (`src/test/`). No `await Future.delayed`, no wall-clock dependency. This is the foundation that lets `journey-engine` tests drive any signal synchronously.

---

### Case: Mock returns exactly the caller-driven lock state
**ID:** TC-013
**Priority:** P0
**Type:** happy-path
**Covers:** AC-6

Given the mock `ActivityPlugin` source is selected via direct injection
When a caller sets the lock value to `true`, then `false`, calling `isScreenLocked()` after each set
Then the plugin returns exactly `true`, then `false` — no real OS access, no timer, no wait

**Notes:** Deterministic unit test (`src/test/`).

---

### Case: Real and mock backends are interchangeable without changing caller code
**ID:** TC-014
**Priority:** P0
**Type:** happy-path
**Covers:** AC-6, AC-11

Given a consumer that depends only on the `ActivityPlugin` interface and receives its instance via dependency injection
When the consumer is constructed once with the mock source and once with the real backend, using the **same** calling code
Then both compile and run against the identical interface (`getSystemIdleSeconds()` / `isScreenLocked()` signatures), and the consumer needs no source change to swap them — confirming the injection seam

**Notes:** Mostly a deterministic unit/compile-time test for the seam (`src/test/`); the real-backend half is exercised on-device. Guards the "swap requires no change to calling code" clause of AC-6 and the portability clause of AC-11.

---

### Case: `--mock-activity` flag selects the mock source
**ID:** TC-015
**Priority:** P1
**Type:** happy-path
**Covers:** AC-6

Given the app is launched with the `--mock-activity` flag
When the dependency-injection container resolves `ActivityPlugin`
Then the **mock source** is bound (not the native backend), so dev/UI runs use deterministic driven values and never touch real OS idle/lock APIs

**Notes:** Integration-level test of the flag→DI wiring (`src/test/` or a small harness). Without the flag, the real backend resolves on a supported desktop platform.

---

### Case: Plugin surfaces a typed error when the OS idle API is unavailable
**ID:** TC-016
**Priority:** P1
**Type:** negative
**Covers:** AC-10

Given a backend (or a fault-injecting test double over the platform channel) in which the underlying OS idle API is unavailable or returns an error
When `getSystemIdleSeconds()` is called
Then the call completes with a **`Future` error of type `ActivityPluginException`** (not a thrown-and-crash, not a silently wrong number), and the error's reason identifies the condition as **unavailable/denied** rather than a normal reading

**Notes:** Deterministic unit test using a faked platform channel / fault-injected backend (`src/test/`). The caller (`journey-engine`) owns the fallback — these cases assert only that the error is raised and typed, not what the caller does with it.

---

### Case: Plugin surfaces a typed error when lock-state read is unavailable/denied
**ID:** TC-017
**Priority:** P1
**Type:** negative
**Covers:** AC-10

Given a backend / fault-injecting double in which the lock-state OS API is unavailable or permission is denied
When `isScreenLocked()` is called
Then the call completes with a **`Future` error of type `ActivityPluginException`** whose reason distinguishes unavailable/denied from a normal reading, without crashing the process

**Notes:** Deterministic unit test (`src/test/`). On macOS there may be **no "denied" path** for these APIs (idle/lock need no permission) — the denied branch is then untestable on macOS and that is acceptable; still test the "unavailable / channel-error" branch. Document the per-OS applicability when authoring scripts.

---

### Case: Privacy audit — code reads only aggregate idle + lock
**ID:** TC-018
**Priority:** P0
**Type:** regression
**Covers:** AC-7

Given all `ActivityPlugin` code — Dart interface, native macOS (Swift) + Windows (C++/Win32) backends, and the mock source
When `privacy-guardian` runs `/privacy-audit` and inspects what the code reads, buffers, logs, or persists
Then it confirms the code accesses ONLY an aggregate system-idle duration and the screen-lock boolean, and accesses NONE of: keystrokes, key contents, screen/display contents, clipboard, files, mouse-position history/coordinates, or window titles — and the audit **passes**

**Notes:** Manual audit case, NOT an automated assertion. Re-run on any change to native backend code. This is the headline privacy promise; a fail here blocks ship regardless of other passes.

---

### Case: Privacy audit — no disqualifying dependency introduced
**ID:** TC-019
**Priority:** P0
**Type:** regression
**Covers:** AC-8

Given the dependency set this slice introduces (any pub.dev package adopted from the spike, plus any native libraries linked by the backends)
When `privacy-guardian` reviews each dependency's capabilities
Then no added dependency is *capable* of capturing input content, screen, clipboard, files, mouse-position history, or window titles; any dependency that can is **rejected**

**Notes:** Manual audit case. Re-run on **every** dependency change (new pub.dev package, version bump that adds capability, new native lib). Guards the privacy promise at the supply-chain level, not just our own code.

---

### Case: Regression — no new capability-broadening dependency or content-reading API since approval
**ID:** TC-020
**Priority:** P0
**Type:** regression
**Covers:** AC-7, AC-8

Given a previously-audited, passing `activity-detection` slice
When a later change adds a dependency, bumps a dependency version, or introduces a new native API call in the `ActivityPlugin` backends
Then a diff-level re-check confirms no newly-referenced API reads input *content* (keystrokes/key contents, screen, clipboard, files, mouse coordinates/history, window titles) and no newly-added dependency is *capable* of doing so — the privacy promise is re-verified before merge

**Notes:** Manual / audit regression guard, tied into review (`/review-code` → `/privacy-audit`). Complements TC-018/TC-019 by making the re-audit an explicit gate on change rather than a one-time approval. This is the standing privacy-promise regression case.
