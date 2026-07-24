# Claude Code Configuration for Node.js/TypeScript Projects

> **Forked from** [AratKruglik/claude-laravel](https://github.com/AratKruglik/claude-laravel) — adapted from PHP/Laravel to Node.js/TypeScript targeting Vue/Angular/React environments.

A comprehensive, production-ready Claude Code configuration for Node.js/TypeScript projects. Includes 18 specialized agents, 14 rule files, 31 skills, 2 commands, and a structured workflow pipeline that turns Claude Code into a full AI development team.

**Stack:** Node.js 22+ · TypeScript 5 · Vue 3 / Angular 17+ / React 18+ · Prisma / TypeORM / Drizzle · PostgreSQL 17 · Redis · Docker · Vitest / Playwright · BullMQ

## Repo Structure

- **`AGENTS.md`** — portable core (stack, git safety, code style essentials, Model Tiers vocabulary, on-demand rules index), readable by any AI CLI (Claude Code, Codex, Gemini, Copilot, ...). CTS-owned, overwrite-synced; `@import`s `AGENTS.local.md` at the end (create that file in your project for local overrides — never synced, always wins on conflict).
- **`rules/cts/`** — portable knowledge referenced from `AGENTS.md`'s on-demand index: architecture, testing, validation, migrations/queue, Docker commands, MCP stack, git operations, and the workflow pipeline. CTS-owned, overwrite-synced on every `/cts-update`.
- **`rules/local/`** — your project's own rule overrides and platform-specific splits (e.g. `rules/local/architecture-backend.md`). Never listed in `cts-payload.txt`, so `cts-sync.sh` never touches it. An override file cites the CTS section it displaces (`## Overrides rules/cts/workflow.md § "..."`) so the engine's override-rot detector can flag it when that cited content changes upstream.
- **`CLAUDE.md`** — Claude Code adapter. Imports `AGENTS.md` via `@AGENTS.md` (Claude Code does not auto-load `AGENTS.md`), then adds the orchestrator/dispatcher core: triage, agent routing, pipeline, quality gate, skill preferences. CTS-owned; `@import`s `CLAUDE.local.md` at the end (same never-synced, always-wins convention as `AGENTS.local.md`).
- **`.claude/`** — the rest of the Claude adapter layer: agent definitions (`agents/`), skills (`skills/`), commands (`commands/`), Stop/other hooks (`hooks/`), and the sync engine (`scripts/cts-sync.sh`). Every shipped agent ends with a fixed tail sentence pointing at `.claude/agents-local/<name>.md` (create that file to override a specific agent's instructions — never synced).
- **`.cts/settings.cts.json`** — the CTS-owned settings fragment (model default, MCP servers, the `Stop` knowledge-capture hook, and `Edit`/`Write`-deny rules for `rules/cts/**`/`.cts/**`). `cts-sync.sh` deep-merges this into your own `.claude/settings.json` on every sync (via `jq`) — your existing values win on scalar conflicts, arrays (like `permissions.deny`) are unioned so CTS's entries are always present; the merge hard-fails (refuses to write, non-zero exit) rather than silently drop those entries if an existing `permissions` key has an unexpected shape. `.claude/settings.json` itself is yours; it's never overwritten wholesale. **This is not full read-only enforcement**: the deny rules block direct `Edit`/`Write` tool calls, but Claude Code's permission system can't path-restrict the `Bash` tool, so a `sed -i`/`cat >`/`mv` from Bash can still modify these files. The real backstop is detection, not prevention: `cts-sync.sh`'s ownership-violation check (manifest-hash comparison) catches any such drift on the next sync and overwrites it — loudly, not silently.
- **`cts-payload.txt`** — the manifest of CTS-owned paths copied (plain overwrite, no merge) into target projects by `cts-sync.sh`.
- **`docs/RECIPES.md`** — operator-facing workflows guide: six recipes covering how to run grilling sessions → convert decisions into task files → execute cleanly in isolation → handle quality-gate hard stops → sync/contribute with the template → distill the knowledge inbox. Non-technical reference for humans running this template (agents never load it).
- **`docs/KNOWLEDGE_INBOX.md`** — an append-only "knowledge inbox": the agent-agnostic memory layer for durable, project-relevant learnings whose final home (`PROJECT_CONTEXT.md`, `CLAUDE.md`, a rule, or a skill) isn't clear yet. Any AI tool can append a 3-line entry; Phase 6 (Knowledge Capture) in `rules/cts/workflow.md` distills entries into their permanent home once the inbox grows past ~10 entries, so it trends toward empty. This is project data — `/cts-setup` bootstraps it but it's never part of `cts-payload.txt`.

Non-Claude tools should read `AGENTS.md` + `rules/cts/` only — the orchestrator/pipeline content in `CLAUDE.md`/`.claude/` is Claude-specific and would be wasted context for them. The `Model Tiers` table in `AGENTS.md` gives a vendor-neutral vocabulary (`deep`/`standard`/`cheap`) that each AI maps onto its own models — Claude maps them to `opus`/`sonnet`/`haiku`.

**Two-layer distribution model.** Every path CTS ships is owned by exactly one side — CTS or your project — and is never merged. `cts-sync.sh update` plain-overwrites every CTS-owned file with upstream's content, every time. If you need to customize CTS-owned behavior, do it in the matching override layer (`rules/local/**`, `.claude/agents-local/<name>.md`, `AGENTS.local.md`, `CLAUDE.local.md`) instead of editing the CTS file directly — those paths are never in `cts-payload.txt`, so sync never touches them. If you do edit a CTS-owned file directly anyway, the next sync overwrites it and prints a loud `OWNERSHIP WARNING` first (see [Updating](#updating)) rather than silently discarding or merging your edit.

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

### Rules (14)

Portable rule files in `rules/cts/` (CTS-owned, overwrite-synced), referenced from `AGENTS.md`'s on-demand index and loaded by agents and orchestrator on demand. Pair each with an optional `rules/local/` override if your project needs to customize it — see [Repo Structure](#repo-structure):

| Rule                          | Purpose                                                           |
| ----------------------------- | ----------------------------------------------------------------- |
| `architecture.md`             | Clean Architecture layers, domain organization                    |
| `code-style.md`               | TypeScript strict mode, ESLint/Prettier/tsc conventions, comments |
| `dependencies.md`             | Exact-pin dependency audit procedure (npm/pnpm ranges)            |
| `docker-commands.md`          | Docker-prefixed commands reference (Node.js/npm/Prisma)           |
| `validation-authorization.md` | js-validator-livr (primary) / Zod + Guards / CASL RBAC            |
| `git-operations.md`           | Commit/push safety, PR description format                         |
| `mcp-stack.md`                | MCP tool usage guide (Context7, GitHub, Figma)                    |
| `migrations-queue.md`         | Prisma migration conventions, BullMQ queue pattern                |
| `nx-generators.md`            | Nx generator-output audit checklist (Nx workspaces only)          |
| `task-authoring.md`           | Backlog task-file conventions for plan/grill/grooming sessions    |
| `testing.md`                  | Vitest/Jest, Stryker mutation testing, ORM testing policy         |
| `workflow.md`                 | Agent pipeline orchestration + agent routing table + quality gate |

`CLAUDE.md` carries a single `@AGENTS.md` import (the portable core, needed every turn). `rules/cts/` files are referenced by plain path and loaded by agents on demand only when relevant, instead of being force-loaded into every conversation's context.

### Skills (32)

Reusable knowledge modules organized by category:

**TypeScript & Node.js:** `typescript-pro`, `typescript-architecture`

**Testing:** `vitest-testing`, `test-master`, `playwright-expert`, `tdd` — the red-green-refactor discipline loop itself (seams, anti-patterns, one-slice-at-a-time rules), distinct from `vitest-testing`'s tooling/mocking/coverage setup and `test-master`'s broader strategy/automation-framework guidance

**Database:** `postgres-best-practices`

**Architecture:** `architecture-designer`, `ddd-strategic-design`, `code-reviewer`, `architect-review`

**DevOps:** `devops`, `docker-expert`, `github-actions`

**Debugging & Security:** `debugging-wizard`, `security-reviewer`

**Frontend:** `vue-expert`, `react-expert`, `angular-expert`

**Planning:** `brainstorming`, `grill-me` — one-question-at-a-time interrogation that pressure-tests a plan already on the table, distinct from `brainstorming`'s open-ended idea generation, `handoff` — compacts a conversation into a handoff document so a fresh session can pick up mid-task (also the format cited by the orchestrator's quality-gate continuation-task hard stop). Task breakdown is covered by `rules/cts/task-authoring.md`

**CTS Tooling:** `cts-setup`, `cts-update` — install, configure, and update the CTS template itself (see [Quick Start](#quick-start) and [Updating](#updating)); `cts-import-skill` — maintainer-only flow for curating new skills into CTS itself (see [Add a New Skill](#add-a-new-skill)); `cts-contribute` — consumer-side flow for contributing improvements (skills, rules, orchestrator changes) back to a local CTS checkout

**Maintenance:** `cts-rule-auditor` — audits `.claude/agents/`, `rules/`, `AGENTS.md`, and `docs/KNOWLEDGE_INBOX.md` for structural drift (broken pre-flight paths, stale references, missing index entries); run after any change to `.claude/**` or `rules/**`. `distill-inbox` — categorizes `docs/KNOWLEDGE_INBOX.md` entries into Done/Clear-target/Uncertain and dispatches a docs-writer agent to move each into its permanent home, keeping the inbox trending toward empty. `cts-review-contribution` — owner-side deep-tier judgment gate that reviews whatever is currently uncommitted in the CTS working tree for philosophy/scope fit, safety, and quality-bar consistency, delegating structural checks to `cts-rule-auditor` and always dispatching the judgment pass on opus; report-only, runs only inside the CTS repo itself.

### Workflow Pipeline

The configuration defines a mandatory agent pipeline for feature development:

```
Standard Feature:  Planning Team → Backend Developer → Quality Gate (sequential) → DocsWriter
Bug Fix:           Debugger → Backend Developer → Verify (same quality-gate contract)
CI/CD:             DevOps → Reviewer + Security Scanner
```

**Planning Team** (`plan-{slug}`) runs `ba`, `ddd-architect`, and `devil` in parallel. `devil` is a read-only devil's advocate that challenges requirements and architecture decisions via SendMessage before any code is written. For simple features with no arch decisions, `ba` runs sequentially alone.

**Quality Gate (mandatory, sequential — see `rules/cts/workflow.md`)**: `tester` runs first, alone; `reviewer` runs only after `tester` passes; `security-scanner` and `qa` then run in parallel as a final stage, each only when its trigger condition is met (auth/validation/secrets/HMAC for security-scanner, user-visible flow change for qa). Any failure at any stage restarts from `tester`, capped at 2 full restart cycles. `reviewer` and `security-scanner` emit two sections per report — `## Fix Now` (introduced by this changeset, drives the restart) and `## Emit as Task` (pre-existing, filed as a task and does not block the gate) — with a severity floor that drops pure polish/preference findings instead of emitting them. Also gated by a **foresight gate**: seam-touching tasks (new cross-layer contract, shared enum, topology change) require a blast-radius map before implementation starts, not just before review.

## Prerequisites

- [Claude Code](https://code.claude.com) CLI installed
- Node.js 18+ (only needed if using the optional `npx skills` CLI in Step 3)
- A Node.js/TypeScript project (ideally with Docker)

## Quick Start

### Step 1: Install the CTS Payload

**New project (no existing `.claude/` or `CLAUDE.md`):** open a Claude Code session in your project and paste:

> Set up the claude-ts template in this project: fetch `https://raw.githubusercontent.com/vaReliy/claude-ts/main/.claude/scripts/cts-sync.sh`, run `bash cts-sync.sh init`, then follow the `/cts-setup` guided configuration.

`/cts-setup` walks you through the [Install Profile](#install-profile-pruning-for-your-stack) (pruning the frontend agents/skills you don't need) and records your choices in `.ctsignore` so future updates respect them.

**Existing project (already has `CLAUDE.md` and/or `.claude/`):** run `/cts-setup` directly. Since every CTS-owned path is a plain overwrite (no merge), `/cts-setup` moves anything worth keeping from your existing files into the override layer (`CLAUDE.local.md`, `AGENTS.local.md`, `rules/local/**`, `.claude/agents-local/*.md`) BEFORE running the engine with `--force` — so nothing is lost, and nothing needs hand-reconciliation afterward.

<details>
<summary>Manual script invocation (CI, or no agent session available)</summary>

```bash
curl -fsSL https://raw.githubusercontent.com/vaReliy/claude-ts/main/.claude/scripts/cts-sync.sh -o cts-sync.sh
chmod +x cts-sync.sh
bash cts-sync.sh init        # fresh project; add --force to overwrite an existing CLAUDE.md/AGENTS.md/.claude
bash cts-sync.sh init --dry-run   # preview without writing anything
```

The script clones `claude-ts` into `~/.cache/claude-ts`, plain-overwrites every path listed in `cts-payload.txt` (`AGENTS.md`, `CLAUDE.md`, `.mcp.json`, `rules/cts/`, `.claude/agents|skills|scripts`, and `.cts/settings.cts.json`), deep-merges the settings fragment into `.claude/settings.json`, and writes `.cts-version` (an informational marker only — never a merge baseline) plus `.cts/manifest.json` (per-file content hashes used by the update-time ownership-violation detector, also never used for merging). It refuses to overwrite an existing `CLAUDE.md`/`AGENTS.md`/`.claude/` without `--force`.

</details>

> **All bundled skills** are included in `.claude/skills/` and activate as soon as they're installed — no separate install needed.

### Install Profile (Pruning for Your Stack)

This template ships with all 3 frontend frameworks and their skills so it works as a starting point for any Node.js/TypeScript project. `/cts-setup` prunes what you don't use and records the pruned paths in `.ctsignore` (so `/cts-update` never re-adds them):

- **Backend-only project (no UI):** remove `vue-developer.md`, `react-developer.md`, `angular-developer.md` from `.claude/agents/`; remove `vue-expert/`, `react-expert/`, `angular-expert/` from `.claude/skills/`; remove the frontend rows from the routing table and the `## Frontend` row in `CLAUDE.md`'s Orchestrator Core; drop the frontend frameworks from the `## Stack` line.
- **Single-framework project:** keep only the matching agent (e.g. `vue-developer.md`) and its skill (e.g. `vue-expert/`); remove the other two frontend agents/skills and narrow the `## Frontend` routing row to the one you kept.
- Re-run `grep -L 'Report Format' .claude/agents/*.md` after pruning — it should return nothing for the agents you keep.

### Step 2 (Optional): Install Extra Community Skills

The bundled skills already cover TypeScript, testing, frontend, DevOps, architecture, and debugging. To pull **additional** skills from external GitHub repos, use the [`skills` CLI](https://www.npmjs.com/package/skills):

```bash
npx skills add <owner/repo>
```

Skip this step unless you have specific external skills to install.

## Updating

Run `/cts-update` inside the project. It pulls the latest `claude-ts` and re-syncs the payload, leaving anything listed in `.ctsignore` untouched.

<details>
<summary>How it works (internals)</summary>

`/cts-update` calls `.claude/scripts/cts-sync.sh update`, which:

1. **Self-updates first.** If the source's copy of `cts-sync.sh` itself differs from the one running, it overwrites itself and re-execs with the new version before touching anything else — atomically (`cp` to a sibling temp file, then `mv` over the real path; `mv`/rename doesn't invalidate the currently-executing process's open file descriptor, so there's no mid-read corruption hazard). You'll see `cts-sync engine updated; re-running with the new version...` in the output when this fires; the rest of the same run then executes under the new engine.
2. Refreshes the cached `claude-ts` checkout (`~/.cache/claude-ts`) to the latest commit — or, with `--source <local-path>`, uses a local checkout directly (no network, useful for testing an unpushed contribution before it lands upstream).
3. **Plain-overwrites every path in `cts-payload.txt`**, skipping anything matched by `.ctsignore` (gitignore syntax, in your project root). There is no merge, no baseline reconciliation, and no "diverged" state to preserve — every CTS-owned file simply becomes upstream's content, every run. `.cts-version` is purely an informational engine/release marker; it is never read as a merge base.
4. Runs two detectors in place of merging:
   - **Ownership violation** — a CTS-owned file whose content no longer matches the hash recorded for it at the last sync (i.e. you edited it directly instead of through an override file) prints `OWNERSHIP WARNING: <path>` before being overwritten anyway.
   - **Override rot** — an override file (`rules/local/**`, `.claude/agents-local/*.md`, `AGENTS.local.md`, `CLAUDE.local.md`) that cites a CTS file/section via a `## Overrides <path>` line prints `OVERRIDE ROT: <path> cites "<target>"` when that cited content actually changed content this run. The override file itself is never touched — this is a loud notice, not a merge.
5. Never deletes files. If a payload file no longer exists upstream, it's printed as "removed upstream — delete manually if unwanted".
6. Reports every ignored file that **changed upstream** since your last sync ("ignored, but changed upstream — review manually"), with a ready-to-run `git diff` command per file — so forking a file never silently cuts you off from its upstream improvements.
7. Deep-merges `.cts/settings.cts.json` into your `.claude/settings.json` via `jq` — your existing scalar values win on conflict, arrays (e.g. `permissions.deny`) are unioned so CTS's entries are always present. This is the one deliberate exception to plain overwrite: `.claude/settings.json` stays yours, but CTS can still push new defaults into it over time.
8. Prints the `claude-ts` changelog between your old and new `.cts-version`, then updates `.cts-version` and `.cts/manifest.json`.
9. Finishes with `Done. Review with: git diff` — review the changes like any other dependency bump and commit them yourself.

**Customizing a CTS-owned file the supported way.** Don't edit a `rules/cts/**` file or `.claude/agents/*.md` directly — the next sync overwrites it (with a warning, but the edit is still gone). Instead:

- **Rules**: create `rules/local/<name>.md`, starting with a citation of what it displaces: `## Overrides rules/cts/workflow.md § "Quality gate stage sequencing"`, followed by your replacement text. Agents and the orchestrator read both layers; local wins on conflict.
- **Agents**: create `.claude/agents-local/<agent-name>.md`. Every shipped agent ends with a fixed tail sentence that reads this file first, if it exists, and treats its instructions as overriding. Frontmatter (`name`/`model`/`tools`) is not layerable — it stays single-file.
- **`CLAUDE.md`/`AGENTS.md`**: create `CLAUDE.local.md`/`AGENTS.local.md`. Both CTS files already `@import` them at the end.
- **`.claude/settings.json`**: just edit it directly — it's yours; see the deep-merge behavior above.

**`.ctsignore`** (gitignore syntax, project root) is for the narrower cases an override file doesn't fit:

- **Pruned CTS files** — paths removed during `/cts-setup` that should stay removed (e.g. `.claude/agents/vue-developer.md`).
- **Project-only additions** placed under payload directories (e.g. a custom `.claude/agents/my-agent.md`).
- **Whole-file forks** — the discouraged exception, not the default; prefer an override file (above) whenever the customization is narrow enough to cite a section.

A leading `/` anchors a pattern to the project root: `/AGENTS.md` protects only your root `AGENTS.md`, while a bare `AGENTS.md` would also match nested payload files with that name (e.g. `.claude/skills/postgres-best-practices/AGENTS.md`). Always anchor root-level entries.

**Keep `.ctsignore` shrinking, not growing.** Every entry is either (a) a deliberate prune — keep it; (b) a whole-file fork that's actually a general improvement — contribute it upstream via `/cts-contribute`, then remove the entry so the file returns to CTS ownership; or (c) something an override file would now handle more narrowly — migrate it and remove the entry.

Run `bash .claude/scripts/cts-sync.sh update --dry-run` to preview without touching anything.

</details>

## Using CTS Day-to-Day

For real-world development workflows beyond the Quick Start, see **[`docs/USAGE.md`](./docs/USAGE.md)** — eight copy-pasteable recipes for:

1. Idea → task session (grill mode)
2. Direct chat pipeline session (triage, tier routing, quality gate)
3. Implement-a-task session (executor model, clean session execution)
4. Standalone-skill sessions (TDD, refactoring, brainstorming outside the pipeline)
5. Receive CTS updates (ownership warnings, override rot, sync semantics)
6. Override a CTS rule/agent (lex specialis, rules/local, agents-local)
7. Contribute back (discovery, review, round-trip verification)
8. Model/cost tips (frontmatter pins, opusplan, per-dispatch overrides)

Each recipe is self-contained and links to deeper rules files for reference.

## Customization

### Add a New Agent

Create `.claude/agents/my-agent.md`:

```yaml
---
name: my-agent
description: 'What this agent does. Trigger words — EN: keyword1, keyword2. Trigger words — UA: слово1, слово2.'
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

**Contributing to CTS itself** (this repo): create `rules/cts/my-rule.md` with markdown content, then add it to `AGENTS.md`'s On-Demand Rules Index. `rules/cts/` files are not auto-loaded — agents and the orchestrator read them on demand when relevant.

**Customizing a consumer project**: create `rules/local/my-rule.md` instead — see [Customizing a CTS-owned file the supported way](#updating) in the Updating section. Never listed in `cts-payload.txt`, so it's never touched by sync.

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
