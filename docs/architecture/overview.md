# Architecture overview

One-page picture of the system. Update when the shape of things changes; don't let it drift.

## Components

> All decisions trace to `planning/backlog/vietnam_focus_journey_plan.md` §0 (locked v1).

- **`JourneyEngine`** (pure Dart, *domain*) — the core loop. `tick(delta)` converts active time into distance using the speed-only model; it tracks `activeTimeToday` (journey time, including the 5-minute idle grace), `rawActiveTime` (true input time, no grace), `idleTimeToday`, `distanceKm`, `state`, and `mode`. It takes an **injected clock + injected `ActivityPlugin`** — no real timers or `DateTime.now()` inside — so it is deterministic and unit-testable. Stats/streaks are computed from `rawActiveTime`; distance is computed from journey time.
- **`ActivityPlugin`** (*domain* interface + platform-channel implementations) — `getSystemIdleSeconds()`, `isScreenLocked()`. macOS (Swift) + Windows (C++/Win32) implementations, plus a **mock source** (`--mock-activity`) for dev/UI testing. (Spike first: check pub.dev for an existing idle package before writing custom native code.)
- **Activity ticker** (app service) — the periodic driver. Each tick computes elapsed time as `now − lastTickTimestamp` (NOT an assumed 5s), compares idle seconds against the configured threshold → active | idle | paused, then feeds `engine.tick(delta)`.
- **Presentation (Bloc)** — Blocs/Cubits expose engine + activity state to widgets. Clean-Architecture presentation layer; dependencies are injected, never `new`-ed inside widgets/blocs.
- **Journey view (Flame scene)** — POV trapezoid road, scrolling lane lines, parallax side objects, vehicle skin sprites, and active/idle visual states. Driven by Bloc state.
- **Route/progress model** — Vietnam as one continuous province chain (Mũi Cà Mau ⇄ Hà Giang); the user picks a start province + direction (north/south) + position. Custom-painted map screen (no live tiles).
- **Local stats / settings / onboarding-privacy** — daily/weekly stats derived from raw active time; a user-configurable idle threshold (default 5 minutes); an onboarding privacy screen whose claims must match actual API usage.
- **Persistence** (*data*) — `shared_preferences`/JSON repository (the data is tiny).
- **Layering** — presentation / domain / data (Clean Architecture), SOLID, dependency injection.
- **Mini-window + tray/menu-bar (v2)** — a user-invoked compact Picture-in-Picture mode, **single-window two-mode** (full ⇄ compact PiP, mutually exclusive — never co-visible) driven by `window_manager`, plus an always-present tray/menu-bar icon (hide-to-tray) via `tray_manager`. One `FlutterEngine`, one `JourneyEngine`/Bloc/ticker/Flame scene shared across both modes — see **ADR-0003**.
- **Deferred to v2 / later** — `flutter_map`, `drift`/SQLite, `rive`, leaderboard backend, AI coach.

## Data flow

```
OS idle counters ──platform channel──▶ ActivityPlugin.getSystemIdleSeconds()
        │
        ▼
Activity ticker (Timer): delta = now − lastTick; idle vs threshold → active | idle | paused
        │
        ▼
JourneyEngine.tick(delta): speed-only distance; tracks journey-time vs raw-active-time
        │
        ▼
Bloc emits state ──▶ Flame journey scene  +  Flutter widgets (journey / map / stats screens)
        │
        ▼
Persistence (shared_preferences / JSON)
```

**Sleep/wake behaviour:** on wake, the OS idle counter is large → correctly read as idle. The sleep gap counts as neither journey nor active time, because each tick's elapsed time is computed from the last tick timestamp rather than an assumed interval.

## External dependencies

- **No network services in v1** — no backend, cloud sync, auth, or live map tiles (the map is custom-painted). The app is fully local/offline.
- **OS APIs** (system idle time, screen lock, sleep/wake) accessed via Flutter platform channels. Failure mode: API unavailable or permission denied → treat as idle and surface an error; the mock source covers dev.
- **Flutter packages** (build-time dependencies, not services): `flame`, `flutter_bloc`, `shared_preferences`. `window_manager` + `tray_manager` drive the v2 mini-window (single-window full ⇄ compact PiP + tray, per ADR-0003); compact-window position is persisted via `shared_preferences` and clamped onto a visible display via `screen_retriever`. `launch_at_startup` / `local_notifier` are v1-optional.
- **Deferred to v2:** leaderboard backend, `flutter_map` + OSM tiles, `drift`, `rive`.

## Environments

- **Dev** — `flutter run -d macos|windows`; the `--mock-activity` flag toggles active/idle manually without real system idle; hot reload available.
- **No staging.**
- **Internal release** — per-OS *unsigned* builds: macOS `.app`/`.dmg` (user does Right-click → Open), Windows `.zip`/`.exe` (SmartScreen warning). No signing/notarization in v1. Behaviour is identical to dev minus the mock flag.

## Automation testing

- **Unit:** `flutter test` (Dart unit + widget/golden tests). `JourneyEngine` is deterministic via the injected clock — no real timers or wall-clock waits.
- **Integration:** `flutter test` (Bloc ↔ UI wiring; widget tests).
- **E2E:** the `integration_test` package, run via `flutter test integration_test/`.

**Test layout (CONFIRMED decision — deviates from the chassis):** Flutter tests physically live INSIDE the Flutter package — unit/widget under `src/test/`, e2e under `src/integration_test/` — because `flutter test` only discovers tests inside the package. The chassis top-level `tests/unit|integration|e2e` dirs are therefore NOT used for executables on this project. The chassis dirs are still used for their non-executable purposes: `tests/cases/` holds the human-readable Given/When/Then scenarios, and `tests/_runner/reports/<slug>/<timestamp>/` holds run reports.

> NOTE for `/execute-tests` and the test agents: on this project, executable tests live under `src/` (`src/test/`, `src/integration_test/`), not under the top-level `tests/` tree.

**Reports & coverage:** redirect runner output into `tests/_runner/reports/<slug>/<timestamp>/`. Coverage example: run `flutter test --coverage`, then move/point `coverage/lcov.info` into that timestamped folder. Do not leave coverage data at the repo root or in `tests/_runner/` itself.

## Agent roster (role → project agent)

The chassis phase commands (`/implement`, `/review-code`, …) delegate by **role**. This project maps each role to a concrete agent and lists the per-phase skills to run. `system-architect` owns this section; `/init-architecture` refines it. Where a role is blank, the chassis default (in parentheses) applies.

**Coding-standards baseline** every implementer/reviewer follows: Clean Architecture (`presentation` / `domain` / `data`), SOLID, dependency injection, Effective Dart. (Pin as an ADR via `/add-adr`.)

| Phase | Role (chassis default) | Project agent(s) | Phase skills to run |
|---|---|---|---|
| 3 Build | Implementer (`code-generator`) | `flutter-app-developer` (UI/Bloc) · `flutter-native-plugin-engineer` (idle/tray/window native) · `flame-game-developer` (POV scene) | `/flutter-bootstrap` (first run only, if `src/` has no Flutter project) · `/source-assets` (gather art) · `/self-review` (before review) |
| 3 Build | Unit tests (`unit-test-writer`) | `unit-test-writer` | — |
| 3 Build | Test automation (`test-script-author`) | `test-script-author` | — |
| 4 Review | Reviewer (`code-reviewer`) | `flutter-code-reviewer` | `/privacy-audit` (runs `privacy-guardian`) |

> Stack: **Flutter desktop** (macOS + Windows), state via **Bloc**. Full rationale + locked v1/v2/v3 scope: `planning/backlog/vietnam_focus_journey_plan.md` §0. The **Automation testing** section above still needs the Flutter runner filled in by `/init-architecture` (likely `flutter test` for unit, `integration_test` for e2e) before `/execute-tests` can run.

## See also
- Decisions: [decisions/](decisions/)
- Diagrams: [diagrams/](diagrams/)
