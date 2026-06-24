---
description: Adversarial self-review of the current feature/diff BEFORE human review or /review-code — finds bugs, code smells, SOLID/Clean-Architecture violations, edge cases, race conditions, and missing tests, with a ranked findings list and suggested fixes. Run at the end of Phase 3 (Build).
argument-hint: <feature-slug>
---

Self-review the implementation for `$ARGUMENTS` before it goes to Phase 4.

Preconditions:
- [ ] Some implementation exists under `src/` for `$ARGUMENTS`.

Delegate to `flutter-code-reviewer` in self-review mode. Pass it: the spec + ACs, the cases file, and the in-scope `src/` / test files (prefer the current git diff — `git diff` / changed files for this slug).

Ask it to reason adversarially (how could this break? worst input? what isn't tested?) and return findings grouped **Blocking / Suggestion / Nit**, each citing `path:line`, with a suggested fix and the agent to route it to. End with a verdict.

This is a fast feedback loop you run yourself; it does **not** replace `/review-code` (the formal Phase 4 gate). Route obvious fixes to `flutter-app-developer`, then proceed to `/review-code $ARGUMENTS`.
