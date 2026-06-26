# Changelog

All notable changes to this Claude Code configuration template are documented here.

## [Unreleased] — Sync Hardening

### Fixed

- **`.claude/agents/dba.md`, `.claude/agents/qa.md`**: skill-activation tables still referenced skills deleted during the skill dedup (`database-optimizer`, `postgresql`, `playwright-skill`); now they reference the surviving `postgres-best-practices` and `playwright-expert` only.
- **`.claude/scripts/cts-sync.sh`**: `is_ignored()` now supports root-anchored patterns — a leading `/` (e.g. `/AGENTS.md`) matches only the project-root file, so protecting a customized root `AGENTS.md`/`CLAUDE.md` no longer collaterally skips same-named nested payload files (e.g. `.claude/skills/postgres-best-practices/AGENTS.md`). Bare patterns keep gitignore's match-anywhere behavior.
- **`.claude/scripts/cts-sync.sh`**: a `set -e` guard bug aborted `update` silently on the first ignored file when not in `--dry-run`.

### Added

- **`cts-sync.sh` upstream-drift report**: `update` now prints `ignored, but changed upstream — review manually: <path>` (with a ready-to-run `git diff` command) for every `.ctsignore`d file that changed in CTS since the last sync — customizing a file no longer silently cuts the project off from upstream improvements. Per-file `skip (ignored)` lines now print only in `--dry-run`.
- **`/cts-update` merge step**: for each drift-flagged file the skill reviews the upstream diff and offers to hand-merge applicable hunks into the customized local file, or suggests removing the `.ctsignore` entry when local and upstream have converged.
- **`README.md`**: documents `.ctsignore` root-anchoring and a hygiene policy — every ignore entry is either project-specific (keep), an improvement to contribute upstream then un-ignore, or style-only divergence (prefer un-ignoring).

## [Unreleased] — Knowledge Inbox

### Added

- **`docs/KNOWLEDGE_INBOX.md` pattern** (agent-agnostic memory layer): an append-only inbox for durable, project-relevant learnings whose final home (`PROJECT_CONTEXT.md`, `CLAUDE.md`, a rule, or a skill) isn't clear yet. `rules/workflow.md`'s Phase 6 (Knowledge Capture) defines the 3-line entry format, the decision rule for when to use the inbox vs. auto-memory vs. a permanent home, and automatic threshold-based distillation (>10 entries or ~3 KB) back into permanent homes. `AGENTS.md`'s On-Demand Rules Index references the file by plain path (never `@`-referenced, to avoid force-loading it). `/cts-setup` bootstraps `docs/KNOWLEDGE_INBOX.md` from the template if absent; it is project data and intentionally excluded from `cts-payload.txt`. `README.md` documents the pattern in the Repo Structure section.

## [Unreleased] — Distribution Engine

### Added

- **`.claude/skills/cts-import-skill/SKILL.md`** (`/cts-import-skill`): maintainer-only flow for importing an external skill into CTS's curated `.claude/skills/`. Guards that it's running inside the `claude-ts` repo, fetches the source, runs a blocking duplication check against every existing skill and `THIRD_PARTY.md` (merge/replace/reject/import-as-is), brings the description/body up to CTS's skill-quality bar, checks license compatibility, and updates the README skills inventory, `THIRD_PARTY.md`, and this changelog. Never commits.
- **`.claude/skills/cts-setup/SKILL.md`** (`/cts-setup`): guided install/merge of the CTS payload into a project — one `cts-sync.sh init` (or `init --dry-run` + hand-merge for existing projects) engine call, then AskUserQuestion-driven frontend-framework pruning per the Install Profile, recording pruned/customized paths in `.ctsignore`.
- **`.claude/skills/cts-update/SKILL.md`** (`/cts-update`): narrated `cts-sync.sh update` — summarizes upstream changes, files updated/skipped, flags locally-modified files at risk of being overwritten, and suggests `.ctsignore` additions. Never commits.
- **`cts-payload.txt`**: manifest listing every path (`AGENTS.md`, `CLAUDE.md`, `.mcp.json`, `rules/`, `.claude/agents|skills|scripts/`, `.claude/settings.json`) that `cts-sync.sh` installs into target projects.
- **`.claude/scripts/cts-sync.sh`**: zero-dependency bash engine with `init`/`update`/`--dry-run`/`--force` modes. `init` copies the payload into a target git repo and writes `.cts-version` (source commit SHA); `update` re-syncs the payload while skipping paths listed in `.ctsignore`, reports files removed upstream without deleting them, and prints the `claude-ts` changelog between the old and new `.cts-version`. Source defaults to `claude-ts` on GitHub (cached at `~/.cache/claude-ts`) or a local checkout via `--source <path>`.
- **`.ctsignore` convention** (documented in `README.md`): gitignore-syntax file in the target project root for customized CTS files, pruned CTS files, and project-only additions under payload directories — `cts-sync.sh update` never touches matching paths.

### Changed

- **`README.md`**: install/update flow is now skill-first — Quick Start gives a copy-paste prompt that runs `cts-sync.sh init` then `/cts-setup`; updating documents `/cts-update` with an internals box explaining the script, `.ctsignore`, `.cts-version`, and `git diff`-based review. The Install Profile (pruning) section is reframed as part of `/cts-setup`, recorded in `.ctsignore`. Removed the manual clone + `cp -r` install instructions; a manual `cts-sync.sh` invocation remains documented as a secondary path for CI / no-agent use.

## [Unreleased] — Framework-Agnostic Split

### Changed

- **Split into a portable core and a Claude adapter**: new root `AGENTS.md` carries Stack, Git Safety, Code Style Essentials, the On-Demand Rules Index, and a new vendor-neutral **Model Tiers** vocabulary (`deep`/`standard`/`cheap`, mapped to `opus`/`sonnet`/`haiku` for Claude) — readable by any AI CLI. `CLAUDE.md` is now a thin Claude adapter: it imports `AGENTS.md` via `@AGENTS.md` (Claude Code does not auto-load `AGENTS.md`) and keeps only the Orchestrator (Dispatcher) Core and Skills preferences.
- **`.claude/rules/` moved to root `rules/`** (`git mv .claude/rules rules`); all references updated across `CLAUDE.md`, `AGENTS.md`, `README.md`, and `.claude/agents/*.md`/`.claude/commands/*.md`. Root `rules/` is no longer auto-loaded — files are read on demand by agents and the orchestrator, as the On-Demand Rules Index always intended.
- **`README.md`**: added a "Repo Structure" section explaining the portable-core (`AGENTS.md` + `rules/`) vs Claude-adapter (`CLAUDE.md` + `.claude/`) split, and updated the Rules table and "Add a New Rule" instructions for the new `rules/` location.

## [Unreleased] — Token Optimization Round 1

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
