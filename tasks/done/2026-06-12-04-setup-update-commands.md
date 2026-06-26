# Task 04 — /cts-setup and /cts-update skills (user-facing interface)

| Field | Value |
| --- | --- |
| Clean session | **Yes** — run in a fresh session |
| Executor model | **Sonnet** |
| Repo | CTS (`claude-ts`), branch `feat/round-2-distribution-and-agnostic` |
| Depends on | Task 03 (the script they wrap) |
| On completion | Suggest a one-line commit message in your summary. **Do NOT commit or push.** Owner moves this file to `tasks/done/`. |

## Context & rationale

Decision D2: users interact with CTS **only through skills**; the bash script is the deterministic engine underneath. Pattern: "deterministic core + AI judgment" — the skill makes ONE script call and spends agent effort only on what a script can't do (merging, narrating, asking). Inspiration: `setup-matt-pocock-skills` (progressive-disclosure configuration questions).

Both ship inside the payload (`.claude/skills/`), so every CTS-consuming project gets them. Use the standard skill format (`.claude/skills/<name>/SKILL.md` with frontmatter `name` + `description`); they are invoked as `/cts-setup` and `/cts-update`. Follow D7 description discipline: 1–2 sentences what+when, explicit NOT-for, EN trigger keywords + 4–5 strongest UA keywords.

## Deliverable 1 — `.claude/skills/cts-setup/SKILL.md`

Guided install/configuration of the CTS template in the **current project**. Instruction flow for the agent:

1. **Preflight:** verify current dir is a git repo with a clean-enough working tree (warn otherwise). Detect whether CTS is already installed (`.cts-version` exists → suggest `/cts-update` instead).
2. **Engine call:** if payload absent, run `bash .claude/scripts/cts-sync.sh init` (script may have been fetched by the README bootstrap prompt; if missing, fetch it from the CTS repo raw URL first). For an **existing project with its own `CLAUDE.md`/`AGENTS.md`/`.claude/`**: run `init --dry-run`, then copy non-conflicting payload, and MERGE conflicting files by hand (agent judgment): CTS content prepended/integrated into the project's existing instruction files, never silently overwriting.
3. **Profile questions (one at a time, AskUserQuestion):** Which frontend framework — Vue / React / Angular / none (backend-only)? Any agents/skills known to be irrelevant (e.g. queue-specialist if no queues)?
4. **Prune:** delete the not-chosen frontend agents + skills, remove their routing rows from the orchestrator table, adjust the Stack line — exactly per the Install Profile rules in README.
5. **Record:** write every pruned or customized path into `.ctsignore` (so updates never re-add/overwrite them).
6. **Verify:** `grep -L 'Report Format' .claude/agents/*.md` returns nothing for kept agents; `.cts-version` + `.ctsignore` exist; print a short summary table (installed / pruned / ignored).
7. Remind the user: review `git diff`, commit yourself. Do not commit for them.

## Deliverable 2 — `.claude/skills/cts-update/SKILL.md`

Narrated update of an already-installed project:

1. **Engine call:** `bash .claude/scripts/cts-sync.sh update` (pass through `--source`/`--branch` if user gave them).
2. **Narrate:** read the script output + `git diff --stat` and summarize: what CTS changed (use the printed changelog), which local files were updated, what was skipped via `.ctsignore`, which files the script flagged as "removed upstream".
3. **Flag risks:** if the diff shows an updated file that the project had locally modified (heuristic: `git log --oneline -1 -- <file>` shows a non-CTS-sync commit touching it), warn explicitly and suggest either reverting that hunk or adding the path to `.ctsignore`.
4. **Suggest:** concrete `.ctsignore` additions when appropriate; next step (`git diff` review → commit). Never commit.

## Deliverable 3 — README + docs touch-up

- README sections from task 03 reference these skills — verify naming consistency (`/cts-setup`, `/cts-update`) and adjust if task 03 used placeholders.
- Add both skills to the README skills inventory table.
- `CHANGELOG.md` entry.

## Acceptance criteria

- Both SKILL.md files exist, frontmatter descriptions follow D7 (NOT-for + EN/UA triggers), bodies ≤ ~150 lines each (thin wrappers, not essays).
- Neither skill duplicates script logic (no inline copy loops — engine calls only).
- README inventory + flows consistent.
- Smoke test: in a throwaway git dir, walk Deliverable 1's flow manually (agent simulating a user choosing "backend-only") and confirm the resulting `.ctsignore` lists the pruned frontend files. Report the result.
