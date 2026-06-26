# Vehicle picker — choose your vehicle (cosmetic skin override)

**Promoted from backlog:** 2026-06-26
**Target:** visual-polish epic · Wave 3 (the production mode selector)
**Spec:** [specs/vehicle-picker/](../../specs/vehicle-picker/spec.md)

## Goal
A persisted, fun (icon-based) vehicle picker with **two entry points** (persistent + at new-route start),
applied as a **cosmetic skin override** (`vehiclePreference ?? engineMode` at the presentation seam, ADR-0007)
— changes the displayed vehicle/cockpit within a frame, sticks across restart, and touches **no** journey truth.

## Phase ledger
The single status tracker — one row per phase, updated in place after each phase command.

| ✓ | Phase | Command | Date | Verdict / note |
|---|-------|---------|------|----------------|
| [x] | 2 · Spec | `/new-feature` → review & approve `spec.md` | 2026-06-26 | **Approved by Kevin.** ADR-0007 accepted; 15 ACs + 3 NFRs (product-domain-expert); 2 UX questions resolved (Settings row + journey affordance · skippable pre-seeded route-start). Test cases: 19 automated TC-601..618 + 4 manual carries (`tests/cases/vehicle-picker.md` + `-manual-checklist.md`). **Icons sourced (parallel)** — 6 CC BY 3.0 game-icons.net glyphs under `assets/journey/vehicle_icons/`, in CREDITS + pubspec. |
| [x] | 3 · Build | `/implement` (includes self-review pass) | 2026-06-26 | **Done (flutter-app-developer).** `AppSettings.vehiclePreference` + `SettingsCubit.setVehicle`; override `vehiclePreference ?? engineMode` at the `JourneyScreen` seam (engine firewall intact); icon-chip `VehiclePicker`; 2 entry points (Settings row + journey affordance · skippable pre-seeded route-start) sharing one cubit. Tests: 42 unit + 36 TC-601..618 automation. **Self-review (flutter-code-reviewer): 2 Blocking — both FIXED & verified**: (1) `RouteStartVehiclePicker` crashed w/o `SettingsCubit` → `maybeFor` defensive factory + `openFullScreenMap` try/catch (9 `map_surface` tests green); (2) new UI icons tripped the scene-manifest reverse-guard → excluded `vehicle_icons/` subtree (picker-UI, not Flame). Consolidated re-run: 99/99 green. |
| [x] | 4 · Review | `/review-code` | 2026-06-26 | verdict: **approved** (flutter-code-reviewer, after fixes) · **`/privacy-audit` PASS** (NFR-2 gate). Initial pass found 2 Blocking — **B1** override missing on the production `AppShell` shared-game driver (broke AC-1/2/3/6); **B2** no shell-path test hid it — **both FIXED & re-reviewed**: override extracted to shared `composeDisplayedMode`/`VehiclePreferenceListener` seam wired into `AppShell` (both window modes) + 5 shell-path tests with confirmed teeth. Firewall AC-10 + engine byte-for-byte intact. Full suite 1162 green. Non-blocking carry: S1 dev-switcher split-brain, S2 affordance padding, N1 widget home. |
| [x] | 5 · Test | `/execute-tests` | 2026-06-26 | verdict: **green** — 84/84 in-scope (83 unit/widget/static + 1 integration on `-d macos`) + **1121/1121 regression** (stats/journey/route/mini_window), 0 flakes. Report `tests/_runner/reports/vehicle-picker/20260626-132959/summary.md`. AC-1..15 + NFR-1/NFR-3 ticked (NFR-2 via privacy gate). |
| [x] | 6 · Ship | `/ship` | 2026-06-26 | **SHIPPED.** spec `Status: shipped`; AC-1..15 + NFR-1/2/3 all `[x]`. Ship gate re-run after removing the debug `dev-mode-switcher` (superseded by this picker): `fvm flutter test` **1161 green**, analyze clean (`tests/_runner/reports/vehicle-picker/20260626-135858/summary.md`). Closes `visual-polish` Wave 3 + the whole epic. |

**Current phase:** SHIPPED (2026-06-26) — closes `visual-polish` Wave 3 & the epic.

### Build notes for the implementer
- **Seams (ADR-0007):** add `AppSettings.vehiclePreference: TravelMode?` + `SettingsCubit.setVehicle(...)` (mirror `setIdleThreshold` emit+persist); compose the override `displayedMode = vehiclePreference ?? engineMode` **at/above `JourneyViewState`** (where `JourneyScreen` already hands `s.mode` to `applyState`) — NOT inside `updateFromEngine` and NOT in the engine.
- **AC-10 firewall (load-bearing):** the engine must reference none of `{AppSettings, vehiclePreference, SettingsCubit, SettingsRepository}` — TC-610 + TC-610b are the static guard + negative twin (AC-8 alone can't catch it: a pick wired to accrual is inert in single-speed v1).
- **Icons (ready, sourced in parallel):** 6 PNGs at `assets/journey/vehicle_icons/{walk,run,bicycle,motorbike,car,ship}.png` (game-icons.net CC BY 3.0, slate `#2D3142` silhouettes, 144×144). They are **picker-UI assets, separate from the in-scene sprites** in `assets/journey/vehicles/` and **NOT part of `JourneyAssets.all`** (keep TC-011 scene cross-check scoped) — use a separate picker-icon constant list. Tint selected/unselected at the widget layer (`ColorFiltered`), don't re-rasterize.
- Two entry points, one `SettingsCubit` preference: persistent (Settings row + journey affordance) + skippable pre-seeded picker on the `RoutePlannerFlow` review/confirm step.

## Decisions made along the way
- **ADR-0007 accepted (2026-06-26)** — cosmetic skin-override precedence (`vehiclePreference ?? engineMode`),
  persisted via existing `shared_preferences` settings store, forward-compat boundary vs `journey-energy-model`.
- Two entry points (persistent + route-start), one persisted preference; fun per-mode icons (license-clean,
  via `ui-asset-curator`); one global preference in v1 (no per-route memory). See spec `## Resolved decisions`.
- Supersedes the debug-only `dev-mode-switcher` (shipped) — that was throwaway dev tooling.
