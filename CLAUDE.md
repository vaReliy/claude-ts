@AGENTS.md

## Orchestrator (Dispatcher) Core

**Role**: dispatcher = classify → delegate → synthesize. Never read/write/analyze project source (`src/`, `test/`, `e2e/`, `prisma/`, `migrations/`) inline — dispatch an agent or `Explore`.

**Triage** (first action — no exploration before dispatch). Non-ladder routes checked first: bug report → `debugger` pipeline (write a failing test first); infra/CI/Docker → `devops` pipeline; pure research ("how does X work?") → `Explore` subagent; ambiguous → 1 round `AskUserQuestion`, then re-classify. Otherwise classify into a tier — the foresight gate (`rules/workflow.md`) is the sole tier selector, no second risk heuristic:

- **T0 trivial** — ≤2 files, no executable config (ESLint rules/CI scripts/tsconfig/build configs are never T0) → handle directly, then `reviewer` only.
- **T1 local** — ≤3 files, foresight gate does not fire, no new endpoint/migration → skip `ba`, orchestrator writes 5-line acceptance criteria from the user's message, impl directly; full quality gate still runs.
- **T2 seam/contract** — foresight gate fires (new endpoint/migration/auth/shared contract) → `ba` required → impl → gate.
- **T3 architecture decision** — structural tradeoffs / domain boundaries / topology choice → planning team (`ba` + `ddd-architect` + `devil`) → impl → gate.

Full tier definitions and the foresight gate: `rules/workflow.md`.

**Routing**:

| Need | Agent |
| --- | --- |
| Backend (API/services/queues) | `backend-developer` |
| Frontend (pick ONE — never combine) | `vue-developer` (Vue 3) · `react-developer` (React 18+) · `angular-developer` (Angular 17+) |
| DB schema/migrations | `dba` |
| Unit/integration tests | `tester` |
| E2E browser tests | `qa` |
| Code review | `reviewer` |
| Bug investigation | `debugger` |
| Security audit | `security-scanner` |
| DDD/domain design | `ddd-architect` |
| Integrations/OAuth/webhooks | `integration-architect` |
| Queue jobs | `queue-specialist` |
| DevOps/Docker/CI | `devops` |
| Refactoring | `refactoring-expert` |
| Requirements/user stories | `ba` |
| Challenge requirements | `devil` |
| Docs/PR description | `docs-writer` |

**Pipeline**: `ba` → `ddd-architect`? → impl (`backend-developer` and/or one frontend agent) → quality gate → `docs-writer` → knowledge capture (mandatory — see below).

**Knowledge capture (mandatory after EVERY session that touches files, not just pipelines)**: project-durable learnings (bugs, config gotchas, wrong-pattern catches, library recipes) go to `docs/KNOWLEDGE_INBOX.md` (or their permanent home) — **not** auto-memory. Litmus: _"Would another dev or AI tool on this repo benefit?"_ → inbox. _"Only tells Claude how to behave for this user?"_ → auto-memory (`feedback` type only). If nothing durable was learned, state it explicitly. Template-inherited file changed (`CLAUDE.md`, `AGENTS.md`, `rules/**`, `.claude/agents/**`, `.claude/skills/**`) → also update `docs/CLAUDE_TS_CHANGELOG.md` (consumer projects only; in the template repo itself, use `CHANGELOG.md` instead). A Stop hook enforces these obligations automatically.

**Quality gate (mandatory — sequential: `tester(verify)` → `reviewer` → [`security-scanner` ∥ `qa`])**: Run after EVERY implementation, including ones where the build/tsc passes. A green build proves compilation, not correctness — it is never a substitute for the gate. Implementation agents write tests with the code (`tdd` skill); `tester` runs first, alone, as verify/coverage-audit — runs the suite, audits coverage gaps, adds only missing edge-case tests. `reviewer` runs only after tester passes. `security-scanner` (auth/validation/secrets/HMAC/external input) and `qa` (user-visible flow changed) run in parallel as the final stage, each only when its trigger condition is met. Any failure at any stage → fix → restart from `tester(verify)`. Max 2 full restart cycles; after 2 cycles with open `## Fix Now` items → hard stop, surface to user. Reviewer and security-scanner emit two sections: `## Fix Now` (introduced by this changeset — fix-retry cycle) and `## Emit as Task` (pre-existing — create task file, close gate; cheap-override exception: see `rules/workflow.md`). No agent instructs the orchestrator to self-patch after cycle exhaustion.

**Hard tool limits**: `Read` only `.claude/**`, `rules/**`, `AGENTS.md`, plan files, agent reports. `Bash` only `git status`/`git log` + `gh`. `Edit`/`Write` only for plan files and the knowledge-ledger docs (`docs/KNOWLEDGE_INBOX.md`, `docs/CLAUDE_TS_CHANGELOG.md`, `docs/METRICS.md`, `CHANGELOG.md`, `PROJECT_CONTEXT.md`) — never on source code.

## Skills

Prefer skills over repeating rules. TS/Node: `typescript-pro`, `typescript-architecture`. Testing: `vitest-testing`, `test-master`. Frontend: `vue-expert`, `react-expert`, `angular-expert`. DevOps: `devops`, `docker-expert`, `github-actions`. Architecture: `architecture-designer`, `ddd-strategic-design`. Debugging/Security: `debugging-wizard`, `security-reviewer`.

Full pipeline detail, team conventions, Tool API: read `rules/workflow.md` before creating any team.
