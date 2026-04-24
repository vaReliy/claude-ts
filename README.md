# Claude Code Configuration for Node.js/TypeScript Projects

> **Forked from** [AratKruglik/claude-laravel](https://github.com/AratKruglik/claude-laravel) — adapted from PHP/Laravel to Node.js/TypeScript targeting Vue/Angular/React environments.

A comprehensive, production-ready Claude Code configuration for Node.js/TypeScript projects. Includes 18 specialized agents, 9 rule files, 23 skills, 2 commands, and a structured workflow pipeline that turns Claude Code into a full AI development team.

**Stack:** Node.js 22+ · TypeScript 5 · Vue 3 / Angular 17+ / React 18+ · Prisma / TypeORM / Drizzle · PostgreSQL 17 · Redis · Docker · Vitest / Playwright · BullMQ

## What's Included

### Agents (18)

Specialized AI agents that handle different aspects of development. Each agent has an explicit `tools:` list in its frontmatter — only the tools it actually needs (principle of least privilege).

| Agent | Purpose | Model | Write? | Key extras |
|-------|---------|-------|--------|------------|
| `ba` | Business analysis, requirements, user stories | opus | — | Web, Context7, Agent |
| `dba` | Database design, migrations, query optimization | sonnet | + | — |
| `ddd-architect` | Domain modeling, Clean Architecture placement | opus | — | Context7, Agent |
| `debugger` | Bug investigation, root-cause analysis | opus | + | — |
| `backend-developer` | Node.js/TypeScript backend features | sonnet | + | Context7, IDE, Agent |
| `vue-developer` | Vue 3 components, Pinia, Tailwind, a11y | sonnet | + | Context7, Figma, IDE |
| `react-developer` | React 18+ components, Zustand, TanStack Query | sonnet | + | Context7, Figma, IDE |
| `angular-developer` | Angular 17+ standalone components, signals, RxJS | sonnet | + | Context7, Figma, IDE |
| `devil` | Devil's advocate in planning phase | opus | — | SendMessage only |
| `devops` | Docker, CI/CD, PM2, GitHub Actions, infrastructure | haiku | + | GitHub MCP |
| `docs-writer` | Technical documentation, README, API docs | haiku | + | GitHub MCP |
| `integration-architect` | OAuth, webhooks, third-party services | sonnet | + | Web, Context7 |
| `refactoring-expert` | Refactoring, N+1 fixes, code quality | sonnet | + | — |
| `qa` | E2E testing, Playwright, visual regression | sonnet | + | All 21 Playwright tools |
| `queue-specialist` | BullMQ workers, jobs, async processing | sonnet | + | — |
| `reviewer` | Code review, architecture audit | sonnet | — | GitHub MCP (review) |
| `security-scanner` | OWASP, auth/authz, credential leaks | opus | — | Web (CVE lookup) |
| `tester` | Unit/integration tests, Vitest, Stryker mutation | sonnet | + | — |

### Rules (9)

Rule files loaded by agents and orchestrator on demand:

| Rule | Purpose |
|------|---------|
| `architecture.md` | Clean Architecture layers, domain organization |
| `code-style.md` | TypeScript strict mode, ESLint/Prettier/tsc conventions |
| `docker-commands.md` | Docker-prefixed commands reference (Node.js/npm/Prisma) |
| `validation-authorization.md` | js-validator-livr (primary) / Zod + Guards / CASL RBAC |
| `git-operations.md` | Commit/push safety, PR description format |
| `mcp-stack.md` | MCP tool usage guide (Context7, GitHub, Figma) |
| `migrations-queue.md` | Prisma migration conventions, BullMQ queue pattern |
| `testing.md` | Vitest/Jest, Stryker mutation testing, ORM testing policy |
| `workflow.md` | Agent pipeline orchestration + agent routing table |

Three files (`workflow.md`, `code-style.md`, `git-operations.md`) are auto-imported in `CLAUDE.md` via `@`-imports — always in context. The rest are loaded by agents on demand via reference links.

### Skills (23)

Reusable knowledge modules organized by category:

**TypeScript & Node.js:** `typescript-pro`, `typescript-architecture`

**Testing:** `vitest-testing`, `test-master`, `playwright-expert`, `playwright-skill`

**Database:** `database-optimizer`, `postgresql`, `postgres-best-practices`

**Architecture:** `architecture-designer`, `ddd-strategic-design`, `code-reviewer`, `architect-review`

**DevOps:** `devops`, `docker-expert`, `github-actions`

**Debugging & Security:** `debugging-wizard`, `security-reviewer`

**Frontend:** `vue-expert`, `react-expert`, `angular-expert`

**Planning:** `plan-writing`, `brainstorming`

### Workflow Pipeline

The configuration defines a mandatory agent pipeline for feature development:

```
Standard Feature:  Planning Team → Backend Developer → Quality Gate Team → DocsWriter
Bug Fix:           Debugger → Backend Developer → Verify Team
CI/CD:             DevOps → Reviewer + Security Scanner
```

**Planning Team** (`plan-{slug}`) runs `ba`, `ddd-architect`, and `devil` in parallel. `devil` is a read-only devil's advocate that challenges requirements and architecture decisions via SendMessage before any code is written. For simple features with no arch decisions, `ba` runs sequentially alone.

**Quality Gate Team** (`qg-{slug}`) runs `tester`, `reviewer`, `security-scanner`, and `qa` in parallel via TeamCreate. If any agent reports a Critical or Important issue, findings route back to Backend Developer and the team reruns.

## Prerequisites

- [Claude Code](https://code.claude.com) CLI installed
- Node.js 18+ (only needed if using the optional `npx skills` CLI in Step 3)
- A Node.js/TypeScript project (ideally with Docker)

## Quick Start

### Step 1: Copy Configuration

Clone this repository:

```bash
git clone git@github.com:vaReliy/claude-ts.git /tmp/claude-ts-config
```

**Fresh project (no existing `.claude/` or `CLAUDE.md`):**

```bash
cp -r /tmp/claude-ts-config/.claude /path/to/your-project/
cp /tmp/claude-ts-config/CLAUDE.md /path/to/your-project/
```

**Existing project (already has `CLAUDE.md` and/or `.claude/`):**

1. **Merge `.claude/` subdirectories** — copy `agents/`, `rules/`, `skills/`, `commands/` from this repo into your project's `.claude/`. Do not overwrite existing files you want to keep.
2. **Prepend `CLAUDE.md` content** — paste this repo's `CLAUDE.md` at the **top** of your existing `CLAUDE.md`. Keep the `@.claude/rules/*.md` imports intact; they resolve from the project root.
3. **Merge `settings.json`** — if your project already has `.claude/settings.json`, add `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` to its `env` block rather than overwriting the file.

> **All 23 skills** are already bundled in `.claude/skills/` and activate as soon as you copy the folder — no separate install needed.

### Step 2: Install Superpowers Plugin

[Superpowers](https://github.com/obra/superpowers) provides structured development workflows.

Run inside Claude Code:

```
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```

### Step 3 (Optional): Install Extra Community Skills

The 23 bundled skills already cover TypeScript, testing, frontend, DevOps, architecture, and debugging. To pull **additional** skills from external GitHub repos, use the [`skills` CLI](https://www.npmjs.com/package/skills):

```bash
npx skills add <owner/repo>
```

Skip this step unless you have specific external skills to install.

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

### Add a New Rule

Create `.claude/rules/my-rule.md` with markdown content. Rules are auto-loaded for every conversation.

### Add a New Skill

Create `.claude/skills/my-skill/SKILL.md`:

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

| Layer | Pattern |
|-------|---------|
| HTTP entry | Route handler / Controller |
| Business operation | UseCase |
| Shared logic | Service |
| Data access | Repository |
| Domain model | Entity |
| Authorization | Guard / Middleware / CASL |
| Validation | js-validator-livr (primary) / Zod |
| Value objects | Enums |
| Async work | BullMQ Workers |
| Cross-cutting | Events / Handlers |

**Strict role separation:** `backend-developer` handles Node.js API only. Each frontend framework has its own dedicated agent (`vue-developer`, `react-developer`, `angular-developer`) — no combined "fullstack" agents.

## License

MIT
