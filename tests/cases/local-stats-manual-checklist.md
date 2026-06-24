# Manual run checklist — local-stats

Per-OS, human-driven verification of the `local-stats` cases that cannot be a
deterministic Dart unit/widget/integration test because they need a **real OS
toast**, **real launch-at-startup registration**, or are a **privacy audit** of
the copy ⇄ code contract. Follow this during `/execute-tests` and record the
verdict per case **per OS**.

- Authoritative scenarios: [local-stats.md](local-stats.md) (TC-001..TC-022 + TC-026/027 + TC-NF1..TC-NF5).
- Coverage matrix + layer reality: [specs/local-stats/test-plan.md](../../specs/local-stats/test-plan.md).
- Automated companions live under `src/focus_journey/test/` (unit/widget) and
  `src/focus_journey/integration_test/` (e2e) — see "Automated companions" below.

## How this maps to automation

| TC | Verification here | Automated companion |
|----|-------------------|---------------------|
| TC-001..TC-007, TC-013..TC-020 | **Already automated** (widget/unit/integration) — NOT in this checklist | `test/features/stats/**`, `integration_test/stats_persistence_test.dart` |
| TC-008, TC-009, TC-010 (fake leg), TC-011, TC-012, TC-NF3 | **Already automated** (integration/widget against fakes) — NOT in this checklist | `integration_test/stats_wiring_test.dart`, `test/features/stats/presentation/settings_screen_test.dart` |
| TC-021 (copy renders) | **Already automated** (widget) — NOT in this checklist | `test/features/stats/presentation/onboarding_screen_test.dart` |
| **TC-022** | **Manual privacy audit** — `/privacy-audit` copy ⇄ code release gate | static reinforcement only: `test/features/stats/stats_separation_static_test.dart` (TC-026/027) — does NOT replace the audit |
| **TC-NF5** | **Manual / device** — real launch-at-startup registration + real toast delivery, per OS | injected-fake legs: `integration_test/stats_wiring_test.dart` (TC-010/TC-011) prove the Bloc wiring |
| **TC-NF4** | **Deferred** — goldens not introduced (see "Deferred" below); structure asserted behaviourally instead | `test/features/stats/presentation/*_test.dart` assert the visual structure |

## Conventions / tolerance

- **No automated proxy for the real-OS side.** The fakes (`FakeStartupController`,
  `FakeNotifier`) prove the Cubit reads-then-writes and that "toast requested ⇔
  enabled". They do **not** prove the OS actually registered open-at-login or that
  a real toast was delivered — that is exactly what this checklist verifies once
  per release per OS.
- **Build the real backend.** Run a real per-OS build (NOT `--mock-activity` — the
  mock is irrelevant to these cases but use a real build so packages initialise).
  `launch_at_startup.setup(...)` and `localNotifier.setup(...)` run at app startup
  (see `main.dart`); a build that skips them invalidates TC-NF5.
- **Offline-verifiable.** During the toast / registration checks, confirm **no**
  network egress (e.g. Little Snitch / `nettop` on macOS, Resource Monitor on
  Windows). Any outbound connection from the app is a **Fail** for TC-NF5's
  offline clause.

## Per-OS preconditions

- [ ] Build/run a **real** per-OS build (macOS `.app`, Windows `.exe`).
- [ ] Have OS settings reachable to verify open-at-login:
  - macOS: System Settings → General → Login Items → "Open at Login".
  - Windows: Task Manager → Startup apps (or Settings → Apps → Startup).
- [ ] Notifications permitted for the app (macOS: System Settings → Notifications;
      Windows: Settings → System → Notifications). If the OS suppresses toasts
      globally, record the toast leg as **Blocked**, not Fail.
- [ ] Note the OS version tested (record below).

OS versions under test — macOS: `__________`   Windows: `__________`

---

## Cases

Legend per cell: `[ ]` Pass `[ ]` Fail `[ ]` Blocked (check exactly one per OS).

### TC-NF5a — Real launch-at-startup registration reflects + persists (P1, per-OS)
Covers AC-10 (real-OS leg). Automated fake leg: TC-010 in `stats_wiring_test.dart`.

Steps:
1. Open Settings in the app. Note the "Launch at startup" toggle's initial state;
   confirm it **matches** the real OS open-at-login state for the app.
2. Enable the toggle. Open the OS login-items / startup list → the app is **listed
   / enabled**.
3. Quit and relaunch the app → the toggle still reads **enabled** and the OS entry
   persists.
4. Disable the toggle → the OS entry is **removed / disabled**; relaunch → toggle
   reads disabled.

Expect: the user-visible toggle and the **real** OS open-at-login state stay
consistent across enable → relaunch → disable, with no drift.

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows: Pass [ ]  Fail [ ]  Blocked [ ]

### TC-NF5b — Real badge-earned toast is delivered locally (P1, per-OS)
Covers AC-11/AC-12 (real-OS leg). Automated fake leg: TC-011/TC-012 in `stats_wiring_test.dart`.

Steps:
1. Ensure notifications are enabled (master + "Badge earned" per-type on).
2. Drive a real badge to its threshold (e.g. accrue enough distance/focus, or run
   a build seeded to cross the first badge mark).
3. Observe a **local OS toast** announcing the badge.
4. Turn the master notifications toggle **off**, re-trigger a badge condition →
   **no** toast fires.

Expect: a real desktop toast appears via `local_notifier` (no in-app-only banner,
no push, no network), and the master toggle gates it.

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows: Pass [ ]  Fail [ ]  Blocked [ ]

### TC-NF5c — Real daily streak-reminder toast is delivered + gated (P1, per-OS)
Covers AC-12 (real-OS leg). Automated fake leg: TC-012 in `stats_wiring_test.dart`.

Steps:
1. With notifications on and "Daily streak reminder" enabled, set the system clock
   (or wait) past the configured reminder time on a day that has **not** reached
   25 minutes of raw focus.
2. Observe a single **local OS toast** nudging the streak. Confirm it does **not**
   repeat the same day (no nag) and does **not** fire while a journey is actively
   progressing.
3. Reach 25 minutes of raw focus on another day before the reminder time → **no**
   reminder fires that day.

Expect: at most one real reminder toast per day, only when today is unqualified
and the journey is not actively progressing; suppressed once qualified.

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows: Pass [ ]  Fail [ ]  Blocked [ ]

### TC-NF5d — No network egress for any local-stats path (P0, per-OS)
Covers NF — No network / offline (real-OS leg). Static leg: TC-NF3 in `stats_separation_static_test.dart`.

Steps:
1. With a network monitor running, exercise: open stats, earn a badge (toast),
   fire a streak reminder, toggle launch-at-startup, change settings.
2. Watch for any outbound connection originating from the app.

Expect: **zero** network egress from the app on every path — fully local/offline.

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows: Pass [ ]  Fail [ ]  Blocked [ ]

### TC-022 — Onboarding privacy claims match the code (`/privacy-audit` release gate) (P0)
Covers AC-21, NF — Privacy by construction. **Ship-blocker.** Static reinforcement:
TC-026/TC-027 in `stats_separation_static_test.dart`.

Steps (run `/privacy-audit`, i.e. `privacy-guardian`, over the slice):
1. Confirm the onboarding copy's "reads" claims (aggregate idle + lock/sleep only)
   match actual API usage — the slice calls **no** `getSystemIdleSeconds()` /
   `isScreenLocked()` / idle-lock platform channel directly (reads engine scalars
   only).
2. Confirm the "never reads" list (keystrokes/content, screen, clipboard, files,
   browser, mouse-position history, window titles) is not contradicted by any API
   or dependency in the slice.
3. Confirm the two new deps (`launch_at_startup`, `local_notifier`) add **no**
   capability to read input/screen/clipboard/files/network — `local_notifier`
   delivers local toasts only.
4. Confirm the "fully local / offline / no account" claim: no network package, no
   cloud sync, no push, no account.

Expect: **no** API or dependency contradicts the onboarding copy. A contradiction
**fails this AC and blocks ship** regardless of all other passes. Re-run on any
change to the slice's source or its dependency set.

- Audit verdict (no per-OS split — source-level): Pass [ ]  Fail [ ]  Blocked [ ]
- Auditor / date: `__________`

---

## Deferred (not run as automation, by decision)

- **TC-NF4 goldens (stats card / badges grid / onboarding screen).** Goldens are
  **deferred**, consistent with the journey-view slice (no goldens exist in this
  repo and no stable, fixed-font/per-OS-tolerant golden harness is established).
  Introducing goldens now would produce flaky frames rather than dependable
  signal. The visual STRUCTURE those goldens would pin — the two-distinct-values
  honesty layout (TC-002), the earned/locked badge list (TC-013), and the full
  onboarding claim copy (TC-021) — is asserted **behaviourally** in the widget
  tests under `test/features/stats/presentation/`. Revisit if/when a shared
  golden harness is adopted project-wide.

## Automated companions (for reference)

- `src/focus_journey/test/features/stats/presentation/stats_screen_test.dart` — TC-001/TC-002/TC-003 (widget).
- `src/focus_journey/test/features/stats/presentation/badges_screen_test.dart` — TC-013..TC-018 (widget).
- `src/focus_journey/test/features/stats/presentation/settings_screen_test.dart` — TC-008/TC-010/TC-011/TC-012 (widget), TC-021 re-open.
- `src/focus_journey/test/features/stats/presentation/onboarding_screen_test.dart` — TC-021 (widget).
- `src/focus_journey/test/features/stats/stats_separation_static_test.dart` — TC-026/TC-027/TC-NF2/TC-NF3 (static).
- `src/focus_journey/integration_test/stats_persistence_test.dart` — TC-005/TC-007/TC-019/TC-020 (e2e).
- `src/focus_journey/integration_test/stats_wiring_test.dart` — TC-008/TC-010/TC-011/TC-012/TC-NF3 (e2e).
- The pure stat/weekly/streak/badge math (TC-003/TC-004/TC-006/TC-014..TC-018/TC-NF1) is owned by
  `unit-test-writer` under `src/focus_journey/test/features/stats/domain/`.
