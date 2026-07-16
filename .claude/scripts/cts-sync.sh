#!/usr/bin/env bash
# CTS sync engine — installs/updates the claude-ts (CTS) payload in a project.
# Normally invoked by the /cts-setup and /cts-update skills, not run directly.
set -euo pipefail

DEFAULT_SOURCE="https://github.com/vaReliy/claude-ts.git"
DEFAULT_BRANCH="main"
CACHE_DIR="$HOME/.cache/claude-ts"
PAYLOAD_FILE="cts-payload.txt"
VERSION_FILE=".cts-version"
SOURCE_FILE=".cts-source"
IGNORE_FILE=".ctsignore"

usage() {
  cat <<'EOF'
Usage: cts-sync.sh <init|update> [--source <path-or-url>] [--branch <name>] [--dry-run] [--force] [--no-merge]

  init    Install the CTS payload into the current project (must be a git repo)
  update  Re-sync the CTS payload, skipping paths listed in .ctsignore

Options:
  --source <path-or-url>  Local checkout dir or git URL (default: claude-ts on GitHub)
  --branch <name>         Branch to track when --source is a URL (default: main)
  --dry-run               Print what would change without copying anything
  --force                 init: overwrite an existing CLAUDE.md/AGENTS.md/.claude/
  --no-merge              update: never 3-way merge — preserve diverged files as-is
EOF
}

[ $# -ge 1 ] || { usage; exit 1; }
CMD="$1"; shift
SOURCE="$DEFAULT_SOURCE"; BRANCH="$DEFAULT_BRANCH"; DRY_RUN=0; FORCE=0; NO_MERGE=0
EXPLICIT_SOURCE=0; EXPLICIT_BRANCH=0
while [ $# -gt 0 ]; do
  case "$1" in
    --source) SOURCE="$2"; EXPLICIT_SOURCE=1; shift 2 ;;
    --branch) BRANCH="$2"; EXPLICIT_BRANCH=1; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --force) FORCE=1; shift ;;
    --no-merge) NO_MERGE=1; shift ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done
case "$CMD" in init|update) ;; *) usage; exit 1 ;; esac

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || { echo "Error: current directory is not a git repository." >&2; exit 1; }

# Resolve the source checkout. Local paths are used as-is; URLs are mirrored
# into a local cache so repeat runs avoid a full clone.
if [ -d "$SOURCE" ]; then
  SRC_DIR="$SOURCE"
else
  mkdir -p "$(dirname "$CACHE_DIR")"
  if [ -d "$CACHE_DIR/.git" ]; then
    git -C "$CACHE_DIR" fetch --quiet origin "$BRANCH"
    git -C "$CACHE_DIR" reset --quiet --hard "origin/$BRANCH"
  else
    git clone --quiet --branch "$BRANCH" "$SOURCE" "$CACHE_DIR"
  fi
  SRC_DIR="$CACHE_DIR"
fi
NEW_SHA=$(git -C "$SRC_DIR" rev-parse HEAD 2>/dev/null || echo "local")

# A plain re-run resolves the same DEFAULT_SOURCE/DEFAULT_BRANCH every time, but
# a run that previously used an explicit --source/--branch (e.g. a local WIP
# checkout) leaves no record of *which* source produced .cts-version's SHA.
# A later plain-default run against a source with an older tip than that
# previous one is then indistinguishable from upstream having lost commits —
# only a diff against the wrong baseline. Record what was actually used, and
# warn (don't block — the caller may legitimately be switching sources) when
# an implicit (no flags passed) run's resolution disagrees with the last one.
CURRENT_SOURCE_DESC="$SOURCE $BRANCH"
if [ -f "$SOURCE_FILE" ] && [ "$EXPLICIT_SOURCE" != 1 ] && [ "$EXPLICIT_BRANCH" != 1 ]; then
  # .cts-source is a multi-line record (source:/branch:/synced:/outcome:) as of
  # this script's current version, but a project synced by an older cts-sync.sh
  # left a bare "SOURCE BRANCH" line — handle both so the mismatch check keeps
  # working through the format transition.
  if grep -q '^source:' "$SOURCE_FILE" 2>/dev/null; then
    PREV_SOURCE=$(grep '^source:' "$SOURCE_FILE" | head -1 | sed 's/^source:[[:space:]]*//' || true)
    PREV_BRANCH=$(grep '^branch:' "$SOURCE_FILE" | head -1 | sed 's/^branch:[[:space:]]*//' || true)
    PREV_SOURCE_DESC="$PREV_SOURCE $PREV_BRANCH"
  else
    PREV_SOURCE_DESC=$(cat "$SOURCE_FILE" 2>/dev/null || echo "")
  fi
  if [ -n "${PREV_SOURCE_DESC:-}" ] && [ "$PREV_SOURCE_DESC" != "$CURRENT_SOURCE_DESC" ]; then
    echo "Warning: last sync used source \"$PREV_SOURCE_DESC\"; this run resolved \"$CURRENT_SOURCE_DESC\" — these differ." >&2
    echo "         A large or unexpected diff below may reflect the source change, not upstream data loss." >&2
    echo "         Pass --source/--branch to match the prior run, or continue to switch sources." >&2
  fi
fi

# Written by write_source_file (see below) at both init/update completion.
# .cts-source is intentionally NOT a format cts-contribute parses — only
# .cts-version (a bare SHA) is read by cts-contribute step 1c, and this
# function never touches it.
write_source_file() {
  local copied="$1" merged="$2" conflicts="$3" needs_attention="$4"
  {
    echo "source: $SOURCE"
    echo "branch: $BRANCH"
    echo "synced: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "outcome: $copied files updated, $merged merged, $conflicts conflicts, $needs_attention needs-attention"
  } > "$SOURCE_FILE"
}

mapfile -t PAYLOAD < <(grep -vE '^[[:space:]]*(#|$)' "$SRC_DIR/$PAYLOAD_FILE")

# Defense-in-depth: some files are project-local and must never be shipped to
# consumers (docs/KNOWLEDGE_INBOX.md — see the "Explicitly NOT payload" note
# in cts-payload.txt). That's currently enforced only by never listing it as
# a payload entry; this guard turns a future careless edit (e.g. listing
# "docs/" as a whole directory instead of individual files) into a loud
# failure instead of a silent leak.
NEVER_PAYLOAD=(docs/KNOWLEDGE_INBOX.md)
covers_forbidden() {
  local entry="$1" forbidden="$2"
  [ "$entry" = "$forbidden" ] && return 0
  [ -d "$SRC_DIR/$entry" ] || return 1
  case "$forbidden" in "$entry"/*) return 0 ;; *) return 1 ;; esac
}
for entry in "${PAYLOAD[@]}"; do
  entry="${entry%/}"
  for forbidden in "${NEVER_PAYLOAD[@]}"; do
    if covers_forbidden "$entry" "$forbidden"; then
      echo "Error: $forbidden must never be a payload entry (project-local, never synced to consumers)." >&2
      exit 1
    fi
  done
done

# Owner-only skills: live in this repo's .claude/skills/ (which IS a payload
# entry as a whole directory), but must never reach a consumer's tree. Unlike
# NEVER_PAYLOAD this can't be enforced by refusing a payload *entry* (the
# entry is the whole "/.claude/skills/" directory, and it must stay a
# payload entry so every other skill still syncs) — so the exclusion is
# enforced per-file in copy_one() below instead. The guard here only catches
# the failure mode of someone later adding one of these paths as its own
# explicit cts-payload.txt line, which would bypass the per-file skip. Unlike
# covers_forbidden() above, this match is exact-only (no directory-covers-file
# case) — a payload line naming a single file *inside* an owner-only skill dir
# would slip past this guard, though is_owner_only_skill() in copy_one() still
# catches it as a second layer, so no actual leak results.
OWNER_ONLY_SKILLS=(.claude/skills/cts-review-contribution/)
for entry in "${PAYLOAD[@]}"; do
  entry="${entry%/}"
  for owner_only in "${OWNER_ONLY_SKILLS[@]}"; do
    if [ "$entry" = "${owner_only%/}" ]; then
      echo "Error: $owner_only must never be listed as its own payload entry (owner-only, never synced to consumers)." >&2
      exit 1
    fi
  done
done

is_owner_only_skill() {
  local rel="$1" owner_only
  for owner_only in "${OWNER_ONLY_SKILLS[@]}"; do
    case "$rel" in "${owner_only%/}"/*) return 0 ;; esac
  done
  return 1
}

# Gitignore-style check: a bare pattern matches exact paths and "dir/" prefixes
# anywhere in the tree; a leading "/" anchors it to the project root only
# (so "/AGENTS.md" protects the root file without shadowing nested ones).
is_ignored() {
  local p="$1" pat
  [ -f "$IGNORE_FILE" ] || return 1
  while IFS= read -r pat; do
    case "$pat" in ''|'#'*) continue ;; esac
    pat="${pat%/}"
    case "$pat" in
      /*)
        pat="${pat#/}"
        case "$p" in "$pat"|"$pat"/*) return 0 ;; esac ;;
      *)
        case "$p" in "$pat"|"$pat"/*|*/"$pat"|*/"$pat"/*) return 0 ;; esac ;;
    esac
  done < "$IGNORE_FILE"
  return 1
}

# Payload paths and file listings come from the chosen --source, which can be
# a URL or a local checkout the operator doesn't fully control (e.g. a fork).
# Refuse anything that could resolve outside the project root before it
# reaches a write sink (cp/mkdir -p) in copy_one or merge_one.
is_safe_rel() {
  case "$1" in
    /*|*/../*|../*|*/..) return 1 ;;
    ..) return 1 ;;
  esac
  return 0
}

# .claude/scripts/ contains this running script. Bash does not fully buffer a
# script's source before executing straight-through code, so if copy_one wrote
# the new .claude/scripts/cts-sync.sh directly, later reads of this script's
# remaining bytes would land on the new file at the old file's byte offsets —
# garbage that doesn't parse as any coherent statement, producing a spurious
# non-zero exit (or worse) after all real work already completed correctly.
# Fix: writes targeting .claude/scripts/ are staged here instead, and flushed
# into place by flush_self_scripts as the literal last statement of the
# script (see end of file) — nothing executes after that copy, so no
# mid-read corruption is possible.
SCRIPTS_STAGE=$(mktemp -d)
is_self_script() {
  case "$1" in .claude/scripts/*) return 0 ;; *) return 1 ;; esac
}
flush_self_scripts() {
  if [ -d "$SCRIPTS_STAGE/.claude/scripts" ]; then
    mkdir -p ./.claude/scripts
    cp -rp "$SCRIPTS_STAGE/.claude/scripts/." ./.claude/scripts/
  fi
  rm -rf "$SCRIPTS_STAGE"
}

LOCALLY_MODIFIED=()

# During update, a file is only fast-forwarded if the working copy still
# matches what was synced last time (content at OLD_SHA). If it diverged
# (local customization not yet in .ctsignore), skip it and report it instead
# of clobbering — the file may be headed for cts-contribute, not overwrite.
is_locally_modified() {
  local rel="$1"
  [ "$CMD" = update ] || return 1
  [ -n "${OLD_SHA:-}" ] || return 1
  [ -e "./$rel" ] || return 1
  git -C "$SRC_DIR" cat-file -e "$OLD_SHA:$rel" 2>/dev/null || return 1
  ! git -C "$SRC_DIR" show "$OLD_SHA:$rel" 2>/dev/null | cmp -s - "./$rel"
}

# True once a diverged file (see is_locally_modified) has also moved
# upstream since OLD_SHA — the case that needs a 3-way merge rather than
# a plain skip-and-report.
upstream_changed() {
  local rel="$1"
  ! git -C "$SRC_DIR" show "$OLD_SHA:$rel" 2>/dev/null | cmp -s - "$SRC_DIR/$rel"
}

MERGED=()
CONFLICTS=()
COPIED=()

# Three-way merge a payload file both the project and upstream CTS have
# changed since the last sync (base = OLD_SHA content). git merge-file does
# the line-level work: non-overlapping hunks combine silently, overlapping
# ones get standard conflict markers left in the file for the operator to
# resolve by hand — `-p` keeps it from touching "./$rel" until we've seen
# whether the merge was clean.
# Cleanup uses an EXIT trap, not `trap ... RETURN` — RETURN is shell-global
# in bash (not scoped to this function), so it would re-fire (with the temp
# paths out of scope) on the next function return anywhere later in the
# script and crash under `set -u`. The EXIT trap is always cleared with
# `trap - EXIT` before the function returns normally; it only ever fires for
# real if `git show`/`cp` fail and `set -e` is unwinding the whole script
# anyway, which is exactly when the leaked temp files need to be caught.
# MERGE_BASE/MERGE_RESULT are deliberately globals, not `local` — when
# errexit unwinds out of this function to run the EXIT trap, bash has
# already torn down the function's local scope, so a trap referencing
# locals dies with "unbound variable" under `set -u` at the worst possible
# moment (mid-failure, right when cleanup is needed).
merge_one() {
  local rel="$1" clean=0 dest="./$1"
  is_self_script "$rel" && dest="$SCRIPTS_STAGE/$rel"
  MERGE_BASE=$(mktemp); MERGE_RESULT=$(mktemp)
  trap 'rm -f "$MERGE_BASE" "$MERGE_RESULT"' EXIT
  git -C "$SRC_DIR" show "$OLD_SHA:$rel" > "$MERGE_BASE"
  git merge-file -p "./$rel" "$MERGE_BASE" "$SRC_DIR/$rel" > "$MERGE_RESULT" 2>/dev/null && clean=1
  if [ "$DRY_RUN" = 1 ]; then
    if [ "$clean" = 1 ]; then echo "merge (dry-run): $rel"; else echo "conflict (dry-run): $rel"; fi
  else
    mkdir -p "$(dirname "$dest")"
    cp "$MERGE_RESULT" "$dest"
    if [ "$clean" = 1 ]; then
      MERGED+=("$rel")
      echo "merged: $rel"
    else
      CONFLICTS+=("$rel")
      echo "CONFLICT: $rel"
    fi
  fi
  rm -f "$MERGE_BASE" "$MERGE_RESULT"
  trap - EXIT
}

copy_one() {
  local rel="$1"
  if ! is_safe_rel "$rel"; then
    echo "refusing unsafe path from source: $rel" >&2
    return
  fi
  if is_owner_only_skill "$rel"; then
    if [ "$DRY_RUN" = 1 ]; then echo "skip (owner-only skill): $rel"; fi
    return
  fi
  if [ "$CMD" = update ] && is_ignored "$rel"; then
    if [ "$DRY_RUN" = 1 ]; then echo "skip (ignored): $rel"; fi
    return
  fi
  if is_locally_modified "$rel"; then
    if [ "$NO_MERGE" != 1 ] && upstream_changed "$rel"; then
      merge_one "$rel"
      return
    fi
    LOCALLY_MODIFIED+=("$rel")
    if [ "$DRY_RUN" = 1 ]; then echo "skip (locally modified): $rel"; fi
    return
  fi
  if [ "$DRY_RUN" = 1 ]; then
    echo "copy: $rel"
    return
  fi
  local dest="./$rel"
  is_self_script "$rel" && dest="$SCRIPTS_STAGE/$rel"
  mkdir -p "$(dirname "$dest")"
  cp -p "$SRC_DIR/$rel" "$dest"
  COPIED+=("$rel")
}

# Walk a payload entry (file or directory) and copy every file under it.
# .claude/scripts/ is last in the payload; its writes land in SCRIPTS_STAGE
# (see is_self_script/flush_self_scripts above) rather than the real path, so
# the running script's own on-disk bytes never change mid-execution.
sync_path() {
  local entry="${1%/}"
  if [ -d "$SRC_DIR/$entry" ]; then
    while IFS= read -r -d '' f; do
      copy_one "${f#"$SRC_DIR"/}"
    done < <(find "$SRC_DIR/$entry" -type f -print0)
  else
    copy_one "$entry"
  fi
}

if [ "$CMD" = init ]; then
  if [ "$FORCE" != 1 ]; then
    for p in CLAUDE.md AGENTS.md .claude; do
      [ -e "$p" ] && { echo "Error: $p already exists. Use --force, or run /cts-setup for existing projects." >&2; exit 1; }
    done
  fi
  for entry in "${PAYLOAD[@]}"; do sync_path "$entry"; done
  if [ "$DRY_RUN" != 1 ]; then
    echo "$NEW_SHA" > "$VERSION_FILE"
    write_source_file "${#COPIED[@]}" 0 0 0
    [ -f "$IGNORE_FILE" ] || cat > "$IGNORE_FILE" <<'EOF'
# .ctsignore — gitignore-syntax paths that `cts-sync.sh update` will never touch.
# Use for: customized CTS files, pruned CTS files (prevents re-adding them),
# and project-only additions placed under payload directories.
# A leading "/" anchors to the project root: "/AGENTS.md" protects only the
# root file; a bare "AGENTS.md" would also match nested files with that name.
EOF
  fi
  echo "Done. CTS payload installed at $NEW_SHA."
else
  OLD_SHA=$(cat "$VERSION_FILE" 2>/dev/null || echo "")
  NEEDS_ATTENTION=0
  for entry in "${PAYLOAD[@]}"; do sync_path "$entry"; done
  for rel in "${LOCALLY_MODIFIED[@]}"; do
    echo "locally modified, not overwritten — diff manually: $rel"
    echo "  git -C $SRC_DIR diff $OLD_SHA..$NEW_SHA -- $rel"
    NEEDS_ATTENTION=$((NEEDS_ATTENTION + 1))
  done
  for rel in "${CONFLICTS[@]}"; do
    echo "unresolved conflict markers left in: $rel — resolve by hand, then stage it"
  done
  for entry in "${PAYLOAD[@]}"; do
    entry="${entry%/}"
    [ -d "$SRC_DIR/$entry" ] && [ -d "./$entry" ] || continue
    while IFS= read -r -d '' f; do
      rel="${f#./}"
      if [ -e "$SRC_DIR/$rel" ] || is_ignored "$rel"; then continue; fi
      echo "removed upstream — delete manually if unwanted: $rel"
      NEEDS_ATTENTION=$((NEEDS_ATTENTION + 1))
    done < <(find "./$entry" -type f -print0)
  done
  # Ignored files are never touched, but silence must not hide upstream drift:
  # report any .ctsignore'd payload file that changed in CTS since the last sync.
  if [ -n "$OLD_SHA" ] && [ "$OLD_SHA" != "$NEW_SHA" ] && git -C "$SRC_DIR" cat-file -e "$OLD_SHA" 2>/dev/null; then
    while IFS= read -r f; do
      if is_ignored "$f"; then
        echo "ignored, but changed upstream — review manually: $f"
        echo "  git -C $SRC_DIR diff $OLD_SHA..$NEW_SHA -- $f"
        NEEDS_ATTENTION=$((NEEDS_ATTENTION + 1))
      fi
    done < <(git -C "$SRC_DIR" diff --name-only "$OLD_SHA" "$NEW_SHA")
    if [ "$DRY_RUN" != 1 ]; then
      echo "Changes:"
      git -C "$SRC_DIR" log --oneline "$OLD_SHA..$NEW_SHA"
    fi
  fi
  if [ "$DRY_RUN" != 1 ]; then
    echo "$NEW_SHA" > "$VERSION_FILE"
    write_source_file "${#COPIED[@]}" "${#MERGED[@]}" "${#CONFLICTS[@]}" "$NEEDS_ATTENTION"
  fi
  echo "Done. Review with: git diff"
fi

# Must be the literal last statement — see the comment on SCRIPTS_STAGE above.
# Everything above this line has already executed and produced its output;
# nothing reads further into this script's own source after this call.
flush_self_scripts
