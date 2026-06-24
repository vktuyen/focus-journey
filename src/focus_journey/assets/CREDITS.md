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
| vehicles/car.png | Pixel Vehicle Pack | https://kenney.nl/assets/pixel-vehicle-pack | Kenney | CC0 1.0 | From `PNG/Cars/sedan.png` (side-view car). |
| objects/street_light.png | Pixel Vehicle Pack | https://kenney.nl/assets/pixel-vehicle-pack | Kenney | CC0 1.0 | From `PNG/Props/light.png` (side-view roadside lamp post). |
| objects/sign.png | Pixel Vehicle Pack | https://kenney.nl/assets/pixel-vehicle-pack | Kenney | CC0 1.0 | From `PNG/Props/sign_blue.png` (side-view post-mounted road sign). |
| objects/tree.png | Background Elements Redux | https://kenney.nl/assets/background-elements-redux | Kenney | CC0 1.0 | From `PNG/Default/treePalm.png` (palm tree; chosen for the Vietnam road-trip feel). |
| objects/house.png | Background Elements Redux | https://kenney.nl/assets/background-elements-redux | Kenney | CC0 1.0 | From `PNG/Default/house1.png` (side-view house). |

> Distant background parallax layers (mountains, rice fields, clouds) were
> trialled but are **deferred to a later polish wave** — the v1 scene draws the
> sky/ground procedurally. Their CC0 art (from Background Elements Redux) was
> removed from this manifest; it can be re-sourced from the same pack if/when
> those layers ship.

### Manifest paths NOT yet filled

| Manifest path | Reason |
| --- | --- |
| vehicles/ship.png | No license-clean CC0 **side-view** ship/boat found. Kenney's Pirate Pack and Racing Pack boats are top-down, which would clash with this side/POV scene. Left unfilled deliberately — the scene renders its graceful placeholder. |

## Source pack provenance

- **Pixel Vehicle Pack** — Kenney, CC0 1.0. https://kenney.nl/assets/pixel-vehicle-pack
  Cohesive pixel-art side-view set: vehicles, characters (walk frames), and roadside props (lamp, signs).
- **Background Elements Redux** — Kenney, CC0 1.0. https://kenney.nl/assets/background-elements-redux
  (Mirror used for download: https://opengameart.org/content/background-elements-redux)
  Flat-vector side-view scenery; v1 ships only the roadside `tree.png` and `house.png` from this pack.

Style note: foreground vehicles/props are pixel-art (Pixel Vehicle Pack) while the roadside
tree/house are flat-vector (Background Elements Redux). Both are Kenney CC0. The style
difference is mild at the roadside scale and reads as depth, not clash.

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

### Tray source provenance

- **Lucide** — Lucide Icons & Contributors, **ISC License**. https://lucide.dev/license
  Clean monochrome stroke icons; the three used (`car-front`, `circle-parking`,
  `route`) export cleanly to macOS template images and read at 16–18px. Glyphs
  chosen to stay on-theme with the shipped journey scene (a vehicle on a route)
  while remaining legible at tray scale — where the Kenney pixel-art vehicle
  sprites used in the scene would not render clearly or make a clean template.
