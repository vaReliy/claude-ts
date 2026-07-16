#!/usr/bin/env bash
# Regression harness for .claude/scripts/cts-sync.sh — not shipped as payload
# (verify with: grep -c '^tests/' cts-payload.txt should be 0). No test
# runner exists in this repo (no package.json), so this is a self-contained
# bash harness: build throwaway git repos, run the engine against them,
# assert on its output and the resulting files. Exits non-zero on any
# failed assertion so it can be wired into CI later.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/.claude/scripts/cts-sync.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

FAILURES=0
fail() { echo "FAIL: $1"; FAILURES=$((FAILURES + 1)); }
pass() { echo "ok: $1"; }

assert_contains() {
  local haystack="$1" needle="$2" msg="$3"
  case "$haystack" in *"$needle"*) pass "$msg" ;; *) fail "$msg (expected to find: $needle)" ;; esac
}
assert_not_contains() {
  local haystack="$1" needle="$2" msg="$3"
  case "$haystack" in *"$needle"*) fail "$msg (did not expect to find: $needle)" ;; *) pass "$msg" ;; esac
}
assert_file_equals() {
  local file="$1" expected="$2" msg="$3"
  if [ "$(cat "$file")" = "$expected" ]; then pass "$msg"; else fail "$msg (file: $file)"; fi
}

git_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git init -q "$dir"
  git -C "$dir" config user.email test@test.local
  git -C "$dir" config user.name "CTS Test"
}

# ---------------------------------------------------------------------------
# Case 1a: Bug A — new payload path is an APPEND_MERGE_PATHS list file
# (.prettierignore): consumer's own lines survive, CTS's required line is
# appended, and the collision is reported (not silently overwritten).
# ---------------------------------------------------------------------------
src1="$WORK/src1"; consumer1="$WORK/consumer1"
git_repo "$src1"
{
  echo "AGENTS.md"
} > "$src1/cts-payload.txt"
echo "root agents file" > "$src1/AGENTS.md"
git -C "$src1" add -A && git -C "$src1" commit -q -m "commit1: no .prettierignore in payload"
OLD_SHA1=$(git -C "$src1" rev-parse HEAD)

{
  echo "AGENTS.md"
  echo ".prettierignore"
} > "$src1/cts-payload.txt"
{
  echo "# CTS-required exclusion"
  echo ".claude/skills/postgres-best-practices/"
} > "$src1/.prettierignore"
git -C "$src1" add -A && git -C "$src1" commit -q -m "commit2: add .prettierignore to payload"

git_repo "$consumer1"
echo "$OLD_SHA1" > "$consumer1/.cts-version"
{
  echo "/dist"
  echo "/coverage"
  echo ".nx/**"
} > "$consumer1/.prettierignore"
git -C "$consumer1" add -A && git -C "$consumer1" commit -q -m "consumer baseline"

# ---------------------------------------------------------------------------
# Case 1a-2: same as 1a, but the consumer's list file has NO trailing
# newline (mirrors real-world .prettierignore files, e.g. penny's) — `>>` is
# a raw byte append, so without a newline-before-append guard the first
# appended line would concatenate onto the consumer's last existing line
# instead of starting its own. Every other fixture in this suite is built
# via `{ echo ...; } >`, which always ends in a newline from the last echo,
# so this exact failure mode is structurally invisible to those — this case
# exists specifically to exercise it.
# ---------------------------------------------------------------------------
consumer1a2="$WORK/consumer1a2"
git_repo "$consumer1a2"
echo "$OLD_SHA1" > "$consumer1a2/.cts-version"
printf '/dist\n/coverage\n.nx/**' > "$consumer1a2/.prettierignore"
git -C "$consumer1a2" add -A && git -C "$consumer1a2" commit -q -m "consumer baseline, no trailing newline"

out1a2=$(cd "$consumer1a2" && bash "$SCRIPT" update --source "$src1" 2>&1)
exit1a2=$?
if [ "$exit1a2" -ne 0 ]; then
  fail "case 1a-2: engine exited non-zero ($exit1a2): $out1a2"
else
  if grep -qxF ".nx/**" "$consumer1a2/.prettierignore"; then
    pass "case 1a-2: consumer's last line stays its own line (no trailing newline in source)"
  else
    fail "case 1a-2: consumer's last line stays its own line (got: $(cat "$consumer1a2/.prettierignore"))"
  fi
  if grep -qxF "# CTS-required exclusion" "$consumer1a2/.prettierignore"; then
    pass "case 1a-2: appended CTS comment line stays its own line (not concatenated)"
  else
    fail "case 1a-2: appended CTS comment line stays its own line (got: $(cat "$consumer1a2/.prettierignore"))"
  fi
fi

out1=$(cd "$consumer1" && bash "$SCRIPT" update --source "$src1" 2>&1)
exit1=$?

if [ "$exit1" -ne 0 ]; then
  fail "case 1a: engine exited non-zero ($exit1): $out1"
else
  assert_contains "$out1" "appended CTS-required lines (kept your own): .prettierignore" \
    "case 1a: reports append-merge for .prettierignore"
  pi_content=$(cat "$consumer1/.prettierignore")
  case "$pi_content" in
    *"/dist"*) pass "case 1a: consumer's /dist entry survives" ;;
    *) fail "case 1a: consumer's /dist entry survives (got: $pi_content)" ;;
  esac
  case "$pi_content" in
    *"/coverage"*) pass "case 1a: consumer's /coverage entry survives" ;;
    *) fail "case 1a: consumer's /coverage entry survives" ;;
  esac
  case "$pi_content" in
    *".nx/**"*) pass "case 1a: consumer's .nx/** entry survives" ;;
    *) fail "case 1a: consumer's .nx/** entry survives" ;;
  esac
  case "$pi_content" in
    *".claude/skills/postgres-best-practices/"*) pass "case 1a: CTS-required exclusion appended" ;;
    *) fail "case 1a: CTS-required exclusion appended (got: $pi_content)" ;;
  esac
fi

# ---------------------------------------------------------------------------
# Case 1b: Bug A — new payload path is NOT a list file (.editorconfig):
# flagged and left untouched, never silently overwritten.
# ---------------------------------------------------------------------------
src1b="$WORK/src1b"; consumer1b="$WORK/consumer1b"
git_repo "$src1b"
echo "AGENTS.md" > "$src1b/cts-payload.txt"
echo "root agents file" > "$src1b/AGENTS.md"
git -C "$src1b" add -A && git -C "$src1b" commit -q -m "commit1: no .editorconfig in payload"
OLD_SHA1B=$(git -C "$src1b" rev-parse HEAD)

{
  echo "AGENTS.md"
  echo ".editorconfig"
} > "$src1b/cts-payload.txt"
echo "root = true" > "$src1b/.editorconfig"
git -C "$src1b" add -A && git -C "$src1b" commit -q -m "commit2: add .editorconfig to payload"

git_repo "$consumer1b"
echo "$OLD_SHA1B" > "$consumer1b/.cts-version"
echo "consumer-local editorconfig, unrelated" > "$consumer1b/.editorconfig"
git -C "$consumer1b" add -A && git -C "$consumer1b" commit -q -m "consumer baseline"

out1b=$(cd "$consumer1b" && bash "$SCRIPT" update --source "$src1b" 2>&1)
exit1b=$?

if [ "$exit1b" -ne 0 ]; then
  fail "case 1b: engine exited non-zero ($exit1b): $out1b"
else
  assert_contains "$out1b" \
    "new payload file already exists locally, not overwritten — reconcile manually: .editorconfig" \
    "case 1b: reports new-file collision for .editorconfig"
  assert_file_equals "$consumer1b/.editorconfig" "consumer-local editorconfig, unrelated" \
    "case 1b: consumer's .editorconfig is never overwritten"
fi

# ---------------------------------------------------------------------------
# Case 2: renormalize — a consumer file that differs from upstream only by
# prettier-collapsible formatting is not flagged "locally modified" when a
# receiver prettier is detected, and IS flagged with --no-normalize.
# Skips cleanly if no prettier binary is resolvable in this test env.
# ---------------------------------------------------------------------------
resolve_prettier() {
  local c
  for c in "$REPO_ROOT/../penny/node_modules/.bin/prettier" "$(command -v prettier 2>/dev/null || true)"; do
    [ -n "$c" ] && [ -x "$c" ] && { echo "$c"; return 0; }
  done
  return 1
}

if PRETTIER_PATH=$(resolve_prettier); then
  # The prettier binary shim resolves its module relative to its own real
  # location (node_modules/prettier/bin/...) — symlinking just the .bin
  # entry breaks that resolution, so symlink the whole node_modules dir.
  PRETTIER_NODE_MODULES="$(dirname "$(dirname "$PRETTIER_PATH")")"
  src2="$WORK/src2"
  git_repo "$src2"
  echo "data.json" > "$src2/cts-payload.txt"
  printf '{\n  "a": 1,\n  "b": 2\n}\n' > "$src2/data.json"
  git -C "$src2" add -A && git -C "$src2" commit -q -m "commit1: baseline data.json"
  OLD_SHA2=$(git -C "$src2" rev-parse HEAD)

  setup_consumer2() {
    local dir="$1"
    git_repo "$dir"
    echo "$OLD_SHA2" > "$dir/.cts-version"
    # Indentation-only difference from the baseline (4-space vs 2-space) —
    # prettier's objectWrap:preserve default keeps single-line-vs-multi-line
    # layout as authored, so a collapsed-to-one-line variant would NOT
    # renormalize to the same canonical form; re-indentation does.
    printf '{\n    "a": 1,\n    "b": 2\n}\n' > "$dir/data.json"
    ln -s "$PRETTIER_NODE_MODULES" "$dir/node_modules"
    git -C "$dir" add -A && git -C "$dir" commit -q -m "consumer baseline"
  }

  consumer2a="$WORK/consumer2a"
  setup_consumer2 "$consumer2a"
  out2a=$(cd "$consumer2a" && bash "$SCRIPT" update --source "$src2" 2>&1)
  exit2a=$?
  if [ "$exit2a" -ne 0 ]; then
    fail "case 2a: engine exited non-zero ($exit2a): $out2a"
  else
    assert_not_contains "$out2a" "locally modified, not overwritten — diff manually: data.json" \
      "case 2a: formatting-only diff not flagged locally modified (prettier detected)"
  fi

  consumer2b="$WORK/consumer2b"
  setup_consumer2 "$consumer2b"
  out2b=$(cd "$consumer2b" && bash "$SCRIPT" update --source "$src2" --no-normalize 2>&1)
  exit2b=$?
  if [ "$exit2b" -ne 0 ]; then
    fail "case 2b: engine exited non-zero ($exit2b): $out2b"
  else
    assert_contains "$out2b" "locally modified, not overwritten — diff manually: data.json" \
      "case 2b: --no-normalize falls back to raw comparison, flags the diff"
  fi

  # Case 2c: renormalize must also apply to the Bug A new-payload-path
  # collision check (is_new_payload_collision), not just is_locally_modified/
  # upstream_changed/merge_one — a brand-new prettier-handled payload file
  # that differs from the consumer's copy only by formatting must not be
  # wrongly reported as a NEW_COLLISIONS "needs attention" item.
  src2c="$WORK/src2c"
  git_repo "$src2c"
  echo "AGENTS.md" > "$src2c/cts-payload.txt"
  echo "root agents file" > "$src2c/AGENTS.md"
  git -C "$src2c" add -A && git -C "$src2c" commit -q -m "commit1: no new.json in payload"
  OLD_SHA2C=$(git -C "$src2c" rev-parse HEAD)
  {
    echo "AGENTS.md"
    echo "new.json"
  } > "$src2c/cts-payload.txt"
  printf '{\n  "a": 1,\n  "b": 2\n}\n' > "$src2c/new.json"
  git -C "$src2c" add -A && git -C "$src2c" commit -q -m "commit2: add new.json to payload"

  consumer2c="$WORK/consumer2c"
  git_repo "$consumer2c"
  echo "$OLD_SHA2C" > "$consumer2c/.cts-version"
  printf '{\n    "a": 1,\n    "b": 2\n}\n' > "$consumer2c/new.json"
  ln -s "$PRETTIER_NODE_MODULES" "$consumer2c/node_modules"
  git -C "$consumer2c" add -A && git -C "$consumer2c" commit -q -m "consumer baseline"

  out2c=$(cd "$consumer2c" && bash "$SCRIPT" update --source "$src2c" 2>&1)
  exit2c=$?
  if [ "$exit2c" -ne 0 ]; then
    fail "case 2c: engine exited non-zero ($exit2c): $out2c"
  else
    assert_not_contains "$out2c" "new payload file already exists locally, not overwritten" \
      "case 2c: new-payload-path formatting-only diff not flagged NEW_COLLISIONS (prettier detected)"
  fi
else
  echo "skip: no prettier binary resolvable in this test env — renormalize case skipped"
fi

# ---------------------------------------------------------------------------
# Case 3: init on a fresh project still works end-to-end, and a self-script
# (.claude/scripts/*.sh) survives the SCRIPTS_STAGE flush with its executable
# bit intact — the non-prettier-extension cp -p path, distinct from case 2's
# norm_file path (is_prettier_ext excludes .sh, so this always takes cp -p
# even when a receiver prettier is present).
# ---------------------------------------------------------------------------
src3="$WORK/src3"; consumer3="$WORK/consumer3"
mkdir -p "$src3/.claude/scripts"
git_repo "$src3"
echo ".claude/scripts/" > "$src3/cts-payload.txt"
printf '#!/usr/bin/env bash\necho hi\n' > "$src3/.claude/scripts/foo.sh"
chmod 755 "$src3/.claude/scripts/foo.sh"
git -C "$src3" add -A && git -C "$src3" commit -q -m "commit1: baseline script"

git_repo "$consumer3"
touch "$consumer3/.keep"
git -C "$consumer3" add -A && git -C "$consumer3" commit -q -m "empty consumer baseline"

out3=$(cd "$consumer3" && bash "$SCRIPT" init --source "$src3" 2>&1)
exit3=$?
if [ "$exit3" -ne 0 ]; then
  fail "case 3: init exited non-zero ($exit3): $out3"
else
  assert_contains "$out3" "Done. CTS payload installed at" "case 3: init reports success"
  if [ -f "$consumer3/.claude/scripts/foo.sh" ]; then
    pass "case 3: self-script copied to consumer tree"
  else
    fail "case 3: self-script copied to consumer tree (missing: .claude/scripts/foo.sh)"
  fi
  if [ -x "$consumer3/.claude/scripts/foo.sh" ]; then
    pass "case 3: self-script executable bit preserved (cp -p path)"
  else
    fail "case 3: self-script executable bit preserved (cp -p path)"
  fi
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All assertions passed."
  exit 0
else
  echo "$FAILURES assertion(s) failed."
  exit 1
fi
