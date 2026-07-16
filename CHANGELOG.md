# Changelog

All notable changes to this Claude Code configuration template are documented here.

## [Unreleased] — CTS-owner review-contribution skill (2026-07-16)

### Added

- **`.claude/skills/cts-review-contribution/SKILL.md`** (new): owner-side deep-tier judgment gate for CTS itself — reviews whatever is currently uncommitted in the working tree (from `/cts-contribute`, a manual edit, or anything else) for philosophy/scope fit, safety (secrets, dangerous commands, prompt-injection-shaped content), and quality-bar consistency. Delegates structural checks to `cts-rule-auditor` instead of reimplementing them; always dispatches the judgment pass via an explicit `Agent` call with `model: "opus"`, regardless of the owner's active session model. Report-only — never commits/pushes, uses `AskUserQuestion` for findings it isn't confident resolving alone.
- **`.claude/scripts/cts-sync.sh`**: new `OWNER_ONLY_SKILLS` array (mirrors the existing `NEVER_PAYLOAD` pattern) plus an `is_owner_only_skill()` check in `copy_one()`, so `.claude/skills/cts-review-contribution/` is excluded from the `.claude/skills/` payload directory on both `init` and `update` sync paths even though the payload entry itself stays a whole-directory line. A hard-error guard catches the failure mode of someone later re-listing that path as its own explicit `cts-payload.txt` entry (mirrors the `NEVER_PAYLOAD` guard's style, adapted because the forbidden path here is a subpath *within* a directory entry rather than a whole entry).
- **`cts-payload.txt`**: documented the exclusion in the existing "Explicitly NOT payload" comment block.

## [Unreleased] — Guess-note resolution lifecycle (2026-07-16)

### Added

- **`.claude/skills/distill-inbox/SKILL.md`**: Category C ("guess") inbox entries previously had no exit path — they accumulated permanently with no resolution mechanism. Added a staleness gate (`age_days >= 14 AND commits_since >= 5`, computed via `git log --since=<entry-date>`) and a new interactive Step 1.5 that resolves gate-fired entries on explicit human `/distill-inbox` invocation only (never during automatic Phase-6 dispatch — an explicit invocation-mode detection rule with an ambiguous→skip default was added to keep this safe for unattended cheap-tier dispatch). Four resolution options: promote to a concrete target, promote to claude-ts-upstream (branches on consumer-project vs. template-repo-itself via `cts-payload.txt` + `.cts-version` detection), discard, or still-uncertain (re-prompts every future run — deliberately no snooze state). Step 5's report gained resolved/still-uncertain counts.
- **`.claude/skills/cts-contribute/SKILL.md`** §1d: replaced a dead check referencing a `status: keep`/`status: undecided` field that was never implemented anywhere, with a check against the real stale-gate state `distill-inbox` now computes.

### Fixed

- **`.claude/skills/distill-inbox/SKILL.md`** Step 3's ledger obligation unconditionally required appending to `docs/CLAUDE_TS_CHANGELOG.md` for template-inherited targets, but that file doesn't exist/apply when this skill runs in the claude-ts host repo itself. Step 3 now branches on repo kind using the same `cts-payload.txt` + `.cts-version` detection Step 1.5 Option 2 already established: consumer projects still append to `docs/CLAUDE_TS_CHANGELOG.md`; the template repo itself appends to its own root `CHANGELOG.md` instead.

## [Unreleased] — Contributed from penny (2026-07-16 round)

### Added

- **`rules/docs-style.md`** (new file) + **`.prettierrc`**: `"proseWrap": "never"` so markdown prose is reflowed by `prettier --write` (already wired via lint-staged) instead of relying on agents to follow a manual no-hard-wrap convention. Reflowed the template's own docs accordingly (excluding the vendored `postgres-best-practices` skill) and fixed a pre-existing missing-blank-line bug in `rules/workflow.md`'s "Frontend agent selection" table that the reflow exposed (Prettier's markdown parser merges a block with no blank line before it into one paragraph, silently destroying table syntax).
- **`.claude/skills/cts-rule-auditor/SKILL.md`**: Check 11 — every `command` field in `.claude/settings.json` hooks must resolve to a path listed in `cts-payload.txt`, catching a payload-sync gap where a settings file references a hook script missing from a consumer's payload.
- **`rules/testing.md`**: `.env` secret-loading pattern for integration tests (`set -a && source .env && set +a`), NestJS guard-decorator-chain and pino exception-filter testing conventions, E2E production-bundle testing via a static-file-server target (dev-server transformations can hide production-only issues like minification breaking a reverse-proxy string-match rewrite), a skip-guard verification rule (grep the actual guard, don't trust a comment claiming skip-behavior), and a DB-backed-integration-specs-need-explicit-isolation-under-parallel-workers note.
- **`rules/task-authoring.md`**: default task routing moved to a top-level `./tasks/<phase>/todo|parked|done/` convention with a committed `.gitignore` entry (clone-portable, vs. a local-only `.git/info/exclude` entry), a "Premise Verification for 'Fix This' Tasks" step (check `git log -S<marker>` before trusting a task's "X is broken" premise — it may already be partially fixed), and a "Deferred ADRs Go Stale Without an Explicit Closing Step" section (any task implementing previously-deferred work must carry an AC to update that ADR's Status).
- **`rules/nx-generators.md`**: `@nx/angular:app`/`:lib` must always be scaffolded via `nx g` (never hand-written `project.json`) and silently ignores positional args without `--directory`; three generator-hygiene gotchas — a lib missing `eslint.config.mjs` is silently dropped from `nx show projects --with-target lint`/`nx affected -t lint` forever; `@nx/vitest`-based projects need a hand-added `typecheck` target since `@nx/vite/plugin`'s `typecheckTargetName` only fires for `@nx/vite:build`; `includedScripts` belongs in `package.json`'s `nx` field, not `project.json` (silently does nothing there).
- **`rules/docker-commands.md`**: `curl` (not BusyBox `wget`) for Alpine healthchecks (no happy-eyeballs IPv4/IPv6 fallback), `node:22-alpine` has neither so use inline Node HTTP, GitHub Actions service-container `--health-cmd` needs single-token quoting for multi-word commands, and a note that continuous healthcheck-cadence logs matching the configured `interval` are not a bug.
- **`rules/code-style.md`**: Shell Script Conventions — jq's `// "default"` and shell's `|| echo default` are NOT equivalent on malformed input (jq yields empty string on parse failure; the shell fallback always produces a value), so a script switching between a jq branch and a grep/sed fallback needs one branch-independent normalization step after both.
- **`.claude/skills/github-actions/SKILL.md`**: `on.branches` silently skips the entire job on non-matching branches — no error, the job simply doesn't appear in the Actions UI for that branch.
- **`.claude/skills/distill-inbox/SKILL.md`**: a CTS-managed ledger check (distilling into a template-inherited file now requires a `docs/CLAUDE_TS_CHANGELOG.md` entry in the same pass), anti-fabrication guardrails on the docs-writer dispatch (code examples must be lifted verbatim, causal claims preserved exactly), and a Step 4.5 post-write verification pass (re-read each distilled section against the source, check for structural corruption like an orphaned bullet list).
- **`rules/dependencies.md`**: CI Action SHA-pinning must dereference via `refs/tags/<tag>^{}` (a bare `git ls-remote` on an annotated tag returns the tag-object SHA, not the commit SHA — both are 40 hex chars), a metadata-only-manifest pattern for `@nx/dependency-checks` on projects with no real package-manager-importer manifest, a lockfile-reserialization false-alarm note, a "every lib importing a shared lib needs its own dependency entry" reminder, and pnpm's `-w` flag for workspace-root-only deps.
- **`rules/git-operations.md`**: never `git stash`/`git stash pop` mid-session — it mutates the working tree the user/other agents are tracking via `git diff` across turns; use `git show HEAD:<path>`, `git diff HEAD -- <path>`, or `git worktree add` instead.
- **`.claude/agents/ba.md`**, **`.claude/agents/ddd-architect.md`**: `## Learnings` report-format bullet, mirroring the existing convention on implementation agents.
- **`CLAUDE.md`**: one sentence on mid-pipeline `## Learnings` transcription (appended to the inbox immediately upon receipt, not deferred to the final phase) and one sentence on a same-session micro-resolution lane (orchestrator may resolve ≤3 qualifying non-security findings immediately after gate close, batch-verified once).
- **`rules/workflow.md`**: a "Dispatch/report protocol" note (every dispatch must instruct the agent to report back via `SendMessage`; a bare `idle_notification` gets one ping, not a duplicate re-dispatch), typecheck-target guidance (`@nx/vitest` projects need a hand-added `typecheck` target; target names come from `nx.json` plugin registrations and must stay in lockstep with the Command Execution Policy table), two quality-gate hardening rules ("verify working-tree side effects via `git diff --stat`/`git status` before dispatching `tester`" and "a plain-English claim that a lint rule will fire is not proof — demonstrate with a scratch violation"), a same-session micro-resolution lane, a mid-pipeline knowledge-transcription subsection, a "Skill Renaming" section documenting the four touch-points (directory, frontmatter `name:`, `triggers:` list, prose self-references), a Planning Team "spawn-context requirement" (paste every prior agent's full output into a reviewer/challenger's spawn prompt — a spawned agent can't assume an idle teammate will re-serve its own past output via `SendMessage`), and a corrected Tool API Reference (the `TeamCreate`/`TeamDelete`/`team_name` examples were stale — `team_name` is deprecated/ignored and there is no team object to create or delete; coordination is purely name-based `SendMessage` between agents spawned via plain `Agent` calls). Five other stray `TeamCreate`/`TeamDelete` references elsewhere in the file (Orchestrator Tool Policy, Execution Model, frontend-routing note, Team Conventions) were updated to match.
- **`rules/validation-authorization.md`**: a generalized "manual bootstrap/registration step" note — some validation libraries require a one-time registration call at process startup before any validator is constructed; document the exact call for whichever validator a project uses, since omitting it typically passes build/tsc but fails at runtime.
- **`rules/architecture.md`**: a generalized CAS-via-optional-param pattern for closing TOCTOU races on scoped entity-field updates (an optional `expectedCurrentValue` param added to a repository method's conditional-update call, returning no-match on a filter mismatch, surfaced by the caller as an explicit conflict rather than a silent retry) — store-agnostic, not specific to any one database.

### Fixed

- **`.claude/hooks/knowledge-capture-nudge.sh`**: hardened Stop-hook stdin handling — `SESSION_ID` is now normalized (empty → `"unknown"`) and sanitized to `[A-Za-z0-9_-]` before marker-path interpolation (closing a path-traversal / arbitrary-file-creation gap), with a backstop empty-check in case sanitization emptied the value; added a subagent-scoping guard (presence of `agent_id`/`agent_type` in stdin — which also covers `claude --agent` invocations, not just subagents — exits early, since the knowledge-capture obligation belongs to the orchestrator session only); added a `METRICS_UPDATED` check mirroring the existing inbox/changelog pattern, since `docs/METRICS.md` is an "Always" ledger per `rules/workflow.md` but had no corresponding Stop-hook check.
- **`.claude/settings.json`**: removed dead `docker compose exec app` eslint/prettier Stop-hook commands that no longer matched the project's actual tooling invocation.
- **`.claude/scripts/cts-sync.sh`**: fixed the self-overwrite bug where `update` (or `init`) exits non-zero with a spurious syntax error after all real work completed successfully — bash does not fully buffer a script's source before executing straight-through code, so once `.claude/scripts/cts-sync.sh` (last in `cts-payload.txt`, deliberately) overwrote itself mid-run, later reads of the script's own remaining bytes landed on the new file at the old file's byte offsets, producing garbage that doesn't parse. Fix: writes targeting `.claude/scripts/` are now staged in a temp directory during the sync and flushed into place by `flush_self_scripts` as the **literal last statement** of the script — nothing reads further into the script's own source after that point, so no mid-run corruption is possible. Verified end-to-end against a scratch repo (`init` + `update` across two upstream commits, one of which changed `cts-sync.sh` itself): `update` now exits 0 with no spurious error and the self-script is correctly updated.
- **`.claude/scripts/cts-sync.sh`**: added a `.cts-source` companion file (written alongside `.cts-version` on every successful run, recording the resolved `<source> <branch>`) to fix a false-regression trap — a project that sometimes runs `/cts-update` with an explicit `--source`/`--branch` (e.g. a local WIP checkout) and sometimes runs the plain default has no way to tell, from `.cts-version` alone, which source produced the current baseline. A later plain-default run against a source with an older tip than the previously-used one was indistinguishable from upstream having lost commits. The engine now warns (does not block — switching sources may be intentional) when an implicit run (no `--source`/`--branch` passed) resolves a source/branch that disagrees with the last recorded one, before touching any files. Verified: the warning fires correctly on an implicit-run mismatch and stays silent when `--source`/`--branch` is passed explicitly.
- **`.claude/skills/cts-update/SKILL.md`**: added two triage notes to step 3 — one for a mass of "locally modified, not overwritten" notices after a contribution round-trip (expected, not drift), and one for a mass-deletion-shaped diff that may be a source mismatch rather than real upstream data loss (now largely superseded by the `.cts-source` engine-level warning above, but kept as manual-verification guidance for older `cts-sync.sh` versions or a missed warning).
- **`.claude/skills/github-actions/SKILL.md`**: frontmatter `name:` was `GitHub Actions Expert` (spaces, mixed case), failing the loader's `[a-z0-9-]+` / dir-match validation and blocking the skill from registering at all. Corrected to `github-actions` to match the directory name.

Contributed from penny via `/cts-contribute`. Deliberately excluded: `.claude/agents/{tester,qa,angular-developer,reviewer,security-scanner}.md` (upstream is ahead on the TDD-shift; exporting penny's older copies would regress them — needs a 3-way `/cts-update` merge instead), and several undocumented local simplifications in penny's `rules/workflow.md`/`CLAUDE.md` (a dropped Tiered Planning Ladder, dropped `handoff`-skill hard-stop, dropped Generation damping) that were never logged as intentional upstream changes. The `rules/architecture.md` kernel→contracts doc-drift fix and the code-style/architecture platform-split were also skipped — both require the deferred structural split session, since CTS's current single-file `rules/architecture.md`/`rules/code-style.md` have no Nx-tag/`depConstraints` system to attach the fix to.

## [Unreleased] — Task-file handling rules

### Changed

- **`rules/task-authoring.md`**: three fixes closing gaps observed during round-3 execution: (1) explicit "plain `mv`, never `git mv`" rule for moving task files — the directories were already documented as git-excluded, but the operational consequence wasn't spelled out, and executors repeatedly tried `git mv` (which fails on untracked paths); (2) the canonical and continuation-template `On completion` rows now read "Do NOT commit. **Do NOT move this file.**" — some executors moved their own task file to `done/`, preempting the owner's review-commit-move confirmation step; (3) Standing Completion Rule rewritten with the exact completion-report shape the executor must emit ("All acceptance criteria met. Suggested commit message: `…`. After committing, move this task file to `done/`.").
- **`rules/workflow.md`**, **`docs/METRICS.md`**: METRICS ledger wording updated from "one line per task" to "one table row per task" — the Entries section is now a markdown table (renders properly, still trivially parseable) rather than pipe-delimited raw lines; append-only semantics unchanged.

## [Unreleased] — cts-sync 3-way merge

### Added

- **`.claude/scripts/cts-sync.sh`**: `update` now 3-way-merges a payload file that diverged both locally and upstream since the last sync (base = content at the old `.cts-version`), instead of always skipping it. Clean merges apply and print `merged: <path>`; overlapping hunks leave standard `<<<<<<<`/`=======`/`>>>>>>>` conflict markers and print `CONFLICT: <path>`. Files that diverged locally with no upstream change still skip-and-report as before (`locally modified, not overwritten`). New `--no-merge` flag restores the old preserve-only behavior for every diverged file. Closes R3-D11 — round 2 deferred this (R2-D1: "no 3-way merge... v2 only if pain proves need"); the pain (contribution became a de-facto precondition for receiving upstream updates to any file with a pending contribute-preparation) has since proven the need.
- Added `is_safe_rel()` path-containment guard in `cts-sync.sh`, applied in `copy_one` before any write — rejects payload-derived relative paths containing `..` segments or a leading `/`. Added during this change's security-scanner pass (payload/file listings originate from the operator-chosen `--source`, which may be a fork or local checkout the operator doesn't fully control); closes a path-traversal gap that predates this feature but was surfaced by the new `merge_one` write path.
- Added a `NEVER_PAYLOAD` guard in `cts-sync.sh`, checked once right after `PAYLOAD` is built — hard-fails with a clear error if `docs/KNOWLEDGE_INBOX.md` (project-local, never synced to consumers per `cts-payload.txt`) is ever resolved as a payload entry, directly or via a directory entry that contains it. Today that exclusion is enforced only by never listing the file in `cts-payload.txt`; this turns a future careless edit (e.g. listing `docs/` as a whole directory instead of individual files) into a loud failure at sync time instead of a silent leak to every consumer project.

### Changed

- **`.claude/skills/cts-update/SKILL.md`**: step 3 narration gains "Merged cleanly" / "Conflicts" groups; step 5 rewritten so judgment is spent only on `CONFLICT:` files (hunk-by-hunk resolution with the user) — `merged:` files need no review beyond `git diff --stat`. Step 2's engine-call instruction also now tells the agent to pass `--no-merge` when the user wants to skip merge attempts for the run — previously only `--source`/`--branch` pass-through was documented, leaving `--no-merge` usage undocumented and dependent on agent improvisation.
- **`README.md`**: Updating → "How it works" step 3 and a new "Merge semantics" paragraph document the fast-forward / preserve / merge / conflict split and `--no-merge`.

### Fixed

- **`.claude/scripts/cts-sync.sh`**: added a code comment directly above `merge_one` warning against reintroducing `trap ... RETURN` for its temp-file cleanup — it's shell-global in bash, not function-scoped, so it re-fires (with the local vars out of scope) on the next function return anywhere later in the script. Placed as an inline comment rather than a `docs/KNOWLEDGE_INBOX.md` entry since the affected area was already known and immediately edit-able.

- **`.claude/scripts/cts-sync.sh`**: `merge_one`'s two `mktemp` temp files are now cleaned up on both the normal exit path and error exit via a `trap ... EXIT` that's explicitly cleared (`trap - EXIT`) right before the function's single return, instead of the old explicit `rm -f` before each of several early returns (which leaked the temp files if `git show`/`cp` failed under `set -euo pipefail`). The trap's temp-path variables (`MERGE_BASE`/`MERGE_RESULT`) are deliberately module-level globals, not `local` — testing showed that when `set -e` unwinds out of the function on a failed command, bash tears down the function's local scope _before_ running the EXIT trap, so a trap referencing `local` vars crashes with "unbound variable" under `set -u` at exactly the moment cleanup is needed. Verified against a scratch repo covering fast-forward, preserve, merge, conflict, `--no-merge`, dry-run, and a forced `cp` permission-denied failure. Closes the follow-up tracked in `tasks/todo/2026-07-07-11-cts-sync-mergeone-trap-cleanup.md` (authored as `…-08-…`, renamed to resolve a per-date sequence collision with the consumer-validation task).

## [Unreleased] — Stale tester-role descriptions

### Fixed

- **`.claude/agents/{ba,dba,ddd-architect,debugger,devops,docs-writer,integration-architect,queue-specialist,refactoring-expert,security-scanner}.md`**: frontmatter `description` (and `docs-writer.md`'s scope-boundary line) reworded from generic "tests (tester)" to "test verification/coverage audits (tester)" — the TDD-shift task (`2026-07-07-02-tdd-shift-quality-gate`) redefined `tester` as the verify/coverage-audit stage rather than primary test author, but that redefinition had only reached `ba.md`/`debugger.md`'s body notes, not the frontmatter descriptions dispatchers actually read for routing. Closes `tasks/todo/2026-07-07-10-stale-tester-role-references.md`.

## [Unreleased] — Metrics ledger

### Added

- **`docs/METRICS.md`**: new append-only ledger, one pipe-delimited line per completed task (`date | repo | task | tier | cycles | fixnow t/r/s/q | emitted | hardstop | model`), never @-referenced (same constraint as `docs/KNOWLEDGE_INBOX.md`). Raw data collection ahead of a dedicated measurement-design session once 20–30 rows exist (R3-D9). Shipped to consumer projects via `cts-payload.txt`.

### Changed

- **`rules/workflow.md`**: Phase 6 gains an append-one-line obligation for `docs/METRICS.md`, alongside the existing `docs/CLAUDE_TS_CHANGELOG.md` obligation.
- **`CLAUDE.md`**: Hard tool limits' knowledge-ledger docs list (orchestrator Edit/Write allowlist) gains `docs/METRICS.md`.

## [Unreleased] — Operator recipes guide

### Added

- **`docs/RECIPES.md`**: new operator-facing (never agent-loaded) workflows guide, six recipes each ≤ half a page: grill→tier→stamps→tasks, clean-session execution, hard-stop continuation, `/cts-update`, `/cts-contribute`, and `/distill-inbox` cadence. Shipped to consumer projects via `cts-payload.txt`.
- **`README.md`**: links to `docs/RECIPES.md` alongside the existing project-map bullets.

### Fixed

- **`CLAUDE.md`**: knowledge-capture line clarified — the `docs/CLAUDE_TS_CHANGELOG.md` instruction is consumer-project-only (that file logs template divergences for `/cts-contribute` to port upstream); in the claude-ts template repo itself, template-inherited-file changes are logged in this `CHANGELOG.md` instead.
- **`.claude/agents/docs-writer.md`**: added a "Post-Edit Check" step — after rewording/renaming any phrase, `grep -n` the entire file (not just the edited section) to catch stale duplicate occurrences before reporting done. Closes a gap where a prior docs-writer pass reworded one of two identical phrase occurrences in the same file, caught only by the `reviewer` quality-gate pass.

## [Unreleased] — Task-authoring provenance rows and emission control

### Changed

- **`rules/task-authoring.md`**: canonical task header grows from 5 to 8 rows, adding `Planning tier` (T0–T3, per `rules/workflow.md`'s ladder), `Planning` (role-granular `ba`/`devil`/`ddd-architect` status — `done` only if the source session produced that role's artifact, `required`, or `skipped` for the T1 no-`ba` case), and `Generation` (G0 = feature work, G1+ = tasks emitted from a prior gate). Added the executor obey-the-stamp rule (dispatch only roles marked `required`, never re-judge planning recorded at authoring time) and a seam-vs-stamp contradiction guard (task body visibly touches a seam but tier says T0/T1 → executor STOPs and flags, does not silently proceed or re-triage). Added a continuation-task template for the quality-gate hard-stop case, wrapping the `handoff` skill's attempt-log/hypotheses output in the canonical header (tier/generation inherited, `Planning: done`).
- **`rules/workflow.md`**: Quality Gate's Emit-as-Task rule reworded from "one task per finding" to "one task per context cluster" — findings sharing a module/seam/file-area collapse into one task file with a findings checklist; unrelated findings stay separate. Added a generation-damping rule: at Generation ≥2, only Correctness/Security findings may spawn a new task file — Comprehension/Consistency findings instead go to the existing sub-floor ledger (`docs/KNOWLEDGE_INBOX.md`) and follow its existing ≥3-occurrences-promotes rule. Bug Fix Pipeline's parallel "create task file per finding" wording updated to point at the same context-cluster rule instead of duplicating the old phrasing.

## [Unreleased] — Tiered planning ladder (T0–T3)

### Changed

- **`rules/workflow.md`**: replaced the flat "First Action: Triage" decision tree, the standalone "Pipeline Trigger: REQUIRED When ANY Applies" list, and the separately-triggered "Foresight gate" section with a single T0–T3 tiered ladder. T0 (trivial, ≤2 files, no executable config) → direct + `reviewer` only. T1 (local, ≤3 files, foresight gate does not fire, no new endpoint/migration) → orchestrator writes 5-line acceptance criteria directly, skips `ba`, full quality gate still runs. T2 (foresight gate fires — new seam/contract/endpoint/migration/auth) → `ba` required. T3 (architecture decision — structural tradeoffs/domain boundaries/topology) → full Planning Team (`ba`+`ddd-architect`+`devil`). The foresight gate is now the sole tier selector — no second file-count/risk heuristic layered on top (R3-D2, R3-D5). Planning Team section re-keyed to trigger on T3 specifically, with T2 running `ba` alone (plus `ddd-architect` when the seam spans domain layers). Quality gate hard-stop (after 2 failed restart cycles) changed from a bare "surface to user" to invoking the `handoff` skill to emit a continuation task (open Fix-Now items, per-cycle attempt log, hypotheses) saved under `todo/`; the Bug Fix Pipeline's hard-stop now references the same behavior instead of duplicating it.
- **`CLAUDE.md`**: Triage block compressed to mirror the same T0–T3 ladder, delegating full tier definitions and the foresight gate to `rules/workflow.md`.

## [Unreleased] — TDD-shift quality gate

### Changed

- **`rules/workflow.md`**: quality gate stage 1 redefined from `tester` (primary test author) to `tester(verify)` — implementation agents (`backend-developer` + frontend agents) now write unit/feature/integration tests alongside the code they produce, per the `tdd` skill (red/green/refactor), so `reviewer` Fix-Now cycles no longer invalidate test authorship. `tester` runs the suite, audits coverage gaps, and adds only the tests needed to close a real gap. Restart semantics (max 2 full cycles, restart from stage 1) unchanged. ASCII diagrams and the phase table updated to say `tester(verify)`.
- **`CLAUDE.md`**: Quality gate paragraph updated to match, compressed to the existing paragraph's density.
- **`.claude/agents/tester.md`**: redefined as verify/coverage-audit stage; scope-boundary table now shows implementation agents as primary test authors; TDD workflow section scoped to gap-filling tests only (a failing gap-fill test is a `## Fix Now` finding routed back to the implementation agent, not something tester patches itself).
- **`.claude/agents/backend-developer.md`, `vue-developer.md`, `react-developer.md`, `angular-developer.md`**: each gained a mandatory "Tests-with-Code" obligation referencing the `tdd` skill; the three frontend agents also gained a `tdd` row in their Skills-to-Activate table.

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
