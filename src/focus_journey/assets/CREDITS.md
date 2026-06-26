# Asset credits

All shipped assets are **CC0 1.0 Universal (public domain)** by **Kenney** (https://kenney.nl).
CC0 requires no attribution; Kenney is credited here voluntarily as a courtesy.
License text: https://creativecommons.org/publicdomain/zero/1.0/

Every file the journey scene is allowed to load is declared in
`lib/features/journey/presentation/game/journey_assets.dart` (`JourneyAssets.all`).
The scene degrades gracefully (renders a placeholder) for any manifest path that is
not yet shipped.

## Journey scene

| File (under assets/journey/) | Source pack | Source URL | Author | Licence | Attribution / notes |
| --- | --- | --- | --- | --- | --- |
| vehicles/walk.png | Pixel Vehicle Pack | https://kenney.nl/assets/pixel-vehicle-pack | Kenney | CC0 1.0 | From `PNG/Characters/man_walk1.png` (side-view walking person). |
| vehicles/run.png | Pixel Vehicle Pack | https://kenney.nl/assets/pixel-vehicle-pack | Kenney | CC0 1.0 | From `PNG/Characters/man_walk2.png` (2nd walk frame, reused as the running skin). |
| vehicles/bicycle.png | Pixel Vehicle Pack | https://kenney.nl/assets/pixel-vehicle-pack | Kenney | CC0 1.0 | From `PNG/Cars/cycle.png` (side-view bicycle). |
| vehicles/motorbike.png | Pixel Vehicle Pack | https://kenney.nl/assets/pixel-vehicle-pack | Kenney | CC0 1.0 | From `PNG/Cars/scooter.png` (side-view scooter, used as the motorbike skin). |
| vehicles/car.png | Pixel Vehicle Pack | https://kenney.nl/assets/pixel-vehicle-pack | Kenney | CC0 1.0 | **REPLACED by journey-scene-art-v3** — see the art-v3 catalogue below (original flat side-view car, 384×192). The pixel sedan row is retained only as the AC-9 predecessor record. |

> **journey-scene-art-v3 / AC-3 (RESOLVED):** the four v1 `objects/*` roadside
> kinds — `objects/tree.png`, `objects/house.png`, `objects/street_light.png`,
> `objects/sign.png` (from Background Elements *Redux* + the low-craft Pixel
> Vehicle Pack) — were **RETIRED** in the wholesale re-source and removed from
> the bundle + `JourneyAssets`. Their roadside roles are covered by the
> re-sourced forest / city / countryside kinds. The six vehicle skins +
> man/man_point people were **REPLACED** by original flat side-view vectors (see
> the journey-scene-art-v3 catalogue below for sources, licences, and the AC-9
> predecessor→new dimensions).

> Distant background parallax layers were trialled in v1, then shipped as bands
> in journey-scene-v2 (mountains/hills) and re-sourced in journey-scene-art-v3
> (original 2× bands + the net-new beach/coast band) — see below.

## journey-pov first-person cockpit glyphs (#2 / AC-16 / AC-17)

The stylized-flat first-person cockpit (car + motorbike) is built from two kinds
of art, recoloured to the journey palette to stay cohesive with the Kenney-flat
scene (AC-16):

1. **Sourced glyph primitives** — `CC BY 3.0` icons by **Delapouite** at
   **game-icons.net**. CC BY **requires attribution**, so each carries a full
   File / Source / Author / Licence row below (AC-17 — stronger than the CC0
   scenery rows above, which need no attribution).
2. **Original flat shapes** — the large dashboard / handlebar / fuel-tank are
   drawn **procedurally by `CockpitPainter`** as ORIGINAL flat vectors (no
   third-party licence); their manifest PNG paths are intentionally left
   unfilled so the never-throws loader degrades them to the procedural shape
   (AC-13). They are listed below so the AC-17 cross-check ("every requested
   cockpit asset path has a CREDITS entry") passes for all 7 paths.

CC BY 3.0 attribution / recolour notes: the source SVGs were taken from
game-icons.net (black-on-transparent variant), their fill recoloured from black
to the journey "lane cream" `#E8E2C8` (so each glyph reads as light ticks/lines
over the painter's dark `#11151B` gauge bezel and `#1B1E24` wheel rim — AC-16),
then rasterized to transparent PNG with `rsvg-convert`. No path data was altered;
only the fill colour and raster size. License text:
https://creativecommons.org/licenses/by/3.0/

### Cockpit — sourced glyphs (CC BY 3.0 — attribution REQUIRED, AC-17)

| File (under assets/journey/) | Source pack | Source URL | Author | Licence | Attribution / notes |
| --- | --- | --- | --- | --- | --- |
| cockpit/car/steering_wheel.png | game-icons.net | https://game-icons.net/1x1/delapouite/steering-wheel.html | Delapouite | CC BY 3.0 | "Steering wheel" glyph. Attribution: *Steering wheel icon by Delapouite under CC BY 3.0* (https://game-icons.net). Recoloured to `#E8E2C8`, 256px. |
| cockpit/car/speedometer.png | game-icons.net | https://game-icons.net/1x1/delapouite/speedometer.html | Delapouite | CC BY 3.0 | "Speedometer" glyph — **decorative only**, NOT wired to any speed value (AC-2). Attribution: *Speedometer icon by Delapouite under CC BY 3.0*. Recoloured to `#E8E2C8`, 192px. |
| cockpit/car/fuel_gauge.png | game-icons.net | https://game-icons.net/1x1/delapouite/fuel-tank.html | Delapouite | CC BY 3.0 | From the "Fuel tank" glyph (reads as a flat fuel/tank gauge) — **decorative only**, NOT wired to any fuel value (AC-2). Attribution: *Fuel tank icon by Delapouite under CC BY 3.0*. Recoloured to `#E8E2C8`, 192px. |
| cockpit/motorbike/gauge_pod.png | game-icons.net | https://game-icons.net/1x1/delapouite/speedometer.html | Delapouite | CC BY 3.0 | "Speedometer" glyph reused for the motorbike gauge pod — **decorative only** (AC-2). Attribution: *Speedometer icon by Delapouite under CC BY 3.0*. Recoloured to `#E8E2C8`, 192px. |

### Cockpit — procedural shapes (no file; original flat vectors, no licence)

| Manifest path | Reason it is left unfilled |
| --- | --- |
| cockpit/car/dashboard.png | Large flat dashboard body — drawn **procedurally** by `CockpitPainter` as an ORIGINAL flat vector (license-clean by construction). No cohesive license-clean flat asset would improve on it, so the PNG path is deliberately left unfilled and the never-throws loader degrades it to the procedural shape (AC-13). |
| cockpit/motorbike/handlebar.png | Large flat handlebar — drawn **procedurally** (original flat vector). Left unfilled deliberately; degrades to the procedural shape (AC-13). |
| cockpit/motorbike/fuel_tank.png | Large flat fuel tank body — drawn **procedurally** (original flat vector). Left unfilled deliberately; degrades to the procedural shape (AC-13). |

> All 7 journey-pov cockpit manifest paths now have a CREDITS entry (4 sourced
> CC BY 3.0 glyphs above + 3 intentionally-procedural shapes) — AC-17 cross-check
> passes. The scene loads no cockpit asset absent from this file.

## Vehicle-picker per-mode icons (vehicle-picker AC-14 / AC-15)

The vehicle picker shows one distinct flat glyph per `TravelMode`
(`walk` / `run` / `bicycle` / `motorbike` / `car` / `ship`) so choosing a vehicle
is fun and visual — NOT a text dropdown (AC-14). These are PICKER-UI icons, kept
separate from the in-scene side-view sprites under `assets/journey/vehicles/`
(those are the rendered skins; these are the chooser affordances).

**Source / licence:** all six are **`CC BY 3.0`** glyphs from **game-icons.net** —
the SAME established source/family as the journey-pov cockpit glyphs above, so the
picker stays cohesive with the shipped art. CC BY **requires attribution**, so
each carries a full File / Source / Author / Licence row below (AC-15 — stronger
than the CC0 scenery rows). Five are by **Delapouite**; the `run` glyph is by
**Lorc** (game-icons.net's only clean running-figure glyph) — both are
game-icons.net authors under the identical CC BY 3.0 licence, and at chip size
the single-colour silhouettes read as one set.

**Recolour / build notes (no path geometry changed):** each source SVG
(512×512, white foreground path on a black bounding square) had its black
bounding-square path **removed** (→ transparent background) and its `#fff` fill
recoloured to the journey slate **`#2D3142`** so the silhouette — not colour —
carries the mode (NFR-3), then rasterized to a 144×144 transparent PNG with
`rsvg-convert` (3× of the ~48px chip for Retina). Only the background-square
removal, fill colour, and raster size changed. License text:
https://creativecommons.org/licenses/by/3.0/

### Vehicle-picker icons (CC BY 3.0 — attribution REQUIRED, AC-15)

| File (under assets/journey/) | TravelMode | Source URL | Author | Licence | Attribution / notes |
| --- | --- | --- | --- | --- | --- |
| vehicle_icons/walk.png | `TravelMode.walk` | https://game-icons.net/1x1/delapouite/walk.html | Delapouite | CC BY 3.0 | "Walk" glyph (side-view walking figure). Attribution: *Walk icon by Delapouite under CC BY 3.0* (https://game-icons.net). Recoloured to `#2D3142`, bg square removed, 144px. |
| vehicle_icons/run.png | `TravelMode.run` | https://game-icons.net/1x1/lorc/run.html | Lorc | CC BY 3.0 | "Run" glyph (leaning running figure — distinct from walk). Attribution: *Run icon by Lorc under CC BY 3.0* (https://game-icons.net). Recoloured to `#2D3142`, bg square removed, 144px. |
| vehicle_icons/bicycle.png | `TravelMode.bicycle` | https://game-icons.net/1x1/delapouite/cycling.html | Delapouite | CC BY 3.0 | "Cycling" glyph (cyclist on a bicycle). Attribution: *Cycling icon by Delapouite under CC BY 3.0* (https://game-icons.net). Recoloured to `#2D3142`, bg square removed, 144px. |
| vehicle_icons/motorbike.png | `TravelMode.motorbike` | https://game-icons.net/1x1/delapouite/scooter.html | Delapouite | CC BY 3.0 | "Scooter" glyph (used as the motorbike icon — matches the in-scene scooter-derived motorbike skin). Attribution: *Scooter icon by Delapouite under CC BY 3.0* (https://game-icons.net). Recoloured to `#2D3142`, bg square removed, 144px. |
| vehicle_icons/car.png | `TravelMode.car` | https://game-icons.net/1x1/delapouite/city-car.html | Delapouite | CC BY 3.0 | "City car" glyph (clean side-view car). Attribution: *City car icon by Delapouite under CC BY 3.0* (https://game-icons.net). Recoloured to `#2D3142`, bg square removed, 144px. |
| vehicle_icons/ship.png | `TravelMode.ship` | https://game-icons.net/1x1/delapouite/sailboat.html | Delapouite | CC BY 3.0 | "Sailboat" glyph (clean boat silhouette; chosen over the busier `cargo-ship` for legibility at chip size). Attribution: *Sailboat icon by Delapouite under CC BY 3.0* (https://game-icons.net). Recoloured to `#2D3142`, bg square removed, 144px. |

> All 6 vehicle-picker icons are CC BY 3.0 (attribution recorded per-row above) —
> AC-15 cross-check passes. The picker loads no icon absent from this file. Path →
> mode mapping for the implementer: `vehicle_icons/{walk,run,bicycle,motorbike,car,ship}.png`
> → `TravelMode.{walk,run,bicycle,motorbike,car,ship}` respectively.

## Source pack provenance

- **Pixel Vehicle Pack** — Kenney, CC0 1.0. https://kenney.nl/assets/pixel-vehicle-pack
  Cohesive pixel-art side-view set: vehicles, characters (walk frames), and roadside props (lamp, signs).
- **Background Elements Redux** — Kenney, CC0 1.0. https://kenney.nl/assets/background-elements-redux
  (Mirror used for download: https://opengameart.org/content/background-elements-redux)
  Flat-vector side-view scenery; v1 ships only the roadside `tree.png` and `house.png` from this pack.

Style note: foreground vehicles/props are pixel-art (Pixel Vehicle Pack) while the roadside
tree/house are flat-vector (Background Elements Redux). Both are Kenney CC0. The style
difference is mild at the roadside scale and reads as depth, not clash.

## Journey scene — richer scenery (journey-scene-v2, #11 / AC-8)

Expanded, cohesive roadside + background scenery for the v2 scene. All assets are
**CC0 1.0** from **Kenney** flat-vector / pixel packs, chosen to extend the existing
single-Kenney-pack cohesion rule (scenery from *Background Elements Redux* — the same
pack v1's `tree.png` / `house.png` came from; people from *Pixel Vehicle Pack* — the
same pack the shipped vehicle/walk skins came from). CC0 requires no attribution;
Kenney credited voluntarily. License text: https://creativecommons.org/publicdomain/zero/1.0/

Content-appropriateness (AC / review gate): people are simple, abstract, **non-realistic
and non-identifiable** generic figures; no realistic/identifiable individuals. European
medieval `castle*`/`tower*`/`pyramid*` sprites in the redux pack were deliberately **NOT**
imported for the "city/buildings" category to avoid an off-theme depiction of Vietnam —
generic gable/small houses are used instead.

### Scenery — mountains / hills (far-background parallax bands + peaks)

| File (under assets/journey/) | Source pack | Source URL | Author | Licence | Used for |
| --- | --- | --- | --- | --- | --- |
| scenery/mountains/mountain_range.png | Background Elements Redux | https://kenney.nl/assets/background-elements-redux | Kenney | CC0 1.0 | Far mountain silhouette band (from `Backgrounds/Elements/mountains.png`, 1024×400, tintable). |
| scenery/mountains/hills.png | Background Elements Redux | https://kenney.nl/assets/background-elements-redux | Kenney | CC0 1.0 | Rolling-hill far band (from `hills.png`). |
| scenery/mountains/hills_large.png | Background Elements Redux | https://kenney.nl/assets/background-elements-redux | Kenney | CC0 1.0 | Larger rolling-hill band (from `hillsLarge.png`). |
| scenery/mountains/peak_a.png | Background Elements Redux | https://kenney.nl/assets/background-elements-redux | Kenney | CC0 1.0 | Individual mountain peak (from `mountainA.png`). |
| scenery/mountains/peak_b.png | Background Elements Redux | https://kenney.nl/assets/background-elements-redux | Kenney | CC0 1.0 | Individual mountain peak (from `mountainB.png`). |
| scenery/mountains/peak_c.png | Background Elements Redux | https://kenney.nl/assets/background-elements-redux | Kenney | CC0 1.0 | Individual tall mountain peak (from `mountainC.png`). |

### Scenery — forest / jungle (trees)

| File (under assets/journey/) | Source pack | Source URL | Author | Licence | Used for |
| --- | --- | --- | --- | --- | --- |
| scenery/forest/palm.png | Background Elements Redux | https://kenney.nl/assets/background-elements-redux | Kenney | CC0 1.0 | Palm tree (Vietnam tropical feel; from `treePalm.png` — same sprite as v1's `objects/tree.png`). |
| scenery/forest/pine.png | Background Elements Redux | https://kenney.nl/assets/background-elements-redux | Kenney | CC0 1.0 | Pine/conifer for highland forest (from `treePine.png`). |
| scenery/forest/tree_round.png | Background Elements Redux | https://kenney.nl/assets/background-elements-redux | Kenney | CC0 1.0 | Round broadleaf tree (from `tree.png`). |
| scenery/forest/tree_tall.png | Background Elements Redux | https://kenney.nl/assets/background-elements-redux | Kenney | CC0 1.0 | Tall slim tree (from `treeLong.png`). |
| scenery/forest/sapling.png | Background Elements Redux | https://kenney.nl/assets/background-elements-redux | Kenney | CC0 1.0 | Small sapling for near-road fill (from `treeSmall_green1.png`). |

### Scenery — countryside / rice-paddy (low fill)

| File (under assets/journey/) | Source pack | Source URL | Author | Licence | Used for |
| --- | --- | --- | --- | --- | --- |
| scenery/countryside/bush.png | Background Elements Redux | https://kenney.nl/assets/background-elements-redux | Kenney | CC0 1.0 | Roadside bush / paddy-edge greenery (from `bush1.png`). |
| scenery/countryside/bush_alt.png | Background Elements Redux | https://kenney.nl/assets/background-elements-redux | Kenney | CC0 1.0 | Alternate bush shape for spacing variety (from `bushAlt1.png`). |
| scenery/countryside/fence.png | Background Elements Redux | https://kenney.nl/assets/background-elements-redux | Kenney | CC0 1.0 | Wooden field/paddy fence (from `fence.png`). |
| scenery/countryside/fence_iron.png | Background Elements Redux | https://kenney.nl/assets/background-elements-redux | Kenney | CC0 1.0 | Iron fence variant (from `fenceIron.png`). |

### Scenery — city / buildings (generic houses)

| File (under assets/journey/) | Source pack | Source URL | Author | Licence | Used for |
| --- | --- | --- | --- | --- | --- |
| scenery/city/house_gable.png | Background Elements Redux | https://kenney.nl/assets/background-elements-redux | Kenney | CC0 1.0 | Generic gable house (from `houseAlt1.png`). |
| scenery/city/house_gable_alt.png | Background Elements Redux | https://kenney.nl/assets/background-elements-redux | Kenney | CC0 1.0 | Generic gable house variant (from `houseAlt2.png`). |
| scenery/city/house_small.png | Background Elements Redux | https://kenney.nl/assets/background-elements-redux | Kenney | CC0 1.0 | Small house (from `houseSmall1.png`). |
| scenery/city/house_small_alt.png | Background Elements Redux | https://kenney.nl/assets/background-elements-redux | Kenney | CC0 1.0 | Small house variant (from `houseSmall2.png`). |

### Scenery — sky (clouds + day/night markers)

| File (under assets/journey/) | Source pack | Source URL | Author | Licence | Used for |
| --- | --- | --- | --- | --- | --- |
| scenery/sky/cloud_1.png | Background Elements Redux | https://kenney.nl/assets/background-elements-redux | Kenney | CC0 1.0 | Drifting cloud (from `cloud1.png`). |
| scenery/sky/cloud_2.png | Background Elements Redux | https://kenney.nl/assets/background-elements-redux | Kenney | CC0 1.0 | Drifting cloud variant (from `cloud3.png`). |
| scenery/sky/cloud_3.png | Background Elements Redux | https://kenney.nl/assets/background-elements-redux | Kenney | CC0 1.0 | Drifting cloud variant (from `cloud5.png`). |
| scenery/sky/sun.png | Background Elements Redux | https://kenney.nl/assets/background-elements-redux | Kenney | CC0 1.0 | Sun for the day tint (from `sun.png`). |
| scenery/sky/moon.png | Background Elements Redux | https://kenney.nl/assets/background-elements-redux | Kenney | CC0 1.0 | Moon for the night tint (from `moonFull.png`). |

### People / characters (stylized, non-identifiable)

| File (under assets/journey/) | Source pack | Source URL | Author | Licence | Used for |
| --- | --- | --- | --- | --- | --- |
| people/man.png | Pixel Vehicle Pack | https://kenney.nl/assets/pixel-vehicle-pack | Kenney | CC0 1.0 | Generic standing figure (from `PNG/Characters/man.png`; same pixel family as the shipped walk/run skins). |
| people/man_point.png | Pixel Vehicle Pack | https://kenney.nl/assets/pixel-vehicle-pack | Kenney | CC0 1.0 | Waving/pointing figure for roadside variety (from `man_point.png`). |
| people/woman.png | Pixel Vehicle Pack | https://kenney.nl/assets/pixel-vehicle-pack | Kenney | CC0 1.0 | Generic standing figure (from `woman.png`). |
| people/woman_point.png | Pixel Vehicle Pack | https://kenney.nl/assets/pixel-vehicle-pack | Kenney | CC0 1.0 | Waving/pointing figure (from `woman_point.png`). |

### journey-scene-v2 categories NOT sourced — **RESOLVED by journey-scene-art-v3**

| Category | journey-scene-v2 status | journey-scene-art-v3 resolution |
| --- | --- | --- |
| **Beach / coast (water, sand, waves)** | Deferred — no flat-vector coast sprite in the Kenney family; tropical read approximated procedurally. | **RESOLVED (AC-5).** Closed with `scenery/beach/coast_band.png` — an original flat-vector sea/sand horizon **band** (net-new) drawn as one more far parallax backdrop theme cycling by scroll phase alongside mountains/hills. No geographic logic. See the art-v3 catalogue below. |
| **Animals (side-view, full-body)** | Dropped — Kenney's animal packs are badge-style faces, not side profiles. | **RESOLVED (AC-6).** Closed with `animals/{water_buffalo,dog,chicken,bird}.png` — original flat-vector **side-profile full-body** animals (net-new) wired as pooled `SideObjectKind`s in the spawn rotation. NOT badge faces. See the art-v3 catalogue below. |

## Source pack provenance (journey-scene-v2 additions)

- **Background Elements Redux** — Kenney, CC0 1.0. https://kenney.nl/assets/background-elements-redux
  (Download mirror used, with embedded `License.txt` confirming CC0: https://opengameart.org/content/background-elements-redux)
  Same pack as v1's roadside `tree.png` / `house.png`. ~90 flat-vector PNGs; this slice adds
  mountains/hills (background bands + peaks), more trees, bushes/fences, generic houses, and sky elements.
- **Pixel Vehicle Pack** ("Pixel Car Pack") — Kenney, CC0 1.0. https://kenney.nl/assets/pixel-vehicle-pack
  (Download mirror: https://opengameart.org/content/pixel-vehicle-pack) Same pack as the shipped
  vehicle + walk/run skins; this slice adds its generic `man`/`woman` figures as roadside people.

Style note: scenery is flat-vector (Background Elements Redux) and the people are pixel-art
(Pixel Vehicle Pack) — identical to the established v1 mix, where the difference reads as depth,
not clash, at roadside scale.

## Tray / menu-bar icons (mini-window slice)

The system-tray / menu-bar state icons are **monochrome line glyphs from Lucide**
(https://lucide.dev), released under the **ISC License**. The three glyphs used
(`car-front`, `circle-parking`, `route`) are core Lucide icons (NOT in Lucide's
Feather-derived MIT subset), so they are covered by Lucide's ISC license.

ISC requires the copyright notice be retained — it is kept verbatim in
`assets/tray/LICENSE-lucide.txt` and reproduced here:

> ISC License — Copyright (c) Lucide Icons and Contributors. Permission to use,
> copy, modify, and/or distribute this software for any purpose with or without
> fee is hereby granted, provided that the above copyright notice and this
> permission notice appear in all copies.

These are STATIC icons (no animation — per mini-window AC-11's resolved
"static tray icon" decision); active vs idle/paused is conveyed by the icon
**variant** (car vs. parking-P) and tooltip, not motion.

**Per-OS format:** macOS menu-bar wants a monochrome **template** image (pure
black + alpha; the OS recolors it for light/dark) — these are the
`*_template*.png` files and the canonical `tray_<state>.png` (+`@2x`) the tray
controller loads with `setIcon(..., isTemplate: true)`. Windows tray wants a
small **colored** icon — these are the `*_color*.png` files (active = journey
green `#1F7A4D`, paused = grey `#8A9099`, neutral = slate `#2D3142`); wire those
with `isTemplate: false` on Windows. All optimised PNG with transparency; `@2x`
are Retina/high-DPI variants (`tray_manager` auto-picks `@2x`).

| File (under assets/tray/) | Glyph | Variant / size | Source pack | Source URL | Author | Licence |
| --- | --- | --- | --- | --- | --- | --- |
| tray_active.png | car-front | macOS template, 18px (canonical active) | Lucide | https://lucide.dev/icons/car-front | Lucide Icons & Contributors | ISC |
| tray_active@2x.png | car-front | macOS template, 36px @2x | Lucide | https://lucide.dev/icons/car-front | Lucide Icons & Contributors | ISC |
| tray_active_template.png / _template@2x.png | car-front | macOS template, 18/36px (explicit name) | Lucide | https://lucide.dev/icons/car-front | Lucide Icons & Contributors | ISC |
| tray_active_template_16/22/32/44.png | car-front | macOS template size ladder | Lucide | https://lucide.dev/icons/car-front | Lucide Icons & Contributors | ISC |
| tray_active_color.png / _color@2x.png / _color_16/32/44.png | car-front | Windows colored (green #1F7A4D) | Lucide | https://lucide.dev/icons/car-front | Lucide Icons & Contributors | ISC |
| tray_paused.png | circle-parking | macOS template, 18px (canonical paused) | Lucide | https://lucide.dev/icons/circle-parking | Lucide Icons & Contributors | ISC |
| tray_paused@2x.png | circle-parking | macOS template, 36px @2x | Lucide | https://lucide.dev/icons/circle-parking | Lucide Icons & Contributors | ISC |
| tray_paused_template.png / _template@2x.png | circle-parking | macOS template, 18/36px (explicit name) | Lucide | https://lucide.dev/icons/circle-parking | Lucide Icons & Contributors | ISC |
| tray_paused_template_16/22/32/44.png | circle-parking | macOS template size ladder | Lucide | https://lucide.dev/icons/circle-parking | Lucide Icons & Contributors | ISC |
| tray_paused_color.png / _color@2x.png / _color_16/32/44.png | circle-parking | Windows colored (grey #8A9099) | Lucide | https://lucide.dev/icons/circle-parking | Lucide Icons & Contributors | ISC |
| tray_neutral.png | route | macOS template, 18px (default/neutral) | Lucide | https://lucide.dev/icons/route | Lucide Icons & Contributors | ISC |
| tray_neutral@2x.png | route | macOS template, 36px @2x | Lucide | https://lucide.dev/icons/route | Lucide Icons & Contributors | ISC |
| tray_neutral_template.png / _template@2x.png | route | macOS template, 18/36px (explicit name) | Lucide | https://lucide.dev/icons/route | Lucide Icons & Contributors | ISC |
| tray_neutral_template_16/22/32/44.png | route | macOS template size ladder | Lucide | https://lucide.dev/icons/route | Lucide Icons & Contributors | ISC |
| tray_neutral_color.png / _color@2x.png / _color_16/32/44.png | route | Windows colored (slate #2D3142) | Lucide | https://lucide.dev/icons/route | Lucide Icons & Contributors | ISC |
| LICENSE-lucide.txt | — | Lucide ISC license text (retained per ISC) | Lucide | https://lucide.dev/license | Lucide Icons & Contributors | ISC |

### Cockpit source provenance (journey-pov)

- **game-icons.net** — glyphs by **Delapouite**, **CC BY 3.0**. https://game-icons.net
  CC BY **requires attribution** (recorded per-file above; full text:
  https://creativecommons.org/licenses/by/3.0/). Source SVGs (black-on-transparent
  variant) were recoloured (black fill → journey lane-cream `#E8E2C8`) and
  rasterized to transparent PNG; no path geometry was changed. The CC0 Wikimedia
  steering-wheel was available as a zero-attribution fallback but the cohesive
  Delapouite set was chosen instead (AC-16), so the CC BY attribution above is
  the binding obligation. The car dashboard / motorbike handlebar / motorbike
  fuel tank are NOT sourced here — they are original flat vectors drawn by
  `CockpitPainter` (no third-party licence).

### Vehicle-picker icon source provenance

- **game-icons.net** — glyphs by **Delapouite** (walk/cycling/scooter/city-car/
  sailboat) and **Lorc** (run), **CC BY 3.0**. https://game-icons.net
  Deliberately the SAME source family as the cockpit glyphs above, so the picker
  reads as one set with the shipped art. CC BY **requires attribution** (recorded
  per-file in the "Vehicle-picker icons" table; full text:
  https://creativecommons.org/licenses/by/3.0/). Source SVGs had their black
  bounding-square path removed (transparent bg) and `#fff` fill recoloured to the
  journey slate `#2D3142`, then rasterized to 144px transparent PNG; no path
  geometry was changed. These are the PICKER chooser icons — separate from the
  in-scene side-view vehicle sprites under `vehicles/` (the rendered skins).

### Tray source provenance

- **Lucide** — Lucide Icons & Contributors, **ISC License**. https://lucide.dev/license
  Clean monochrome stroke icons; the three used (`car-front`, `circle-parking`,
  `route`) export cleanly to macOS template images and read at 16–18px. Glyphs
  chosen to stay on-theme with the shipped journey scene (a vehicle on a route)
  while remaining legible at tray scale — where the Kenney pixel-art vehicle
  sprites used in the scene would not render clearly or make a clean template.

## journey-scene-art-v3 — SHIPPED cohesive re-source (Wave 1, visual-polish epic)

> **SHIPPED 2026-06-25.** The art-direction spike (spec AC-1) was **SIGNED OFF by
> Kevin (2026-06-25)** and these assets are now live: referenced by
> `JourneyAssets` / `journey_assets.dart`, bundled via `pubspec.yaml`, and drawn
> by the scene. The four v1 `objects/*` roadside kinds were retired (AC-3); the
> six vehicle skins + man/man_point people were replaced; mountains/hills bands
> were re-drawn at 2×; and the net-new beach/coast band + side-view animals close
> the long-standing journey-scene-v2 AC-8 gaps. Predecessor→new PNG dimensions
> below are the **AC-9** evidence (replacements are strictly higher-res; net-new
> assets — beach band, animals, ship — are AC-9 exempt).
>
> **Fallback rung used (spec AC-2) — explicit, SIGNED-OFF deviation (Kevin,
> 2026-06-25):** this spike landed on a **HYBRID of rung 1 + rung 2**. No single
> CC0/permissive family covers side-view full-body animals **and** beach **and**
> side-view vehicles cohesively (confirmed in the coverage matrix below). So:
> scenery/sky = **rung-1 family switch** to *Background Elements Remastered*
> (Kenney's higher-craft CC0 successor to the shipped *Redux* pack, clean 2×
> Retina lift); **vehicles + people + animals + beach band + the two parallax
> bands = rung-2 ORIGINAL flat vectors** drawn to the Kenney-flat palette
> (`#B7E7FA` sky, `#23BF76` green, `#E58032`/`#E8503A` warm, `#F0E3C2`/`#FFF8E7`
> cream, `#2D3142` slate) — **"original, no third-party licence"**, license-clean
> by construction. The rung-2 use is the recorded AC-2 deviation, signed off by
> Kevin 2026-06-25 (no silent category drop).

### A) Scenery / sky — rung-1 family switch to Background Elements Remastered (CC0, 2× Retina lift)

Same Kenney flat-vector pack family as the shipped *Background Elements Redux*,
but the **Remastered** edition ships Retina (2×) PNGs — a clean strict
resolution increase for AC-9. CC0 1.0; Kenney credited voluntarily.

| File (under assets/journey/) | Replaces predecessor path | Predecessor dims → new dims (AC-9) | Source pack | Source URL | Author | Licence | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| scenery/forest/pine.png | scenery/forest/pine.png | 106×254 → 212×508 | Background Elements Remastered | https://kenney.nl/assets/background-elements-remastered | Kenney | CC0 1.0 | Retina `treePine.png`. |
| scenery/forest/tree_round.png | scenery/forest/tree_round.png | 94×204 → 188×408 | Background Elements Remastered | https://kenney.nl/assets/background-elements-remastered | Kenney | CC0 1.0 | Retina `tree.png`. |
| scenery/forest/tree_tall.png | scenery/forest/tree_tall.png | 82×249 → 163×498 | Background Elements Remastered | https://kenney.nl/assets/background-elements-remastered | Kenney | CC0 1.0 | Retina `treeLong.png`. |
| scenery/forest/sapling.png | scenery/forest/sapling.png | 20×43 → 40×86 | Background Elements Remastered | https://kenney.nl/assets/background-elements-remastered | Kenney | CC0 1.0 | Retina `treeSmall_green1.png`. |
| scenery/forest/palm.png | (objects/tree.png / forest palm) | 200×238 → 400×476 | Background Elements Remastered | https://kenney.nl/assets/background-elements-remastered | Kenney | CC0 1.0 | Retina `treePalm.png` (Vietnam tropical read). |
| scenery/countryside/bush.png | scenery/countryside/bush.png | 120×60 → 240×120 | Background Elements Remastered | https://kenney.nl/assets/background-elements-remastered | Kenney | CC0 1.0 | Retina `bush1.png`. |
| scenery/countryside/bush_alt.png | scenery/countryside/bush_alt.png | 141×47 → 282×95 | Background Elements Remastered | https://kenney.nl/assets/background-elements-remastered | Kenney | CC0 1.0 | Retina `bushAlt1.png`. |
| scenery/countryside/fence.png | scenery/countryside/fence.png | 104×77 → 207×155 | Background Elements Remastered | https://kenney.nl/assets/background-elements-remastered | Kenney | CC0 1.0 | Retina `fence.png`. |
| scenery/countryside/fence_iron.png | scenery/countryside/fence_iron.png | 120×121 → 240×242 | Background Elements Remastered | https://kenney.nl/assets/background-elements-remastered | Kenney | CC0 1.0 | Retina `fenceIron.png`. |
| scenery/city/house_gable.png | scenery/city/house_gable.png | 168×224 → 335×448 | Background Elements Remastered | https://kenney.nl/assets/background-elements-remastered | Kenney | CC0 1.0 | Retina `houseAlt1.png`. |
| scenery/city/house_gable_alt.png | scenery/city/house_gable_alt.png | 241×217 → 482×434 | Background Elements Remastered | https://kenney.nl/assets/background-elements-remastered | Kenney | CC0 1.0 | Retina `houseAlt2.png`. |
| scenery/city/house_small.png | scenery/city/house_small.png | 76×50 → 150×100 | Background Elements Remastered | https://kenney.nl/assets/background-elements-remastered | Kenney | CC0 1.0 | Retina `houseSmall1.png`. |
| scenery/city/house_small_alt.png | scenery/city/house_small_alt.png | 76×70 → 153×140 | Background Elements Remastered | https://kenney.nl/assets/background-elements-remastered | Kenney | CC0 1.0 | Retina `houseSmall2.png`. |
| scenery/sky/cloud_1.png | scenery/sky/cloud_1.png | 203×121 → 406×242 | Background Elements Remastered | https://kenney.nl/assets/background-elements-remastered | Kenney | CC0 1.0 | Retina `cloud1.png`. |
| scenery/sky/cloud_2.png | scenery/sky/cloud_2.png | 216×139 → 432×278 | Background Elements Remastered | https://kenney.nl/assets/background-elements-remastered | Kenney | CC0 1.0 | Retina `cloud3.png`. |
| scenery/sky/cloud_3.png | scenery/sky/cloud_3.png | 203×121 → 406×242 | Background Elements Remastered | https://kenney.nl/assets/background-elements-remastered | Kenney | CC0 1.0 | Retina `cloud5.png`. |
| scenery/sky/sun.png | scenery/sky/sun.png | 84×84 → 168×168 | Background Elements Remastered | https://kenney.nl/assets/background-elements-remastered | Kenney | CC0 1.0 | Retina `sun.png`. |
| scenery/sky/moon.png | scenery/sky/moon.png | 84×84 → 168×168 | Background Elements Remastered | https://kenney.nl/assets/background-elements-remastered | Kenney | CC0 1.0 | Retina `moonFull.png`. |

### B) Far-background parallax bands — rung-2 ORIGINAL flat vectors (license-clean, AC-9 lift)

The Remastered pack ships the mountain/hills **bands** at the SAME 1024×400 as
the shipped *Redux* set (no strict-res lift). Rather than invoke the equal-res
deviation valve, these two bands are redrawn as **original flat vectors** in the
Kenney palette at 2048×800 — a clean strict AC-9 increase, license-clean by
construction (no third-party licence).

| File (under assets/journey/) | Replaces predecessor path | Predecessor dims → new dims (AC-9) | Source | Author | Licence | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| scenery/mountains/mountain_range.png | scenery/mountains/mountain_range.png | 1024×400 → 2048×800 | Original flat vector (this slice) | ui-asset-curator | No third-party licence (original) | Ridge silhouette band, tileable; palette `#8FB6C9`/`#6E97AB`. |
| scenery/mountains/hills.png | scenery/mountains/hills.png | 1024×400 → 2048×800 | Original flat vector (this slice) | ui-asset-curator | No third-party licence (original) | Rolling-hill band, tileable; palette `#23BF76`/`#1E9E62`. |

### C) Beach / coast band — rung-2 ORIGINAL flat vector (NET-NEW, closes journey-scene-v2 AC-8)

The journey-scene-v2 beach gap (no CC0 flat-vector coast sprite in the Kenney
family) is closed with an **original flat-vector** sea+sand horizon band drawn
to the Kenney palette — a far parallax **band** (AC-5), net-new (AC-9 exempt),
license-clean by construction.

| File (under assets/journey/) | Target category | Source | Author | Licence | Notes |
| --- | --- | --- | --- | --- | --- |
| scenery/beach/coast_band.png (2048×800) | NEW backdrop band (AC-5) | Original flat vector (this slice) | ui-asset-curator | No third-party licence (original) | Sea (`#7FD6EE`→`#4FB9DD`), foam (`#DEF5FF`/`#EAF8FD`), sand (`#F0E3C2`→`#FAF0D6`); transparent above sea line so it composites over the sky tint like the mountains/hills bands. Cycles by scroll phase, no geographic logic. |

### D) Side-view full-body animals — rung-2 ORIGINAL flat vectors (NET-NEW, closes journey-scene-v2 AC-8)

The journey-scene-v2 animal gap (Kenney *Animal Pack Redux* = 30 animals as
**square/round badge faces**, NOT side-profile — confirmed at
https://kenney.nl/assets/animal-pack-redux) is closed with **original
flat-vector side-profile full-body** animals in the Kenney palette. Net-new
(AC-9 exempt), license-clean by construction.

| File (under assets/journey/) | Target category | Source | Author | Licence | Notes |
| --- | --- | --- | --- | --- | --- |
| animals/water_buffalo.png (512×384) | NEW pooled SideObjectKind (AC-6) | Original flat vector (this slice) | ui-asset-curator | No third-party licence (original) | Side profile, four legs + curved horns + tail; Vietnam paddy icon. NOT a badge face. |
| animals/dog.png (384×288) | NEW pooled SideObjectKind (AC-6) | Original flat vector (this slice) | ui-asset-curator | No third-party licence (original) | Side profile, tail up, floppy ear. |
| animals/chicken.png (256×256) | NEW pooled SideObjectKind (AC-6) | Original flat vector (this slice) | ui-asset-curator | No third-party licence (original) | Side profile, comb + wattle + beak + legs. |
| animals/bird.png (256×160) | NEW pooled SideObjectKind (AC-6) | Original flat vector (this slice) | ui-asset-curator | No third-party licence (original) | Side profile flying bird (wings + beak); for sky/roadside variety. |

### E) Side-view vehicles + people — rung-2 ORIGINAL flat vectors (replacements + the ship net-new)

The only cohesive CC0 **side-view** vehicle source is the shipped pixel-art
*Pixel Vehicle Pack* (single-digit-pixel sprites — the low-craft set this slice
exists to replace); Kenney's flat-vector vehicle packs (*Racing Pack*, *Car
Kit*) are **top-down/3D** and clash with the side-view scene (same reason the
journey-scene-v2 ship gap was left unfilled). So vehicles + people are redrawn
as **original flat-vector side-view** sprites in the Kenney palette. All are a
large strict resolution lift; the ship is net-new (AC-9 exempt).

| File (under assets/journey/) | Replaces predecessor path | Predecessor dims → new dims (AC-9) | Source | Author | Licence | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| vehicles/walk.png | vehicles/walk.png | 7×15 → 160×320 | Original flat vector (this slice) | ui-asset-curator | No third-party licence (original) | Side-view walking figure, mid-stride; non-identifiable. |
| vehicles/run.png | vehicles/run.png | 11×15 → 200×320 | Original flat vector (this slice) | ui-asset-curator | No third-party licence (original) | Side-view running figure, leaning. |
| vehicles/bicycle.png | vehicles/bicycle.png | 16×10 → 320×192 | Original flat vector (this slice) | ui-asset-curator | No third-party licence (original) | Side-view bicycle. |
| vehicles/motorbike.png | vehicles/motorbike.png | 15×9 → 320×192 | Original flat vector (this slice) | ui-asset-curator | No third-party licence (original) | Side-view motorbike/scooter. |
| vehicles/car.png | vehicles/car.png | 29×13 → 384×192 | Original flat vector (this slice) | ui-asset-curator | No third-party licence (original) | Side-view car. |
| vehicles/ship.png | (vehicles/ship.png — was UNFILLED) | net-new → 448×256 | Original flat vector (this slice) | ui-asset-curator | No third-party licence (original) | Side-view boat/ship — closes the long-standing ship gap. NET-NEW (AC-9 exempt). |
| people/man.png | people/man.png | 9×15 → 160×320 | Original flat vector (this slice) | ui-asset-curator | No third-party licence (original) | Side standing figure; non-identifiable. |
| people/man_point.png | people/man_point.png | 13×15 → 200×320 | Original flat vector (this slice) | ui-asset-curator | No third-party licence (original) | Standing figure, waving arm; non-identifiable. |

### Spike findings — coverage matrix & craft caveat (for the AC-1 human leg)

| Category | Covering CC0 family found? | Decision |
| --- | --- | --- |
| Scenery (forest/countryside/city/sky) | YES — Background Elements Remastered (CC0) | Rung 1: switch family, 2× Retina lift. **Highest craft of the shipped set.** |
| Mountains/hills bands | Family ships SAME res | Rung 2: original 2× bands (clean AC-9). |
| Vehicles (6 side-view skins) | NO cohesive CC0 side-view flat set (pixel pack is low-craft; flat packs are top-down/3D) | Rung 2: original flat vectors. |
| People | (as above) | Rung 2: original flat vectors. |
| Beach/coast | NO CC0 flat-vector coast sprite in the family | Rung 2: original flat band (net-new). |
| Side-view animals | NO — Kenney Animal Pack Redux is badge faces | Rung 2: original flat side-profile animals (net-new). |

> **Craft caveat for the look judgement (AC-1):** the rung-1 scenery (Remastered
> Retina) is shippable as-is. The rung-2 original-flat vectors (vehicles /
> people / animals / beach / bands) are **side-view-correct, readable, and a
> clear resolution + craft lift over the single-digit-pixel sprites**, and they
> establish the shape/composition/palette — but in the contact sheet they read
> **flatter and simpler than the Kenney Remastered scenery** (no soft shading /
> highlight detail). They are a faithful *direction* of the rung-2 fallback, not
> a final-polish tier. If Kevin signs off the direction, a craft pass (subtle
> shading, outline weight, palette tightening to match Remastered) is
> recommended during `/implement` before these land in the manifest.

