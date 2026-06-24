---
description: Capture a raw idea / high-level business requirement as a well-framed backlog item (Phase 0, before /new-feature) by coordinating the domain, architecture, and test-design agents.
argument-hint: <idea-slug>
---

Capture the idea `$ARGUMENTS` as a backlog item. This is **Phase 0** — it turns a fuzzy ask into a well-framed `planning/backlog/$ARGUMENTS.md`, ready to promote with `/new-feature`. If the idea turns out to be large or multi-feature, it instead becomes an **epic** broken into per-wave child slices (see step 6). Keep it commitment-free: agents write their framing INTO the backlog item(s) and only *flag* candidates — they must NOT touch `docs/domain/` or `docs/architecture/` yet.

Preconditions (check before starting; STOP and report if any fail):
- [ ] `$ARGUMENTS` is a non-empty kebab-case slug.
- [ ] `planning/backlog/_template.md` exists.
- [ ] `planning/backlog/$ARGUMENTS.md` does NOT already exist — never clobber an existing item.

Steps:

1. **Gather the raw idea** from me in plain language (1–3 sentences). If it's too vague to frame, ask 2–3 targeted clarifying questions before proceeding. Do not guess the business intent.

2. **Scaffold the item**: copy `planning/backlog/_template.md` → `planning/backlog/$ARGUMENTS.md`. Set `Intake date` to today (YYYY-MM-DD) and `Requested by`. Leave `Size (rough)` for the architect to set in step 4.

3. **Delegate framing to `product-domain-expert`** — it fills:
   - **Why** — the problem, who it's for, and why now.
   - **Domain notes** (new section) — personas touched, key edge cases, and any *conflict* with existing `docs/domain/business-rules.md`.
   - A **candidate domain updates** checklist (unchecked) — e.g. `[ ] candidate glossary term: ...`, `[ ] candidate business rule: ...`.
   It must NOT write to `docs/domain/` — only flag candidates inside the backlog item.

4. **Delegate feasibility to `system-architect`** — pass it the idea framing directly (preserve its convention of NOT reading `docs/domain/`). It adds:
   - **Feasibility (high-level)** (new section) — fit with the current architecture in `docs/architecture/overview.md`, rough effort, and key risks. Use the rough effort to set the `Size (rough)` field.
   - A **candidate ADRs** checklist (unchecked) — decisions that will need an ADR if promoted.
   It must NOT write ADRs or touch `docs/architecture/` — only flag candidates inside the backlog item.

5. **Delegate to `test-case-designer`** (lightweight) — it adds a **Headline success signals** section: 2–4 observable, testable indicators of success, so the idea carries testable intent early. It must NOT create a `tests/cases/$ARGUMENTS.md` file yet.

6. **Decide scope — single item or epic.** Using the architect's `Size` signal (S/M ⇒ single; L/XL ⇒ candidate epic) **and** the domain expert's feature-boundary read (does this span multiple coherent capabilities / personas / bounded contexts?), choose one of the two paths below. Reuse the framing already gathered — do NOT spawn a fresh 3-agent pass per child.

   **Path A — Single item** (the idea is one coherent feature):
   - **Signals** — what would make this ready to promote to `active/`, plus any named blockers (`[blocked by: X]`).
   - **First step** — "Run `/new-feature $ARGUMENTS` to promote this into a spec bundle."

   **Path B — Epic** (the idea is large / multi-feature):
   - **Propose, don't auto-create.** Present a proposed breakdown to me first: candidate slices, a one-line scope for each, a suggested wave order, and `[blocked by: …]` dependencies. Let me confirm / rename / merge / re-order slices before any child file is written.
   - **Check child-slug collisions** (precondition): no proposed child slug may already exist under `planning/backlog/`, `planning/active/`, `planning/done/`, or `specs/`. Adjust names if they collide. Use flat kebab-case (prefer a shared stem, e.g. `payments-tracking` / `payments-reminders`) — **no nesting, colons, or subfolders**.
   - **Make `$ARGUMENTS` the epic item.** Set `Size (rough)` = `XL (epic)` and add a **Breakdown** section after the framing sections:
     ```
     ## Breakdown
     Delivered as independently-shippable slices (wave discipline). Promote each with `/new-feature <slug>` in wave order.

     | Wave | Slice (slug)          | Scope (one line) | Depends on            |
     |------|-----------------------|------------------|-----------------------|
     | 1    | [child-a](child-a.md) | …                | —                     |
     | 2    | [child-b](child-b.md) | …                | [blocked by: child-a] |
     ```
     The epic keeps the full framing (Why, Domain notes + candidate flags, Feasibility + candidate ADRs, epic-level Headline success signals). Set its `First step` to "Promote Wave 1: `/new-feature <wave-1-slug>`."
   - **Scaffold one child backlog item per slice** from `planning/backlog/_template.md`, kept light (heavy framing lives in the epic):
     ```
     # <Slice name>
     **Intake date:** <today>  **Requested by:** <who>  **Size (rough):** <S/M/L>
     **Part of epic:** [$ARGUMENTS]($ARGUMENTS.md) · Wave <n>

     ## Why         <scoped to this slice, 1–2 sentences>
     ## Signals     Ready when: <slice-specific>. [blocked by: <child-x>] (if any)
     ## First step  Run `/new-feature <child-slug>` to promote this slice into a spec.
     ```
     Defer per-child Headline success signals to that child's `/new-feature` (don't re-run `test-case-designer` per child now).

7. **Offer** (ask, don't assume) to seed `planning/roadmap.md`:
   - **Single:** one line under **Later**, linking `backlog/$ARGUMENTS.md`.
   - **Epic:** add the epic; put Wave-1 child(ren) under **Next** (ready to start) and later waves under **Later** with their `[blocked by: …]` notes.

8. **Summarize**:
   - **Single:** file path, a 3-bullet summary, the candidate flags each agent raised (domain terms / business rules / ADRs), and the next step — `/new-feature $ARGUMENTS`.
   - **Epic:** the epic file path, the ordered slice list (wave + deps), candidate flags raised, and the next step — `/new-feature <wave-1-slug>`.
