---
name: cts-update
description: "Narrated re-sync of an already-installed CTS project: runs the sync engine, summarizes what changed upstream, what was skipped via .ctsignore, and surfaces locally-modified payload files that the engine preserved instead of overwriting. NOT for first-time installs (use cts-setup) and NOT for projects without a .cts-version file.\n\nTrigger — EN: cts-update, update CTS, sync claude-ts, refresh template, check upstream changes.\nTrigger — UA: оновити CTS, синхронізувати шаблон, оновлення claude-ts, апдейт агентів, перевірити зміни."
---

# /cts-update

Wraps `.claude/scripts/cts-sync.sh update` ("engine call") and narrates the result. Make exactly ONE engine call; everything else is reading its output plus `git diff`, then summarizing and flagging risks.

## 1. Preflight

- If `.cts-version` is missing, this project was never installed via `cts-sync.sh` — tell the user to run `/cts-setup` instead and stop.
- Print one non-blocking FYI line before the engine call — this is discoverability, not a question, so don't wait for a reply. Default: `Using default source (claude-ts main). Options: --source/--branch to track a fork, --no-merge to skip auto-merge.` If `.cts-source` exists and its `source:`/`branch:` lines show a non-default value was used last time, name that source/branch instead of "default" (e.g. `Using last-used source (<source> @ <branch>). Options: ...`).

## 2. Engine call

Run `bash .claude/scripts/cts-sync.sh update`, capturing stderr, and passing through `--source <path-or-url>` and/or `--branch <name>` if the user specified them (e.g. to track a fork or a feature branch). Also pass `--no-merge` if the user says they'd rather skip merge attempts entirely this run (e.g. testing, or they want to keep reviewing every diverged file by hand as before) — otherwise the engine attempts a 3-way merge on any file that changed on both sides.

- Check the call's exit code. A non-zero exit (git clone/fetch failure, missing repo, bad `--source`/`--branch`, etc.) means the sync **did not run** — this is not "already up to date." Stop, show the captured stderr verbatim, and tell the user to retry (most often a transient network issue reaching the source repo). Do not proceed to step 3 in this case, and do not touch `.cts-version` or any files yourself.
- If the exit code is 0, also sanity-check that something actually happened: the script always prints `Done. Review with: git diff` on success. If that line is missing even though the exit code was 0, treat it the same as a failure — surface the raw output and stop.
- **Unconditionally** check the captured stderr for a line starting `Warning: last sync used source ... this run resolved ...` — do this for every successful run, before any narration, not only when the diff already looks alarming. If present, stop here (before step 3) and tell the user plainly: "Last sync used `<prev source/branch>`; this run resolved `<current source/branch>` — these differ. Continue with the current source, or re-run with `--source`/`--branch` matching the prior sync?" Wait for their choice before proceeding to step 3.

## 3. Narrate

Only reached after a confirmed successful engine call and, if the mismatch warning fired, after the user has chosen to continue (see step 2).

- Capture the script's stdout: the "Changes:" section (commit log between old and new `.cts-version`), any `ignored, but changed upstream — review manually: <path>` lines, any `merged: <path>` lines, any `CONFLICT: <path>` lines, any `locally modified, not overwritten — diff manually: <path>` lines, and any `removed upstream — delete manually if unwanted: <path>` lines.
- Run `git diff --stat` to see which local files actually changed.
- Summarize for the user in five short groups: **Upstream changes** (from the changelog), **Updated locally** (from `git diff --stat`), **Merged cleanly** (`merged:` lines — both sides touched the file, non-overlapping hunks combined automatically), **Conflicts** (`CONFLICT:` lines — both sides touched the same hunk, standard `<<<<<<<`/`=======`/`>>>>>>>` markers left in the file), **Needs attention** (changed-upstream-while-ignored + locally-modified-with-no-upstream-change + removed-upstream notices).
  - **Triage note — contribution round-trip**: if this project previously ran `/cts-contribute`, check the upstream commit message for "from <this-project>" — this project's customizations were merged into claude-ts and are now being synced back down. This is not drift, and it is **not** a uniform "expect a no-op" or "expect a CONFLICT" situation — the signal differs by whether the file is `.ctsignore`'d, because the engine checks `.ctsignore` before the merge path (it never runs a 3-way merge on an ignored file):
    - **Mass "locally modified, not overwritten" notices** (non-ignored files, upstream didn't touch this exact content) — local and upstream may agree even though the baseline changed, producing a diverged-file list that looks concerning but just needs a quick confirm-and-skip.
    - **`CONFLICT:` on a CTS-managed (non-ignored) file** where `/cts-contribute` used "edit before export" on this hunk — genuine conflict, not a merge-engine defect: `cts-contribute` only writes the generalized text into CTS, never back into this project's own copy, so base/local/upstream are three real, different texts. See step 5's guidance: the correct resolution is almost always "take upstream," since upstream now holds this project's own contribution in its generalized form.
    - **`ignored, but changed upstream` on a `.ctsignore`'d file** where `/cts-contribute` used "edit before export" on this hunk — same underlying cause as the CONFLICT case above, but this file can never produce `CONFLICT:` markers because it's ignored before the merge path runs. Triage via step 4's judgment instead: this is usually "local file now matches upstream intent," so removing the `.ctsignore` entry is often the right call.
  - **Fallback note (source mismatch, pre-upgrade engine only)**: step 2 now checks stderr for the source-mismatch warning unconditionally and stops before this step ever runs, so this triage path shouldn't normally trigger. It exists only for output from an older `cts-sync.sh` that predates the warning: if the diff looks like a mass _regression_ — large deletions, several files reported `removed upstream` — right after a run with no `--source`/`--branch` flags, check whether the previous sync used an explicit `--source` (e.g. a local checkout on a different branch) that this run didn't repeat. Verify manually: re-run with the `--source`/`--branch` you suspect was used previously and check whether the resulting `.cts-version` matches the old one exactly — a no-op confirms it was a source mismatch, not real data loss.

The engine only overwrites a payload file outright if the working copy still matches what was synced last time. If it diverged and upstream also changed the same file, it runs a 3-way merge (base = content at the old `.cts-version`) instead of skipping — clean hunks apply silently (`merged:`), overlapping hunks get conflict markers (`CONFLICT:`). If it diverged but upstream did **not** touch that file, or `--no-merge` was passed, it's skipped and reported as `locally modified, not overwritten` rather than silently clobbered.

## 4. Merge upstream changes into ignored files

For each `ignored, but changed upstream` line, the script prints a ready-to-run `git diff` command — run it and judge the upstream change against the local customized file:

- **Improvement that applies here** (new section, fixed instruction, better rule) → offer to hand-merge those hunks into the local file, preserving the project's customizations. Apply only after the user agrees.
- **Doesn't apply** (upstream change conflicts with why the file was customized) → say so in one line and move on.
- **Local file now matches upstream intent** (e.g. a local fix that CTS has since adopted) → suggest removing the `.ctsignore` entry so the file returns to CTS ownership.

## 5. Resolve conflicts and locally-modified files

Judgment here is spent only on `CONFLICT:` files — `merged:` files already applied cleanly and need no review beyond what `git diff --stat` already showed in step 3.

For each `CONFLICT: <path>` line, open the file and resolve the `<<<<<<<`/`=======`/`>>>>>>>` markers hunk-by-hunk with the user: for each hunk, decide whether to keep the local side, take the upstream side, or hand-write a combination, then remove the markers. Once every hunk in the file is resolved, tell the user it's ready to stage. If a hunk looks like this project's own wording generalized (see the contribution round-trip triage note in step 3), taking upstream is almost always correct.

For each `locally modified, not overwritten` line (diverged locally, unchanged upstream — no merge was attempted), run `git -C <src> diff OLD..NEW -- <path>` and judge the same way as step 4:

- **Local edit is a candidate to push upstream** (this is what `/cts-contribute` is for) → say so and point the user at `/cts-contribute`.
- **Ongoing divergence you want to keep quiet in future runs** → suggest adding the file to `.ctsignore` so subsequent updates skip it without re-reporting it every time.

Because the engine only merges or skips — it never overwrites a diverged file outright — there's nothing to "revert" for either group; the pre-run content is either still there untouched (`locally modified`) or already merged in place (`merged:`/`CONFLICT:`).

## 6. Suggest & hand off

If nothing was flagged this run — no `CONFLICT:` lines, no `.ctsignore` addition/removal candidates from steps 4-5, no push-upstream candidate — skip the menu entirely: state plainly that the sync was clean and there's nothing to act on. Don't ask a question with only one option.

Otherwise, call `AskUserQuestion` with `multiSelect: true`, built from what steps 3-5 actually found this run. Always include the baseline option; include the others only when their trigger condition is met:

- "Resolve conflicts now" — only if any `CONFLICT:` lines existed (step 5).
- "Review `.ctsignore` additions" — only if step 5 flagged a locally-modified file worth silencing going forward (root-level entries should be `/`-anchored, e.g. `/AGENTS.md` — a bare filename also matches nested payload files).
- "Review `.ctsignore` removals" — only if step 4 flagged a local-file-now-matches-upstream case.
- "Run cts-contribute" — only if step 5 flagged a push-upstream candidate.
- "Stop here, I'll review `git diff` myself" — always include, as the baseline option.

Whatever the user picks, remind them: `git diff` is the merge tool — review and commit themselves. This skill never commits or pushes.
