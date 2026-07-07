# Knowledge Inbox

Append-only queue for durable, project-relevant learnings whose final home isn't clear yet. Distilled into PROJECT_CONTEXT.md / CLAUDE.md / a rule / a skill, then deleted from here — this file should trend toward empty.

## 2026-07-07 — rules-editing: reworded phrases must be grepped repo-wide before closing

Why: a docs-writer pass reworded a phrase in one section of a rules file, but missed an identical occurrence elsewhere in the same file — two independent copies of the old phrase, only one updated. `reviewer` caught the stale copy as a Fix Now item on the quality-gate pass.
Belongs in (guess): rule (add a step to `rules/task-authoring.md` or a docs-writer pre-flight: after rewording a phrase, `grep -n "<old phrase>"` the full file before reporting done, not just the section you edited)
