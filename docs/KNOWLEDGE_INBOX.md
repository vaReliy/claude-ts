# Knowledge Inbox

Append-only queue for durable, project-relevant learnings whose final home isn't clear yet. Distilled into PROJECT_CONTEXT.md / CLAUDE.md / a rule / a skill, then deleted from here — this file should trend toward empty.

## 2026-07-07 — [bash] EXIT trap can still crash on `local` vars under `set -u`
Why: fixing `merge_one()` in `.claude/scripts/cts-sync.sh` (temp-file cleanup on error exit), a `trap 'rm -f "$base" "$result"' EXIT` inside a function with `local base result` crashed with "unbound variable" the moment `set -e` aborted the function on a failed `cp`/`git show` — bash tears down the function's local scope *before* running the EXIT trap, so the trap sees the names as genuinely undeclared, not just empty. Fix: make the trap's referenced variables function-scoped-but-not-`local` (plain global assignment) when the function isn't reentrant/recursive, so the trap always resolves them regardless of teardown timing. Caught only via a forced-failure test (chmod'd a real file read-only), not by reasoning about the code — a `trap ... RETURN` fix looked even more plausible on paper and was already reverted once for a different bug (shell-global re-firing on later unrelated returns).
Belongs in (guess): rule (bash scripting gotchas, no dedicated rule file yet — maybe new `rules/shell-scripting.md` if this class of bug recurs)

