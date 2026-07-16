# Business rules

Invariants that hold regardless of feature. Each is **numbered** (cite as `BR-3`), **testable**, and
**owned**. Default owner: the engine/product team (Kevin); privacy rules are gated by `privacy-guardian`.

## Rules

### BR-1 — Privacy boundary *(trust invariant)*
Reads **only** aggregate system idle seconds + screen-lock/sleep state. Never keystrokes, text, screen,
clipboard, files, GPS, device location, or browser. *Owner: `privacy-guardian` (`/privacy-audit` gate).*

### BR-2 — Active condition
The journey is active only when input occurred within the idle threshold **and** the screen is unlocked
**and** the machine is not sleeping; otherwise it is paused.

### BR-3 — Idle threshold
The journey pauses after the configured idle threshold (default 5 min; options 3/5/10/custom).

### BR-4 — Timestamp-delta ticks
Each tick's elapsed time is computed from the last-tick timestamp, never an assumed fixed interval.

### BR-5 — Sleep/wake gap
A sleep/wake gap counts as **neither** journey time nor active time.

### BR-6 — Distance vs stats split
Distance accrues from **journey time** (incl. grace); stats and streaks use **raw active time**.

### BR-7 — Cosmetic modes (v1)
All travel modes share one virtual speed (`kmPerActiveHour`); modes differ only visually. A vehicle pick is
a cosmetic override (`vehiclePreference ?? engineMode`) and never changes engine truth. *(ADR-0007.)*

### BR-8 — Daily reset
Daily counters reset at local midnight; cumulative distance, streak, and badges persist across resets and
app restarts (within the same local day for in-progress distance).

### BR-9 — Streak qualification
A day counts toward a streak when raw active time ≥ 25 minutes.

### BR-10 — Route lifecycle *(v2)*
An authored route is `active`, `completed`, or `abandoned`. Completion shows a celebration + summary with no
auto-advance and retained progress; abandon silently restarts over the never-reset engine distance and is
distinct from completion. *(ADR-0005.)*

### BR-11 — Network egress *(v2)*
The only network egress is anonymous OSM map-tile GETs (`{z}/{x}/{y}` + static user-agent, no user data),
with a graceful offline fallback and visible OSM attribution. *(ADR-0004.)*

### BR-12 — Positioning
This is a personal productivity **game**, never employee-monitoring software.
