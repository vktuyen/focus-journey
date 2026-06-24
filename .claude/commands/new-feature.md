---
description: Start a new feature by scaffolding a specs/<slug>/ folder from the template
argument-hint: <feature-slug>
---

Create a new feature spec folder:

1. Copy `specs/_template/` to `specs/$ARGUMENTS/`.
2. Open `specs/$ARGUMENTS/spec.md` and fill in the problem statement with me.
3. Delegate the domain framing to the `product-domain-expert` agent — have it propose acceptance criteria based on the problem statement.
4. Once the spec is reviewed, delegate test case design to `test-case-designer` (writes to `tests/cases/$ARGUMENTS.md`).
5. Add an entry under `planning/active/$ARGUMENTS.md` from the active template.

Do NOT start implementation until steps 1-4 are done and I've reviewed the spec.
