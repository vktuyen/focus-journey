---
description: Append a new numbered ADR under docs/architecture/decisions/ using the template.
argument-hint: <title>
---

Add an Architecture Decision Record titled: $ARGUMENTS

Delegate to the `system-architect` agent. The agent should:

1. Read `docs/architecture/decisions/_template.md` for the ADR shape.
2. Scan `docs/architecture/decisions/` to find the highest existing ADR number (`NNNN-*.md`), then increment by 1.
3. Create `docs/architecture/decisions/NNNN-<slug>.md` where `<slug>` is a kebab-case form of `$ARGUMENTS`.
4. Walk through each section interactively — Context, Decision, Consequences, Alternatives considered — asking for content before writing.
5. Default Status = `proposed`, Date = today (YYYY-MM-DD), Deciders = ask the user.
6. After writing, surface the file path and a one-paragraph summary of the decision.

If an existing ADR is being superseded:
- Mark the old ADR's Status as `superseded by ADR-NNNN`.
- Reference the old ADR in the new ADR's Context.
- Never edit the body of the old ADR — only its Status line.

Preconditions:
- [ ] `docs/architecture/decisions/_template.md` exists.
- [ ] `$ARGUMENTS` is non-empty.

If preconditions are missing, STOP and report what's missing.
