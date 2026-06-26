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

  /// Ship skin. journey-scene-art-v3: now SHIPPED (original flat side-view boat)
  /// — closes the long-standing journey-scene-v2 ship gap.
  static const String vehicleShip = 'vehicles/ship.png';

  // --- Richer scenery set (journey-scene-v2 #11 / AC-8, re-sourced wholesale by
  //     journey-scene-art-v3 / AC-3). All CC0 / original-flat license-clean,
  //     recorded in assets/CREDITS.md. Grouped by scenery family.
  //
  //     journey-scene-art-v3 / AC-3 NOTE: the four v1 `objects/*` roadside kinds
  //     (tree/house/street_light/sign — Background Elements *Redux* + the
  //     low-craft Pixel Vehicle Pack) were RETIRED in the wholesale re-source.
  //     Neither pack is the signed-off family; their roadside roles are fully
  //     covered by the re-sourced forest / city / countryside kinds below. ---

  // Forest / jungle (roadside trees).
  /// Pine / conifer for highland forest.
  static const String forestPine = 'scenery/forest/pine.png';

  /// Round broadleaf tree.
  static const String forestTreeRound = 'scenery/forest/tree_round.png';

  /// Tall slim tree.
  static const String forestTreeTall = 'scenery/forest/tree_tall.png';

  /// Small sapling (near-road fill).
  static const String forestSapling = 'scenery/forest/sapling.png';

  // Countryside / rice-paddy (low fill).
  /// Roadside bush / paddy-edge greenery.
  static const String countrysideBush = 'scenery/countryside/bush.png';

  /// Alternate bush shape (spacing variety).
  static const String countrysideBushAlt = 'scenery/countryside/bush_alt.png';

  /// Wooden field/paddy fence.
  static const String countrysideFence = 'scenery/countryside/fence.png';

  /// Iron fence variant.
  static const String countrysideFenceIron =
      'scenery/countryside/fence_iron.png';

  /// Tall slim tree variant — palm (tropical Vietnam roadside read). P1
  /// dead-weight fix: was bundled + credited but unmanifested; now a pooled
  /// forest kind so it actually renders.
  static const String forestPalm = 'scenery/forest/palm.png';

  // City / buildings (generic houses).
  /// Generic gable house.
  static const String cityHouseGable = 'scenery/city/house_gable.png';

  /// Small house.
  static const String cityHouseSmall = 'scenery/city/house_small.png';

  /// Alternate gable house (city variety). P1 dead-weight fix: was bundled +
  /// credited but unmanifested; now a pooled city kind so it actually renders.
  static const String cityHouseGableAlt = 'scenery/city/house_gable_alt.png';

  /// Alternate small house (city variety). P1 dead-weight fix: was bundled +
  /// credited but unmanifested; now a pooled city kind so it actually renders.
  static const String cityHouseSmallAlt = 'scenery/city/house_small_alt.png';

  // People / characters (stylized, non-identifiable).
  /// Generic standing person.
  static const String peopleMan = 'people/man.png';

  /// Waving/pointing person.
  static const String peopleManPoint = 'people/man_point.png';

  /// Standing woman (roadside variety). P1 dead-weight fix: was bundled +
  /// credited but unmanifested; now a pooled person kind so it actually renders.
  static const String peopleWoman = 'people/woman.png';

  /// Pointing/waving woman (roadside variety). P1 dead-weight fix: was bundled +
  /// credited but unmanifested; now a pooled person kind so it actually renders.
  static const String peopleWomanPoint = 'people/woman_point.png';

  // --- Far-background parallax layers (journey-scene-v2 #11 / AC-8). Drawn as
  //     scrolling silhouette bands behind the road, not as pooled side objects. ---
  /// Far mountain silhouette band.
  static const String mountainRange = 'scenery/mountains/mountain_range.png';

  /// Rolling-hill far band.
  static const String hills = 'scenery/mountains/hills.png';

  /// Larger rolling-hill far band — the deepest HIGHLAND backdrop layer. P1
  /// dead-weight fix: was bundled + credited but unmanifested; now drawn in the
  /// highland theme (theme 0) of `paintFarBackground` behind [mountainRange] for
  /// extra depth. NOT a pooled side-object (AC-7 even-spacing does not apply).
  static const String hillsLarge = 'scenery/mountains/hills_large.png';

  /// Highland peak silhouette A — layered with [mountainPeakB]/[mountainPeakC]
  /// as foreground peaks within the highland backdrop theme (theme 0). P1
  /// dead-weight fix: bundled + credited but unmanifested; now actually drawn.
  /// NOT a pooled side-object.
  static const String mountainPeakA = 'scenery/mountains/peak_a.png';

  /// Highland peak silhouette B (see [mountainPeakA]). P1 dead-weight fix.
  static const String mountainPeakB = 'scenery/mountains/peak_b.png';

  /// Highland peak silhouette C (see [mountainPeakA]). P1 dead-weight fix.
  static const String mountainPeakC = 'scenery/mountains/peak_c.png';

  /// Far-background beach/coast band (sea + sand horizon). journey-scene-art-v3
  /// AC-5: drawn as ONE MORE far parallax band cycling alongside mountains/hills
  /// by SCROLL PHASE — NOT a pooled side-object, NO geographic logic. Net-new
  /// (closes the journey-scene-v2 procedural-tint approximation). Original flat
  /// vector; transparent above the sea line so it composites over the sky tint.
  static const String coastBand = 'scenery/beach/coast_band.png';

  // --- Sky layer (FURTHEST backdrop, behind the mountain bands). Drawn by
  //     `RoadPainter.paintSky`. The sun/moon are placed by the cosmetic
  //     `timeOfDayHours` (an already-passed-in value — NO clock read); the
  //     clouds drift by SCROLL PHASE ONLY (the same `_motion.offset` the
  //     parallax bands use — NO wall-clock, NO geography). All CC0 (Kenney
  //     Background Elements), recorded in assets/CREDITS.md. A null image is
  //     skipped (graceful degradation → procedural sky stands in, AC-14).
  //     P1 dead-weight fix: these were bundled + credited but unmanifested;
  //     now drawn so they actually render. ---

  /// Sun disc — shown during day hours, arced across the sky by `timeOfDayHours`.
  static const String skySun = 'scenery/sky/sun.png';

  /// Moon disc — shown during night hours, arced across the sky by
  /// `timeOfDayHours` (crossfades with [skySun] across dawn/dusk).
  static const String skyMoon = 'scenery/sky/moon.png';

  /// Drifting cloud sprite 1 (slow scroll-phase parallax, furthest layer).
  static const String skyCloud1 = 'scenery/sky/cloud_1.png';

  /// Drifting cloud sprite 2 (slow scroll-phase parallax, furthest layer).
  static const String skyCloud2 = 'scenery/sky/cloud_2.png';

  /// Drifting cloud sprite 3 (slow scroll-phase parallax, furthest layer).
  static const String skyCloud3 = 'scenery/sky/cloud_3.png';

  // --- Side-view full-body animals (journey-scene-art-v3 #/AC-6). Pooled
  //     SideObjectKinds in the spawn rotation — first-class side-objects, NOT
  //     badge faces. Net-new (closes the journey-scene-v2 "animals dropped"
  //     deviation). Original flat side-profile vectors, license-clean. ---

  /// Side-view water buffalo (Vietnam paddy icon).
  static const String animalWaterBuffalo = 'animals/water_buffalo.png';

  /// Side-view dog.
  static const String animalDog = 'animals/dog.png';

  /// Side-view chicken.
  static const String animalChicken = 'animals/chicken.png';

  /// Side-view bird (sky/roadside variety).
  static const String animalBird = 'animals/bird.png';

  // --- First-person cockpit glyphs (journey-pov). Composited as a FOREGROUND
  //     overlay over the road for TravelMode.car / TravelMode.motorbike ONLY
  //     (AC-1/AC-3/AC-6). Stylized-flat, license-clean: CC BY 3.0 glyphs
  //     (steering wheel / speedometer / fuel gauge — Delapouite, game-icons.net;
  //     CC0 Wikimedia wheel as a zero-attribution fallback) + ORIGINAL flat
  //     dash/handlebar/tank shapes. Sourced/placed/attributed via
  //     `ui-asset-curator` (`/source-assets`); CC BY attribution recorded in
  //     `assets/CREDITS.md` (AC-17). Until populated, the never-throws loader
  //     degrades each to a neutral placeholder (AC-13) and the CockpitPainter
  //     falls back to ORIGINAL flat vector shapes drawn on the canvas (which are
  //     license-clean by construction). ---

  // Car cockpit glyphs.
  /// Car steering wheel glyph (CC BY 3.0 game-icons.net; CC0 Wikimedia fallback).
  static const String cockpitCarSteeringWheel =
      'cockpit/car/steering_wheel.png';

  /// Car flat dashboard shape (original flat vector; license-clean).
  static const String cockpitCarDashboard = 'cockpit/car/dashboard.png';

  /// Car decorative speedometer glyph (CC BY 3.0 game-icons.net). Static —
  /// NOT wired to any speed value (AC-2).
  static const String cockpitCarSpeedometer = 'cockpit/car/speedometer.png';

  /// Car decorative fuel gauge glyph (CC BY 3.0 game-icons.net). Static —
  /// NOT wired to any fuel value (AC-2).
  static const String cockpitCarFuelGauge = 'cockpit/car/fuel_gauge.png';

  // Motorbike cockpit glyphs.
  /// Motorbike handlebar shape (original flat vector; license-clean).
  static const String cockpitMotorbikeHandlebar =
      'cockpit/motorbike/handlebar.png';

  /// Motorbike gauge pod glyph (CC BY 3.0 game-icons.net). Decorative (AC-2).
  static const String cockpitMotorbikeGaugePod =
      'cockpit/motorbike/gauge_pod.png';

  /// Motorbike fuel tank shape (original flat vector; license-clean).
  static const String cockpitMotorbikeFuelTank =
      'cockpit/motorbike/fuel_tank.png';

  // journey-scene-art-v3 / AC-5 + AC-6 (RESOLVED — the journey-scene-v2 gaps are
  // CLOSED): BEACH/COAST now ships as an original flat-vector far parallax band
  // ([coastBand], drawn alongside mountains/hills, cycled by scroll phase, no
  // geographic logic). ANIMALS now ship as original flat-vector side-view
  // full-body sprites ([animalWaterBuffalo]/[animalDog]/[animalChicken]/
  // [animalBird]) wired as pooled SideObjectKinds in the spawn rotation. Both
  // are recorded as the AC-2 rung-2 deviation in assets/CREDITS.md.

  /// Every asset the scene is allowed to load. The CREDITS cross-check
  /// (journey-view TC-011 / journey-scene-v2 TC-009) enumerates exactly this
  /// list — the scene loads NOTHING absent from here, and every entry has a
  /// CC0/permissive row in `assets/CREDITS.md`.
  static const List<String> all = <String>[
    // Vehicles (cosmetic skins).
    vehicleWalk,
    vehicleRun,
    vehicleBicycle,
    vehicleMotorbike,
    vehicleCar,
    vehicleShip,
    // Richer scenery (#11 / AC-8; re-sourced wholesale by art-v3 / AC-3).
    forestPine,
    forestTreeRound,
    forestTreeTall,
    forestSapling,
    forestPalm,
    countrysideBush,
    countrysideBushAlt,
    countrysideFence,
    countrysideFenceIron,
    cityHouseGable,
    cityHouseSmall,
    cityHouseGableAlt,
    cityHouseSmallAlt,
    peopleMan,
    peopleManPoint,
    peopleWoman,
    peopleWomanPoint,
    // Far-background parallax bands (highland theme).
    mountainRange,
    hills,
    hillsLarge,
    mountainPeakA,
    mountainPeakB,
    mountainPeakC,
    // Beach/coast far band (art-v3 / AC-5; net-new).
    coastBand,
    // Sky layer (furthest backdrop; P1 dead-weight fix — were unmanifested).
    skySun,
    skyMoon,
    skyCloud1,
    skyCloud2,
    skyCloud3,
    // Side-view animals (art-v3 / AC-6; net-new pooled kinds).
    animalWaterBuffalo,
    animalDog,
    animalChicken,
    animalBird,
    // First-person cockpit glyphs (journey-pov — car + motorbike only).
    cockpitCarSteeringWheel,
    cockpitCarDashboard,
    cockpitCarSpeedometer,
    cockpitCarFuelGauge,
    cockpitMotorbikeHandlebar,
    cockpitMotorbikeGaugePod,
    cockpitMotorbikeFuelTank,
  ];

  /// The cockpit glyph paths requested for [TravelMode.car], in draw order
  /// (far → near). journey-pov AC-1/AC-17 test seam: assert the car cockpit
  /// requests exactly these and each has a CREDITS entry.
  static const List<String> cockpitCar = <String>[
    cockpitCarDashboard,
    cockpitCarSpeedometer,
    cockpitCarFuelGauge,
    cockpitCarSteeringWheel,
  ];

  /// The cockpit glyph paths requested for [TravelMode.motorbike], in draw
  /// order (far → near). journey-pov AC-3/AC-17 test seam.
  static const List<String> cockpitMotorbike = <String>[
    cockpitMotorbikeFuelTank,
    cockpitMotorbikeGaugePod,
    cockpitMotorbikeHandlebar,
  ];
}
