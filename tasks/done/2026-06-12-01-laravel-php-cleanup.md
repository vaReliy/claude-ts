# Task 01 — Remove Laravel/PHP leftovers from CTS

| Field | Value |
| --- | --- |
| Clean session | **Yes** — run in a fresh session |
| Executor model | **Haiku** (`/model haiku`) |
| Repo | CTS (`claude-ts`), branch `feat/round-2-distribution-and-agnostic` |
| Depends on | — |
| On completion | Suggest a one-line commit message in your summary. **Do NOT commit or push.** Owner moves this file to `tasks/done/`. |

## Context

CTS was forked from a PHP/Laravel template. Round 1 removed most PHP content; this task removes the confirmed remainder. Fork attribution must stay.

## Steps

1. **`.mcp.json`** — delete the entire `laravel-boost` server block (the `docker compose exec -T app php /var/www/artisan boost:mcp` entry). Keep `context7`, `figma`, `github` untouched. Validate the file is still valid JSON.
2. **Delete two orphaned files** (not referenced by their skill's SKILL.md):
   - `.claude/skills/typescript-pro/references/laravel-patterns.md`
   - `.claude/skills/typescript-pro/references/modern-php-features.md`
3. **`.claude/skills/debugging-wizard/references/quick-fixes.md`** — remove the `## PHP / Laravel Common Errors` section (around line 108) entirely (heading + its content, up to the next same-level heading).
4. **`.claude/skills/debugging-wizard/references/debugging-tools.md`** — remove the `## PHP / Laravel` section (around line 70) the same way.
5. **Verify** — run `grep -ri "laravel\|artisan\|composer.json\|php" --include="*.md" --include="*.json" --include="*.yml" .claude/ .mcp.json` and confirm zero hits. (Root `README.md`, `THIRD_PARTY.md`, `CHANGELOG.md` are exempt — fork attribution and history stay.)
6. **`CHANGELOG.md`** — add one entry under today's date: removal of `laravel-boost` MCP server and last PHP/Laravel reference content.

## Do NOT

- Do not touch `README.md` / `THIRD_PARTY.md` attribution lines.
- Do not modify `.claude/settings.local.json` (untracked, owner handles it manually).
- Do not reformat unrelated parts of edited files.

## Acceptance criteria

- `grep` from step 5 returns nothing for `.claude/` and `.mcp.json`.
- `.mcp.json` parses as JSON and contains exactly 3 servers.
- `git status` shows only the files listed above.
