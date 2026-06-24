# Local Stats

**Intake date:** 2026-06-23  **Requested by:** tuyenv@joblogic.com  **Size (rough):** M
**Part of epic:** [vietnam-focus-journey](vietnam-focus-journey.md) · Wave 1 (v1)

## Why
Closes the v1 loop with the user-facing surfaces: daily/weekly stats (active time, distance, idle, best focus period, **raw active time shown separately from journey time**), settings (idle threshold, launch-at-startup, notifications), local milestone **badges** ("100 km this week", "halfway", "crossed N provinces", streaks), and the **onboarding/privacy** screen that states the trust promise.

## Signals
Ready when: daily counters reset at local midnight while cumulative position/streak/badges persist; stats distinguish raw active time from journey time; idle-threshold setting changes engine behaviour; onboarding privacy claims match what `privacy-guardian` verifies in code. [blocked by: journey-engine]

## First step
Run `/new-feature local-stats` to promote this slice into a spec (after `journey-engine`).
