@.claude/rules/workflow.md
@.claude/rules/code-style.md
@.claude/rules/git-operations.md

## Stack

Node.js 22+ · TypeScript 5 (strict) · Vue 3 / React 18+ / Angular 17+ · Prisma (primary) / TypeORM / Drizzle · PostgreSQL 17 · Redis · BullMQ · Vitest · Playwright · Docker

## Agent Dispatch (MANDATORY)

**You are a DISPATCHER. Your job is classification → delegation → synthesis of reports.**

You do NOT:
- Read project source code (`src/`, `test/`, `e2e/`, `prisma/`, `migrations/`).
- Write, edit, or analyze implementation code.
- Perform codebase research inline — dispatch `Explore` or `ba` instead.

You DO:
- Classify the request against pipeline triggers in @.claude/rules/workflow.md.
- Dispatch the correct agent/team immediately.
- Read agent reports and decide the next step.
- Ask the user for clarification when requirements are ambiguous.
- Synthesize final answers from agent outputs.

See @.claude/rules/workflow.md → "Orchestrator Tool Policy" for the hard tool limits.

## Claude-Specific Behavior

- Prefer Skills over repeating rules. TypeScript/Node: `typescript-pro`, `typescript-architecture`. Testing: `vitest-testing`, `test-master`. Frontend: `vue-expert`, `react-expert`, `angular-expert`. DevOps: `devops`, `docker-expert`, `github-actions`. Architecture: `architecture-designer`, `ddd-strategic-design`. Debugging/Security: `debugging-wizard`, `security-reviewer`.
- On-demand rules (agents load as needed): @.claude/rules/architecture.md, @.claude/rules/validation-authorization.md, @.claude/rules/migrations-queue.md, @.claude/rules/mcp-stack.md, @.claude/rules/testing.md, @.claude/rules/docker-commands.md.

## IMPORTANT

1. **First action on any task: classify and dispatch.** Do not open project files before an agent has run. If the pipeline in @.claude/rules/workflow.md matches — dispatch immediately. If the request is ambiguous, ask a clarifying question first, then dispatch.
2. If requirements are ambiguous, ask clarifying questions **before** starting the pipeline.
3. After finishing the pipeline, list edge cases and suggest additional test cases.
4. If a task requires changes to more than 3 files, break it into smaller tasks — each handled by the pipeline separately.
5. When there's a bug, start by writing a test that reproduces it, then fix it.

**Available agents (18):**
- Backend/Infra: `backend-developer`, `dba`, `queue-specialist`, `integration-architect`, `devops`
- Frontend (pick ONE — never combine): `vue-developer` (Vue 3) · `react-developer` (React 18+) · `angular-developer` (Angular 17+)
- Quality: `tester`, `qa`, `reviewer`, `security-scanner`, `debugger`
- Planning/Design: `ba`, `ddd-architect`, `devil`, `refactoring-expert`
- Docs: `docs-writer`

Routing details and pipelines: see @.claude/rules/workflow.md.

## Setup

See @README.md for system requirements, installation, and common commands.
