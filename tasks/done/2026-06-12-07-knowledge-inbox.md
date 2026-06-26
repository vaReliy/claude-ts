# Task 07 — Knowledge Inbox pattern (agent-agnostic memory layer)

| Field | Value |
| --- | --- |
| Clean session | **Yes** — run in a fresh session |
| Executor model | **Sonnet** |
| Repo | CTS (`claude-ts`), branch `feat/round-2-distribution-and-agnostic` |
| Depends on | Task 02 (rules live at root `rules/`), Task 04 (`/cts-setup` exists — gets a bootstrap step) |
| Execution order | **Between tasks 04 and 05** — so HPW adoption (05) carries the pattern over |
| On completion | Suggest a one-line commit message in your summary. **Do NOT commit or push.** Owner moves this file to `tasks/done/`. |

## Context & rationale

Design source: HPW `tmp/CLAUDE_USAGE_GUIDE.md` §8 (owner idea, validated 2026-06-11). Claude auto-memory is vendor-private and per-machine — it does not travel with the repo or to other agents (Codex/Gemini/Copilot). A repo-committed "knowledge inbox" is the **agent-agnostic memory layer** — which is why it belongs to the framework-agnostic round. Pattern: append-only inbox where sessions dump durable learnings whose final home is unclear; periodically distilled into permanent homes; inbox trends toward empty (queue, not archive).

**Must work "under the box"**: capture and threshold-triggered distillation both happen automatically inside Phase 6 (Knowledge Capture) — the user's only touchpoint is the normal `git diff` review before committing.

## Deliverables

### 1. Update `rules/workflow.md` — Phase 6 (Knowledge Capture)

Add the inbox to the Phase 6 artifact table and decision rules:

- **Capture rule:** durable, project-relevant learning whose final home (PROJECT_CONTEXT / CLAUDE.md / a rule / a skill) is unclear → append an entry to `docs/KNOWLEDGE_INBOX.md`. Create the file from the template below if absent. Claude-session-specific gotchas still go to auto-memory; learnings with an obvious home go straight there (inbox is only for "durable but unplaced").
- **Entry format (3 lines, append-only):**

  ```markdown
  ## YYYY-MM-DD — [area] short fact
  Why: …
  Belongs in (guess): PROJECT_CONTEXT | CLAUDE.md | rule | skill | discard
  ```

- **Distill rule (automatic):** during every Phase 6, check the inbox; if it exceeds **10 entries or ~3 KB**, run distillation as part of knowledge capture (use a `cheap`-tier agent if dispatched): move each entry into its permanent home, then DELETE it from the inbox. Manual trigger ("distill the knowledge inbox") and end-of-roadmap-phase trigger also documented.
- **Hard constraint:** the inbox must NEVER be `@`-referenced from CLAUDE.md/AGENTS.md (it would become always-loaded noise). Plain-path mention in the on-demand index only.

### 2. Mention in `AGENTS.md` (portable layer)

One short subsection or index line: `docs/KNOWLEDGE_INBOX.md` — append-only inbox for durable-but-unplaced learnings; any AI tool working in the repo may append entries in the 3-line format; distillation policy lives in `rules/workflow.md`. (This is what makes the memory layer vendor-neutral.)

### 3. Inbox file template (shipped as documentation, NOT as payload)

The file is **project data** — it must NOT be in `cts-payload.txt` (updates would overwrite project inboxes). Instead:

- Put the template (header comment explaining format + the 3-line entry format) inside the workflow.md rule, so any agent can create the file on demand.
- Add a bootstrap step to `.claude/skills/cts-setup/SKILL.md`: create `docs/KNOWLEDGE_INBOX.md` from the template if absent (after the prune/record steps).
- Verify `cts-payload.txt` does NOT include `docs/` (it shouldn't, per task 03).

### 4. Division-of-labor note (one place, `rules/workflow.md`)

- auto-memory = Claude-private workflow preferences / session gotchas
- inbox = project-durable knowledge **in transit**
- PROJECT_CONTEXT.md (or equivalent) = distilled, stable domain truth
- CHANGELOG.md = what changed and why, per task

### 5. `README.md` — one short paragraph in the appropriate section describing the inbox pattern. `CHANGELOG.md` entry.

## Acceptance criteria

- Phase 6 in `rules/workflow.md` contains capture rule, 3-line format, automatic threshold distillation, and the no-`@`-reference constraint.
- `AGENTS.md` references the inbox as part of the portable layer.
- `cts-payload.txt` does not ship any inbox file; `/cts-setup` bootstraps it.
- Grep check: no `@` followed by the inbox path anywhere.
