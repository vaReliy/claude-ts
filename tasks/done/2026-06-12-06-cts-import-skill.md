# Task 06 — /cts-import-skill (maintainer-side skill curation)

| Field | Value |
| --- | --- |
| Clean session | **Yes** — run in a fresh session |
| Executor model | **Sonnet** |
| Repo | CTS (`claude-ts`), branch `feat/round-2-distribution-and-agnostic` |
| Depends on | None hard; run last (lowest urgency) |
| On completion | Suggest a one-line commit message in your summary. **Do NOT commit or push.** Owner moves this file to `tasks/done/`. |

## Context & rationale

CTS is a **curated superset** (round-1 decision D6): every skill earns its place, duplicates get merged or rejected, descriptions must actually trigger (D7). Importing an external skill by hand risks silently re-introducing the duplication round 1 cleaned up (3× Postgres, 2× Playwright…). This skill codifies the curation checklist as an executable flow. It is **maintainer-side**: meant to run in the CTS repo itself (and that constraint must be enforced).

## Deliverable — `.claude/skills/cts-import-skill/SKILL.md`

Invocation: `/cts-import-skill <github-url | owner/repo/path | local-path>`. Instruction flow for the agent:

1. **Guard:** verify CWD is the CTS repo (e.g. `cts-payload.txt` exists at root and git remote matches claude-ts). If not → stop, tell the user this is a CTS-maintainer skill.
2. **Fetch:** obtain the skill source — raw SKILL.md (+ any `references/`, `examples/`, scripts) from the given URL/repo path, or read from a local path. Show the user the skill's name + description before proceeding.
3. **Duplication check (blocking):** compare against ALL existing `.claude/skills/*/SKILL.md` names + descriptions. Report overlaps with a recommendation per the round-1 rule: *merge* (fold unique content into the existing skill, like the Postgres fold-in), *replace* (imported one is clearly superior), *reject* (adds nothing), or *import as-is* (genuinely new). Ask the user to decide (AskUserQuestion) when not clear-cut.
4. **Quality pass (per D7):** description must be 1–2 sentences what+when, contain explicit NOT-for, EN trigger keywords + 4–5 strongest UA keywords; no placeholder descriptions ("X Expert"). Fix the description if needed. Check the body for: progressive disclosure (small SKILL.md, detail in references/), no vendor lock the skill doesn't need, no stack assumptions conflicting with CTS (Node/TS).
5. **Stack fit:** strip or adapt content for irrelevant stacks (the laravel-ci.yml lesson). Flag anything requiring runtime dependencies (scripts, package.json) — CTS prefers dependency-free skills.
6. **Integrate:** copy into `.claude/skills/<name>/`; add to README skills inventory table; add attribution to `THIRD_PARTY.md` (source repo, license — check the license allows redistribution; warn if missing/unclear); `CHANGELOG.md` entry. Payload coverage is automatic (`.claude/skills/` is in `cts-payload.txt`) — no script changes needed.
7. **Report:** summary table (imported / merged-into / rejected + why), and remind: review `git diff`, commit yourself. Never commit.

Frontmatter description for this skill itself must follow D7 too (NOT-for: "not for installing skills into consumer projects — those receive skills via /cts-update").

## Also

- README: add `/cts-import-skill` to the maintainer/customization section ("Add a New Skill" area), explaining manual addition is discouraged in favor of this flow.
- `CHANGELOG.md` entry.

## Acceptance criteria

- SKILL.md exists, ≤ ~150 lines, D7-compliant description, guard step present.
- Walkthrough test: simulate importing `mattpocock/skills` `caveman` — the flow must detect the existing local `caveman` skill and recommend *reject/merge*, NOT import a duplicate. Report the walkthrough result in your summary.
- README + THIRD_PARTY.md instructions present.
