/// Presentation layer (Flame). Pure asset manifest — no Flutter, no Bloc, no
/// engine, no OS signals. Lists every image the journey scene may load so the
/// `assets/CREDITS.md` cross-check (TC-011) is mechanical and the
/// `/source-assets` step knows exactly which files to populate.
///
/// IMPORTANT (AC-11 / TC-011): the scene loads ONLY paths declared in
/// [JourneyAssets.all]. Do not `images.load(...)` anything not listed here.
/// Every path below must have a matching licence + attribution entry in
/// `assets/CREDITS.md` before it ships. These are stable relative paths under
/// `assets/journey/...`; the `/source-assets` step populates the real Kenney
/// CC0 files and adds the `pubspec.yaml` `assets:` block.
///
/// Flame's image cache is rooted at `assets/images/` by default. To keep all
/// journey art under `assets/journey/` we point the game's image prefix at
/// `assets/journey/` (see `JourneyGame`), so the paths here are RELATIVE to
/// that prefix (e.g. `vehicles/car.png` resolves to
/// `assets/journey/vehicles/car.png`).
library;

/// The single source of truth for the scene's asset paths.
///
/// Grouped by purpose; [all] is the flat manifest the CREDITS test reads.
abstract final class JourneyAssets {
  /// Prefix prepended by Flame's image cache. The game sets
  /// `images.prefix = assetPrefix` so every path here is relative to it.
  static const String assetPrefix = 'assets/journey/';

  // --- Vehicle skins (one per TravelMode; cosmetic only — AC-8). ---

  /// Walking traveller skin.
  static const String vehicleWalk = 'vehicles/walk.png';

  /// Running traveller skin.
  static const String vehicleRun = 'vehicles/run.png';

  /// Bicycle skin.
  static const String vehicleBicycle = 'vehicles/bicycle.png';

  /// Motorbike skin — the v1 default.
  static const String vehicleMotorbike = 'vehicles/motorbike.png';

  /// Car skin.
  static const String vehicleCar = 'vehicles/car.png';

  /// Ship skin.
  static const String vehicleShip = 'vehicles/ship.png';

  // --- Parallax side objects (spawn at horizon, scale toward camera). ---

  /// Roadside tree.
  static const String tree = 'objects/tree.png';

  /// Roadside house.
  static const String house = 'objects/house.png';

  /// Roadside street light.
  static const String streetLight = 'objects/street_light.png';

  /// Road sign.
  static const String sign = 'objects/sign.png';

  // NOTE: distant background parallax layers (mountains, rice fields, clouds)
  // are deferred to a later polish wave. They are intentionally NOT in the v1
  // manifest — RoadPainter draws the sky/ground procedurally.

  /// Every asset the scene is allowed to load. The CREDITS cross-check
  /// (TC-011) enumerates exactly this list.
  static const List<String> all = <String>[
    vehicleWalk,
    vehicleRun,
    vehicleBicycle,
    vehicleMotorbike,
    vehicleCar,
    vehicleShip,
    tree,
    house,
    streetLight,
    sign,
  ];
}
