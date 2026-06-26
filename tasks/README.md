# Round 2 — Distribution & Framework-Agnostic Roadmap

> **Audience:** project owner (human) + any agent executing the task files in `tasks/todo/`.
> **Date:** 2026-06-12. Produced by a grilling session; every decision below was explicitly confirmed by the owner.
> **Branch:** `feat/round-2-distribution-and-agnostic` (stacked on `feat/token-optimization-round-1`).
> Do NOT implement from this file — use the self-contained task files. This file is the "why"; task files are the "how".

## Terminology

- **CTS** = this repo (`claude-ts`) — shareable Claude config template for TS projects.
- **HPW** = `../home-pulse-watcher` — testbed where CTS changes are validated before being trusted.
- **Payload** = the set of files CTS installs into a target project (defined in `cts-payload.txt` after task 03).

## Status of the original Step-5 backlog

| Item | Outcome |
| --- | --- |
| Framework-agnostic | **In scope this round** — tasks 02 (split) + 07 (knowledge inbox = vendor-neutral memory layer) |
| Postgres skill fold-in | **Already done** in commit `71504d6` (§8.3 + §8.4 merged into `postgres-best-practices`, donor skills `postgresql` + `database-optimizer` deleted). Closed, no task. |
| Measure, then iterate | **Skipped** — no metrics collected yet (owner decision). |
| Laravel MCP / PHP leftovers | **In scope** — task 01. |
| DX of CTS usage & updates | **In scope** — tasks 03, 04, 05. |

## Decisions (confirmed 2026-06-12)

| ID | Decision |
| --- | --- |
| D1 | **Distribution engine**: one zero-dependency bash script `.claude/scripts/cts-sync.sh` (part of the payload) with `init`/`update` modes. It self-manages a cached CTS clone (`~/.cache/claude-ts`, shallow clone + pull) — no manual sibling-repo bookkeeping; `--source <path>` overrides for the maintainer's local loop. Target-project side: `.ctsignore` (gitignore syntax) lists paths CTS must never touch (customizations, prunes, project-only additions); `.cts-version` records the last-synced CTS commit so updates can print "what changed". Review mechanism = `git diff` in the target repo. **No npm, no hashes, no merge engine** (v2 option: hash-based "you edited this" warnings — only if real pain appears). |
| D2 | **User-facing interface = skills, not the script.** `/cts-setup` (guided install in target project), `/cts-update` (narrated update in target project), `/cts-import-skill` (maintainer-side curation in CTS). All are thin wrappers: the script does deterministic copying; the agent does only judgment work (merging an existing CLAUDE.md, narrating diffs, profile questions). Users normally never run the script directly; it remains available for CI/no-agent use. New-project bootstrap = copy-paste prompt in README (agent fetches script, runs init, continues setup). |
| D3 | **Framework-agnostic split**: `AGENTS.md` = portable core (Stack, Git Safety, Code Style Essentials, on-demand rules index, model-tier vocabulary) readable by any AI CLI. `CLAUDE.md` = thin Claude adapter (Orchestrator Core + AGENTS.md import if needed — implementer verifies whether Claude Code auto-loads AGENTS.md natively). `.claude/rules/` moves to root `rules/`. Skills **stay** in `.claude/skills/` (Claude Code discovery requirement; their content is already portable). `.claude/` = the Claude-specific adapter layer. |
| D4 | **Model tiers**: generic layer speaks `deep / standard / cheap` (deep = cascading decisions, hardest debugging; standard = implementation/review/requirements; cheap = mechanical work). Concrete mapping exists only for Claude now: deep=opus, standard=sonnet, cheap=haiku. Other vendors (Gemini/Codex/Copilot) deferred until actually used — test-first principle. |
| D5 | **Laravel/PHP cleanup** (task 01): remove `laravel-boost` from `.mcp.json`; delete orphaned `laravel-patterns.md` + `modern-php-features.md` from `typescript-pro/references/`; remove "PHP / Laravel" sections from `debugging-wizard` references. Fork attribution in README/THIRD_PARTY.md **stays**. |
| D6 | **Process**: one branch, one commit per executed task. Task files `tasks/todo/YYYY-MM-DD-NN-slug.md`; finished files move to `tasks/done/`. Each task runs in a **clean session** with the model named in its header; at the end the agent suggests a one-line commit message and **does not commit**. |
| D7 | **Knowledge inbox** (HPW usage guide §8, part of the framework-agnostic layer): `docs/KNOWLEDGE_INBOX.md` per project — append-only, repo-committed, vendor-neutral memory-in-transit. Capture and threshold-triggered distillation (>10 entries / ~3 KB) run automatically inside Phase 6 (Knowledge Capture); the user's only touchpoint is the normal `git diff` review. Never `@`-referenced; NOT part of the payload (project data, created on demand / by `/cts-setup`). |

## Task list (execute in this order)

| # | File (`tasks/todo/`) | Executor | Repo | Depends on |
| --- | --- | --- | --- | --- |
| 01 | `2026-06-12-01-laravel-php-cleanup.md` | **Haiku** | CTS | — |
| 02 | `2026-06-12-02-framework-agnostic-split.md` | **Sonnet** | CTS | 01 |
| 03 | `2026-06-12-03-cts-sync-script.md` | **Sonnet** | CTS | 02 |
| 04 | `2026-06-12-04-setup-update-commands.md` | **Sonnet** | CTS | 03 |
| 07 | `2026-06-12-07-knowledge-inbox.md` | **Sonnet** | CTS | 02, 04 — **run between 04 and 05** |
| 05 | `2026-06-12-05-hpw-adoption.md` | **Sonnet** | **HPW** | 04, 07 |
| 06 | `2026-06-12-06-cts-import-skill.md` | **Sonnet** | CTS | — (run last) |

Suggested prompt per session:

> "Execute task file `tasks/todo/<filename>`. Follow it exactly; it is self-contained."

After each task: review `git diff`, commit yourself with the message the agent suggests (adjust freely), move the task file to `tasks/done/`.

## How existing projects (HPW) receive this round

**Human guide: `tasks/HPW-UPGRADE-NOTES.md`** — prerequisites, what the agent does, your manual checklist, push gates, and the post-adoption steady state. Task 05 is the executable adoption procedure: it builds HPW's `.ctsignore` from its known deviations (pruned frontend agents/skills, embedded-cpp persona, customized files), runs the new update flow against the local CTS checkout, and validates the result. **Task 05 is also the validation gate** — treat round-2 like round-1: do not push CTS to remote until HPW adoption works cleanly.

Manual note for the owner: your untracked `.claude/settings.local.json` files (CTS and possibly HPW) contain a stale `laravel-boost` disable entry — delete it yourself after task 01 lands.

## How NEW projects connect (after tasks 03+04 land)

Copy-paste bootstrap prompt from the CTS README into a Claude Code session in the target project; the agent fetches `cts-sync.sh`, runs `init`, then continues with the `/cts-setup` guided flow (profile questions, pruning, `.ctsignore` generation, CLAUDE.md/AGENTS.md merge). No manual script invocation.

## Push gates / git state

- `feat/token-optimization-round-1` is committed but **unpushed** — gated on HPW real-use validation (HPW `tmp/NEXT_ACTIONS.md` Step 3). Round 2 stacks on top of it; both push together once task 05 validates cleanly.

## Deferred / future backlog (decided NOT now)

- npm publishing of the sync script (`npx cts ...`) — non-breaking upgrade later if CTS gets external users.
- skills.sh multi-tool skill installation (Codex/Gemini/Copilot skill dirs).
- Gemini/Codex/Copilot tier mappings (D4) — when actually used.
- Hash-based overwrite warnings in the sync script (v2).
- **Grooming workflow codification (round-3 candidate):** triage gains a branch — ambiguous or multi-task requests → grilling interview in the **main session** (deep tier; subagent `ba` is the wrong host — it can't converse with the user directly) → decision record + self-contained task files per D6 format (clean session, executor tier, acceptance criteria, suggest-commit-don't-commit) → execute per task. `ba` formalizes grilled decisions instead of re-questioning. Equivalent of mattpocock's `grill-me → to-issues` flow. Pairs with the existing "skip `ba` for small well-specified tasks" lever. **Must be self-contained in CTS** (round-1 D6: no dependency on user-global skills): bundle ONE CTS-flavored `/groom` skill (grill + emit D6-format task files; THIRD_PARTY attribution to mattpocock/skills), optionally a `/run-task` wrapper for the "execute task file X exactly" prompt. Covers three entry points: explicit grooming; executing existing task files in fresh per-tier sessions; and mid-conversation escalation ("let's groom this" — the conversation becomes the grooming input, task files become the durable handoff out of the expensive context).
- "Measure, then iterate" — collect `/cost` data during normal HPW work, revisit pipeline depth after.

## Reference

- mattpocock/skills review verdict: vision aligned (grilling, CONTEXT.md, TDD loops, deliberate architecture); its `setup-matt-pocock-skills` pattern inspired `/cts-setup`; its skills.sh covers skills-only distribution and stays a future option.
- Full session context snapshot (untracked): `tmp/2026-06-12-round-2-grilling-context.md`.
- Prior round record: HPW `tmp/CLAUDE_SETUP_IMPROVEMENTS.md` + `tmp/CLAUDE_USAGE_GUIDE.md`.
