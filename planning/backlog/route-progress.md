# Route Progress

**Intake date:** 2026-06-23  **Requested by:** tuyenv@joblogic.com  **Size (rough):** M
**Part of epic:** [vietnam-focus-journey](vietnam-focus-journey.md) · Wave 1 (v1)

## Why
Models Vietnam as one continuous **province chain** (Mũi Cà Mau ⇄ Hà Giang). The user picks a **start province + direction**; the model maps accumulated virtual distance to a position along the chain (provinces passed vs ahead, distance to next, % of country) and shows it on a **custom-painted** map screen (no live tiles in v1). Handles route completion (celebration + summary, no auto-advance).

## Signals
Ready when: province-chain data exists with neighbours + inter-province distances; start/direction selection works; position advances with distance and is visible on the custom-painted map; completion shows a summary and waits for user choice. [blocked by: journey-engine]

## First step
Run `/new-feature route-progress` to promote this slice into a spec (after `journey-engine`).
