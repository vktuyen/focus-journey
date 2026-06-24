# ADR-0002: Stack — Flutter desktop + Bloc + Flame

- Status: accepted
- Date: 2026-06-23
- Deciders: Kevin (Tuyen Vo) / system-architect

## Context

Vietnam Focus Journey is a privacy-first desktop productivity game targeting both macOS and Windows. The team already has Flutter experience. The product needs:

- cross-platform desktop delivery from one codebase,
- a custom animated UI (a POV journey scene), and
- the ability to reach native OS idle-detection APIs (system idle time, screen lock, sleep/wake) via platform channels.

It also wants a clean-architecture layering and straightforward unit testing of the core loop.

## Decision

Build Vietnam Focus Journey as a cross-platform Flutter desktop app (macOS + Windows) using Bloc (`flutter_bloc`) for state management and Flame for the POV journey scene.

- **v1 stack scope:** `flame` + `flutter_bloc` + `shared_preferences` (with `window_manager` / `tray_manager` reserved for the v2 mini-window).
- **Deferred to v2:** `rive` (character polish), `flutter_map` + `latlong2` (geographic map), `drift`/SQLite (session history).

## Consequences

- **Easier:** shared UI + business logic across macOS and Windows; testable Blocs; Flame handles the custom POV animation.
- **Harder:** native idle/lock/sleep detection requires per-OS platform-channel code (Swift on macOS, C++/Win32 on Windows). A spike should first check pub.dev for an existing idle package before custom native code is written.
- **Obligations:** the chosen stack is the single source of truth in `docs/architecture/overview.md`; downstream agents must read it from there rather than assume.

## Alternatives considered

### Pure web app
Rejected: a browser page cannot reliably detect global computer activity (VS Code, Terminal, and other apps outside the page) or screen lock/sleep.

### Electron / native-per-OS
Rejected: loses the single shared codebase and the team's existing Flutter expertise.

### Riverpod for state management
Rejected in favour of Bloc for clean-architecture fit and straightforward unit testing (per the locked decision in `planning/backlog/vietnam_focus_journey_plan.md` §0.A.5).
