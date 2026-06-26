# Task 03 — cts-sync.sh engine + payload definition + README rewrite

| Field | Value |
| --- | --- |
| Clean session | **Yes** — run in a fresh session |
| Executor model | **Sonnet** |
| Repo | CTS (`claude-ts`), branch `feat/round-2-distribution-and-agnostic` |
| Depends on | Task 02 (final payload layout: AGENTS.md, rules/, thin CLAUDE.md) |
| On completion | Suggest a one-line commit message in your summary. **Do NOT commit or push.** Owner moves this file to `tasks/done/`. |

## Context & rationale

Today CTS is installed by clone + `cp -r` and updated by hand — updates overwrite downstream customizations. Decision: a single deterministic bash script is the **engine**; users normally interact via the `/cts-setup` and `/cts-update` skills (task 04) which call it. Design principles: no npm, no hashes, no merge logic — **`git diff` in the target repo is the review mechanism**; project-specific paths are protected by `.ctsignore`.

## Deliverables

### 1. `cts-payload.txt` (CTS repo root)

Plain list of payload paths (one per line, comments with `#`), defining what gets installed into target projects:

```
AGENTS.md
CLAUDE.md
.mcp.json
rules/
.claude/agents/
.claude/skills/
.claude/scripts/
.claude/settings.json
```

Explicitly NOT payload: `README.md`, `CHANGELOG.md`, `THIRD_PARTY.md`, `LICENSE`, images, `tasks/`, `tmp/`, `cts-payload.txt` itself, `.claude/settings.local.json`.

### 2. `.claude/scripts/cts-sync.sh` (zero-dependency bash, target ~60–100 lines)

```
Usage: cts-sync.sh <init|update> [--source <path-or-url>] [--branch <name>] [--dry-run]
```

Behavior:

- **Source resolution:** default = `https://github.com/vaReliy/claude-ts.git`, cached at `~/.cache/claude-ts` (clone on first run, `git fetch`+ reset to origin/<branch> on later runs). `--source <local-path>` uses an existing checkout directly (maintainer dev loop, used by task 05).
- **`init`:** copy all payload paths from source into the current directory (must be a git repo — abort otherwise with a clear message). Refuse to overwrite an existing `CLAUDE.md`/`AGENTS.md`/`.claude/` unless `--force` (existing-project merge is `/cts-setup`'s job, not the script's). Write `.cts-version` (source commit SHA). Create an empty commented `.ctsignore` template if absent.
- **`update`:** read `.ctsignore` (gitignore syntax; supports files and dir globs) and copy payload paths from source EXCEPT matching ones. Never delete target files; if a file exists locally under a payload path but no longer exists in CTS, print it as a "removed upstream — delete manually if unwanted" candidate. Print the CTS changelog between `.cts-version` and new SHA (`git -C <cache> log --oneline <old>..<new>`), then update `.cts-version`. Finish with: `Done. Review with: git diff`.
- **`--dry-run`:** print what would be copied/skipped, touch nothing.
- Must be safe to re-run (idempotent). Use `rsync -a --exclude-from` if available with a `cp` fallback, or implement the filter in pure bash — your choice, but keep it simple and readable.
- The script is part of the payload — it updates itself on `update`; structure it so self-overwrite is safe (e.g. it is read fully before copying begins, or copies itself last).

### 3. `.ctsignore` convention (document, don't ship a file in CTS itself)

Documented in README: gitignore syntax, lives in the target project root, meaning "CTS never touches these paths — my responsibility". Covers three cases: customized CTS files, pruned CTS files (prevents re-adding), project-only additions under payload dirs.

### 4. `README.md` rewrite — install/update sections (skill-first)

- **Quick Start (new project):** a copy-paste **prompt** for a Claude Code session in the target project, e.g.: *"Set up the claude-ts template in this project: fetch `https://raw.githubusercontent.com/vaReliy/claude-ts/main/.claude/scripts/cts-sync.sh`, run `bash cts-sync.sh init`, then follow the `/cts-setup` guided configuration."* Manual script invocation documented as a secondary path (CI / no-agent).
- **Updating:** primary = run `/cts-update` inside the project; internals box explains the script + `.ctsignore` + `.cts-version` + `git diff` review.
- **Existing-project install:** points to `/cts-setup` (task 04), replacing the current manual merge instructions.
- Keep the Install Profile (pruning) knowledge but reframe it: pruning is performed during `/cts-setup` and recorded in `.ctsignore`.
- Remove/replace any now-stale instructions (the `/tmp/claude-ts-config` clone+cp flow).
- Keep README aligned with the task-02 structure section.

### 5. `CHANGELOG.md` entry.

## Testing (do this before finishing)

In a throwaway dir: `git init`, run `init` from the local checkout (`--source .`), verify payload lands + `.cts-version` written; add a `.ctsignore` entry, modify CTS-side file, run `update`, verify ignored path untouched and changed file updated; verify `--dry-run` touches nothing. Report results in your summary.

## Acceptance criteria

- `bash .claude/scripts/cts-sync.sh` with no args prints usage and exits non-zero.
- init/update/dry-run behave per spec in the throwaway-dir test.
- README has no remaining clone+`cp -r` instructions; skill-first flow documented.
- `shellcheck` (if available) passes or only cosmetic warnings remain.
