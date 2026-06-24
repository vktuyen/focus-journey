# Activity Detection

**Intake date:** 2026-06-23  **Requested by:** tuyenv@joblogic.com  **Size (rough):** L
**Part of epic:** [vietnam-focus-journey](vietnam-focus-journey.md) · Wave 1 (v1)

## Why
The whole product is gated on reliably reading **aggregate system idle time** (and screen-lock / sleep-wake) across macOS and Windows — without ever capturing input content. This slice delivers the Dart `ActivityPlugin` interface, native backends (Swift macOS first, then C++/Win32), and a mock source for UI/tests.

## Signals
Ready when: a spike proves real idle-seconds on macOS in a Flutter window; `ActivityPlugin` exposes idle-seconds + screen-locked + sleeping behind a mockable interface; `privacy-guardian` confirms no input-content/screen/clipboard access. [blocked by: nothing] — ⚠️ **do the idle spike before any custom-plugin work; check pub.dev first.**

## First step
Run `/new-feature activity-detection` to promote this slice into a spec. (Highest-risk foundation — start here.)
