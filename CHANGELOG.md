# Changelog

All notable changes to this Claude Code configuration template are documented here.

## [Unreleased] — Skill imports wave 1

### Added

- **`.claude/skills/grill-me/`** (new, from `mattpocock/skills`): one-question-at-a-time interrogation loop that pressure-tests a plan/design already on the table. Upstream split the original self-contained skill into a thin `grill-me` wrapper plus a separate `grilling` skill holding the body; folded `grilling`'s content back into a single self-contained `grill-me` for CTS, which prefers dependency-free skills. Dedup ruling vs. `brainstorming` (open-ended idea generation before a design exists) and `plan-writing` (task breakdown after a design is agreed): no overlap, import as-is.
- **`.claude/skills/handoff/`** (new, from `mattpocock/skills`): compacts the current conversation into a handoff document for a fresh agent session to pick up. Cited by the `rules/workflow.md` quality-gate hard-stop continuation-task format (R3-D5).
- **`.claude/skills/tdd/`** (new, from `mattpocock/skills`): the red-green-refactor discipline loop (seams, anti-patterns, one-slice-at-a-time rules) — distinct from `vitest-testing`'s tooling/mocking/coverage setup and `test-master`'s broader test-strategy/automation-framework guidance. Code examples reformatted to `singleQuote: true` per this project's `.prettierrc`.
- **`THIRD_PARTY.md`**: entries for all three imports above, plus attribution details on the `grill-me`/`grilling` merge.
- **`README.md`**: skill inventory bumped to 30, with dedup notes inline for the three new skills.

## [Unreleased] — Contributed from penny

### Fixed

- **`.prettierrc`** (new) + 40 files under `.claude/skills/**` and `rules/migrations-queue.md`: reformatted embedded code examples to `singleQuote: true`, matching both consumer projects' own Prettier config (Penny, HPW). CTS had no `.prettierrc` of its own, so its code fences drifted to Prettier's double-quote default while consumers reformatted their synced copies to their project style — producing phantom diffs on every `/cts-contribute` run. Content is otherwise byte-identical; this is a pure formatting alignment, no semantic changes.

## [Unreleased] — Contributed from penny (workflow & agent enhancements)

### Added

- **`.claude/skills/cts-rule-auditor/`** (renamed from `rules-auditor`): extended from 5 to 10 structural checks — foresight gate presence, severity floor coverage across workflow.md + reviewer.md + security-scanner.md, project-scope pre-flight doc existence, roadmap-prioritization rule, stale `rules-auditor` reference detection.
- **`.claude/skills/distill-inbox/`** (new): distills `docs/KNOWLEDGE_INBOX.md` by categorizing entries into Done/Clear-target/Uncertain and dispatching a docs-writer agent to perform the writes.
- **`rules/task-authoring.md`** (new): backlog task-file convention — naming, header, body sections, splitting rule, blast-radius map for seam-touching tasks, parked-task convention.
- **`rules/nx-generators.md`** (new): Nx generator-output audit checklist — caret-range injection, tsconfig strict block, LIVR/bootstrap-style silent failures, bundler-contract prescription, Vitest target name (`vite:test` vs `test`), SCSS enforcement, `--name`/`--directory` flag fixes, deprecated `@nx/vite` plugin removal.
- **`rules/dependencies.md`** (new): exact-pin dependency audit procedure, extracted from AGENTS.md.
- **`.claude/hooks/knowledge-capture-nudge.sh`** (new) + `cts-payload.txt`: added `.claude/hooks/` to the payload manifest (it was referenced by `.claude/settings.json` but never synced to consumers) and added the Stop hook itself, which nudges the orchestrator once per session per unmet knowledge-capture obligation.
- **`rules/workflow.md`**: foresight gate (blast-radius map required before implementation on seam-touching tasks), severity floor (4-tier emit-vs-drop table preventing infinite review loops), roadmap-prioritization rule for emitted tasks, Command Execution Policy (Nx targets) section, sequential quality gate (`tester` → `reviewer` → `[security-scanner ∥ qa]`, max 2 restart cycles), two-section Fix-Now/Emit-as-Task finding-classification contract, mixed infra+code split-dispatch routing note.
- **`rules/validation-authorization.md`**: HTTP status contract (authn guards → 401, authz guards → 403) and a generalized two-guard pattern (SessionGuard + StatusGuard) for multi-step/status-gated authorization flows.
- **`rules/code-style.md`**: Object Destructuring section; full Comments section (acceptable vs. never-write, TODO/FIXME hygiene).
- **`AGENTS.md`**: comment-hygiene bullet, exact-pin dependency bullet, Verification Commands section (Nx-target directive), on-demand index entries for the three new rules files.
- **All `.claude/agents/*.md`** (except `vue-developer`, `react-developer`): mandatory `## Pre-flight` section — read `docs/KNOWLEDGE_INBOX.md` before acting; technical agents additionally read `rules/architecture.md` + `rules/code-style.md` (+ platform-specific rules files if the project splits them, e.g. `-angular`/`-backend` suffixes); `reviewer`/`security-scanner` additionally get project-scope pre-flight (read `ARCHITECTURE.md`/`DECISIONS.md`/`CONTEXT.md` if present), seam-aware bidirectional-wiring depth, `## Fix Now` / `## Emit as Task` finding classification, severity-floor application, and a commit policy (suggest, never commit). `## Learnings` report bullet added to all agents' Report Format sections.
- **`.mcp.json`**: `--name github-mcp-server` flag to avoid random container names for the Docker-based GitHub MCP server.

### Fixed

- **`CLAUDE.md`**: triage rule 1 no longer treats ESLint/CI/tsconfig/build-config changes as "trivial" just because they touch ≤2 files (these are executable and correctness-bearing); quality gate rewritten to mandatory sequential execution; hard tool limits carve out ledger docs (`docs/KNOWLEDGE_INBOX.md`, `CHANGELOG.md`, etc.) as orchestrator-writable; knowledge-capture paragraph rewritten with an explicit litmus test and a pointer to the cheap-override exception.
- **`rules/testing.md`**: `vi.stubEnv(KEY, '')` vs. `delete process.env[KEY]` anti-pattern documented — the latter escapes `vi.unstubAllEnvs()` tracking and leaks state across tests.
- **`.claude/agents/devops.md`**: pre-flight scoped to `rules/code-style.md` only (not `rules/architecture.md`, which covers Clean Architecture layers irrelevant to infra-only work).

## [2026-07-01] — Sync Reliability: Failure Surfacing + Local-Edit Preservation

### Fixed

- **`.claude/skills/cts-update/SKILL.md`**: the engine call step never checked the exit code or the presence of the script's `Done. Review with: git diff` success marker before narrating results. When `cts-sync.sh update` failed before copying anything (e.g. the upstream clone/fetch couldn't reach the network, leaving `~/.cache/claude-ts` never created), the skill reported it as "nothing to update" instead of surfacing the failure — indistinguishable from a project genuinely being up to date. The skill now treats a non-zero exit, or a zero exit missing the success marker, as a hard stop: it shows the raw stderr and tells the user to retry, without touching `.cts-version` or narrating step 3.
- **`.claude/scripts/cts-sync.sh`**: `update` previously did an unconditional full recopy of every non-ignored payload file to the source's current tip on every run, silently overwriting any local customization that hadn't yet been added to `.ctsignore` — a direct conflict with the `/cts-contribute` workflow, which depends on those edits surviving until they're exported upstream. A file is now only fast-forwarded if the working copy still matches the version last synced (the blob at `.cts-version`'s recorded SHA); if it diverged, the copy is skipped and reported as `locally modified, not overwritten — diff manually: <path>` (with a ready-to-run `git diff` command) instead of being clobbered.
- **`.claude/skills/cts-update/SKILL.md`**: building on the failure-surfacing fix above, step 3 narration now also surfaces `locally modified, not overwritten` lines alongside the existing `ignored, but changed upstream` and `removed upstream` notices. Step 5 ("Flag risks") is replaced with "Resolve locally-modified files", since the engine no longer overwrites-then-warns — it refuses the overwrite up front, so the skill's job is to help merge the upstream diff, point to `/cts-contribute` for edits meant to go upstream, or suggest a `.ctsignore` entry to quiet future reports.

## [2026-06-30] — Reverse Contribution Flow

### Added

- **`.claude/skills/cts-contribute/SKILL.md`** (`/cts-contribute`): consumer-side skill for contributing improvements back to a local CTS checkout. Runs from inside a consumer project (`penny`, `hpw`, etc.) and guides a full export session: four pre-flight hard blocks (consumer identity, CTS target resolution, sync alignment, knowledge inbox gate), three-case candidate discovery (net-new skills auto-queued; CTS-managed file edits flagged; `.ctsignore`'d file hunks pre-filtered by project-specific signals then reviewed interactively), hunk-level Q/A with export/skip/edit-before-export decisions, writes only after all decisions are confirmed, updates both CTS `CHANGELOG.md` and the consumer's `docs/CLAUDE_TS_CHANGELOG.md` (distills contributed entries). Never commits or pushes. Natural counterpart to `/cts-update`.

## [2026-06-26] — Sync Hardening

### Fixed

- **`.claude/agents/dba.md`, `.claude/agents/qa.md`**: skill-activation tables still referenced skills deleted during the skill dedup (`database-optimizer`, `postgresql`, `playwright-skill`); now they reference the surviving `postgres-best-practices` and `playwright-expert` only.
- **`.claude/scripts/cts-sync.sh`**: `is_ignored()` now supports root-anchored patterns — a leading `/` (e.g. `/AGENTS.md`) matches only the project-root file, so protecting a customized root `AGENTS.md`/`CLAUDE.md` no longer collaterally skips same-named nested payload files (e.g. `.claude/skills/postgres-best-practices/AGENTS.md`). Bare patterns keep gitignore's match-anywhere behavior.
- **`.claude/scripts/cts-sync.sh`**: a `set -e` guard bug aborted `update` silently on the first ignored file when not in `--dry-run`.

### Added

- **`cts-sync.sh` upstream-drift report**: `update` now prints `ignored, but changed upstream — review manually: <path>` (with a ready-to-run `git diff` command) for every `.ctsignore`d file that changed in CTS since the last sync — customizing a file no longer silently cuts the project off from upstream improvements. Per-file `skip (ignored)` lines now print only in `--dry-run`.
- **`/cts-update` merge step**: for each drift-flagged file the skill reviews the upstream diff and offers to hand-merge applicable hunks into the customized local file, or suggests removing the `.ctsignore` entry when local and upstream have converged.
- **`README.md`**: documents `.ctsignore` root-anchoring and a hygiene policy — every ignore entry is either project-specific (keep), an improvement to contribute upstream then un-ignore, or style-only divergence (prefer un-ignoring).

## [2026-06-26] — Knowledge Inbox

### Added

- **`docs/KNOWLEDGE_INBOX.md` pattern** (agent-agnostic memory layer): an append-only inbox for durable, project-relevant learnings whose final home (`PROJECT_CONTEXT.md`, `CLAUDE.md`, a rule, or a skill) isn't clear yet. `rules/workflow.md`'s Phase 6 (Knowledge Capture) defines the 3-line entry format, the decision rule for when to use the inbox vs. auto-memory vs. a permanent home, and automatic threshold-based distillation (>10 entries or ~3 KB) back into permanent homes. `AGENTS.md`'s On-Demand Rules Index references the file by plain path (never `@`-referenced, to avoid force-loading it). `/cts-setup` bootstraps `docs/KNOWLEDGE_INBOX.md` from the template if absent; it is project data and intentionally excluded from `cts-payload.txt`. `README.md` documents the pattern in the Repo Structure section.

## [2026-06-26] — Distribution Engine

### Added

- **`.claude/skills/cts-import-skill/SKILL.md`** (`/cts-import-skill`): maintainer-only flow for importing an external skill into CTS's curated `.claude/skills/`. Guards that it's running inside the `claude-ts` repo, fetches the source, runs a blocking duplication check against every existing skill and `THIRD_PARTY.md` (merge/replace/reject/import-as-is), brings the description/body up to CTS's skill-quality bar, checks license compatibility, and updates the README skills inventory, `THIRD_PARTY.md`, and this changelog. Never commits.
- **`.claude/skills/cts-setup/SKILL.md`** (`/cts-setup`): guided install/merge of the CTS payload into a project — one `cts-sync.sh init` (or `init --dry-run` + hand-merge for existing projects) engine call, then AskUserQuestion-driven frontend-framework pruning per the Install Profile, recording pruned/customized paths in `.ctsignore`.
- **`.claude/skills/cts-update/SKILL.md`** (`/cts-update`): narrated `cts-sync.sh update` — summarizes upstream changes, files updated/skipped, flags locally-modified files at risk of being overwritten, and suggests `.ctsignore` additions. Never commits.
- **`cts-payload.txt`**: manifest listing every path (`AGENTS.md`, `CLAUDE.md`, `.mcp.json`, `rules/`, `.claude/agents|skills|scripts/`, `.claude/settings.json`) that `cts-sync.sh` installs into target projects.
- **`.claude/scripts/cts-sync.sh`**: zero-dependency bash engine with `init`/`update`/`--dry-run`/`--force` modes. `init` copies the payload into a target git repo and writes `.cts-version` (source commit SHA); `update` re-syncs the payload while skipping paths listed in `.ctsignore`, reports files removed upstream without deleting them, and prints the `claude-ts` changelog between the old and new `.cts-version`. Source defaults to `claude-ts` on GitHub (cached at `~/.cache/claude-ts`) or a local checkout via `--source <path>`.
- **`.ctsignore` convention** (documented in `README.md`): gitignore-syntax file in the target project root for customized CTS files, pruned CTS files, and project-only additions under payload directories — `cts-sync.sh update` never touches matching paths.

### Changed

- **`README.md`**: install/update flow is now skill-first — Quick Start gives a copy-paste prompt that runs `cts-sync.sh init` then `/cts-setup`; updating documents `/cts-update` with an internals box explaining the script, `.ctsignore`, `.cts-version`, and `git diff`-based review. The Install Profile (pruning) section is reframed as part of `/cts-setup`, recorded in `.ctsignore`. Removed the manual clone + `cp -r` install instructions; a manual `cts-sync.sh` invocation remains documented as a secondary path for CI / no-agent use.

## [2026-06-26] — Framework-Agnostic Split

### Changed

- **Split into a portable core and a Claude adapter**: new root `AGENTS.md` carries Stack, Git Safety, Code Style Essentials, the On-Demand Rules Index, and a new vendor-neutral **Model Tiers** vocabulary (`deep`/`standard`/`cheap`, mapped to `opus`/`sonnet`/`haiku` for Claude) — readable by any AI CLI. `CLAUDE.md` is now a thin Claude adapter: it imports `AGENTS.md` via `@AGENTS.md` (Claude Code does not auto-load `AGENTS.md`) and keeps only the Orchestrator (Dispatcher) Core and Skills preferences.
- **`.claude/rules/` moved to root `rules/`** (`git mv .claude/rules rules`); all references updated across `CLAUDE.md`, `AGENTS.md`, `README.md`, and `.claude/agents/*.md`/`.claude/commands/*.md`. Root `rules/` is no longer auto-loaded — files are read on demand by agents and the orchestrator, as the On-Demand Rules Index always intended.
- **`README.md`**: added a "Repo Structure" section explaining the portable-core (`AGENTS.md` + `rules/`) vs Claude-adapter (`CLAUDE.md` + `.claude/`) split, and updated the Rules table and "Add a New Rule" instructions for the new `rules/` location.

## [2026-06-26] — Token Optimization Round 1

### Changed

- **`CLAUDE.md`** rewritten with zero `@`-imports. The orchestrator core (triage tree, routing table, conditional quality gate, hard tool limits, git safety, code-style essentials) is now inline; rule files are referenced by plain path and load on demand instead of being force-loaded into every conversation.
- **`.claude/rules/workflow.md`**: quality gate is now conditional — `tester` and `reviewer` always run; `security-scanner` only for changes touching auth/validation/secrets/HMAC/external input; `qa` only when a user-visible flow changed. Added a mandatory "Phase 6: Knowledge Capture" step after `docs-writer` (CHANGELOG/project-context/auto-memory updates).
- **All 18 agent definitions** (`.claude/agents/*.md`, including the 3 frontend agents): trimmed descriptions (dropped `<example>` blocks, Ukrainian trigger lists reduced to 4-5 keywords); model tier changes — `ba`, `devil`, `security-scanner` downgraded to `sonnet` (kept `opus` for `ddd-architect` and `debugger`); every agent now ends with a standardized `## Report Format (mandatory)` section.
- **`.claude/skills/postgres-best-practices/AGENTS.md`**: gained two new sections (8.3 Specialized Data Types and Extensions, 8.4 Server Configuration Tuning) consolidating unique content from the removed `postgresql` and `database-optimizer` skills.
- **`.claude/skills/github-actions/`**: scoped to JavaScript/TypeScript and Docker pipelines — removed PHP (Laravel/Symfony/NativePHP) and .NET workflow references, examples, and caching steps.
- **`.claude/skills/security-reviewer/`** and **`.claude/skills/playwright-expert/`**: descriptions compressed to match the rest of the agent/skill set.
- **`README.md`**: agent count table updated for new model tiers, skill count updated to 20, added an "Install Profile" section describing how to prune frontend agents/skills for single-framework or backend-only projects, and a maintenance note on preserving each agent's `## Report Format` section.
- Normalized markdown formatting across `.claude/` with Prettier (whitespace/table-alignment only, no content changes).

### Removed

- `.claude/skills/playwright-skill/` — superseded by `playwright-expert/`.
- `.claude/skills/postgresql/` and `.claude/skills/database-optimizer/` — superseded by `postgres-best-practices/` (unique content folded in, see above).
- **Laravel/PHP leftover content** (Round 2): `.mcp.json` `laravel-boost` MCP server block; three reference files (`.claude/skills/typescript-pro/references/laravel-patterns.md`, `modern-php-features.md`, `async-patterns.md`); PHP/Laravel sections from debugging-wizard references; PHP mention from code-reviewer language-specific expertise; PHPStan comparison from code-style.md.
