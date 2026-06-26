---
description: Small-change lane — ship a bug fix or tiny tweak end-to-end without the full 6-phase ceremony. Lean spec stub → implement+test+self-review → review → test → ship, skipping /capture-idea, separate test-case design, ADRs, and summaries. Use for small, low-risk work; use the full /new-feature loop for genuine features.
argument-hint: <slug>  (kebab-case; describe the change after it)
---

Ship the small change `$ARGUMENTS` through a **lean lane**. This is the fast path for bug fixes and
tiny, low-risk tweaks — it collapses the 6-phase pipeline into one command while keeping the two gates
that actually protect quality: a **review** and a **green test run**.

**When NOT to use this** — if the change needs a new architectural decision (ADR), spans multiple
features/personas, adds a new dependency or native surface, or you can't state it in a couple of
sentences with 1–4 acceptance criteria, STOP and use the full loop instead: `/capture-idea` (if fuzzy)
→ `/new-feature $ARGUMENTS` → `/implement` → `/review-code` → `/execute-tests` → `/ship`. Say so and stop.

Preconditions (check first; STOP and report if any fail):
- [ ] `$ARGUMENTS` is a non-empty kebab-case slug not already under `specs/`, `planning/active/`, or `planning/done/`.
- [ ] The project is already scaffolded (`src/` has the Flutter project). If not, this isn't a small change — use the full loop.

Steps:

1. **Lean spec stub.** Gather the change from me in 1–3 sentences. Create `specs/$ARGUMENTS/spec.md`
   from `specs/_template/spec.md` but keep it minimal: fill Problem, the one-line outcome, In/Out scope,
   and **1–4 acceptance criteria inline** (the ACs double as the test checklist — do NOT spawn
   `test-case-designer` or write a separate `tests/cases/$ARGUMENTS.md`). Set `Status: approved` once I
   confirm the ACs (no separate approval round-trip for a small change). Skip `/capture-idea`,
   backlog framing, ADRs, and `/gen-summary`.

2. **Create a light tracker.** Add `planning/active/$ARGUMENTS.md` from the template, but note in its
   Phase ledger that this is a **quick-change** (phases 3→4→5→6 only; phase 2 was the inline stub).

3. **Implement + unit-test + self-review (one pass).** Delegate to `flutter-app-developer` (or the
   right specialist — `flutter-native-plugin-engineer` for native, `flame-game-developer` for scenes)
   to make the change against the ACs, and to `unit-test-writer` for tests covering each AC and a
   regression test for the bug. Then run a quick **self-review** with `flutter-code-reviewer` in
   self-review mode on the diff and fix obvious findings before review. Keep changes minimal and in-scope.

4. **Review.** Delegate to `flutter-code-reviewer` (read-only) against the spec + ACs + the diff. If it
   touches anything that reads system signals, also run `/privacy-audit`. Surface findings by severity;
   route fixes back to the implementer. Gate: no open Blocking/P0/P1 findings.

5. **Execute tests + ship.** Run the project test command (per `docs/architecture/overview.md`) over the
   in-scope tests and write a report to `tests/_runner/reports/$ARGUMENTS/<timestamp>/summary.md` with a
   `verdict:` field (hard gate — same as `/execute-tests`/`/ship`). If `green` and all ACs are `[x]`:
   tick the ledger, set `spec.md` `Status: shipped` with today's date, and move
   `planning/active/$ARGUMENTS.md` → `planning/done/$ARGUMENTS.md`. If not green, stop and report.

6. **Summarize** in 3 bullets (what changed, ACs verified, report timestamp + pass count) and update
   `planning/roadmap.md` "Where I am right now" if this change is roadmap-relevant.

Throughout, update the Phase ledger in `planning/active/$ARGUMENTS.md` in place (single source of truth —
no separate status log). Respect the same guardrails as the full loop: in-scope edits only, review is
read-only, shipping requires a machine-verified green report.
