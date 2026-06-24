# Roadmap

High-level direction. Details live in [active/](active/), [backlog/](backlog/), and [done/](done/).

## Now (this quarter)
- **🎉 Wave 1 (v1 MVP) is COMPLETE (2026-06-24)** — all 5 slices shipped, in [done/](done/): `activity-detection` · `journey-engine` · `journey-view` · `route-progress` · `local-stats`. The full work→travel loop, map, stats/settings/badges, and onboarding/privacy screen are built and green. (Public-release prep still owes the deferred on-device/real-OS verification legs — see each slice's `done/` doc + execution-roadmap §7.)

## Next — Wave 2 (v2), STARTED 2026-06-24
- **mini-window** — always-on-top PiP + tray/menu-bar · [blocked by: journey-view ✅] — **🚧 Phase 3 (Build) NEXT** — spec **approved**; ADR-0003 (single-window two-mode); 18 ACs + 9 NFRs; 28 test cases. `/implement` after the ADR-0003 macOS spike-gate (see `planning/active/mini-window.md`)
- **journey-energy-model** — per-mode speeds + energy/fuel strategy · [blocked by: journey-engine ✅]
- **map-geographic** — `flutter_map` + real OSM tiles · [blocked by: route-progress ✅] (reuses the shipped chain model + position math)
- **team-leaderboard** — backend + team race (its own sub-epic) · [blocked by: local-stats ✅]
- (Child backlog files don't exist yet — create them with `/capture-idea <slug>` when starting the wave.)

## Later
- **Wave 3 (v3):** ai-coach · signed-distribution
- (Child backlog files for Wave 3 are created when that wave starts — wave discipline.)

## Principles
- **Privacy-first, always.** Read only aggregate idle time; never keystrokes/screen/files. The trust promise is the product.
- **Wave discipline.** Ship a wave before starting the next; each slice is independently shippable.
- **Validate the loop cheaply.** Local-only v1 before any backend/AI/signing investment.
