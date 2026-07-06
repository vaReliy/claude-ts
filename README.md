# Claude Code Configuration for Node.js/TypeScript Projects

> **Forked from** [AratKruglik/claude-laravel](https://github.com/AratKruglik/claude-laravel) — adapted from PHP/Laravel to Node.js/TypeScript targeting Vue/Angular/React environments.

A comprehensive, production-ready Claude Code configuration for Node.js/TypeScript projects. Includes 18 specialized agents, 9 rule files, 25 skills, 2 commands, and a structured workflow pipeline that turns Claude Code into a full AI development team.

**Stack:** Node.js 22+ · TypeScript 5 · Vue 3 / Angular 17+ / React 18+ · Prisma / TypeORM / Drizzle · PostgreSQL 17 · Redis · Docker · Vitest / Playwright · BullMQ

## Repo Structure

- **`AGENTS.md`** — portable core (stack, git safety, code style essentials, Model Tiers vocabulary, on-demand rules index), readable by any AI CLI (Claude Code, Codex, Gemini, Copilot, ...).
- **`rules/`** — portable knowledge referenced from `AGENTS.md`'s on-demand index: architecture, testing, validation, migrations/queue, Docker commands, MCP stack, git operations, and the workflow pipeline.
- **`CLAUDE.md`** — Claude Code adapter. Imports `AGENTS.md` via `@AGENTS.md` (Claude Code does not auto-load `AGENTS.md`), then adds the orchestrator/dispatcher core: triage, agent routing, pipeline, quality gate, skill preferences.
- **`.claude/`** — the rest of the Claude adapter layer: agent definitions (`agents/`), skills (`skills/`), commands (`commands/`), Stop/other hooks (`hooks/`), settings, and the sync engine (`scripts/cts-sync.sh`).
- **`cts-payload.txt`** — the manifest of paths copied into target projects by `cts-sync.sh` (everything above, plus `.mcp.json` and `.claude/settings.json`).
- **`docs/KNOWLEDGE_INBOX.md`** — an append-only "knowledge inbox": the agent-agnostic memory layer for durable, project-relevant learnings whose final home (`PROJECT_CONTEXT.md`, `CLAUDE.md`, a rule, or a skill) isn't clear yet. Any AI tool can append a 3-line entry; Phase 6 (Knowledge Capture) in `rules/workflow.md` distills entries into their permanent home once the inbox grows past ~10 entries, so it trends toward empty. This is project data — `/cts-setup` bootstraps it but it's never part of `cts-payload.txt`.

Non-Claude tools should read `AGENTS.md` + `rules/` only — the orchestrator/pipeline content in `CLAUDE.md`/`.claude/` is Claude-specific and would be wasted context for them. The `Model Tiers` table in `AGENTS.md` gives a vendor-neutral vocabulary (`deep`/`standard`/`cheap`) that each AI maps onto its own models — Claude maps them to `opus`/`sonnet`/`haiku`.

## What's Included

### Agents (18)

Specialized AI agents that handle different aspects of development. Each agent has an explicit `tools:` list in its frontmatter — only the tools it actually needs (principle of least privilege).

| Agent                   | Purpose                                            | Model  | Write? | Key extras              |
| ----------------------- | -------------------------------------------------- | ------ | ------ | ----------------------- |
| `ba`                    | Business analysis, requirements, user stories      | sonnet | —      | Web, Context7, Agent    |
| `dba`                   | Database design, migrations, query optimization    | sonnet | +      | —                       |
| `ddd-architect`         | Domain modeling, Clean Architecture placement      | opus   | —      | Context7, Agent         |
| `debugger`              | Bug investigation, root-cause analysis             | opus   | +      | —                       |
| `backend-developer`     | Node.js/TypeScript backend features                | sonnet | +      | Context7, IDE, Agent    |
| `vue-developer`         | Vue 3 components, Pinia, Tailwind, a11y            | sonnet | +      | Context7, Figma, IDE    |
| `react-developer`       | React 18+ components, Zustand, TanStack Query      | sonnet | +      | Context7, Figma, IDE    |
| `angular-developer`     | Angular 17+ standalone components, signals, RxJS   | sonnet | +      | Context7, Figma, IDE    |
| `devil`                 | Devil's advocate in planning phase                 | sonnet | —      | SendMessage only        |
| `devops`                | Docker, CI/CD, PM2, GitHub Actions, infrastructure | haiku  | +      | GitHub MCP              |
| `docs-writer`           | Technical documentation, README, API docs          | haiku  | +      | GitHub MCP              |
| `integration-architect` | OAuth, webhooks, third-party services              | sonnet | +      | Web, Context7           |
| `refactoring-expert`    | Refactoring, N+1 fixes, code quality               | sonnet | +      | —                       |
| `qa`                    | E2E testing, Playwright, visual regression         | sonnet | +      | All 21 Playwright tools |
| `queue-specialist`      | BullMQ workers, jobs, async processing             | sonnet | +      | —                       |
| `reviewer`              | Code review, architecture audit                    | sonnet | —      | GitHub MCP (review)     |
| `security-scanner`      | OWASP, auth/authz, credential leaks                | sonnet | —      | Web (CVE lookup)        |
| `tester`                | Unit/integration tests, Vitest, Stryker mutation   | sonnet | +      | —                       |

### Rules (12)

Portable rule files in root `rules/`, referenced from `AGENTS.md`'s on-demand index and loaded by agents and orchestrator on demand:

| Rule                           | Purpose                                                          |
| ------------------------------ | ----------------------------------------------------------------- |
| `architecture.md`              | Clean Architecture layers, domain organization                    |
| `code-style.md`                | TypeScript strict mode, ESLint/Prettier/tsc conventions, comments |
| `dependencies.md`              | Exact-pin dependency audit procedure (npm/pnpm ranges)             |
| `docker-commands.md`           | Docker-prefixed commands reference (Node.js/npm/Prisma)           |
| `validation-authorization.md`  | js-validator-livr (primary) / Zod + Guards / CASL RBAC             |
| `git-operations.md`            | Commit/push safety, PR description format                         |
| `mcp-stack.md`                 | MCP tool usage guide (Context7, GitHub, Figma)                     |
| `migrations-queue.md`          | Prisma migration conventions, BullMQ queue pattern                 |
| `nx-generators.md`             | Nx generator-output audit checklist (Nx workspaces only)          |
| `task-authoring.md`            | Backlog task-file conventions for plan/grill/grooming sessions    |
| `testing.md`                   | Vitest/Jest, Stryker mutation testing, ORM testing policy         |
| `workflow.md`                  | Agent pipeline orchestration + agent routing table + quality gate |

`CLAUDE.md` carries a single `@AGENTS.md` import (the portable core, needed every turn). `rules/` files are referenced by plain path and loaded by agents on demand only when relevant, instead of being force-loaded into every conversation's context.

### Skills (30)

Reusable knowledge modules organized by category:

**TypeScript & Node.js:** `typescript-pro`, `typescript-architecture`

**Testing:** `vitest-testing`, `test-master`, `playwright-expert`, `tdd` — the red-green-refactor discipline loop itself (seams, anti-patterns, one-slice-at-a-time rules), distinct from `vitest-testing`'s tooling/mocking/coverage setup and `test-master`'s broader strategy/automation-framework guidance

**Database:** `postgres-best-practices`

**Architecture:** `architecture-designer`, `ddd-strategic-design`, `code-reviewer`, `architect-review`

**DevOps:** `devops`, `docker-expert`, `github-actions`

**Debugging & Security:** `debugging-wizard`, `security-reviewer`

**Frontend:** `vue-expert`, `react-expert`, `angular-expert`

**Planning:** `plan-writing`, `brainstorming`, `grill-me` — one-question-at-a-time interrogation that pressure-tests a plan already on the table, distinct from `brainstorming`'s open-ended idea generation and `plan-writing`'s task breakdown, `handoff` — compacts a conversation into a handoff document so a fresh session can pick up mid-task (also the format cited by the orchestrator's quality-gate continuation-task hard stop)

**CTS Tooling:** `cts-setup`, `cts-update` — install, configure, and update the CTS template itself (see [Quick Start](#quick-start) and [Updating](#updating)); `cts-import-skill` — maintainer-only flow for curating new skills into CTS itself (see [Add a New Skill](#add-a-new-skill)); `cts-contribute` — consumer-side flow for contributing improvements (skills, rules, orchestrator changes) back to a local CTS checkout

**Maintenance:** `cts-rule-auditor` — audits `.claude/agents/`, `rules/`, `AGENTS.md`, and `docs/KNOWLEDGE_INBOX.md` for structural drift (broken pre-flight paths, stale references, missing index entries); run after any change to `.claude/**` or `rules/**`. `distill-inbox` — categorizes `docs/KNOWLEDGE_INBOX.md` entries into Done/Clear-target/Uncertain and dispatches a docs-writer agent to move each into its permanent home, keeping the inbox trending toward empty.

### Workflow Pipeline

The configuration defines a mandatory agent pipeline for feature development:

```
Standard Feature:  Planning Team → Backend Developer → Quality Gate (sequential) → DocsWriter
Bug Fix:           Debugger → Backend Developer → Verify (same quality-gate contract)
CI/CD:             DevOps → Reviewer + Security Scanner
```

**Planning Team** (`plan-{slug}`) runs `ba`, `ddd-architect`, and `devil` in parallel. `devil` is a read-only devil's advocate that challenges requirements and architecture decisions via SendMessage before any code is written. For simple features with no arch decisions, `ba` runs sequentially alone.

**Quality Gate (mandatory, sequential — see `rules/workflow.md`)**: `tester` runs first, alone; `reviewer` runs only after `tester` passes; `security-scanner` and `qa` then run in parallel as a final stage, each only when its trigger condition is met (auth/validation/secrets/HMAC for security-scanner, user-visible flow change for qa). Any failure at any stage restarts from `tester`, capped at 2 full restart cycles. `reviewer` and `security-scanner` emit two sections per report — `## Fix Now` (introduced by this changeset, drives the restart) and `## Emit as Task` (pre-existing, filed as a task and does not block the gate) — with a severity floor that drops pure polish/preference findings instead of emitting them. Also gated by a **foresight gate**: seam-touching tasks (new cross-layer contract, shared enum, topology change) require a blast-radius map before implementation starts, not just before review.

## Prerequisites

- [Claude Code](https://code.claude.com) CLI installed
- Node.js 18+ (only needed if using the optional `npx skills` CLI in Step 3)
- A Node.js/TypeScript project (ideally with Docker)

## Quick Start

### Step 1: Install the CTS Payload

**New project (no existing `.claude/` or `CLAUDE.md`):** open a Claude Code session in your project and paste:

> Set up the claude-ts template in this project: fetch
> `https://raw.githubusercontent.com/vaReliy/claude-ts/main/.claude/scripts/cts-sync.sh`,
> run `bash cts-sync.sh init`, then follow the `/cts-setup` guided configuration.

`/cts-setup` walks you through the [Install Profile](#install-profile-pruning-for-your-stack) (pruning the frontend agents/skills you don't need) and records your choices in `.ctsignore` so future updates respect them.

**Existing project (already has `CLAUDE.md` and/or `.claude/`):** run `/cts-setup` directly — it detects existing files and merges instead of overwriting.

<details>
<summary>Manual script invocation (CI, or no agent session available)</summary>

```bash
curl -fsSL https://raw.githubusercontent.com/vaReliy/claude-ts/main/.claude/scripts/cts-sync.sh -o cts-sync.sh
bash cts-sync.sh init        # fresh project; add --force to overwrite an existing CLAUDE.md/AGENTS.md/.claude
bash cts-sync.sh init --dry-run   # preview without writing anything
```

The script clones `claude-ts` into `~/.cache/claude-ts`, copies the payload listed in `cts-payload.txt` (`AGENTS.md`, `CLAUDE.md`, `.mcp.json`, `rules/`, and `.claude/agents|skills|scripts|settings.json`), and writes `.cts-version` (the source commit it installed). It refuses to overwrite an existing `CLAUDE.md`/`AGENTS.md`/`.claude/` without `--force` — that merge is `/cts-setup`'s job.

</details>

> **All 24 skills** are bundled in `.claude/skills/` and activate as soon as they're installed — no separate install needed.

### Install Profile (Pruning for Your Stack)

This template ships with all 3 frontend frameworks and their skills so it works as a starting point for any Node.js/TypeScript project. `/cts-setup` prunes what you don't use and records the pruned paths in `.ctsignore` (so `/cts-update` never re-adds them):

- **Backend-only project (no UI):** remove `vue-developer.md`, `react-developer.md`, `angular-developer.md` from `.claude/agents/`; remove `vue-expert/`, `react-expert/`, `angular-expert/` from `.claude/skills/`; remove the frontend rows from the routing table and the `## Frontend` row in `CLAUDE.md`'s Orchestrator Core; drop the frontend frameworks from the `## Stack` line.
- **Single-framework project:** keep only the matching agent (e.g. `vue-developer.md`) and its skill (e.g. `vue-expert/`); remove the other two frontend agents/skills and narrow the `## Frontend` routing row to the one you kept.
- Re-run `grep -L 'Report Format' .claude/agents/*.md` after pruning — it should return nothing for the agents you keep.

### Step 2: Install Superpowers Plugin

[Superpowers](https://github.com/obra/superpowers) provides structured development workflows.

Run inside Claude Code:

```
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```

### Step 3 (Optional): Install Extra Community Skills

The 24 bundled skills already cover TypeScript, testing, frontend, DevOps, architecture, and debugging. To pull **additional** skills from external GitHub repos, use the [`skills` CLI](https://www.npmjs.com/package/skills):

```bash
npx skills add <owner/repo>
```

Skip this step unless you have specific external skills to install.

## Updating

Run `/cts-update` inside the project. It pulls the latest `claude-ts` and re-syncs the payload, leaving anything listed in `.ctsignore` untouched.

<details>
<summary>How it works (internals)</summary>

`/cts-update` calls `.claude/scripts/cts-sync.sh update`, which:

1. Refreshes the cached `claude-ts` checkout (`~/.cache/claude-ts`) to the latest commit — or, with `--source <local-path>`, uses a local checkout directly (no network, useful for testing an unpushed contribution before it lands upstream).
2. Re-copies every path in `cts-payload.txt`, **skipping** anything matched by `.ctsignore` (gitignore syntax, in your project root).
3. **Skips (does not overwrite) any payload file that diverged locally**, even if it's not in `.ctsignore` — a file is only fast-forwarded if the working copy still matches what was synced last time. Diverged files are printed as `locally modified, not overwritten — diff manually: <path>` with a ready-to-run `git diff` command. This is what makes it safe to edit payload files ahead of a `/cts-contribute` session without them being silently clobbered on the next update.
4. Never deletes files. If a payload file no longer exists upstream, it's printed as "removed upstream — delete manually if unwanted".
5. Reports every ignored file that **changed upstream** since your last sync ("ignored, but changed upstream — review manually"), with a ready-to-run `git diff` command per file — so customizing a file never silently cuts you off from its upstream improvements.
6. Prints the `claude-ts` changelog between your old and new `.cts-version`, then updates `.cts-version`.
7. Finishes with `Done. Review with: git diff` — **`git diff` is the merge tool**: review the changes like any other dependency bump and commit them yourself.

**`.ctsignore`** (gitignore syntax, project root) covers three cases:

- **Customized CTS files** you've edited locally and don't want overwritten (e.g. `rules/code-style.md`).
- **Pruned CTS files** — paths removed during `/cts-setup` that should stay removed (e.g. `.claude/agents/vue-developer.md`).
- **Project-only additions** placed under payload directories (e.g. a custom `.claude/agents/my-agent.md`).

A leading `/` anchors a pattern to the project root: `/AGENTS.md` protects only your root `AGENTS.md`, while a bare `AGENTS.md` would also match nested payload files with that name (e.g. `.claude/skills/postgres-best-practices/AGENTS.md`). Always anchor root-level entries.

**Keep `.ctsignore` shrinking, not growing.** Ignoring a file means owning its drift: every entry is either (a) genuinely project-specific (your `AGENTS.md`, `CLAUDE.md`, settings) — keep it, the changed-upstream report covers you; (b) a fix or improvement CTS should have — contribute it upstream, then remove the entry so the file returns to CTS ownership; or (c) style-only divergence — the weakest reason; consider adopting CTS formatting and un-ignoring.

Run `bash .claude/scripts/cts-sync.sh update --dry-run` to preview without touching anything.

</details>

## Customization

### Add a New Agent

Create `.claude/agents/my-agent.md`:

```yaml
---
name: my-agent
description: "What this agent does. Trigger words — EN: keyword1, keyword2. Trigger words — UA: слово1, слово2."
model: sonnet
color: blue
tools:
  - Read
  - Glob
  - Grep
  - Edit
  - Write
  - Bash
  - SendMessage
---
# Agent Title

Instructions for the agent...
```

Always define `tools:` explicitly — agents inherit ALL tools from the conversation if the field is omitted. Grant only what the agent needs:

- Read-only agents (analysts, auditors): omit `Edit`, `Write`, `Bash`
- Agents that don't call external services: omit MCP tools
- `qa` is the only agent that should get Playwright MCP tools
- `reviewer`, `devops`, `docs-writer` are the only agents that need GitHub MCP

> **Maintenance note:** every agent definition must keep its `## Report Format (mandatory)` section at the end of the file. When adding or editing agents, preserve it — inter-agent reports stay terse (bullets, ≤300 words), while artifacts the agent produces (code, migrations, API contracts, PR descriptions) stay complete and precise.

### Add a New Rule

Create `rules/my-rule.md` with markdown content, then add it to `AGENTS.md`'s On-Demand Rules Index. Root `rules/` files are not auto-loaded — agents and the orchestrator read them on demand when relevant.

### Add a New Skill

Manually creating `.claude/skills/my-skill/SKILL.md` is discouraged for skills sourced from external repos — it risks re-introducing duplication that earlier curation removed (the template once carried 3 Postgres and 2 Playwright skills). Instead, run `/cts-import-skill <github-url | owner/repo/path | local-path>`: it fetches the source, runs a blocking duplication check against every existing skill (merge/replace/reject/import-as-is), brings the description up to CTS's skill-quality bar, and updates this README, `THIRD_PARTY.md`, and `CHANGELOG.md`. This is a CTS-maintainer flow — it runs inside the `claude-ts` repo itself, not in a consumer project (which receives skills via `/cts-update`).

For a genuinely new, project-authored skill (no external source), create it directly:

```yaml
---
name: my-skill
description: What this skill does and when to use it
---
Instructions Claude follows when this skill is active...
```

### Bilingual Agent Support

All agents include trigger words in both English and Ukrainian. To add another language, extend the `description` field in the YAML frontmatter:

```
Trigger words — EN: keyword1, keyword2.
Trigger words — UA: слово1, слово2.
Trigger words — DE: schlüsselwort1, schlüsselwort2.
```

## Architecture Overview

This configuration follows **Clean Architecture** for Node.js/TypeScript:

| Layer              | Pattern                           |
| ------------------ | --------------------------------- |
| HTTP entry         | Route handler / Controller        |
| Business operation | UseCase                           |
| Shared logic       | Service                           |
| Data access        | Repository                        |
| Domain model       | Entity                            |
| Authorization      | Guard / Middleware / CASL         |
| Validation         | js-validator-livr (primary) / Zod |
| Value objects      | Enums                             |
| Async work         | BullMQ Workers                    |
| Cross-cutting      | Events / Handlers                 |

**Strict role separation:** `backend-developer` handles Node.js API only. Each frontend framework has its own dedicated agent (`vue-developer`, `react-developer`, `angular-developer`) — no combined "fullstack" agents.

## Credits / Sources

Base:

- Fork of: https://github.com/AratKruglik/claude-laravel
- Adapted for Node.js / TS stack

Additional skills:

- Some skills adapted from external repositories (see [THIRD_PARTY.md](./THIRD_PARTY.md))

## License

MIT — see [LICENSE](./LICENSE) file.

Third-party attributions:

- https://github.com/mattpocock/skills (MIT)
- https://github.com/AratKruglik/claude-laravel (MIT)
