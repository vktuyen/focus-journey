# Manual run checklist — activity-detection

Per-OS, human-driven verification of the `ActivityPlugin` cases that cannot be a
deterministic Dart unit/widget test because they need **real OS input / lock /
sleep** or are a **privacy audit**. Follow this during `/execute-tests` and
record the verdict per case **per OS**.

- Authoritative scenarios: [activity-detection.md](activity-detection.md) (TC-001..TC-020).
- Coverage matrix + layer reality: [specs/activity-detection/test-plan.md](../../specs/activity-detection/test-plan.md).
- Automated companions live under `src/focus_journey/integration_test/` (see
  "Automated companions" at the bottom).

## How this maps to automation

| TC | Verification here | Automated companion |
|----|-------------------|---------------------|
| TC-001..TC-010 | **Manual primary** (this checklist) | best-effort smoke: `activity_real_backend_smoke_test.dart` (TC-001/TC-002 monotonic, TC-006 read-shape only); logging aid: `activity_logging_harness_test.dart` |
| TC-011 | **Manual regression** — re-run TC-001..TC-010 + TC-014 against the chosen implementation | — |
| TC-014 / TC-015 | flag→DI wiring is **automated** (`activity_flag_di_test.dart`); the real-backend on-device half is confirmed by the default-flag run below | `activity_flag_di_test.dart` |
| TC-012, TC-013, TC-016, TC-017 | **Already covered by Dart unit tests** under `src/focus_journey/test/` — not in this checklist | — |
| TC-018, TC-019, TC-020 | **Manual privacy audit** — run `/privacy-audit` (`privacy-guardian`) | — (audit verdict, no CI signal) |

## Conventions / tolerance

- **±2s tolerance band:** when a case asserts reported idle seconds match elapsed
  untouched wall-clock seconds, "within tolerance" = **±2 seconds** (call latency
  + OS counter granularity). A monotonic check must never show a real *decrease*
  larger than the band during a no-input window.
- **`isScreenLocked()` semantics:** `true` ONLY for an OS **session lock** (login/
  lock screen engaged). A merely sleeping / screensaver-on display whose session
  is **not** locked reports `false` (TC-009).
- **No-input discipline:** during any "leave untouched" window, do NOT move the
  mouse, touch the trackpad, or press a key — that resets the idle counter and
  invalidates the reading.

## Per-OS preconditions

Before running the real-OS cases on a machine:

- [ ] Build/run the **real** backend (NO `--mock-activity` flag). The mock never
      touches the OS and would invalidate every real-OS case.
- [ ] **TC-009 setup (critical):** disable auto-lock-on-sleep so a sleeping
      display does NOT auto-engage the session lock:
  - macOS: System Settings → Lock Screen → "Require password after screen saver
    begins or display is off" = **Never / Off** (or test before the delay elapses).
  - Windows: Settings → Accounts → Sign-in options → "If you've been away, when
    should Windows require you to sign in again?" = **Never**; and screensaver
    "On resume, display logon screen" = **unchecked**.
  - If the machine still auto-locks on sleep, TC-009's precondition cannot hold —
    record TC-009 as **Blocked**, do NOT mark it Pass.
- [ ] Note the OS version tested (record below).

OS versions under test — macOS: `__________`   Windows: `__________`

---

## Cases

Legend per cell: `[ ]` Pass `[ ]` Fail `[ ]` Blocked (check exactly one per OS).

### TC-001 / TC-002 — Idle seconds climb while untouched (P0)
Steps:
1. On the real backend, sample `getSystemIdleSeconds()` at t0 (use the logging
   harness or the smoke test).
2. Leave the machine **completely untouched** ~10s, sample again.
3. Leave untouched another ~10s (~20s total), sample again.

Expect: each successive value is **monotonically non-decreasing**, and each
sample approximates elapsed untouched wall-clock seconds since the last real
input, within **±2s**.

- macOS (TC-001): Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (TC-002): Pass [ ]  Fail [ ]  Blocked [ ]

### TC-003 / TC-004 — Idle resets to ~0 on a real key press (P0)
Steps:
1. Let idle climb to a clearly non-zero value (≥10s).
2. Press a key.
3. Sample `getSystemIdleSeconds()` again.

Expect: the next value is at or near **0** (within ±2s).

- macOS (TC-003): Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (TC-004): Pass [ ]  Fail [ ]  Blocked [ ]

### TC-005 — Idle resets on mouse movement AND click (P1, per-OS)
Steps:
1. Let idle climb to ≥10s.
2. Move the mouse only (no click); sample → expect ~0 (±2s).
3. Let idle climb to ≥10s again.
4. Perform a click; sample → expect ~0 (±2s).

Expect: pointer **movement alone** (not just clicks/keys) resets the counter.

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows: Pass [ ]  Fail [ ]  Blocked [ ]

### TC-006 — Screen-lock true when locked, false when unlocked — macOS (P0)
Steps (use the logging harness so the locked-state read is captured while the
lock UI occupies the screen):
1. Session unlocked → `isScreenLocked()` should read **false**.
2. Lock (Ctrl-Cmd-Q or  menu → Lock Screen) → reads **true**.
3. Unlock (re-authenticate) → reads **false** again.

> macOS risk note: idle/lock APIs need **no permission**, so there is **no
> "denied" path** here — only normal reads.

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows: n/a (Windows lock is TC-007)

### TC-007 — Workstation-lock true when locked, false when unlocked — Windows (P0)
Steps (capture via the logging harness):
1. Workstation unlocked → `isScreenLocked()` reads **false**.
2. Lock (Win+L) → reads **true**.
3. Unlock → reads **false** again.

- macOS: n/a (macOS lock is TC-006)
- Windows: Pass [ ]  Fail [ ]  Blocked [ ]

### TC-008 — Lock state read live at call time, not cached at startup (P1, per-OS)
Steps:
1. Start the harness while **unlocked**.
2. Lock, then poll `isScreenLocked()` repeatedly across the lock→unlock
   transition.

Expect: the boolean tracks the **current** state on every call (true during
lock, false after unlock); never a value frozen at app startup.

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows: Pass [ ]  Fail [ ]  Blocked [ ]

### TC-009 — Display asleep but session unlocked reports NOT locked (P1, per-OS)
Precondition: "require password after sleep" is **OFF** (see Per-OS preconditions).
Steps:
1. With the session unlocked, put the display to sleep / let the screensaver
   engage **without** a session lock.
2. Wake just enough to read (or read via the harness) `isScreenLocked()`.

Expect: returns **false** — a sleeping/dimmed display that has not engaged the
OS session lock is NOT "locked".

> Risk note: sleep ≠ locked. If the machine auto-locks on sleep, the precondition
> cannot hold → record **Blocked**, not Pass.

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows: Pass [ ]  Fail [ ]  Blocked [ ]

### TC-010 — Large idle value after a sleep/wake cycle (P1, per-OS)
Steps:
1. Put the machine to sleep for a known duration (≥2 minutes).
2. Wake it and call `getSystemIdleSeconds()` **before** any new input.

Expect: a **large** value (clearly not 0), consistent with the elapsed sleep
duration, using the standard OS idle API (no dedicated sleep/wake code). The
first input after wake then resets it (TC-003/TC-004).

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows: Pass [ ]  Fail [ ]  Blocked [ ]

### TC-011 — Same observable contract for the chosen implementation (P1, regression)
The spike resolved to a **custom platform-channel plugin** (see
`lib/features/activity/README.md`). Re-run TC-001..TC-010 + TC-014 against this
implementation; confirm AC-1..AC-5, AC-9, AC-10 hold identically and swapping the
implementation needs no calling-code change. Re-run if the implementation changes.

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows: Pass [ ]  Fail [ ]  Blocked [ ]

### TC-014 (real-backend on-device half) — real backend resolves & reads (P0)
Steps: run `activity_flag_di_test.dart` with the **default** flag (real backend
selected) and the smoke test, per the commands below. Confirm the real
`MethodChannelActivityPlugin` resolves and reads succeed on-device.

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows: Pass [ ]  Fail [ ]  Blocked [ ]

---

## Privacy audit (TC-018 / TC-019 / TC-020) — P0, audit, not automated

These are NOT pass/fail assertions in CI; they are a `privacy-guardian` audit.
Run `/privacy-audit` and record the **audit verdict**. A fail here blocks ship
regardless of every other pass.

- [ ] **TC-018** — Code reads ONLY aggregate idle + lock boolean; accesses NONE
      of keystrokes/key contents, screen/display contents, clipboard, files,
      mouse coordinates/history, or window titles. Inspect the Dart interface,
      native macOS (Swift) + Windows (C++/Win32) backends, and the mock.
      Audit verdict: Pass [ ]  Fail [ ]
- [ ] **TC-019** — No added dependency (pub.dev package or native lib) is
      *capable* of capturing input content, screen, clipboard, files, mouse
      history, or window titles. Re-run on every dependency change.
      Audit verdict: Pass [ ]  Fail [ ]
- [ ] **TC-020** — Diff-level re-check on any later change (new dep, version
      bump, new native API call) confirms no newly-referenced API reads input
      content and no new dep is capable. Wired into `/review-code` → `/privacy-audit`.
      Audit verdict: Pass [ ]  Fail [ ]

---

## Automated companions (run before/with the manual pass)

From `src/focus_journey/` (Flutter is fvm-pinned to 3.38.10 — always prefix `fvm`):

```bash
# TC-015 — flag ON: factory binds the deterministic mock.
fvm flutter test integration_test/activity_flag_di_test.dart -d macos \
    --dart-define=mock-activity=true
fvm flutter test integration_test/activity_flag_di_test.dart -d windows \
    --dart-define=mock-activity=true

# TC-014 (real-backend half) — flag OFF (default): factory binds the real backend.
fvm flutter test integration_test/activity_flag_di_test.dart -d macos
fvm flutter test integration_test/activity_flag_di_test.dart -d windows

# TC-001/TC-002/TC-006 best-effort on-device smoke (degrades to skip off-desktop).
fvm flutter test integration_test/activity_real_backend_smoke_test.dart -d macos
fvm flutter test integration_test/activity_real_backend_smoke_test.dart -d windows

# Logging harness to drive/observe lock & idle while doing the manual steps.
fvm flutter test integration_test/activity_logging_harness_test.dart -d macos \
    --dart-define=harness-seconds=60 --dart-define=harness-interval=2
fvm flutter test integration_test/activity_logging_harness_test.dart -d windows \
    --dart-define=harness-seconds=60 --dart-define=harness-interval=2
```

Note: `integration_test` files do NOT run under plain `fvm flutter test` (no
device); they need `-d macos` / `-d windows`. The deterministic unit/contract
tests under `src/focus_journey/test/` run under plain `fvm flutter test`.
