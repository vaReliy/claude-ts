# How to apply round-2 CTS to the existing HPW project

> **Audience:** project owner (human). Read this AFTER all CTS tasks (01–04, 07, optionally 06) are executed and committed on `feat/round-2-distribution-and-agnostic`.
> The executable procedure is `tasks/todo/2026-06-12-05-hpw-adoption.md` — this file explains what happens, what you do manually, and what to check.

## Prerequisites

- [ ] CTS tasks 01, 02, 03, 04, 07 committed on `feat/round-2-distribution-and-agnostic` (06 can wait — it's maintainer-side only).
- [ ] You reviewed each commit's `git diff` (the tasks never commit themselves).
- [ ] HPW working tree is clean (commit or stash anything in progress).

## What HPW will gain

| Change | Effect in HPW |
| --- | --- |
| `.ctsignore` | HPW's deviations (pruned frontend, embedded-cpp persona, customized files) become explicit and update-proof |
| `.cts-version` | Records which CTS commit HPW is synced to; future updates print "what changed" |
| `AGENTS.md` split | HPW's portable knowledge becomes readable by any AI CLI; orchestrator stays Claude-only in CLAUDE.md |
| `rules/` at root | HPW rules move out of `.claude/` to match CTS layout (future updates ship there) |
| `/cts-update` skill | All future CTS updates become one command inside HPW |
| Knowledge inbox | Phase 6 starts capturing durable learnings to `docs/KNOWLEDGE_INBOX.md` automatically |

## Procedure

1. **Open a fresh Sonnet session in HPW** (`cd ~/Projects/vg/home-pulse-watcher`, `/model sonnet`) and prompt:

   > "Execute task file `/home/vh/Projects/vg/claude-ts/tasks/todo/2026-06-12-05-hpw-adoption.md`. Follow it exactly; it is self-contained."

2. **The agent will** (no action from you until it finishes):
   - classify every CTS payload path against HPW's current state (identical / pruned / customized / HPW-only) and write `.ctsignore` from that classification;
   - apply the AGENTS.md split to HPW's customized CLAUDE.md, preserving all HPW-specific content;
   - move HPW `.claude/rules/` → `rules/`;
   - run `cts-sync.sh update --source /home/vh/Projects/vg/claude-ts --branch feat/round-2-distribution-and-agnostic`;
   - validate (idempotent re-run, no ignored file touched, agents intact) and append findings to HPW `tmp/validation-notes.md`;
   - report **gate PASSED / FAILED** and suggest a commit message.

3. **Your manual checklist after the agent finishes:**
   - [ ] Review HPW `git diff` — especially that NOTHING listed in `.ctsignore` changed, and HPW-specific content survived the CLAUDE.md/AGENTS.md split.
   - [ ] Sanity-check `.ctsignore` against your own memory of HPW deviations (frontend prunes per D8, embedded-cpp persona, task-naming rule per D9, Telegram/NestJS specifics).
   - [ ] Delete the stale `laravel-boost` entry from `.claude/settings.local.json` in **both** HPW (if present) and CTS (untracked files — agents won't touch them).
   - [ ] Commit in HPW with the suggested message.
   - [ ] Work normally for a few sessions; confirm routing/skills still behave (same watchlist as round-1 Step 3: routing misses, quality drops, cost).

4. **Push gate:** only when the gate is PASSED and a few normal sessions look healthy → push CTS to remote:

   ```bash
   cd ~/Projects/vg/claude-ts
   git push -u origin feat/token-optimization-round-1
   git push -u origin feat/round-2-distribution-and-agnostic
   # then merge to main per your normal flow (PR or fast-forward)
   ```

   If FAILED: the task-05 summary lists the bugs as new CTS task candidates — fix in CTS (new task files), re-run task 05. Do not patch CTS from the HPW session.

## After adoption — the new steady state

- **Updating HPW from CTS:** run `/cts-update` inside HPW. Review `git diff`, commit. That's the whole procedure.
- **HPW-side experiments → CTS:** unchanged 3-category model (improvements ↑ upstream, subtractions stay + go to `.ctsignore`, project-specifics stay). New customizations of CTS-owned files must be added to `.ctsignore` (or `/cts-update` will flag/overwrite them — `git diff` protects you either way).
- **Other / new projects:** use the README bootstrap prompt → `/cts-setup` guided install. Their project-specifics get their own `.ctsignore` from day one.
- **Knowledge inbox:** works automatically via Phase 6; you only see it in `git diff` as appended entries and occasional distillation moves.
