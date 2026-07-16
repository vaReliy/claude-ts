#!/usr/bin/env bash
# Sanity check: verify that payload-shipped files do not describe or assume
# the host/template repo's own identity, maintenance workflows, or internal
# processes in language that will ship into every consumer's copy.
# Exits non-zero on any violations so it can be wired into CI later.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PAYLOAD_FILE="$REPO_ROOT/cts-payload.txt"

# Owner-only skills that never leak to consumers
OWNER_ONLY_SKILLS=(.claude/skills/cts-review-contribution/)

# Allowlist: legitimate two-way conditional statements that every reader needs
# regardless of which repo they're in. Format: "relative_path:phrase" with
# explanation of why it's OK (necessary conditional rule, not a leaked workflow).
# Add entries only after human review confirms the match is genuinely a rule
# that applies to both consumers and the host, not a describe-host-workflow leak.
declare -a ALLOWLIST=(
  # CLAUDE.md explains that CHANGELOG.md usage differs by repo type (consumer vs host).
  # Consumers need to know this to use the correct file. Not a host-only workflow.
  # (Two entries: the full phrase and the substring caught by "the template repo" search)
  "CLAUDE.md:template repo itself"
  "CLAUDE.md:the template repo"

  # distill-inbox explains that target selection differs by repo type. Consumers
  # running /distill-inbox need to understand this to pick the right target.
  # Not a description of host-only maintenance, but a rule every user needs.
  # (Two entries: the full phrase and the substring caught by "the template repo" search)
  ".claude/skills/distill-inbox/SKILL.md:template repo itself"
  ".claude/skills/distill-inbox/SKILL.md:the template repo"
)

FAILURES=0
fail() { echo "FAIL: $1"; FAILURES=$((FAILURES + 1)); }
pass() { echo "ok: $1"; }

# Check if a file:phrase match is on the allowlist
is_allowlisted() {
  local file="$1" phrase="$2"
  local rel_file="${file#"$REPO_ROOT"/}"
  local entry
  for entry in "${ALLOWLIST[@]}"; do
    if [ "$entry" = "$rel_file:$phrase" ]; then
      return 0
    fi
  done
  return 1
}

# Check if a relative path is under an owner-only skill directory
is_owner_only_skill() {
  local rel="$1" owner_only
  for owner_only in "${OWNER_ONLY_SKILLS[@]}"; do
    case "$rel" in "${owner_only%/}"/*) return 0 ;; esac
  done
  return 1
}

# Phrases indicating host/template-specific content that shouldn't ship
# Check case-insensitive
check_file_for_host_assumptions() {
  local file="$1"
  local rel_file="${file#"$REPO_ROOT"/}"

  # Skip owner-only skills — they never leak to consumers
  if is_owner_only_skill "$rel_file"; then
    return 0
  fi

  # Grep for phrases indicating the file assumes it's being read in the host repo
  # Use -i for case-insensitive, -q for quiet (just return exit code)
  local phrases=(
    "host repo"
    "template repo itself"
    "claude-ts itself"
    "this repo is claude-ts"
    "the template repo"
  )

  for phrase in "${phrases[@]}"; do
    if grep -qi "$phrase" "$file" 2>/dev/null; then
      if is_allowlisted "$file" "$phrase"; then
        # Legitimate conditional rule — skip silently
        continue
      fi
      echo "  → $file: matched phrase '$phrase'"
      return 1
    fi
  done
  return 0
}

# Resolve a payload entry (file or directory) and check all files
check_payload_entry() {
  local entry="$1"

  if [ -d "$REPO_ROOT/$entry" ]; then
    while IFS= read -r -d '' f; do
      if ! check_file_for_host_assumptions "$f"; then
        fail "payload file assumes host/template repo identity: $f"
      fi
    done < <(find "$REPO_ROOT/$entry" -type f -print0)
  elif [ -f "$REPO_ROOT/$entry" ]; then
    if ! check_file_for_host_assumptions "$REPO_ROOT/$entry"; then
      fail "payload file assumes host/template repo identity: $entry"
    fi
  else
    fail "payload entry not found: $entry (file: $REPO_ROOT/$entry)"
  fi
}

# Read payload entries and check each one
if [ ! -f "$PAYLOAD_FILE" ]; then
  fail "cts-payload.txt not found at: $PAYLOAD_FILE"
else
  while IFS= read -r entry; do
    # Skip empty lines and comments
    [ -z "$entry" ] && continue
    [[ "$entry" =~ ^[[:space:]]*# ]] && continue
    check_payload_entry "$entry"
  done < "$PAYLOAD_FILE"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All payload files passed self-containment check."
  exit 0
else
  echo "$FAILURES violation(s) found — payload files contain host-repo-specific language."
  exit 1
fi
