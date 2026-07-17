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
# Case 1c: append_missing_lines source-side trailing-newline drop — mirror
# image of case 1a-2, but on the SOURCE side. `while IFS= read -r line`
# without `|| [ -n "$line" ]` silently skips a final unterminated line, so if
# the SOURCE's list file lacks a trailing newline, the last CTS-required line
# is never appended and the run still reports success. Every other source
# fixture in this suite is built via `{ echo ...; } >`, which always ends in
# a newline — this case exists specifically to exercise the missing-newline
# path via `printf` with no trailing `\n`.
# ---------------------------------------------------------------------------
src1c="$WORK/src1c"; consumer1c="$WORK/consumer1c"
git_repo "$src1c"
echo "AGENTS.md" > "$src1c/cts-payload.txt"
echo "root agents file" > "$src1c/AGENTS.md"
git -C "$src1c" add -A && git -C "$src1c" commit -q -m "commit1: no .prettierignore in payload"
OLD_SHA1C=$(git -C "$src1c" rev-parse HEAD)

{
  echo "AGENTS.md"
  echo ".prettierignore"
} > "$src1c/cts-payload.txt"
# No trailing newline after the last line — the fixture under test.
printf '/dist\n.claude/skills/postgres-best-practices/' > "$src1c/.prettierignore"
git -C "$src1c" add -A && git -C "$src1c" commit -q -m "commit2: add .prettierignore to payload, no trailing newline"

git_repo "$consumer1c"
echo "$OLD_SHA1C" > "$consumer1c/.cts-version"
echo "/coverage" > "$consumer1c/.prettierignore"
git -C "$consumer1c" add -A && git -C "$consumer1c" commit -q -m "consumer baseline"

out1c=$(cd "$consumer1c" && bash "$SCRIPT" update --source "$src1c" 2>&1)
exit1c=$?
if [ "$exit1c" -ne 0 ]; then
  fail "case 1c: engine exited non-zero ($exit1c): $out1c"
else
  if grep -qxF -e "/coverage" "$consumer1c/.prettierignore"; then
    pass "case 1c: consumer's own entry survives"
  else
    fail "case 1c: consumer's own entry survives (got: $(cat "$consumer1c/.prettierignore"))"
  fi
  if grep -qxF -e "/dist" "$consumer1c/.prettierignore"; then
    pass "case 1c: source's first line appended"
  else
    fail "case 1c: source's first line appended (got: $(cat "$consumer1c/.prettierignore"))"
  fi
  if grep -qxF -e ".claude/skills/postgres-best-practices/" "$consumer1c/.prettierignore"; then
    pass "case 1c: source's final (unterminated) line is still appended, not dropped"
  else
    fail "case 1c: source's final (unterminated) line is still appended, not dropped (got: $(cat "$consumer1c/.prettierignore"))"
  fi
fi

# ---------------------------------------------------------------------------
# Case 1d: append_missing_lines leading-dash line — `grep -qxF "$line"`
# (without `-e`) parses a line starting with `-` as an option rather than a
# pattern, so grep errors, the "already present" check silently fails open,
# and the line gets re-appended (duplicated) even though the consumer already
# has it. Fix is `grep -qxF -e "$line"`. Asserts no duplication on the first
# run, and that a second run stays clean (idempotent).
# ---------------------------------------------------------------------------
src1d="$WORK/src1d"; consumer1d="$WORK/consumer1d"
git_repo "$src1d"
echo "AGENTS.md" > "$src1d/cts-payload.txt"
echo "root agents file" > "$src1d/AGENTS.md"
git -C "$src1d" add -A && git -C "$src1d" commit -q -m "commit1: no .prettierignore in payload"
OLD_SHA1D=$(git -C "$src1d" rev-parse HEAD)

{
  echo "AGENTS.md"
  echo ".prettierignore"
} > "$src1d/cts-payload.txt"
{
  printf -- '-n\n'
  echo ".claude/skills/postgres-best-practices/"
} > "$src1d/.prettierignore"
git -C "$src1d" add -A && git -C "$src1d" commit -q -m "commit2: add .prettierignore to payload"

git_repo "$consumer1d"
echo "$OLD_SHA1D" > "$consumer1d/.cts-version"
# Consumer already has the leading-dash line the source will also try to add.
# NOTE: `echo "-n"` is a trap here — the shell builtin interprets `-n` as its
# own suppress-trailing-newline flag rather than printing it literally, so
# `printf` is required to actually write the line into the fixture.
printf -- '-n\n' > "$consumer1d/.prettierignore"
git -C "$consumer1d" add -A && git -C "$consumer1d" commit -q -m "consumer baseline"

out1d=$(cd "$consumer1d" && bash "$SCRIPT" update --source "$src1d" 2>&1)
exit1d=$?
if [ "$exit1d" -ne 0 ]; then
  fail "case 1d: engine exited non-zero ($exit1d): $out1d"
else
  count1d=$(grep -cxF -e "-n" "$consumer1d/.prettierignore")
  if [ "$count1d" -eq 1 ]; then
    pass "case 1d: leading-dash line already present is not duplicated"
  else
    fail "case 1d: leading-dash line already present is not duplicated (count: $count1d, got: $(cat "$consumer1d/.prettierignore"))"
  fi

  # Discriminates the stdin-swallow failure mode: an unguarded `grep -qxF
  # "-n"` (no `-e`) consumes the read loop's redirected stdin on the
  # leading-dash line, silently dropping every source line that follows it —
  # so this line, listed right after "-n" in src1d's .prettierignore, never
  # arrives if the old bug is present.
  if grep -qxF -e ".claude/skills/postgres-best-practices/" "$consumer1d/.prettierignore"; then
    pass "case 1d: source line following the leading-dash line still arrives"
  else
    fail "case 1d: source line following the leading-dash line still arrives (got: $(cat "$consumer1d/.prettierignore"))"
  fi

  # Second run: append_missing_lines fires again since it's still a
  # NEW_COLLISIONS-eligible append-merge path each time cts-payload.txt lists
  # it fresh relative to a stale-baseline .cts-version; re-run against the
  # same source to confirm idempotency (no re-duplication).
  out1d2=$(cd "$consumer1d" && bash "$SCRIPT" update --source "$src1d" 2>&1)
  exit1d2=$?
  if [ "$exit1d2" -ne 0 ]; then
    fail "case 1d: second run exited non-zero ($exit1d2): $out1d2"
  else
    count1d2=$(grep -cxF -e "-n" "$consumer1d/.prettierignore")
    if [ "$count1d2" -eq 1 ]; then
      pass "case 1d: second run stays clean (idempotent, no re-duplication)"
    else
      fail "case 1d: second run stays clean (count: $count1d2, got: $(cat "$consumer1d/.prettierignore"))"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Case 1e: append_missing_lines leading-dash line, NOT yet present — mirror of
# 1d but for the append path itself, not just the dedupe path: a leading-dash
# source line the consumer does NOT already have must still be appended
# (grep -qxF -e must correctly report "not found" and fall through to the
# printf append, not error out and silently skip it).
# ---------------------------------------------------------------------------
src1e="$WORK/src1e"; consumer1e="$WORK/consumer1e"
git_repo "$src1e"
echo "AGENTS.md" > "$src1e/cts-payload.txt"
echo "root agents file" > "$src1e/AGENTS.md"
git -C "$src1e" add -A && git -C "$src1e" commit -q -m "commit1: no .prettierignore in payload"
OLD_SHA1E=$(git -C "$src1e" rev-parse HEAD)

{
  echo "AGENTS.md"
  echo ".prettierignore"
} > "$src1e/cts-payload.txt"
printf -- '-x\n' > "$src1e/.prettierignore"
git -C "$src1e" add -A && git -C "$src1e" commit -q -m "commit2: add .prettierignore to payload"

git_repo "$consumer1e"
echo "$OLD_SHA1E" > "$consumer1e/.cts-version"
# Consumer does NOT have the leading-dash line yet — distinct from case 1d,
# which only covers the already-present/dedupe branch.
printf '/dist\n' > "$consumer1e/.prettierignore"
git -C "$consumer1e" add -A && git -C "$consumer1e" commit -q -m "consumer baseline"

out1e=$(cd "$consumer1e" && bash "$SCRIPT" update --source "$src1e" 2>&1)
exit1e=$?
if [ "$exit1e" -ne 0 ]; then
  fail "case 1e: engine exited non-zero ($exit1e): $out1e"
else
  if grep -qxF -e "/dist" "$consumer1e/.prettierignore"; then
    pass "case 1e: consumer's own entry survives"
  else
    fail "case 1e: consumer's own entry survives (got: $(cat "$consumer1e/.prettierignore"))"
  fi
  count1e=$(grep -cxF -e "-x" "$consumer1e/.prettierignore")
  if [ "$count1e" -eq 1 ]; then
    pass "case 1e: not-yet-present leading-dash line is appended exactly once"
  else
    fail "case 1e: not-yet-present leading-dash line is appended exactly once (count: $count1e, got: $(cat "$consumer1e/.prettierignore"))"
  fi
fi

# ---------------------------------------------------------------------------
# Case 1f: norm_file partial-output-then-fail hazard — if a prettier binary
# writes SOME bytes to stdout before exiting non-zero (buffering is an
# implementation detail, not a guarantee — see the comment on norm_file in
# cts-sync.sh), the mktemp-staged output must never leak into the consumer's
# tree: only the `cat "$src"` fallback's bytes may land in dest. A real
# prettier build never does this deliberately, so this uses a fake prettier
# shim that always writes partial garbage then fails, letting the failure
# path be exercised deterministically regardless of the real prettier's
# actual buffering behavior.
# ---------------------------------------------------------------------------
# init never sets PRETTIER_BIN (update-only per cts-sync.sh), so exercise the
# hazard via update: a brand-new payload file with no prior baseline still
# routes through copy_one's norm_file call when a receiver prettier is
# present.
src1f2="$WORK/src1f2"; consumer1f2="$WORK/consumer1f2"
git_repo "$src1f2"
echo "AGENTS.md" > "$src1f2/cts-payload.txt"
echo "root agents file" > "$src1f2/AGENTS.md"
git -C "$src1f2" add -A && git -C "$src1f2" commit -q -m "commit1: no new.json in payload"
OLD_SHA1F2=$(git -C "$src1f2" rev-parse HEAD)
{
  echo "AGENTS.md"
  echo "new.json"
} > "$src1f2/cts-payload.txt"
printf '{\n  "a": 1\n}\n' > "$src1f2/new.json"
git -C "$src1f2" add -A && git -C "$src1f2" commit -q -m "commit2: add new.json to payload"

git_repo "$consumer1f2"
echo "$OLD_SHA1F2" > "$consumer1f2/.cts-version"
mkdir -p "$consumer1f2/node_modules/.bin"
cat > "$consumer1f2/node_modules/.bin/prettier" <<'EOF'
#!/usr/bin/env bash
printf 'GARBAGE-PARTIAL-OUTPUT-NOT-VALID-JSON-NO-TRAILING-NEWLINE'
exit 1
EOF
chmod 755 "$consumer1f2/node_modules/.bin/prettier"
git -C "$consumer1f2" add -A && git -C "$consumer1f2" commit -q -m "consumer baseline with fake failing prettier"

out1f2=$(cd "$consumer1f2" && bash "$SCRIPT" update --source "$src1f2" 2>&1)
exit1f2=$?
if [ "$exit1f2" -ne 0 ]; then
  fail "case 1f: engine exited non-zero ($exit1f2): $out1f2"
else
  new_json_content=$(cat "$consumer1f2/new.json" 2>/dev/null || echo "MISSING")
  expected_raw=$(printf '{\n  "a": 1\n}\n')
  if [ "$new_json_content" = "$expected_raw" ]; then
    pass "case 1f: prettier partial-output-then-fail falls back to raw src content, no garbage leaks in"
  else
    fail "case 1f: prettier partial-output-then-fail falls back to raw src content, no garbage leaks in (got: $new_json_content)"
  fi
  case "$new_json_content" in
    *GARBAGE*) fail "case 1f: fake prettier's partial garbage does not leak into dest" ;;
    *) pass "case 1f: fake prettier's partial garbage does not leak into dest" ;;
  esac
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

# ---------------------------------------------------------------------------
# Case 4: merge_one's 3x norm_file() calls under a real prettier subprocess,
# genuine 3-way conflict — regression for the EXIT-trap clobber and RETURN-
# trap staleness bugs fixed this session. Unlike case 1f (fake prettier that
# always fails, exercising norm_file's cat-fallback branch on a non-list
# file, but only via copy_one's single call) and case 2 (single norm_file
# call per side via is_locally_modified/upstream_changed), this drives
# norm_file's live-subprocess-success branch three times in a row (base,
# local, upstream) from inside merge_one, with merge_one's own EXIT trap
# armed for the whole call and each norm_file call arming/firing/disarming
# its own RETURN trap on every one of those three calls. Both local and
# upstream diverge from base on the *same* line with different values, so
# git merge-file cannot resolve it silently and conflict markers are left in
# place — the genuine 3-way-conflict path, not a clean fast-forward or a
# non-overlapping auto-merge.
# ---------------------------------------------------------------------------
if PRETTIER_PATH4=$(resolve_prettier); then
  PRETTIER_NODE_MODULES4="$(dirname "$(dirname "$PRETTIER_PATH4")")"
  src4="$WORK/src4"; consumer4="$WORK/consumer4"
  git_repo "$src4"
  printf '{\n  "a": 1,\n  "b": 2,\n  "c": 3\n}\n' > "$src4/data4.json"
  echo "data4.json" > "$src4/cts-payload.txt"
  git -C "$src4" add -A && git -C "$src4" commit -q -m "commit1: baseline data4.json"
  OLD_SHA4=$(git -C "$src4" rev-parse HEAD)

  # Upstream diverges from base: changes "b" on the same line the consumer
  # will also change, to a DIFFERENT value — forces an overlapping,
  # non-auto-mergeable hunk instead of a silently-combinable one.
  printf '{\n  "a": 1,\n  "b": 20,\n  "c": 3\n}\n' > "$src4/data4.json"
  git -C "$src4" add -A && git -C "$src4" commit -q -m "commit2: upstream changes b to 20"

  git_repo "$consumer4"
  echo "$OLD_SHA4" > "$consumer4/.cts-version"
  # Consumer diverges from the SAME base line, to yet another value — a
  # genuine conflicting edit, not just formatting drift.
  printf '{\n  "a": 1,\n  "b": 99,\n  "c": 3\n}\n' > "$consumer4/data4.json"
  ln -s "$PRETTIER_NODE_MODULES4" "$consumer4/node_modules"
  git -C "$consumer4" add -A && git -C "$consumer4" commit -q -m "consumer baseline, locally modified b"

  # Dedicated TMPDIR for this invocation only, so every mktemp call inside
  # the script (SCRIPTS_STAGE, norm_file's $out, merge_one's 5 temp files)
  # lands here — lets us assert nothing survives the run's traps.
  TMPDIR_CASE4="$WORK/tmpdir-case4"
  mkdir -p "$TMPDIR_CASE4"
  out4=$(cd "$consumer4" && TMPDIR="$TMPDIR_CASE4" bash "$SCRIPT" update --source "$src4" 2>&1)
  exit4=$?

  if [ "$exit4" -ne 0 ]; then
    fail "case 4: engine exited non-zero ($exit4): $out4"
  else
    pass "case 4: engine (merge_one, real prettier, 3x norm_file, genuine conflict) exits 0"
  fi

  assert_not_contains "$out4" "unbound variable" \
    "case 4: no unbound-variable errors from RETURN/EXIT trap interaction"

  assert_contains "$out4" "CONFLICT: data4.json" \
    "case 4: merge_one reports a real conflict (overlapping same-line edits)"
  assert_contains "$out4" "unresolved conflict markers left in: data4.json" \
    "case 4: conflict summary line printed"

  data4_content=$(cat "$consumer4/data4.json" 2>/dev/null || echo "MISSING")
  case "$data4_content" in
    *"<<<<<<<"*) pass "case 4: conflict markers left in data4.json for manual resolution" ;;
    *) fail "case 4: conflict markers left in data4.json for manual resolution (got: $data4_content)" ;;
  esac

  leaked4=$(find "$TMPDIR_CASE4" -mindepth 1 2>/dev/null)
  if [ -z "$leaked4" ]; then
    pass "case 4: no leaked temp files under merge_one's live trap context (norm_file RETURN + merge_one EXIT)"
  else
    fail "case 4: no leaked temp files under merge_one's live trap context (found: $leaked4)"
  fi
else
  echo "skip: no prettier binary resolvable in this test env — case 4 (merge_one 3x norm_file, real prettier) skipped"
fi

# ---------------------------------------------------------------------------
# Case 5: is_ignored() trailing-newline drop — `while IFS= read -r pat`
# without `|| [ -n "$pat" ]` silently skips the final line of a .ctsignore
# file that lacks a trailing newline, so that last pattern is never matched
# and the path it should ignore is synced anyway (a silent data overwrite).
# This mirrors the append_missing_lines bug fixed in case 1c; the consumer's
# .ctsignore is built via `printf` with no trailing `\n` to exercise the
# failure mode.
# ---------------------------------------------------------------------------
src5="$WORK/src5"; consumer5="$WORK/consumer5"
git_repo "$src5"
echo "AGENTS.md" > "$src5/cts-payload.txt"
echo "root agents file from source" > "$src5/AGENTS.md"
git -C "$src5" add -A && git -C "$src5" commit -q -m "commit1: baseline AGENTS.md"
OLD_SHA5=$(git -C "$src5" rev-parse HEAD)

echo "root agents file, version 2" > "$src5/AGENTS.md"
git -C "$src5" add -A && git -C "$src5" commit -q -m "commit2: update AGENTS.md"

git_repo "$consumer5"
echo "$OLD_SHA5" > "$consumer5/.cts-version"
echo "consumer-local AGENTS.md content" > "$consumer5/AGENTS.md"
# No trailing newline after the last pattern — the fixture under test.
printf 'AGENTS.md' > "$consumer5/.ctsignore"
git -C "$consumer5" add -A && git -C "$consumer5" commit -q -m "consumer baseline, .ctsignore no trailing newline"

out5=$(cd "$consumer5" && bash "$SCRIPT" update --source "$src5" 2>&1)
exit5=$?
if [ "$exit5" -ne 0 ]; then
  fail "case 5: engine exited non-zero ($exit5): $out5"
else
  agents_content=$(cat "$consumer5/AGENTS.md" 2>/dev/null || echo "MISSING")
  if [ "$agents_content" = "consumer-local AGENTS.md content" ]; then
    pass "case 5: .ctsignore's last (unterminated) pattern 'AGENTS.md' is respected, file not overwritten"
  else
    fail "case 5: .ctsignore's last (unterminated) pattern 'AGENTS.md' is respected, file not overwritten (got: $agents_content)"
  fi
  assert_not_contains "$out5" "copy: AGENTS.md" \
    "case 5: engine did not copy AGENTS.md (is_ignored correctly matched the pattern)"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All assertions passed."
  exit 0
else
  echo "$FAILURES assertion(s) failed."
  exit 1
fi
