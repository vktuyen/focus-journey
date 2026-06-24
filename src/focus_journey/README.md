# Vietnam Focus Journey (`focus_journey`)

A privacy-first Flutter **desktop** app (macOS + Windows) that turns your real focus time into a
virtual road trip up/down Vietnam's province chain. It reads only **aggregate system idle time +
screen-lock/sleep state** — never keystrokes, screen, clipboard, files, or the network.

- **Stack:** Flutter desktop · Bloc · Clean Architecture. SDK is pinned with **[fvm](https://fvm.app)**
  to **Flutter 3.38.10** (see `../../.fvmrc`), so all commands below use `fvm flutter`.
- **Run from this directory:** `src/focus_journey/`.

> **TL;DR — run the macOS app right now:**
> ```bash
> cd src/focus_journey && fvm flutter run -d macos
> ```

---

## 0. Prerequisites (one-time)

- **fvm** installed (`dart pub global activate fvm` or `brew install fvm`), then from this folder:
  ```bash
  fvm install        # fetches the pinned Flutter 3.38.10
  fvm flutter pub get
  ```
  (If you don't use fvm, any Flutter **3.38.10** on your PATH works — just drop the `fvm` prefix.)
- **macOS builds:** Xcode + CocoaPods (`sudo gem install cocoapods`).
- **Windows builds:** Visual Studio with the **"Desktop development with C++"** workload.
- Sanity check: `fvm flutter doctor` (you want the "macOS"/"Windows" toolchain lines green).

---

## 1. Run from source (dev) — `flutter run`

### macOS
```bash
cd src/focus_journey
fvm flutter run -d macos
```

### Windows
```powershell
cd src\focus_journey
fvm flutter run -d windows
```

`flutter run` builds a debug app, launches it, and attaches for **hot reload** (`r`) / hot restart
(`R`) / quit (`q`).

### Mock activity (move the journey without waiting / without touching real OS idle)
By default the app reads **real** system idle time, so the traveller only moves while you're actually
active. For a quick demo or UI work, use the deterministic mock source so it starts "active" out of the
box:

```bash
# macOS
fvm flutter run -d macos --dart-define=mock-activity=true
# Windows
fvm flutter run -d windows --dart-define=mock-activity=true
```

> Note: there is **no bare `--mock-activity` flag** — it's a compile-time define
> (`--dart-define=mock-activity=true`). See `lib/features/activity/README.md` for details.

### List available devices
```bash
fvm flutter devices      # confirm "macos" / "windows" appear
```

---

## 2. Build a release artifact — `flutter build`

### macOS (`.app`)
```bash
cd src/focus_journey
fvm flutter build macos --release
# Output:
#   build/macos/Build/Products/Release/focus_journey.app
```

### Windows (`.exe` + DLLs)
```powershell
cd src\focus_journey
fvm flutter build windows --release
# Output (whole folder must ship together):
#   build\windows\x64\runner\Release\
#     focus_journey.exe   (+ the bundled DLLs and the data\ folder)
```

---

## 3. Install / open the built artifact

**v1 ships unsigned and un-notarized** (no Apple Developer account / no code-signing yet — signing &
notarization are deferred to v3). So the OS will warn on first open; this is expected for internal builds.

### macOS — open the `.app`
1. Copy `focus_journey.app` out of `build/…/Release/` to e.g. `/Applications` or your Desktop.
2. Because it's unsigned, a normal double-click is blocked by Gatekeeper. **First launch only:**
   **Right-click (or Control-click) the app → Open → Open** in the dialog. macOS remembers the choice;
   subsequent launches are a normal double-click.
   - If macOS still refuses ("damaged / cannot be opened"), clear the quarantine attribute:
     ```bash
     xattr -dr com.apple.quarantine /Applications/focus_journey.app
     ```
- (Optional, later) a `.dmg` can be produced for distribution, but the same right-click→Open applies
  until the app is notarized (v3).

### Windows — run the `.exe`
1. Copy the **entire** `Release\` folder (the `.exe` alone won't run — it needs the sibling DLLs and the
   `data\` folder). Zip it to hand it to someone.
2. Double-click `focus_journey.exe`. **SmartScreen** will show *"Windows protected your PC"* because the
   build is unsigned. Click **More info → Run anyway** (first launch only).
- (Optional, later) an MSIX installer can be produced; note the `TODO(local-stats)` in `main.dart` — a
  packaged MSIX build must pass its package identity to `launch_at_startup.setup(packageName:)`.

Behaviour of a release build is identical to dev minus the mock flag (the mock define is a dev/test aid;
don't ship with it on).

---

## 4. Tests

```bash
cd src/focus_journey
fvm flutter test                                   # unit + widget (everything under test/)
fvm flutter test integration_test/<file>.dart      # e2e — run files INDIVIDUALLY (see note)
fvm flutter analyze                                 # static analysis (should be clean)
dart format .                                       # formatting (the repo gates on this)
```

> **Integration tests:** run each `integration_test/*.dart` file **one at a time**. The macOS desktop
> harness can't relaunch the app across multiple integration files in a single batch invocation, so a
> batch `integration_test/` run shows spurious "Unable to start the app" launch failures — a known
> environmental limitation, not a code defect. Per-file runs pass cleanly.

---

## 5. Project layout (Clean Architecture, by feature)

```
lib/
  main.dart                     Composition root: builds the DI graph + nav shell
  features/
    activity/                   Native idle/lock plugin + mock source (ActivityPlugin)
    journey/                    Pure-Dart JourneyEngine (core loop) + Flame POV scene + ticker
    route/                      Province-chain model + custom-painted map screen
    stats/                      Daily/weekly stats, settings, badges, onboarding/privacy
                                (domain / data / presentation)
test/                           Unit + widget tests (mirror lib/features/…)
integration_test/               End-to-end tests (run individually)
```

See `lib/features/activity/README.md` for the mock-activity details, and `../../docs/architecture/overview.md`
for the full architecture + the dev/release environment notes.
