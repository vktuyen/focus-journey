---
description: One-time scaffold of the Flutter desktop project under src/ — flutter create, enable macOS+Windows desktop, add packages (incl. flutter_bloc), Clean-Architecture skeleton, wire .gitignore, commit pubspec.lock. Run once at the start of Phase 3 (Build) when src/ has no Flutter project.
argument-hint: <project-name>
---

Bootstrap the Flutter desktop project. This runs **once for the repo** (a Phase 3 prerequisite), not per feature.

Preconditions (STOP and report if any fail):
- [ ] `docs/architecture/overview.md` declares Flutter desktop as the stack (or the user confirms it here).
- [ ] `src/` has no existing Flutter project (no `src/<name>/pubspec.yaml`). Never clobber an existing project.
- [ ] `flutter` is on PATH (`flutter --version`). If not, STOP — ask the user to install it (suggest they run `! flutter --version`).

Delegate to `flutter-app-developer`. Steps:
1. `flutter create --platforms=macos,windows --org com.joblogic <project-name>` inside `src/`.
2. Add dependencies to `pubspec.yaml`: `flutter_bloc`, `equatable`, `shared_preferences`, `window_manager`, `tray_manager`, `flame`; dev: `bloc_test`, `mocktail`. (Defer `rive` / `flutter_map` / `drift` to v2 per the plan.)
3. Lay down the Clean-Architecture skeleton: `lib/core/`, `lib/features/`, and a short `lib/README.md` documenting the `presentation` / `domain` / `data` convention + Bloc + DI rules.
4. Confirm the project's own `.gitignore` covers Flutter noise (`.dart_tool/`, `build/`, ephemeral dirs). Ensure `src/` is NOT ignored at the repo root and **`pubspec.lock` IS committed** (this is an app).
5. `flutter pub get`, then `flutter analyze` to confirm a clean baseline.

Report: project path, packages added, the folder skeleton, and confirm `pubspec.lock` is tracked. Then launch it once to verify it opens.
