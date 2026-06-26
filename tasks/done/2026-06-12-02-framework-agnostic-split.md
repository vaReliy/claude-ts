# Task 02 — Framework-agnostic split: AGENTS.md + thin CLAUDE.md + root rules/

| Field | Value |
| --- | --- |
| Clean session | **Yes** — run in a fresh session |
| Executor model | **Sonnet** |
| Repo | CTS (`claude-ts`), branch `feat/round-2-distribution-and-agnostic` |
| Depends on | Task 01 (clean payload) |
| On completion | Suggest a one-line commit message in your summary. **Do NOT commit or push.** Owner moves this file to `tasks/done/`. |

## Context & rationale

CTS content splits into two layers:

- **Portable knowledge** — readable by any AI CLI (Claude/Codex/Gemini/Copilot): stack, code style, git safety, on-demand rules. Goes to `AGENTS.md` (the emerging vendor-neutral instruction file) + root `rules/`.
- **Claude adapter** — Claude Code-specific machinery: orchestrator/dispatcher, subagent definitions, skills discovery, settings. Stays in `CLAUDE.md` + `.claude/`.

Key principle: non-Claude tools must NOT ingest the orchestrator/pipeline content (garbage context for them), and Claude must not lose anything it has today.

## Steps

### 1. Verify AGENTS.md loading mechanism (do this FIRST)

Check whether the currently installed Claude Code version auto-loads `AGENTS.md` alongside/instead of `CLAUDE.md` (check `claude --version`, release notes via web search, or the docs). Outcome decides step 3:

- **Auto-loaded** → `CLAUDE.md` needs no import line; just ensure no content duplication between the two files.
- **Not auto-loaded** → `CLAUDE.md` starts with `@AGENTS.md` (a justified force-load: this content is needed every turn).

Record which path you took in your final summary.

### 2. Create `AGENTS.md` (repo root) — the portable core

Move (not copy) these sections out of `CLAUDE.md`:

- `## Stack`
- `## Git Safety`
- `## Code Style Essentials`
- `## On-Demand Rules Index` (update paths per step 4)
- `## Setup` pointer to README

Add one new section — **Model Tiers** (vendor-neutral vocabulary + the Claude mapping as its first concrete instance):

```markdown
## Model Tiers

Generic tiers used across rules and task files; each AI vendor maps them to concrete models.

| Tier | Use for | Claude mapping |
| --- | --- | --- |
| deep | Rare cascading decisions (architecture), hardest root-cause debugging | opus |
| standard | Implementation, review, tests, requirements, security checklists | sonnet |
| cheap | Mechanical/template work: docs, config edits, deletions | haiku |

Other vendors (Gemini, Codex, Copilot): mappings added when those tools are actually used.
```

Keep AGENTS.md free of: orchestrator/triage/routing/pipeline content, agent-team conventions, Claude skill references — that is the adapter layer.

### 3. Slim `CLAUDE.md` — the Claude adapter

Keeps ONLY:

- AGENTS.md import (or nothing, per step 1 outcome)
- `## Orchestrator (Dispatcher) Core` — triage, routing table, pipeline, quality gate, hard tool limits
- `## Skills` preference list
- The pointer to `rules/workflow.md` before team creation

No content may exist in both files (duplication = drift).

### 4. Move `.claude/rules/` → root `rules/`

- `git mv .claude/rules rules`
- Update **every** reference: `grep -rn "\.claude/rules" . --include="*.md" --include="*.json"` and fix all hits (CLAUDE.md, AGENTS.md, README.md, agent definitions in `.claude/agents/`, any skills, CHANGELOG references can stay historical).
- Re-run the grep — zero hits outside `CHANGELOG.md` history entries.

### 5. Update `README.md`

- Repo structure diagram/description: `AGENTS.md` (portable core), `rules/` (portable knowledge), `CLAUDE.md` (Claude adapter), `.claude/` (Claude adapter layer: agents/skills/settings).
- Explain the portable-vs-adapter split in 3–4 sentences (any-AI-tool readable vs Claude-specific).
- Mention the Model Tiers vocabulary.
- Do NOT rewrite install instructions yet — task 03 owns the install/update sections.

### 6. `CHANGELOG.md` — one entry describing the split.

## Acceptance criteria

- `AGENTS.md` exists with the five moved sections + Model Tiers; contains no orchestrator/pipeline content.
- `CLAUDE.md` contains only adapter content; combined files cover 100% of the old CLAUDE.md content (nothing lost, nothing duplicated).
- `rules/` exists at root; `grep -rn "\.claude/rules"` → only historical CHANGELOG hits.
- A fresh Claude Code session in this repo still sees Stack/Git Safety/Code Style rules (via auto-load or import — per step 1).
