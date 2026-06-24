# Journey Engine

**Intake date:** 2026-06-23  **Requested by:** tuyenv@joblogic.com  **Size (rough):** M
**Part of epic:** [vietnam-focus-journey](vietnam-focus-journey.md) · Wave 1 (v1)

## Why
The pure-Dart core loop that turns activity into travel: active/idle state → virtual distance (speed-only, single shared `kmPerActiveHour`), tracking **journey time** (drives distance, includes the idle grace) and **raw active time** (drives stats/streaks) separately, with local persistence. Framework-free so it's fully unit-testable.

## Signals
Ready when: `JourneyEngine` is pure Dart with an **injected clock + injected `ActivityPlugin`**, ticks on real elapsed-time deltas (not a fixed interval), handles sleep/wake gaps correctly, and persists/restores daily progress. Unit tests pass with no real timers. [blocked by: nothing] — can be built in parallel with `activity-detection` behind the mock source.

## First step
Run `/new-feature journey-engine` to promote this slice into a spec.
