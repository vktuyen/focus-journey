# Activity Detection

**Status:** shipped (macOS-verified; Windows runtime verification deferred — see acceptance-criteria.md L3)
**Owner:** Kevin (Tuyen Vo)
**Last updated:** 2026-06-23

## Problem
The entire product is gated on one capability: reliably reading **aggregate system idle time**
(plus screen-lock and sleep/wake state) across **macOS and Windows** — *without ever capturing what
the user is doing*. Until this works, nothing else (the journey engine, the Flame scene, stats) has
a trustworthy signal to drive it, and the product's core privacy promise can't be verified.

This slice delivers the foundation: a Dart `ActivityPlugin` interface, native platform-channel
backends (Swift on macOS first, then C++/Win32 on Windows), and a mockable source for UI/tests. It
is the **highest-risk** slice, so it is sequenced first and de-risked with a throwaway **spike**
before any custom-plugin work.

## User & outcome
- **The focused individual** (developer/student/remote worker) — benefits indirectly: the app can
  tell active from idle from real OS signals, so the journey reflects genuine focus.
- **The privacy-skeptical teammate** — benefits directly and is the harder bar: they will only adopt
  if the trust claim is *verifiable*. Success = `privacy-guardian` confirms the code reads only
  aggregate idle time and screen-lock/sleep state, and touches **no** keystrokes, key contents,
  screen, clipboard, files, mouse-position history, or window titles.

**Observable success:** on each OS, `getSystemIdleSeconds()` returns a value that climbs while the
machine is untouched and resets to ~0 on real input; `isScreenLocked()` reflects lock state; the
mock source lets tests drive any value deterministically; and the privacy audit passes.

## Scope
### In
- **`ActivityPlugin` Dart interface** (domain) exposing at minimum:
  `Future<int> getSystemIdleSeconds()` and `Future<bool> isScreenLocked()`.
- **macOS backend** (Swift, platform channel) — system idle seconds + screen-lock state.
- **Windows backend** (C++/Win32, platform channel) — system idle seconds + screen-lock state.
- **Mock source** implementing the same interface, driven by `--mock-activity` (shorthand; the
  actual mechanism is `--dart-define=mock-activity=true`) for dev/UI/tests.
- **Spike (do first):** prove real idle-seconds in a throwaway Flutter window on macOS; **check
  pub.dev for an existing idle/activity package before writing custom native code.**
- Dependency injection seam so the interface is swappable (real ↔ mock) and unit-testable.

### Out
- The active/idle **decision policy** (threshold comparison, the 5-min grace, delta-from-last-tick) —
  that lives in `journey-engine`. This slice only *exposes raw signals*.
- Distance, travel modes, persistence, any UI/Flame scene, stats, tray, mini-window, notifications.
- Sleep/wake *handling* logic (the engine reacts to large idle on wake); this slice need only ensure
  idle reads are correct across a sleep/wake cycle, not implement the journey response.

## Constraints & assumptions
- **Privacy-first (hard constraint):** read only aggregate idle time + lock/sleep state. Never read
  or store keystrokes, key contents, screen, clipboard, files, mouse-position history, or window
  titles. Any new dependency that *could* break this is disqualifying.
- **Cross-platform:** macOS + Windows desktop (Flutter). macOS implemented first, Windows second.
- **Testability:** the interface must be injectable/mockable; deterministic unit tests with no real
  timers or real idle waits (the mock source covers this).
- **Spike before commit:** if a license-clean pub.dev package already provides reliable idle-seconds,
  prefer it over a custom plugin (plan §22 step 0).
- Stack per `docs/architecture/overview.md`: Flutter desktop, Bloc, Clean Architecture (the plugin
  interface is a *domain* contract; native impls are *data*).

### Resolved decisions
- **Raw signals only (scope boundary).** This slice reports facts (idle-seconds + lock state); the
  active/idle *judgment* (5-min threshold, grace, pause/resume) lives in `journey-engine`. The plugin
  is a "thermometer," not a "thermostat."
- **`isScreenLocked()` on BOTH macOS and Windows** for v1.
- **No special sleep/wake handling.** Standard OS idle APIs naturally report a large idle value after
  wake, which the engine reads as idle. No dedicated sleep/wake signal in this slice. (Revisit only
  if an OS is observed to misbehave.)

## Open questions
- [x] Which OS API per platform? **Resolved (spike):** macOS uses
      `CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .any)` for idle
      (HID counter, no Accessibility/Input-Monitoring permission) and
      `CGSessionCopyCurrentDictionary()` → `CGSSessionScreenIsLocked` for lock. Windows uses
      `GetLastInputInfo` + `GetTickCount64` for idle and `WTSRegisterSessionNotification` +
      `WM_WTSSESSION_CHANGE` (cached last lock/unlock event) for lock. — owner:
      `flutter-native-plugin-engineer`
- [x] Is there a license-clean pub.dev package that removes the custom-plugin work?
      **Resolved (spike): No — build a custom platform-channel plugin.** No single
      well-maintained, license-clean package provides BOTH aggregate idle seconds AND OS
      session-lock state on BOTH macOS and Windows. Packages that read idle reliably are scarce and
      stale; the ones that listen to input (global key/mouse listeners) are *disqualified* by the
      privacy constraint (they capture input content), and any third-party native code would widen
      the privacy-audit surface (AC-8). A custom channel keeps native API usage minimal and
      auditable by construction. See `lib/features/activity/README.md`. — owner: spike

## Related
- Epic: [planning/backlog/vietnam-focus-journey.md](../../planning/backlog/vietnam-focus-journey.md) · Wave 1 (v1)
- Backlog slice: [planning/backlog/activity-detection.md](../../planning/backlog/activity-detection.md)
- Plan detail: `planning/backlog/vietnam_focus_journey_plan.md` §3 (privacy), §4 (activity rule), §7 (native architecture), §22 step 0 (spike)
- Domain rules: [docs/domain/business-rules.md](../../docs/domain/business-rules.md)
- Architecture: [docs/architecture/](../../docs/architecture/) — `ActivityPlugin` in Components; ADR-0002 (stack)
