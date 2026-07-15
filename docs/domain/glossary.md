# Glossary

Canonical definitions for domain terms used across specs, code, and tests. Keep short.
Disambiguate terms that collide with everyday English.

| Term | Definition | Notes |
|------|------------|-------|
| Active time | Input occurred within the idle threshold **and** screen unlocked **and** not sleeping. | Drives distance. |
| Idle time | Not active — no recent input, or locked, or sleeping. | Pauses the journey. |
| Idle threshold | Configurable inactivity duration after which the journey pauses. | Default 5 min (3/5/10/custom). |
| Idle grace window | Up-to-threshold true inactivity that still counts as travel. | Included in journey time, not raw active time. |
| Journey time | Active time **including** the idle grace. | Source for `distanceKm`. |
| Raw active time | True input time, **excluding** grace. | Source for stats & streaks (honest, lower than journey time). |
| `kmPerActiveHour` | Single shared virtual speed in v1; ~8 active hours ≈ full country. | Per-mode speeds deferred to `journey-energy-model` (v2). |
| Province chain / spine | Ordered Vietnam provinces, Mũi Cà Mau ⇄ Hà Giang. | Replaces fixed A→B routes. |
| Checkpoint | A province/city node passed along the chain. | — |
| Route plan | A user-authored contiguous sub-chain (start + end + optional stops) with lifecycle. | v2, ADR-0005. |
| Route lifecycle | `active` → `completed` (celebration) or `abandoned` (silent restart). | Abandon ≠ complete. |
| Canonical-km axis | Single distance axis all projectors share (progress, polyline, idle trace). | v2, ADR-0004. |
| Idle trace | Red segment on the map marking where the journey was paused. | v2, `map-experience`. |
| Travel mode (skin) | Cosmetic vehicle sprite; in v1 all modes share one speed. | `vehiclePreference ?? engineMode`, ADR-0007. |
| Streak | Consecutive local-calendar days meeting the active-minutes threshold. | Qualifies at ≥25 raw active min/day. |
| Milestone / badge | A local achievement (e.g. "halfway", "100 km this week"). | Local only. |
| Mini-window (PiP) | User-invoked compact always-on-top mode; full ⇄ compact are mutually exclusive. | v2, ADR-0003. |
