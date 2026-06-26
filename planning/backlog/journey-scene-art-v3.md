# Journey scene art v3 — hi-res cohesive scenery (incl. beach + animals)

**Intake date:** 2026-06-25  **Requested by:** Kevin (Tuyen Vo)  **Size (rough):** M
**Part of epic:** [visual-polish](visual-polish.md) · Wave 1

## Why
The game scene + side scenery still look placeholder-grade — whatever CC0 asset was available. Re-source a
**higher-resolution, cohesive stylized-flat** set across road/sky/vehicle/parallax + people/city, and **close
the gaps deferred at journey-scene-v2 AC-8** (beach/coast + side-view animals, omitted for lack of a
license-clean cohesive asset). Photoreal stays declined — "more beautiful" = higher-craft stylized.

## Signals
Ready when: a short **art-direction spike** confirms a cohesive, CC0/license-clean stylized-flat set exists
across all categories (incl. beach/coast + animals); then new/replacement assets flow through the existing
`journey_assets` manifest + `journey_sprites` graceful-degradation loader, each higher-res than its
predecessor and each with a `CREDITS.md` source+licence row. New beach/coast/animal `SideObjectKind`s appear
in the spawn rotation without breaking the spawn cadence. `[blocked by: journey-pov ✅]`
Hard constraint: **CC0 / license-clean only** (via `ui-asset-curator`); cohesion is a human sign-off gate.

## First step
Run `/new-feature journey-scene-art-v3` to promote this slice into a spec (its spec opens with the
art-direction spike).
