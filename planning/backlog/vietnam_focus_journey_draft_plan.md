# Vietnam Focus Journey — Product & Technical Plan

_Last updated: 2026-06-23 — refined in Phase 0 review (see §0)._

---

## 0. Reviewer Notes — READ ME FIRST

_Added during the Phase 0 plan review. The original plan (sections 1–28) is preserved below and lightly annotated inline — search for these markers:_
- **`🔒 v1`** — a decision locked for MVP v1 (override by editing the value).
- **`→ v2` / `→ v3`** — capability intentionally deferred to a later release.
- **`⚠️ spike`** — a high-risk item to prove with a throwaway experiment *before* committing.

### A. Open decisions — ANSWERED 2026-06-23 ✅

All five are decided (your answers in **bold**). Two carry downstream impact: **#1 reshapes the route model** (see §10/§14 notes) and **#4 is explained in full below**.

1. **Route pacing & route model** — **ANSWERED.**
   **One focus-day (~8 active hours) = the FULL length of Vietnam, Mũi Cà Mau ⇄ Hà Giang.** The product is **not** a set of fixed A→B routes. The user picks a **start province** and a **direction** (north or south) and travels the continuous chain of provinces that way — e.g. start **Đà Nẵng → go north →** Huế · … · Hà Nội · … · Hà Giang. The provinces/cities passed are the checkpoints.
   - Implication: virtual distance is **time-compressed** — the whole country (~2,000 km of real road) is crossed in ~8 active hours, so the *reference* vehicle moves at ~250 virtual km/h. The realistic km/h in §11 become **flavour only**; real movement uses a scaled virtual speed (exact multipliers = playtest tuning). See the §11 reconciliation note.
2. **Route completion behaviour** — **ANSWERED.** On reaching the chosen destination/end, show a **celebration + summary screen**. **Nothing auto-advances** — the journey rests until the user explicitly chooses what to do next (new start/direction, or continue). Progress already earned is kept.
3. **Day boundary & streak** — **ANSWERED (default accepted).** Resets at **local midnight**; a day counts toward a streak with **≥25 active minutes**. **Plus milestone recognitions** — e.g. "100 km this week", "reached the halfway point", "crossed N provinces". (Drives the achievements/badges design; see §17.)
4. **Distance model for v1** — **ANSWERED: speed-only**, and **travel modes are purely cosmetic SKINS in v1** — walk / bike / car / … all share **one virtual speed**; only the sprite/skin differs. Both per-mode speed *differences* **and** the energy model → v2. (Full explanation below.)
5. **State management** — **ANSWERED: Bloc** — you prefer it for clean architecture + easy unit testing. This **replaces the earlier Riverpod default everywhere** in this doc (`flutter_bloc`).

#### Why "speed-only vs energy" (your question on #4, in detail)

Both turn *active time* into *distance moved*; the difference is how much **strategy** the vehicle choice carries.

**Speed-only model — the v1 lock:**
- Each travel mode is one number — a virtual speed. While active, `distance += speed × elapsed_time`. That's the whole rule.
- Car is simply faster than walking; 1 active hour on a faster mode = more km.
- ✅ Simple, predictable, trivially unit-testable; the loop is obvious to the user.
- ⚠️ No depth — the fastest vehicle is always strictly best; walking differs only cosmetically.

**Energy / fuel model — deferred → v2:**
- Active time first becomes **energy** (e.g. 1 active min = 1 energy). Distance is then "bought" with energy, and each vehicle converts energy→distance *differently, with rules*:
  - **Walk** — cheap, slow, but a **consistency bonus** (rewards many small steady sessions).
  - **Motorbike** — fast, but burns energy quickly ("needs fuel").
  - **Car** — fast, plus a **bonus after 30 continuous active minutes** (rewards long deep-focus blocks).
  - **Ship** — slow but steady; good for long sessions.
- The vehicle becomes a **strategy that fits your work style** (short bursts → walk; long focus → car).
- ⚠️ Much more to balance, test, and explain; easy to feel unfair if mis-tuned.

**Decision:** ship **speed-only** in v1 to validate the core "work → travel" loop is fun; add the energy model in v2 for strategic depth.

### B. Locked for MVP v1 (defaults applied — override by editing)

| # | Area | v1 lock | Deferred |
|---|---|---|---|
| 1 | Animation | **Flame only** | Rive character polish → v2 |
| 2 | Persistence | **`shared_preferences` / JSON** (data is tiny) | `drift`/SQLite session history → v2 |
| 3 | Map screen | **Custom-painted route polyline + checkpoint pins** (no live tiles → no OSM licensing risk) | `flutter_map` + real tiles → v2 |
| 4 | Distance model | **Speed-only**, single shared virtual speed (§20) | Energy/fuel model → v2 |
| 4b | Travel modes | **Cosmetic skins only** — same speed, different sprite | Per-mode speed differences → v2 |
| 5 | State mgmt | **Bloc** (`flutter_bloc`) — clean architecture + easy unit tests | — |
| 6 | Time accounting | **Delta from last tick timestamp** (not an assumed 5 s); track **journey-time AND raw active-time separately** so stats/streaks stay honest | — |
| 7 | Engine testability | `JourneyEngine` takes an **injected clock + injected `ActivityPlugin`** — deterministic, unit-testable with no real timers | — |
| 8 | Idle detection | **Prove first via a spike** (§22 step 0); check pub.dev for an existing package before writing a custom plugin | — |
| 9 | Leaderboard | excluded from v1 | needs a backend → its **own epic** (v2/v3) |

### C. New agents & skills — CREATED & wired into the 6-phase workflow ✅

The repo ships generic agents (code-generator, code-reviewer, test-*). This project's specialists below are now **created** in `.claude/agents/` and `.claude/commands/`, and **wired by ROLE** via the Agent roster in `docs/architecture/overview.md` so the phase commands invoke them automatically — **you never call them separately** (see §0.E).

**Coding-standards baseline (all code agents must follow it):** **Clean Architecture** layering (`presentation` / `domain` / `data`), **SOLID**, dependency injection (no `new`-ing dependencies inside widgets/blocs), small single-purpose units, immutability where practical, and idiomatic Dart/Flutter + Effective Dart. This baseline should be written up once as an **ADR** (`/add-adr`) by `system-architect` so every agent reads the same rules from `docs/architecture/`.

**Agents** (`.claude/agents/`):

| Agent | Purpose |
|---|---|
| `flutter-app-developer` | Implement Flutter widgets, screens, navigation and **Bloc** state from an approved spec, **strictly following the coding-standards baseline above** — Clean Architecture layers, SOLID, DI, design patterns (repository, use-case/interactor, factory, etc.), testable seams. A Flutter specialisation of `code-generator`. |
| `flutter-native-plugin-engineer` | Author & maintain the platform-channel code: **Swift** (macOS) and **C++/Win32** (Windows) for idle time, sleep/lock, tray, window management. The highest-risk, OS-API-heavy code. |
| `flame-game-developer` | Build & iterate the Flame POV road scene — trapezoid road, scrolling lanes, parallax side objects, vehicle skin sprites, active/idle visual states. |
| `ui-asset-curator` | **Source FREE, license-clean visual assets** (illustrations, sprites, vehicle skins, backgrounds, icons, fonts, Rive/Lottie) for the UI — from CC0/permissive sources (e.g. Kenney, OpenGameArt CC0, unDraw, Google Fonts, Lottie community). Verifies each licence, records **attribution + licence** in `assets/CREDITS.md`, optimises and places files under `assets/`. **Never** ships an asset whose licence is unclear. |
| `privacy-guardian` | **Read-only auditor.** Verifies the code only ever reads *aggregate idle time* — never keystrokes, screen, clipboard, files, or browser data — and that onboarding privacy claims match actual API usage. Flags any new dependency that could break the promise. Guards the product's core trust feature. |
| `flutter-code-reviewer` | **Read-only critic** with a Dart/Flutter lens — finds **code smells, bugs, SOLID/Clean-Architecture violations, Bloc misuse, needless widget rebuilds/perf issues, null-safety & async pitfalls, missing tests**. Reasons adversarially ("how could this break?") and ranks findings by severity. Specialises the generic `code-reviewer`. |
| `flutter-test-engineer` _(optional)_ | Author & run Flutter **widget / golden / `integration_test`** tests. Specialises `test-script-author` + `test-executor` for the Flutter harness. |

**Skills** (`.claude/skills/`, branch-scoped):

| Skill | Purpose |
|---|---|
| `/flutter-bootstrap` | One-time scaffold: `flutter create` in `src/`, enable macOS + Windows desktop, add the chosen packages (incl. `flutter_bloc`) to `pubspec.yaml`, wire the project `.gitignore`, commit `pubspec.lock`, lay down the Clean-Architecture folder skeleton. |
| `/flutter-feature` | Scaffold a new feature in the **Clean-Architecture layout** — `data` (models, repository impl), `domain` (entities, repository interface, use-cases), `presentation` (bloc + widgets) — wired with DI, following the standards baseline. |
| `/source-assets` | **Browse the web for free, license-clean UI/game art** matching a described need; present options **with licence + attribution + preview**; on approval, download, optimise, drop into `assets/`, and append to `assets/CREDITS.md`. Runs `ui-asset-curator`. |
| `/run-app` | Launch the desktop app on the current OS with a `--mock-activity` flag to toggle active/idle manually for UI testing (no real idle needed). |
| `/self-review` | **Adversarial self-review pass** on the current diff/feature *before* human review: critically reason about bugs, code smells, SOLID/Clean-Arch violations, edge cases, race conditions, and missing tests; output a ranked findings list with suggested fixes. Complements the generic `/review-code` + `/simplify`. Runs `flutter-code-reviewer`. |
| `/package-release` | Build & package internal distributables — macOS `.app`/`.dmg`, Windows `.zip`/`.exe` (per §8) — and print the "right-click → Open" / SmartScreen instructions. |
| `/add-province` | Add/edit a Vietnam province node on the country chain as data: name, neighbours (north/south), distance-from-neighbour, display label/asset — in the one format the engine and map read. (Replaces the old fixed-route `/add-route` idea, per §0.A.1.) |
| `/privacy-audit` | Run `privacy-guardian` across `src/` and emit a short pass/fail report; intended as a release gate. |

### D. This is an EPIC — proposed child backlog items

When we run `/capture-idea`, this should split into an epic + child items (one per wave). Proposed sequence:

| Child item | Depends on | Release |
|---|---|---|
| `activity-detection` (native idle plugin + `ActivityPlugin` interface + mock source) | — _(spike first)_ | v1 |
| `journey-engine` (pure-Dart core loop: active/idle→distance, modes, persistence) | — | v1 |
| `journey-view` (Flame POV road scene driven by engine state) | journey-engine | v1 |
| `route-progress` (Vietnam province-chain + start-province/direction/position model + custom-painted map screen) | journey-engine | v1 |
| `local-stats` (daily/weekly stats + settings + onboarding/privacy screen) | journey-engine | v1 |
| `mini-window` (always-on-top PiP + tray/menu-bar) | journey-view | v2 |
| `team-leaderboard` (own epic — needs a backend) | local-stats | v2/v3 |
| `ai-coach` (own epic) | local-stats | v3 |

**MVP v1 = `activity-detection` + `journey-engine` + `journey-view` + `route-progress` + `local-stats`.**

### E. Cross-session & versioned-wave workflow (how we actually run this)

Because the Claude session is killed between phases, progress lives on disk and a fresh session resumes via **`/status`**:
- Each phase updates `planning/active/<slug>.md` (status log + **Phase ledger** = current phase + next command), the spec `Status:`, and the test `summary.md`.
- **First command in any new session: `/status [slug]`** → prints the current phase and the exact next command. (The 6 phases: 1 Capture · 2 Spec · 3 Build · 4 Review · 5 Test · 6 Ship — full reference in `docs/guides/development-workflow.md`.)

**Starting v2 / v3 (your question — "from which phase?"):** a version is a **wave of this epic**, *not* a re-run of `/implement`. To start v2 you promote the v2 child slugs with **`/new-feature <slug>`** (Phase 2) and run each through Build → Review → Test → Ship. Enhancements to a shipped v1 component become **new slugs** (e.g. `journey-energy-model`, `per-mode-speeds`, `mini-window`) tagged `[blocked by: <v1-slug>]` — never edit a shipped slug in place. `/capture-idea` records all waves in the epic Breakdown; `planning/roadmap.md` says which wave is Next.

**The new agents/skills are invoked automatically inside the phases** (you don't call them separately) — via the **Agent roster** in `docs/architecture/overview.md`: `/implement` uses the Flutter implementers + `/source-assets` + `/self-review`; `/review-code` uses `flutter-code-reviewer` + `/privacy-audit`. One-time `/flutter-bootstrap` scaffolds the project. See §0.C.

---

## 1. Product Summary

**Vietnam Focus Journey** is a desktop productivity game where a user's active computer time becomes virtual travel progress across Vietnam.

When the user is active on their computer, a character or vehicle travels forward. When the user is inactive for a configured period, the journey pauses.

The app is not an employee-monitoring tool. It should be positioned as a **personal/team productivity game**.

### Core idea

```text
Computer activity
    ↓
Active/idle detection
    ↓
Convert active time to virtual distance
    ↓
Move character/vehicle through Vietnam
    ↓
Show progress, checkpoints, achievements, leaderboard
```

### Example user story

```text
Tuyen chooses the route: Ho Chi Minh City → Đà Lạt.

He starts coding.

After 25 active minutes:
The motorbike travels forward on the road.

After 5 minutes without input:
The motorbike stops at the roadside.

After several focus sessions:
He reaches Bảo Lộc checkpoint.

At the end of the day:
The app shows:
- Active time: 3h 20m
- Distance traveled: 95 km
- Best focus period: 9:20–11:05
- Current location: near Bảo Lộc
```

---

## 2. Main Product Positioning

### Good positioning

```text
A gamified productivity journey app.
A focus adventure app.
A desktop companion that turns work time into travel progress.
A Vietnam road-trip productivity tracker.
```

### Avoid positioning it as

```text
Employee monitoring software
Keyboard tracker
Mouse tracker
Surveillance tool
Productivity enforcement system
```

This matters because the app detects activity. The trust/privacy message must be very clear from the beginning.

---

## 3. Privacy Principles

The app should use **system idle-time detection only**.

It should not record or inspect what the user is doing.

### The app should track

```text
- Whether the computer is active or idle
- System idle duration
- Active minutes
- Idle minutes
- Journey progress
- Selected travel mode
- Daily/weekly statistics
```

### The app should not track

```text
- Actual keys typed
- Text content
- Passwords
- Mouse position history
- Screen content
- Screenshots
- Open files
- Browser history
- Private messages
```

### Privacy statement for the app

```text
This app only checks whether your computer has been idle for more than the configured threshold.
It does not record keystrokes.
It does not read typed text.
It does not capture your screen.
It does not read your files.
```

---

## 4. Activity Detection Rule

The agreed idle threshold should be around **5 minutes**, not 60–120 seconds.

### Default rule

```text
Active:
- User has mouse/keyboard activity within the last 5 minutes
- Screen is not locked
- Computer is not sleeping

Idle:
- No mouse/keyboard activity for 5 minutes
- Or screen is locked
- Or computer is sleeping
```

### User-configurable idle threshold

Provide settings:

```text
Idle after:
- 3 minutes
- 5 minutes
- 10 minutes
- Custom
```

### Recommended default

```text
5 minutes
```

This avoids unfairly pausing the journey when the user is thinking, reading, debugging, watching logs, or reviewing code.

> **🔒 v1 — honest accounting:** the 5-minute grace means up to ~5 min of true idle counts as "travel" every time the user pauses. That's a fine grace for the *journey*, but the engine must also track **raw active-input time** separately, so stats/streaks (and any future leaderboard) aren't inflated by the grace window. Compute each tick's elapsed time from the **last tick timestamp**, never an assumed 5 s — robust to timer drift, missed ticks, and sleep/wake (on wake, idle is large → correctly idle; don't count the sleep gap).

---

## 5. Why Desktop App Instead of Web App

A pure web app cannot reliably detect whether the user is active across the whole computer.

A browser page can detect activity inside the page, but it cannot reliably know whether the user is active in VS Code, Terminal, Figma, Android Studio, Chrome, Slack, etc.

### Web app limitations

| Requirement | Pure web app |
|---|---:|
| Track mouse/keyboard inside the app tab | Yes |
| Detect if the tab is hidden | Yes |
| Track global computer activity | No / unreliable |
| Detect activity in VS Code/Terminal | No |
| Detect screen lock/sleep reliably | No |
| Keep running as a real background utility | No |
| Always-on-top mini player | Limited/browser-dependent |

### Correct product direction

```text
Desktop app first
Web dashboard later
Mobile companion later
```

---

## 6. Recommended Technology Stack

### Main decision

Build with:

```text
Flutter Desktop
+ Native macOS/Windows activity plugin
+ Flame game engine
+ Rive animations
+ flutter_map for Vietnam route/map tracking
```

### Why Flutter

Flutter is a good fit because:

```text
- The team already has Flutter experience
- Cross-platform desktop support: macOS + Windows
- Great for custom animated UI
- Can share UI/business logic across platforms
- Native platform channels can access macOS/Windows APIs
```

### Recommended packages

```yaml
dependencies:
  flame: latest
  rive: latest
  flutter_map: latest
  latlong2: latest
  window_manager: latest
  tray_manager: latest
  launch_at_startup: latest
  local_notifier: latest
  shared_preferences: latest
  drift: latest
```

### Package purpose

| Feature | Package / approach |
|---|---|
| First-person travel animation | `flame` |
| Character/vehicle animation | `rive` |
| Vietnam route map | `flutter_map` |
| Distance and coordinates | `latlong2` |
| Floating mini window | `window_manager` |
| Menu bar / system tray | `tray_manager` |
| Launch at login | `launch_at_startup` |
| Notifications | `local_notifier` |
| Local settings | `shared_preferences` |
| Activity/session history | `drift` / SQLite |
| Native idle-time detection | Flutter platform channels |

> **🔒 v1 stack scope (see §0.B):** `flame` ✅ · `window_manager` + `tray_manager` ✅ (v1 mini-window/tray) · `shared_preferences` ✅. **Deferred:** `rive` → v2, `flutter_map` + `latlong2` → v2 (v1 map is custom-painted), `drift` → v2 (v1 uses shared_preferences/JSON). **Add:** a state-management package — **Bloc** (`flutter_bloc`, §0.A.5). `launch_at_startup` + `local_notifier` are v1-optional (nice-to-have).
> **⚠️ spike before committing:** before building the custom `ActivityPlugin`, check pub.dev for an existing idle/activity package — it may remove the native plugin work entirely. See §22 step 0.

---

## 7. Native Platform Architecture

Flutter should handle the UI and shared logic. Native code should handle system-level activity detection.

### Architecture

```text
Flutter UI
  ↓
ActivityPlugin
  ├── macOS Swift implementation
  └── Windows C++ / C# implementation
```

### macOS native responsibilities

```text
- Get system idle time
- Detect sleep/wake
- Detect screen lock/unlock if needed
- Run in menu bar
- Support always-on-top mini window
- Launch at login
```

### Windows native responsibilities

```text
- Get system idle time
- Detect sleep/wake
- Run in system tray
- Support always-on-top mini window
- Launch at startup
```

### Dart API design

```dart
abstract class ActivityPlugin {
  Future<int> getSystemIdleSeconds();
  Future<bool> isScreenLocked();
}
```

### Activity engine example

```dart
const idleThreshold = Duration(minutes: 5);

Timer.periodic(const Duration(seconds: 5), (_) async {
  final idleSeconds = await activityPlugin.getSystemIdleSeconds();

  final isActive = idleSeconds < idleThreshold.inSeconds;

  if (isActive) {
    journeyEngine.resume();
    journeyEngine.addActiveSeconds(5);
  } else {
    journeyEngine.pause();
  }
});
```

---

## 8. Distribution Plan

### Internal company distribution

This is feasible without an Apple Developer account.

For internal teammates:

```text
macOS:
- Build Flutter macOS release
- Zip the .app or create .dmg
- Send internally via Slack/Drive
- User may need Right click → Open
- User may need Privacy & Security → Open Anyway

Windows:
- Build Flutter Windows release
- Send .zip/.exe internally
- User may see SmartScreen warning
- Technical teammates can still run it
```

### Important note

Unsigned/notarized status mostly affects opening/installing the app, not the core native tracking logic.

System idle-time detection should still work if the user can open the app.

### Public release later

For public macOS distribution, the better flow is:

```text
Apple Developer Program
→ Developer ID signing
→ Notarization
→ DMG download
```

For now, this is not required for internal testing.

---

## 9. Game Concept

The app should feel like a **Vietnam travel adventure**.

The user is not just filling a progress bar. They are traveling across Vietnam.

### Core game loop

```text
Start work/study session
    ↓
Computer remains active
    ↓
Vehicle moves forward
    ↓
Reach checkpoint
    ↓
Unlock badge/story/card
    ↓
Continue route
```

### Active state

```text
Vehicle moves
Road scrolls
Background animates
Distance increases
Energy decreases/increases depending on game design
```

### Idle state

```text
Vehicle stops
Character parks/rests
Road stops moving
Timer pauses
The app shows: "Paused — idle for 5 minutes"
```

---

## 10. Travel Scope: Vietnam Only

> **🔒 v1 route model (revised per §0.A.1):** there are **no fixed A→B routes**. Vietnam is **one continuous province chain** from **Mũi Cà Mau (south tip) → Hà Giang (north)**. The user picks a **start province** + a **direction** (north/south) and travels the chain that way; the provinces/cities passed are the checkpoints, and ~8 active hours covers the full country. The HCMC→Đà Lạt etc. pairs below are now just **illustrative segments**, not the data structure. (Child item `route-progress` in §0.D is "Vietnam province-chain + start/direction/position model".)

The app should focus on Vietnam routes. This gives the product a unique local identity.

### Route examples

```text
Ho Chi Minh City → Đà Lạt
Ho Chi Minh City → Vũng Tàu
Ho Chi Minh City → Cần Thơ
Hà Nội → Hạ Long
Hà Nội → Sa Pa
Đà Nẵng → Hội An
Đà Nẵng → Huế
Nha Trang → Đà Lạt
Vietnam North-to-South route
Vietnam coastal route
Mekong Delta route
```

### Good first route

```text
Ho Chi Minh City → Đà Lạt
```

Why:

```text
- Familiar Vietnam road-trip feeling
- Good for motorbike/car theme
- Has nice checkpoints: HCMC, Biên Hòa, Bảo Lộc, Đà Lạt
- Easy to explain visually
```

### Example checkpoints

```text
Route: Ho Chi Minh City → Đà Lạt

Checkpoint 1: Ho Chi Minh City
Checkpoint 2: Biên Hòa
Checkpoint 3: Dầu Giây
Checkpoint 4: Bảo Lộc
Checkpoint 5: Đà Lạt
```

---

## 11. Travel Modes

Users can choose different travel modes.

### Initial modes

```text
Walk
Run
Bicycle
Motorbike
Car
Ship
```

### Optional future modes

```text
Train
Bus
Plane
Boat
Cyclo
Electric bike
```

### Simple speed model

| Mode | Virtual speed |
|---|---:|
| Walk | 4 km/h |
| Run | 8 km/h |
| Bicycle | 15 km/h |
| Motorbike | 35 km/h |
| Car | 60 km/h |
| Ship | 25 km/h |

> **🔒 v1 pacing reconciliation (ties to §0.A.1):** these realistic km/h are now **flavour only**. The pacing target — **~8 active hours crosses the whole country (~2,000 km)** — implies a *reference* virtual speed of ~250 km/h, far above any realistic figure. v1 therefore uses a **single tunable `kmPerActiveHour`** shared by *all* modes (sized so the country takes ~8 h) — since modes are cosmetic skins in v1. Per-mode relative multipliers (car fastest … walk slowest) arrive with the speed differences in **→ v2**.

### Better game model

Instead of only speed, use:

```text
Active minutes → energy → distance
```

Example:

```text
10 active minutes = 10 energy

Walking:
- Low speed
- Low energy cost
- High consistency bonus

Motorbike:
- Fast
- Uses more energy/fuel

Car:
- Fast for longer sessions
- Bonus after 30 continuous active minutes

Ship:
- Slow but steady
- Good for long project routes
```

This gives more balancing options later.

> **🔒 v1: speed-only, modes are skins.** Travel modes (walk/bike/car/…) are **cosmetic skins sharing one virtual speed** in v1 — the table above is flavour, not behaviour. Per-mode speed differences AND the energy/distance model are both **→ v2**. (See §0.A.4.)

---

## 12. UI Concept

The app should have two main visual modes:

```text
1. First-person journey view
2. Map/progress view
```

---

## 13. First-Person Journey View

This is the main emotional screen.

The user sees the road ahead, like they are traveling forward.

### Visual style

Recommended style:

```text
Stylized 2D
Cozy road-trip illustration
Vietnam-inspired roads and landscapes
Cute vehicle/character
Soft colors
Day/night/weather changes
```

Avoid realistic 3D for the MVP because it increases scope.

> **🔒 v1 — source free, license-clean art (don't draw from scratch).** Polished visuals come from curated **free assets** (CC0 / permissive): road & parallax side objects, **vehicle skin sprites** (walk/bike/car/… are skins, §0.A.4), backgrounds, icons, fonts. Use the **`/source-assets`** skill + **`ui-asset-curator`** agent — every asset's **licence + attribution is recorded in `assets/CREDITS.md`**, and nothing with an unclear licence ships. Sources to prefer: Kenney, OpenGameArt (CC0), unDraw, Google Fonts, Lottie/Rive community. This is an explicit step in the build order (§22).

### Fake 3D using 2D perspective

The road can be drawn as a trapezoid:

```text
      horizon
   ____small road____
  /                  \
 /                    \
/______________________\
      near camera
```

Road lines move toward the user to create forward motion.

Side objects also move:

```text
Trees
Houses
Street lights
Clouds
Mountains
Rice fields
Coffee shops
Road signs
```

Objects start small near the horizon and become bigger as they move toward the camera.

### Active animation

```text
- Road scrolls
- Vehicle engine/running animation plays
- Wind/cloud/trees move
- Distance counter increases
```

### Idle animation

```text
- Road stops
- Vehicle parks
- Character rests
- Small message: "Paused — idle for 5 minutes"
```

---

## 14. Map View

> **🔒 v1 map (revised per §0.A.1):** the map shows the **whole Vietnam province chain** with the user's current position and travel direction — provinces already passed vs ahead, distance to the next province, and overall % of the country covered. Still **custom-painted** (stylized Vietnam silhouette + province pins), **no live tiles** (see §0.B.3). Teammate markers stay → v2.

The map view shows where the user is on the Vietnam route.

### Map features

```text
- Route line
- Current virtual location
- Next checkpoint
- Completed checkpoints
- Remaining distance
- Teammate markers
- Daily/weekly progress
```

### Recommended map library

Use:

```text
flutter_map
```

Reasons:

```text
- Works on Flutter desktop
- Vendor-free
- Good with OpenStreetMap-style tiles
- More suitable than Google Maps for desktop MVP
```

### Production note

For MVP, OpenStreetMap tiles can be used carefully.

For production, consider:

```text
- Proper paid tile provider
- Self-hosted map tiles
- VietMap or other Vietnam-focused map provider if needed
```

> **🔒 v1 map = custom-painted, no tiles.** For a single scripted route (HCMC→Đà Lạt) you don't need real map tiles — draw the route as a `CustomPainter` polyline with checkpoint pins over a stylized background. This removes the whole OSM tile-usage-policy risk (distributed apps hitting OSM tiles need attribution + a valid User-Agent and can be blocked for bulk use). `flutter_map` + real tiles → **v2**, when geographically-accurate multi-route maps matter.

---

## 15. Mini Floating Window

The app should support a mini mode like a small YouTube picture-in-picture window.

### Mini window requirements

```text
- Always on top
- Resizable
- Can sit in screen corner
- Shows vehicle/character traveling
- Shows active/idle status
- Shows today distance
- Can pause/resume
- Can hide to tray/menu bar
```

### Recommended implementation

Use Flutter desktop window plugins:

```text
window_manager
tray_manager
```

Some behavior may require custom native code per OS.

### Mini window content

```text
[Animated vehicle]
Active / Idle
Today: 42.3 km
Next: Bảo Lộc — 18 km left
```

---

## 16. Main Screens

### 1. Onboarding Screen

Purpose:

```text
- Explain the concept
- Explain privacy
- Ask user to choose idle threshold
- Ask user to choose first route
- Ask user to choose first travel mode
```

Important privacy text:

```text
We only check whether your computer is active or idle.
We never record what you type.
We never capture your screen.
```

### 2. Journey Screen

Main screen.

Includes:

```text
- POV road animation
- Current vehicle/character
- Active/idle status
- Distance traveled today
- Current route progress
- Next checkpoint
```

### 3. Map Screen

Includes:

```text
- Vietnam route map
- Current position
- Checkpoints
- Completed route percentage
- Remaining distance
```

### 4. Route Selection Screen

Includes:

```text
- List of Vietnam routes
- Route distance
- Difficulty
- Suggested travel modes
- Checkpoints
```

### 5. Vehicle Selection Screen

Includes:

```text
- Walk
- Run
- Bicycle
- Motorbike
- Car
- Ship
- Unlockable skins later
```

### 6. Stats Screen

Includes:

```text
- Active time today
- Active time this week
- Distance today
- Distance this week
- Idle time
- Best focus period
- Streak
```

### 7. Leaderboard Screen

Includes:

```text
- Team weekly distance
- Team active time
- Route race progress
- Longest streak
- Checkpoint achievements
```

### 8. Settings Screen

Includes:

```text
- Idle threshold
- Launch at startup
- Mini window settings
- Privacy mode
- Local-only mode
- Notification settings
```

---

## 17. Leaderboard Ideas

> **🔒 v1 recognitions (per §0.A.3):** ship **local milestone achievements/badges** in v1 — e.g. *"100 km this week"*, *"reached the halfway point"*, *"crossed 5 provinces"*, *"3-day streak"*. Encouraging, never shaming (see §18). The competitive **leaderboard below needs a backend → v2** (its own epic).

Leaderboard should be fun, but not toxic.

### Possible metrics

```text
Distance this week
Active minutes today
Active minutes this week
Route progress
Checkpoint count
Consistency streak
Team total distance
```

### Avoid rewarding unhealthy behavior

Do not only reward endless active time.

Better score:

```text
Score = active time + consistency + completed focus sessions + route progress
```

### Suspicious activity handling

In the future, detect obvious cheating:

```text
- Extremely long active time with no break
- Repeated mechanical movement patterns
- 12+ hours active every day
```

For MVP, do not over-engineer this.

---

## 18. Agentic / AI Coach Feature

This can be added after MVP.

The app can include an AI coach that analyzes user/team activity and suggests better productivity patterns.

### AI coach examples

```text
You are usually most active from 9:30–11:00.
Try scheduling your hardest coding task in that period.

You are 12 km away from Đà Lạt.
One more 40-minute focus session can complete the route.

Your team is close to reaching Bảo Lộc.
A 30-minute group focus sprint can finish this checkpoint.

You had many idle gaps after 3 PM this week.
Maybe schedule lighter tasks in the afternoon.
```

### AI should not shame the user

Good:

```text
You had shorter focus sessions today. Consider a lighter route tomorrow.
```

Bad:

```text
You were lazy today.
```

---

## 19. Data Model Draft

### UserSession

```dart
class UserSession {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration activeDuration;
  final Duration idleDuration;
  final double distanceKm;
}
```

### JourneyRoute

```dart
class JourneyRoute {
  final String id;
  final String name;
  final List<RoutePoint> points;
  final List<Checkpoint> checkpoints;
  final double totalDistanceKm;
}
```

### Checkpoint

```dart
class Checkpoint {
  final String id;
  final String name;
  final double distanceFromStartKm;
  final String? description;
  final String? badgeAsset;
}
```

### TravelMode

```dart
enum TravelMode {
  walk,
  run,
  bicycle,
  motorbike,
  car,
  ship,
}
```

### ActivityState

```dart
enum ActivityState {
  active,
  idle,
  paused,
}
```

---

## 20. Journey Engine Draft

> **🔒 v1 refinements to the sketch below (these make it testable — see §0.B.6–7):**
> - **Inject** the clock and the `ActivityPlugin` (don't read `DateTime.now()` or a real timer inside the engine) → deterministic, unit-testable with no wall-clock waits.
> - `tick(delta)` should be fed the **real elapsed time since the last tick**, computed by the caller from timestamps — not a hard-coded 5 s.
> - Track **`rawActiveTime`** (true input time, no grace) alongside `activeTimeToday` (journey time, includes the 5-min grace). Stats/streaks use `rawActiveTime`; distance uses journey time. See §4 note.
> - Distance uses the **speed-only** model (§0.A.4); the energy model is → v2.

```dart
class JourneyEngine {
  Duration activeTimeToday = Duration.zero;
  Duration idleTimeToday = Duration.zero;

  double distanceKm = 0;
  ActivityState state = ActivityState.idle;
  TravelMode mode = TravelMode.motorbike;

  void tick(Duration delta) {
    if (state == ActivityState.active) {
      final speed = speedKmPerHour(mode);
      distanceKm += speed * delta.inSeconds / 3600.0;
      activeTimeToday += delta;
    } else if (state == ActivityState.idle) {
      idleTimeToday += delta;
    }
  }

  double speedKmPerHour(TravelMode mode) {
    switch (mode) {
      case TravelMode.walk:
        return 4;
      case TravelMode.run:
        return 8;
      case TravelMode.bicycle:
        return 15;
      case TravelMode.motorbike:
        return 35;
      case TravelMode.car:
        return 60;
      case TravelMode.ship:
        return 25;
    }
  }
}
```

---

## 21. MVP Scope

### MVP v1 — Local desktop prototype

Goal: validate the core loop.

Features:

```text
- Flutter macOS app
- Flutter Windows app
- Native idle-time detection
- 5-minute idle threshold
- Active/idle status
- Simple JourneyEngine
- POV road animation using Flame
- One route: Ho Chi Minh City → Đà Lạt
- One or two vehicles: motorbike, bicycle
- Local daily progress
- Local settings
```

> **🔒 v1 stack locks (see §0.B):** Flame **only** (Rive → v2) · persistence via `shared_preferences`/JSON (drift → v2) · map = custom-painted route polyline (flutter_map → v2) · state mgmt = Bloc · idle detection **proven by a spike first** (§22 step 0).

No need yet:

```text
- Login
- Cloud sync
- Real leaderboard
- AI coach
- Complex anti-cheat
- Production installer
```

### MVP v2 — Internal team version

Features:

```text
- Mini floating window
- Menu bar/tray
- Multiple Vietnam routes
- More vehicles
- Daily/weekly stats
- Export/import progress
- Internal leaderboard using simple backend or shared server
```

### MVP v3 — Product version

Features:

```text
- Account system
- Cloud sync
- Team leaderboard
- Achievements
- AI productivity coach
- Notifications
- Signed/notarized macOS app
- Better installer
- Privacy policy
```

---

## 22. Implementation Order

Recommended order:

```text
0. ⚠️ SPIKE FIRST — prove real system idle-seconds on macOS in a throwaway Flutter
   window. Check pub.dev for an existing idle/activity package before writing a
   custom plugin. Everything below depends on this working.
1. Create Flutter desktop project (inside src/)
2. Build JourneyEngine in pure Dart — injected clock + injected activity source,
   deterministic & unit-tested; track journey-time AND raw active-time separately
3. Build simple UI showing active/idle/distance (Bloc)
4. Implement macOS idle-time plugin behind the ActivityPlugin interface
5. Implement Windows idle-time plugin
6. Add local storage (shared_preferences/JSON)
6b. ⟶ /source-assets — gather free, license-clean art (road, side objects,
    vehicle skin sprites, backgrounds, icons, fonts) into assets/ + CREDITS.md
7. Add Flame road animation
... (then /self-review + /privacy-audit before any internal build)
8. Connect activity state to road speed (delta from last tick, not assumed 5s)
9. Add motorbike/bicycle vehicle
10. Add route progress model + custom-painted route screen
11. → v2: flutter_map geographic route screen
12. Add mini floating window
13. Add tray/menu-bar behavior
14. → v2: internal leaderboard (needs a backend — its own epic)
15. → v3: AI coach
```

---

## 23. First Prototype Acceptance Criteria

The first prototype is successful if:

```text
- App runs on macOS
- App runs on Windows
- App detects active/idle using system idle time
- App pauses after 5 minutes idle
- App resumes when user becomes active
- Vehicle moves when active
- Vehicle stops when idle
- Distance is saved locally
- User can see route progress from HCMC to Đà Lạt
```

---

## 24. Risks and Solutions

| Risk | Solution |
|---|---|
| Users feel tracked | Strong privacy-first messaging |
| Unsigned macOS app warnings | Fine for internal test; sign/notarize later |
| Browser cannot track computer activity | Use desktop app |
| Animation scope becomes too large | Use stylized 2D, not 3D |
| Flutter desktop native APIs require extra work | Use platform channels |
| Leaderboard encourages unhealthy work | Use consistency and focus sessions, not only raw time |
| App becomes boring | Add routes, checkpoints, skins, badges, team races |
| Easy to cheat | Add simple anomaly checks later |

---

## 25. Recommended First Sprint

### Sprint goal

Build a local macOS/Windows proof of concept.

### Tasks

```text
1. Create Flutter desktop app
2. Add basic app layout:
   - Journey screen
   - Stats panel
   - Settings panel

3. Implement JourneyEngine:
   - active state
   - idle state
   - distance calculation
   - travel mode speed

4. Implement mock activity source:
   - toggle active/idle manually for UI testing

5. Implement native idle-time source:
   - macOS first
   - Windows second

6. Build Flame road scene:
   - road trapezoid
   - moving lane lines
   - simple side trees
   - active speed / idle stop

7. Add first route:
   - Ho Chi Minh City → Đà Lạt
   - checkpoints: HCMC, Biên Hòa, Dầu Giây, Bảo Lộc, Đà Lạt

8. Save local progress:
   - active time today
   - distance today
   - current route progress

9. Package internal build:
   - macOS .app/.zip
   - Windows .zip/.exe
```

---

## 26. One-Sentence Product Pitch

```text
Vietnam Focus Journey turns your active computer time into a virtual trip across Vietnam, helping you stay motivated while keeping your privacy safe.
```

---

## 27. Short Product Description

```text
Vietnam Focus Journey is a desktop productivity game for developers, students, and remote workers. When you are active on your computer, your character travels through Vietnam by motorbike, bicycle, car, ship, or on foot. When you become idle for more than 5 minutes, the journey pauses. The app only checks system idle time and never records keystrokes, screen content, or private data.
```

---

## 28. Final Technical Decision

Use:

```text
Flutter Desktop
+ Flame
+ Rive
+ flutter_map
+ Native macOS/Windows platform channels
```

Do not start with:

```text
Pure web app
Realistic 3D engine
Heavy employee-monitoring features
Global keylogging/mouse hooks
```

The correct MVP is:

```text
Privacy-first desktop productivity game
with system idle-time detection
and a Vietnam-only virtual travel experience.
```
