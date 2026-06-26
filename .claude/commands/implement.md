---
description: Implement an approved spec end-to-end — code, unit tests, automation, and a built-in self-review pass — then hand off to /review-code
argument-hint: <feature-slug>
---

Implement the approved spec at `specs/$ARGUMENTS/`.

Preconditions (check before starting):
- [ ] `specs/$ARGUMENTS/spec.md` status is `approved`, with concrete, testable `## Acceptance criteria`
- [ ] `tests/cases/$ARGUMENTS.md` exists with scenarios designed (tagged to AC-IDs)
- [ ] The project is scaffolded. If `src/` has no Flutter project yet, run `/flutter-bootstrap` first (one-time).

If any precondition is missing, STOP and report what's missing. Do not proceed.

Execution plan (agents are named directly — this is a Flutter project):
1. Delegate production code to **`flutter-app-developer`** (UI/Bloc) — reference the spec and its ACs.
   Pull in the right specialist for the slice: **`flutter-native-plugin-engineer`** for native
   idle/tray/window work, **`flame-game-developer`** for Flame scenes. Coordinate them; keep pure
   domain logic framework-free.
2. In parallel, delegate unit tests to **`unit-test-writer`** for the new/changed modules.
3. If the feature needs art, run **`/source-assets`** (uses `ui-asset-curator`) for license-clean assets.
4. Once `src/` is stable, delegate automation to **`test-script-author`** to turn
   `tests/cases/$ARGUMENTS.md` into executable tests (under `src/test/` / `src/integration_test/` per
   `docs/architecture/overview.md`).
5. **Self-review pass (built in — no separate command).** Hand the diff to **`flutter-code-reviewer`**
   in self-review mode: pass the spec + ACs, the cases file, and the in-scope changed files (prefer the
   git diff). Ask it to reason adversarially (how could this break? worst input? what isn't tested?) and
   return findings grouped **Blocking / Suggestion / Nit** with `path:line` + suggested fix. Route obvious
   Blocking fixes back to the implementer and apply them before handoff. This is a fast internal loop; it
   does **not** replace the formal `/review-code` gate.
6. Update the **Phase ledger** in `planning/active/$ARGUMENTS.md` in place (single source of truth — no
   separate status log): tick the **Build** row, set its date + a one-line note, and set Current phase /
   Next command.

Summarize what each agent produced, list any open acceptance criteria, note what the self-review found
and fixed, and point to the next command: `/review-code $ARGUMENTS`.
