# Task 05 — HPW adoption of round-2 CTS (validation gate)

| Field | Value |
| --- | --- |
| Clean session | **Yes** — fresh session **opened in the HPW repo** (`/home/vh/Projects/vg/home-pulse-watcher`) |
| Executor model | **Sonnet** |
| Repo | **HPW** (changes land in HPW; CTS is read-only source) |
| Depends on | Tasks 01–04 done on CTS branch `feat/round-2-distribution-and-agnostic` |
| On completion | Suggest a one-line commit message (for HPW) in your summary. **Do NOT commit or push.** Owner moves this file to `tasks/done/` in CTS. |

## Context & rationale

HPW is the testbed: round-2 (sync engine, skills, AGENTS.md split) is only trusted after HPW adopts it cleanly. **This task is the push gate** — CTS branches `feat/token-optimization-round-1` + `feat/round-2-distribution-and-agnostic` are pushed to remote only after this passes. HPW already carries deliberate deviations from CTS (3-category sync model, see HPW `tmp/CLAUDE_SETUP_IMPROVEMENTS.md`): pruned frontend (D8), project-specific agents/rules (D9, embedded-cpp persona, Telegram/NestJS specifics), and possibly locally tuned CTS files.

## Steps

### 1. Build HPW's `.ctsignore` (the critical artifact)

Diff-driven discovery — compare HPW against the CTS payload (`cts-payload.txt` in `/home/vh/Projects/vg/claude-ts`):

- For each payload path, classify the HPW state: **(a)** identical to CTS → CTS-owned, not ignored; **(b)** exists in CTS but deleted in HPW (frontend agents `vue/react/angular-developer.md`, skills `vue-expert/`, `react-expert/`, `angular-expert/`, etc.) → add to `.ctsignore` (prevents re-add); **(c)** exists in both but HPW-modified (HPW CLAUDE.md certainly; check agents for HPW-specific edits) → add to `.ctsignore` with a trailing comment why; **(d)** HPW-only additions under payload dirs (embedded-cpp persona, HPW-specific rules) → add to `.ctsignore`.
- Write `.ctsignore` at HPW root, grouped with comments (`# pruned`, `# customized`, `# HPW-only`).

### 2. Reconcile the AGENTS.md split

HPW's CLAUDE.md was rewritten in HPW task 01 (round 1) and is HPW-customized. Apply the same split CTS did (task 02): portable parts → HPW `AGENTS.md`, orchestrator stays in HPW `CLAUDE.md`, preserving all HPW-specific content (task-file naming rule, embedded specifics). HPW `.claude/rules/` → HPW root `rules/` only if HPW wants parity — decide by least surprise: **do move**, updating HPW references, since future CTS updates will ship rules to `rules/`.

### 3. Run the update flow

```bash
bash <CTS>/.claude/scripts/cts-sync.sh update --source /home/vh/Projects/vg/claude-ts --branch feat/round-2-distribution-and-agnostic
```

(First run may need `init`-like bootstrapping of `.cts-version` — follow script guidance; if the script offers no adoption path for a pre-existing install, set `.cts-version` to the CTS round-1 commit `71504d6` and run `update`.)

### 4. Validate

- `git diff` review: NO file listed in `.ctsignore` was touched; updated files are wanted CTS improvements only.
- Re-run `update` → idempotent (no changes second time).
- Open a fresh Claude session in HPW: orchestrator rules still load; `/cts-update` skill is available and triggers.
- `grep -L 'Report Format' .claude/agents/*.md` → empty for kept agents.

### 5. Record findings

- Append validation results (what broke, what surprised, `.ctsignore` gotchas) to HPW `tmp/validation-notes.md`.
- If script/skill bugs were found: do NOT fix CTS from this session — list them in the summary as new CTS task candidates.

## Acceptance criteria

- HPW has `.ctsignore`, `.cts-version`, AGENTS.md split applied, update run clean + idempotent.
- Zero HPW-specific files overwritten (verify against the step-1 classification list).
- Findings recorded; summary states clearly: **gate PASSED / FAILED (+why)**.
