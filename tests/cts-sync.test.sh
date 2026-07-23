#!/usr/bin/env bash
# Regression harness for .claude/scripts/cts-sync.sh — not shipped as payload
# (verify with: grep -c '^tests/' cts-payload.txt should be 0). No test
# runner exists in this repo (no package.json), so this is a self-contained
# bash harness: build throwaway git repos, run the engine against them,
# assert on its output and the resulting files. Exits non-zero on any
# failed assertion so it can be wired into CI later.
#
# Two-layer distribution model: the engine no longer merges — every
# CTS-owned payload path is plain-overwritten every run. These cases cover
# overwrite semantics, the two detectors (ownership violation, override
# rot), the settings.json deep-merge, the self-update-first re-exec, and a
# contribute round-trip no-op proof. There is deliberately no 3-way-merge or
# baseline-audit coverage here — that machinery no longer exists in the
# engine.
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
  if [ "$(cat "$file")" = "$expected" ]; then pass "$msg"; else fail "$msg (file: $file, got: $(cat "$file" 2>/dev/null))"; fi
}

git_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git init -q "$dir"
  git -C "$dir" config user.email test@test.local
  git -C "$dir" config user.name "CTS Test"
}

# Every source fixture needs its own copy of the CURRENT engine under test at
# .claude/scripts/cts-sync.sh — the self-update-first step diffs against it.
seed_engine() {
  local dir="$1"
  mkdir -p "$dir/.claude/scripts"
  cp "$SCRIPT" "$dir/.claude/scripts/cts-sync.sh"
  chmod +x "$dir/.claude/scripts/cts-sync.sh"
}

# Every consumer fixture also needs a bootstrap copy of the engine (mirrors
# cts-setup's curl-fetch-then-run bootstrap step) so `bash .claude/scripts/
# cts-sync.sh ...` resolves before any sync has run.
seed_consumer_engine() {
  seed_engine "$1"
}

# ---------------------------------------------------------------------------
# Case 1: init — installs payload, writes .cts-version/.cts-source/.ctsignore/
# manifest, and deep-merges the CTS settings fragment into a fresh
# .claude/settings.json.
# ---------------------------------------------------------------------------
src1="$WORK/src1"; consumer1="$WORK/consumer1"
git_repo "$src1"
mkdir -p "$src1/rules/cts" "$src1/.cts"
{
  echo "AGENTS.md"
  echo "rules/cts/"
  echo ".claude/scripts/"
  echo ".cts/settings.cts.json"
} > "$src1/cts-payload.txt"
echo "root agents file" > "$src1/AGENTS.md"
echo "workflow rules" > "$src1/rules/cts/workflow.md"
seed_engine "$src1"
printf '{"model":"opusplan","permissions":{"deny":["Edit(./rules/cts/**)"]}}\n' > "$src1/.cts/settings.cts.json"
git -C "$src1" add -A && git -C "$src1" commit -q -m "v1"

git_repo "$consumer1"
seed_consumer_engine "$consumer1"
git -C "$consumer1" add -A && git -C "$consumer1" commit -q -m "bootstrap"

out1=$(cd "$consumer1" && bash .claude/scripts/cts-sync.sh init --source "$src1" --force 2>&1)
exit1=$?
if [ "$exit1" -ne 0 ]; then
  fail "case 1: init exited non-zero ($exit1): $out1"
else
  assert_contains "$out1" "Done. CTS payload installed at" "case 1: init reports success"
  assert_file_equals "$consumer1/AGENTS.md" "root agents file" "case 1: AGENTS.md installed"
  assert_file_equals "$consumer1/rules/cts/workflow.md" "workflow rules" "case 1: rules/cts/workflow.md installed"
  [ -f "$consumer1/.cts-version" ] && pass "case 1: .cts-version written" || fail "case 1: .cts-version written"
  [ -f "$consumer1/.ctsignore" ] && pass "case 1: .ctsignore bootstrapped" || fail "case 1: .ctsignore bootstrapped"
  [ -f "$consumer1/.cts/manifest.json" ] && pass "case 1: manifest written" || fail "case 1: manifest written"
  if command -v jq >/dev/null 2>&1 && [ -f "$consumer1/.claude/settings.json" ]; then
    model=$(jq -r '.model' "$consumer1/.claude/settings.json")
    deny=$(jq -r '.permissions.deny | join(",")' "$consumer1/.claude/settings.json")
    [ "$model" = "opusplan" ] && pass "case 1: settings.json received CTS model default" || fail "case 1: settings.json received CTS model default (got: $model)"
    case "$deny" in *"Edit(./rules/cts/**)"*) pass "case 1: settings.json received CTS deny rule" ;; *) fail "case 1: settings.json received CTS deny rule (got: $deny)" ;; esac
  else
    fail "case 1: settings.json exists and is readable by jq"
  fi
fi

# ---------------------------------------------------------------------------
# Case 2: ownership violation — a consumer hand-edits a CTS-owned file after
# init. update overwrites it with upstream's content ("updates never skip
# wholesale") but reports a loud OWNERSHIP WARNING first.
# ---------------------------------------------------------------------------
src2="$WORK/src2"; consumer2="$WORK/consumer2"
git_repo "$src2"
mkdir -p "$src2/rules/cts"
{ echo "AGENTS.md"; echo "rules/cts/"; echo ".claude/scripts/"; } > "$src2/cts-payload.txt"
echo "agents v1" > "$src2/AGENTS.md"
echo "workflow v1" > "$src2/rules/cts/workflow.md"
seed_engine "$src2"
git -C "$src2" add -A && git -C "$src2" commit -q -m "v1"

git_repo "$consumer2"
seed_consumer_engine "$consumer2"
git -C "$consumer2" add -A && git -C "$consumer2" commit -q -m "bootstrap"
(cd "$consumer2" && bash .claude/scripts/cts-sync.sh init --source "$src2" --force >/dev/null 2>&1)
git -C "$consumer2" add -A && git -C "$consumer2" commit -q -m "post-init"

echo "consumer hand-edit, not via an override file" >> "$consumer2/rules/cts/workflow.md"
git -C "$consumer2" add -A && git -C "$consumer2" commit -q -m "hand-edit workflow.md"

# upstream also moves on, unrelated change
echo "agents v2" > "$src2/AGENTS.md"
git -C "$src2" add -A && git -C "$src2" commit -q -m "v2"

out2=$(cd "$consumer2" && bash .claude/scripts/cts-sync.sh update --source "$src2" 2>&1)
exit2=$?
if [ "$exit2" -ne 0 ]; then
  fail "case 2: update exited non-zero ($exit2): $out2"
else
  assert_contains "$out2" "OWNERSHIP WARNING: rules/cts/workflow.md" "case 2: ownership violation reported"
  assert_contains "$out2" "override file" "case 2: warning points at the override-file escape hatch"
  assert_file_equals "$consumer2/rules/cts/workflow.md" "workflow v1" "case 2: hand-edit overwritten with upstream content (no merge)"
  assert_file_equals "$consumer2/AGENTS.md" "agents v2" "case 2: unrelated upstream change still applied"
fi

# ---------------------------------------------------------------------------
# Case 3: override survives + override-rot detector — an override file in
# rules/local/ that cites a CTS file/section is never touched by sync, and
# fires a loud "OVERRIDE ROT" warning once its cited target's content
# actually changes upstream.
# ---------------------------------------------------------------------------
src3="$WORK/src3"; consumer3="$WORK/consumer3"
git_repo "$src3"
mkdir -p "$src3/rules/cts"
{ echo "rules/cts/"; echo ".claude/scripts/"; } > "$src3/cts-payload.txt"
echo "workflow v1" > "$src3/rules/cts/workflow.md"
seed_engine "$src3"
git -C "$src3" add -A && git -C "$src3" commit -q -m "v1"

git_repo "$consumer3"
seed_consumer_engine "$consumer3"
git -C "$consumer3" add -A && git -C "$consumer3" commit -q -m "bootstrap"
(cd "$consumer3" && bash .claude/scripts/cts-sync.sh init --source "$src3" --force >/dev/null 2>&1)
mkdir -p "$consumer3/rules/local"
printf '## Overrides rules/cts/workflow.md § "quality gate"\n\nreplacement text local wins\n' > "$consumer3/rules/local/workflow.md"
git -C "$consumer3" add -A && git -C "$consumer3" commit -q -m "add override"

echo "workflow v2 — upstream changed this section" >> "$src3/rules/cts/workflow.md"
git -C "$src3" add -A && git -C "$src3" commit -q -m "v2"

out3=$(cd "$consumer3" && bash .claude/scripts/cts-sync.sh update --source "$src3" 2>&1)
exit3=$?
if [ "$exit3" -ne 0 ]; then
  fail "case 3: update exited non-zero ($exit3): $out3"
else
  assert_file_equals "$consumer3/rules/local/workflow.md" \
    "$(printf '## Overrides rules/cts/workflow.md § "quality gate"\n\nreplacement text local wins')" \
    "case 3: override file untouched by sync"
  assert_contains "$out3" 'OVERRIDE ROT: rules/local/workflow.md cites "rules/cts/workflow.md"' \
    "case 3: override-rot detector fires when the cited CTS file changes"
fi

# ---------------------------------------------------------------------------
# Case 4: .ctsignore'd file is never touched, but a loud notice fires if its
# CTS-side content changed upstream while ignored.
# ---------------------------------------------------------------------------
src4="$WORK/src4"; consumer4="$WORK/consumer4"
git_repo "$src4"
mkdir -p "$src4/rules/cts"
{ echo "rules/cts/"; echo ".claude/scripts/"; } > "$src4/cts-payload.txt"
echo "docker v1" > "$src4/rules/cts/docker-commands.md"
seed_engine "$src4"
git -C "$src4" add -A && git -C "$src4" commit -q -m "v1"

git_repo "$consumer4"
seed_consumer_engine "$consumer4"
git -C "$consumer4" add -A && git -C "$consumer4" commit -q -m "bootstrap"
(cd "$consumer4" && bash .claude/scripts/cts-sync.sh init --source "$src4" --force >/dev/null 2>&1)
echo "/rules/cts/docker-commands.md" >> "$consumer4/.ctsignore"
echo "fully forked, project-specific" > "$consumer4/rules/cts/docker-commands.md"
git -C "$consumer4" add -A && git -C "$consumer4" commit -q -m "fork docker-commands.md"

echo "docker v2" >> "$src4/rules/cts/docker-commands.md"
git -C "$src4" add -A && git -C "$src4" commit -q -m "v2"

out4=$(cd "$consumer4" && bash .claude/scripts/cts-sync.sh update --source "$src4" 2>&1)
exit4=$?
if [ "$exit4" -ne 0 ]; then
  fail "case 4: update exited non-zero ($exit4): $out4"
else
  assert_file_equals "$consumer4/rules/cts/docker-commands.md" "fully forked, project-specific" \
    "case 4: .ctsignore'd file never overwritten"
  assert_contains "$out4" "ignored, but changed upstream — review manually: rules/cts/docker-commands.md" \
    "case 4: ignored-but-changed-upstream notice fires"
  assert_not_contains "$out4" "OWNERSHIP WARNING" "case 4: ignored file does not also fire an ownership warning"
fi

# ---------------------------------------------------------------------------
# Case 5: self-update-first — when the source's copy of cts-sync.sh itself
# differs from the running one, the engine overwrites itself and re-execs
# with the new version before doing anything else, atomically (no
# mid-execution corruption of the running interpreter).
# ---------------------------------------------------------------------------
src5="$WORK/src5"; consumer5="$WORK/consumer5"
git_repo "$src5"
{ echo "AGENTS.md"; echo ".claude/scripts/"; } > "$src5/cts-payload.txt"
echo "agents" > "$src5/AGENTS.md"
seed_engine "$src5"
printf '\n# ENGINE-MARKER-V2\n' >> "$src5/.claude/scripts/cts-sync.sh"
git -C "$src5" add -A && git -C "$src5" commit -q -m "v1, new engine"

git_repo "$consumer5"
seed_consumer_engine "$consumer5"
git -C "$consumer5" add -A && git -C "$consumer5" commit -q -m "bootstrap, old engine"

out5=$(cd "$consumer5" && bash .claude/scripts/cts-sync.sh update --source "$src5" 2>&1)
exit5=$?
if [ "$exit5" -ne 0 ]; then
  fail "case 5: update exited non-zero ($exit5): $out5"
else
  assert_contains "$out5" "cts-sync engine updated; re-running with the new version" \
    "case 5: self-update-first message printed"
  if grep -qxF "# ENGINE-MARKER-V2" "$consumer5/.claude/scripts/cts-sync.sh"; then
    pass "case 5: consumer's engine file replaced with the new version"
  else
    fail "case 5: consumer's engine file replaced with the new version"
  fi
  assert_file_equals "$consumer5/AGENTS.md" "agents" "case 5: sync still completed after the re-exec (new engine ran the rest)"
fi

# ---------------------------------------------------------------------------
# Case 6: settings.json deep-merge — consumer's own scalar customizations
# (e.g. a chosen model) win, but CTS's permissions.deny entries are always
# present via array union, and re-running the merge is idempotent.
# ---------------------------------------------------------------------------
src6="$WORK/src6"; consumer6="$WORK/consumer6"
git_repo "$src6"
mkdir -p "$src6/.cts"
{ echo "AGENTS.md"; echo ".claude/scripts/"; echo ".cts/settings.cts.json"; } > "$src6/cts-payload.txt"
echo "agents" > "$src6/AGENTS.md"
seed_engine "$src6"
printf '{"model":"opusplan","permissions":{"deny":["Edit(./rules/cts/**)"]}}\n' > "$src6/.cts/settings.cts.json"
git -C "$src6" add -A && git -C "$src6" commit -q -m "v1"

git_repo "$consumer6"
seed_consumer_engine "$consumer6"
git -C "$consumer6" add -A && git -C "$consumer6" commit -q -m "bootstrap"
(cd "$consumer6" && bash .claude/scripts/cts-sync.sh init --source "$src6" --force >/dev/null 2>&1)
if command -v jq >/dev/null 2>&1; then
  jq '.model = "custom-model" | .permissions.deny += ["Read(./secrets/**)"] | .myExtraKey = "keep-me"' \
    "$consumer6/.claude/settings.json" > "$consumer6/.claude/settings.json.tmp"
  mv "$consumer6/.claude/settings.json.tmp" "$consumer6/.claude/settings.json"
  git -C "$consumer6" add -A && git -C "$consumer6" commit -q -m "consumer customizes settings.json"

  out6=$(cd "$consumer6" && bash .claude/scripts/cts-sync.sh update --source "$src6" 2>&1)
  exit6=$?
  if [ "$exit6" -ne 0 ]; then
    fail "case 6: update exited non-zero ($exit6): $out6"
  else
    model6=$(jq -r '.model' "$consumer6/.claude/settings.json")
    deny6=$(jq -r '.permissions.deny | sort | join(",")' "$consumer6/.claude/settings.json")
    extra6=$(jq -r '.myExtraKey' "$consumer6/.claude/settings.json")
    [ "$model6" = "custom-model" ] && pass "case 6: consumer's scalar customization (model) wins" \
      || fail "case 6: consumer's scalar customization (model) wins (got: $model6)"
    case "$deny6" in *"Edit(./rules/cts/**)"*) pass "case 6: CTS deny entry still present after merge" ;; *) fail "case 6: CTS deny entry still present after merge (got: $deny6)" ;; esac
    case "$deny6" in *"Read(./secrets/**)"*) pass "case 6: consumer's own deny entry survives (array union)" ;; *) fail "case 6: consumer's own deny entry survives (got: $deny6)" ;; esac
    [ "$extra6" = "keep-me" ] && pass "case 6: consumer's unrelated top-level key survives" \
      || fail "case 6: consumer's unrelated top-level key survives (got: $extra6)"
  fi
else
  echo "skip: jq not available — case 6 (settings deep-merge) skipped"
fi

# ---------------------------------------------------------------------------
# Case 7: contribute round-trip no-op — a consumer's edit to a CTS-owned
# file (ownership violation on the FIRST sync back) is "contributed" by
# copying its content verbatim into the CTS source (mirrors /cts-contribute
# for a CTS-managed-file edit under this model: a straight file copy, no
# hunk rewriting). Syncing again afterward is byte-identical: no ownership
# warning, no content change — proving the round trip is a no-op by
# construction.
# ---------------------------------------------------------------------------
src7="$WORK/src7"; consumer7="$WORK/consumer7"
git_repo "$src7"
mkdir -p "$src7/rules/cts"
{ echo "rules/cts/"; echo ".claude/scripts/"; } > "$src7/cts-payload.txt"
echo "workflow v1" > "$src7/rules/cts/workflow.md"
seed_engine "$src7"
git -C "$src7" add -A && git -C "$src7" commit -q -m "v1"

git_repo "$consumer7"
seed_consumer_engine "$consumer7"
git -C "$consumer7" add -A && git -C "$consumer7" commit -q -m "bootstrap"
(cd "$consumer7" && bash .claude/scripts/cts-sync.sh init --source "$src7" --force >/dev/null 2>&1)
git -C "$consumer7" add -A && git -C "$consumer7" commit -q -m "post-init"

echo "workflow v1 + consumer's own improvement" > "$consumer7/rules/cts/workflow.md"
git -C "$consumer7" add -A && git -C "$consumer7" commit -q -m "consumer improves workflow.md"

# Simulate /cts-contribute: copy the consumer's file verbatim into CTS.
cp "$consumer7/rules/cts/workflow.md" "$src7/rules/cts/workflow.md"
git -C "$src7" add -A && git -C "$src7" commit -q -m "v2, from consumer7"

out7a=$(cd "$consumer7" && bash .claude/scripts/cts-sync.sh update --source "$src7" 2>&1)
assert_contains "$out7a" "OWNERSHIP WARNING: rules/cts/workflow.md" \
  "case 7: first sync after contribution still flags the pre-existing divergence"
assert_file_equals "$consumer7/rules/cts/workflow.md" "workflow v1 + consumer's own improvement" \
  "case 7: content is byte-identical post-contribution (overwrite is a no-op on content)"

out7b=$(cd "$consumer7" && bash .claude/scripts/cts-sync.sh update --source "$src7" 2>&1)
assert_not_contains "$out7b" "OWNERSHIP WARNING" \
  "case 7: second sync (nothing changed) is a clean no-op — no ownership warning"
assert_file_equals "$consumer7/rules/cts/workflow.md" "workflow v1 + consumer's own improvement" \
  "case 7: content still byte-identical on the no-op run"

# ---------------------------------------------------------------------------
# Case 8: new-payload-path collision — a path newly added to cts-payload.txt
# collides with a pre-existing unrelated local file. Under single ownership
# CTS now owns the path, so it is still overwritten (no merge, no silent
# skip) but the collision is reported loudly.
# ---------------------------------------------------------------------------
src8="$WORK/src8"; consumer8="$WORK/consumer8"
git_repo "$src8"
echo "AGENTS.md" > "$src8/cts-payload.txt"
echo "root agents file" > "$src8/AGENTS.md"
seed_engine "$src8"
echo ".claude/scripts/" >> "$src8/cts-payload.txt"
git -C "$src8" add -A && git -C "$src8" commit -q -m "commit1: no .editorconfig in payload"
git_repo "$consumer8"
seed_consumer_engine "$consumer8"
git -C "$consumer8" add -A && git -C "$consumer8" commit -q -m "bootstrap"
(cd "$consumer8" && bash .claude/scripts/cts-sync.sh init --source "$src8" --force >/dev/null 2>&1)

echo "consumer-local editorconfig, predates CTS ownership" > "$consumer8/.editorconfig"
git -C "$consumer8" add -A && git -C "$consumer8" commit -q -m "consumer's own .editorconfig"

echo ".editorconfig" >> "$src8/cts-payload.txt"
echo "root = true" > "$src8/.editorconfig"
git -C "$src8" add -A && git -C "$src8" commit -q -m "commit2: add .editorconfig to payload"

out8=$(cd "$consumer8" && bash .claude/scripts/cts-sync.sh update --source "$src8" 2>&1)
exit8=$?
if [ "$exit8" -ne 0 ]; then
  fail "case 8: update exited non-zero ($exit8): $out8"
else
  assert_contains "$out8" "NEW PAYLOAD PATH COLLISION: .editorconfig" \
    "case 8: new-payload-path collision reported"
  assert_file_equals "$consumer8/.editorconfig" "root = true" \
    "case 8: single ownership — CTS's content wins outright (no merge, no silent skip)"
fi

# ---------------------------------------------------------------------------
# Case 9: override-rot false-positive guard — an override file citing a path
# that did NOT change this run (either a stale/nonexistent cite, or a real
# CTS path that just wasn't touched by this sync) must never fire "OVERRIDE
# ROT", even though other unrelated payload files did change.
# ---------------------------------------------------------------------------
src9="$WORK/src9"; consumer9="$WORK/consumer9"
git_repo "$src9"
mkdir -p "$src9/rules/cts"
{ echo "rules/cts/"; echo ".claude/scripts/"; } > "$src9/cts-payload.txt"
echo "workflow v1" > "$src9/rules/cts/workflow.md"
echo "testing v1" > "$src9/rules/cts/testing.md"
seed_engine "$src9"
git -C "$src9" add -A && git -C "$src9" commit -q -m "v1"

git_repo "$consumer9"
seed_consumer_engine "$consumer9"
git -C "$consumer9" add -A && git -C "$consumer9" commit -q -m "bootstrap"
(cd "$consumer9" && bash .claude/scripts/cts-sync.sh init --source "$src9" --force >/dev/null 2>&1)
mkdir -p "$consumer9/rules/local"
printf '## Overrides rules/cts/nonexistent-path.md § "made up"\n\nreplacement text\n' > "$consumer9/rules/local/stale-cite.md"
git -C "$consumer9" add -A && git -C "$consumer9" commit -q -m "add override citing a path that never existed"

echo "testing v2 — unrelated file changed" >> "$src9/rules/cts/testing.md"
git -C "$src9" add -A && git -C "$src9" commit -q -m "v2: only testing.md changes, not workflow.md or the stale cite"

out9=$(cd "$consumer9" && bash .claude/scripts/cts-sync.sh update --source "$src9" 2>&1)
exit9=$?
if [ "$exit9" -ne 0 ]; then
  fail "case 9: update exited non-zero ($exit9): $out9"
else
  assert_not_contains "$out9" "OVERRIDE ROT" \
    "case 9: stale cite to a nonexistent path never fires override-rot, even when other files change"
fi

# ---------------------------------------------------------------------------
# Case 10: jq missing — cts-sync.sh depends on jq for settings deep-merge and
# manifest bookkeeping; running with jq hidden from PATH must fail fast with
# a clear, actionable error instead of a confusing mid-run jq: command not
# found failure.
# ---------------------------------------------------------------------------
src10="$WORK/src10"; consumer10="$WORK/consumer10"
git_repo "$src10"
mkdir -p "$src10/rules/cts"
{ echo "rules/cts/"; echo ".claude/scripts/"; } > "$src10/cts-payload.txt"
echo "workflow v1" > "$src10/rules/cts/workflow.md"
seed_engine "$src10"
git -C "$src10" add -A && git -C "$src10" commit -q -m "v1"

git_repo "$consumer10"
seed_consumer_engine "$consumer10"
git -C "$consumer10" add -A && git -C "$consumer10" commit -q -m "bootstrap"

nojq_dir="$WORK/nojq-path"
mkdir -p "$nojq_dir"
for tool in bash git sed grep awk cat find mktemp mv cp chmod sha256sum mkdir printf; do
  bin="$(command -v "$tool" 2>/dev/null)" && ln -sf "$bin" "$nojq_dir/$tool"
done
out10=$(cd "$consumer10" && PATH="$nojq_dir" bash .claude/scripts/cts-sync.sh init --source "$src10" --force 2>&1)
exit10=$?
if [ "$exit10" -eq 0 ]; then
  fail "case 10: init with jq hidden from PATH should fail, but exited 0: $out10"
else
  assert_contains "$out10" "jq is required" \
    "case 10: missing jq produces a clear, actionable error instead of a raw command-not-found failure"
fi

# ---------------------------------------------------------------------------
# Case 11: owner-only skill in the payload must not crash a real (non-dry-run)
# sync. Regression for a `set -e` trap: `is_owner_only_skill "$rel" && { ...;
# return; }` in copy_one() returned whatever `$?` the last command inside the
# block happened to leave (1, when DRY_RUN != 1, since the inner `[ "$DRY_RUN"
# = 1 ] && echo` short-circuits false) instead of an explicit success status.
# copy_one() is called as a bare (unguarded) statement from sync_path(), which
# is itself called bare from the top-level payload loop — a bare function call
# that returns nonzero trips `set -e` immediately, silently killing the whole
# script with no output. This is a live bug in production, not just a test
# artifact: this repo's own .claude/skills/cts-review-contribution/ is always
# present under the .claude/skills/ payload directory entry, so every real
# init/update run hit this exact path before the fix.
# ---------------------------------------------------------------------------
src11="$WORK/src11"; consumer11="$WORK/consumer11"
git_repo "$src11"
mkdir -p "$src11/.claude/skills/cts-review-contribution"
{ echo "AGENTS.md"; echo ".claude/skills/"; echo ".claude/scripts/"; } > "$src11/cts-payload.txt"
echo "agents" > "$src11/AGENTS.md"
echo "owner-only skill content" > "$src11/.claude/skills/cts-review-contribution/SKILL.md"
seed_engine "$src11"
git -C "$src11" add -A && git -C "$src11" commit -q -m "v1"

git_repo "$consumer11"
seed_consumer_engine "$consumer11"
git -C "$consumer11" add -A && git -C "$consumer11" commit -q -m "bootstrap"

out11=$(cd "$consumer11" && bash .claude/scripts/cts-sync.sh init --source "$src11" --force 2>&1)
exit11=$?
if [ "$exit11" -ne 0 ]; then
  fail "case 11: init exited non-zero ($exit11) when payload contains an owner-only skill: $out11"
else
  assert_contains "$out11" "Done. CTS payload installed at" "case 11: init completes successfully past the owner-only-skill path"
  assert_file_equals "$consumer11/AGENTS.md" "agents" "case 11: sync still installed the rest of the payload"
  if [ -e "$consumer11/.claude/skills/cts-review-contribution" ]; then
    fail "case 11: owner-only skill must never be copied into the consumer tree"
  else
    pass "case 11: owner-only skill correctly skipped, not copied"
  fi
fi

# ---------------------------------------------------------------------------
# Case 12: self-script ownership blind spot — if the consumer's local
# cts-sync.sh was hand-edited since the last sync (its hash no longer matches
# what that sync recorded), an upstream update to the engine must still fire
# OWNERSHIP WARNING (matching every other CTS-owned file) before overwriting
# it, instead of silently clobbering the hand-edit.
# ---------------------------------------------------------------------------
src12="$WORK/src12"; consumer12="$WORK/consumer12"
git_repo "$src12"
{ echo "AGENTS.md"; echo ".claude/scripts/"; } > "$src12/cts-payload.txt"
echo "agents" > "$src12/AGENTS.md"
seed_engine "$src12"
git -C "$src12" add -A && git -C "$src12" commit -q -m "v1"

git_repo "$consumer12"
seed_consumer_engine "$consumer12"
git -C "$consumer12" add -A && git -C "$consumer12" commit -q -m "bootstrap"
(cd "$consumer12" && bash .claude/scripts/cts-sync.sh init --source "$src12" --force >/dev/null 2>&1)

printf '\n# HAND-EDITED-LOCALLY\n' >> "$consumer12/.claude/scripts/cts-sync.sh"

printf '\n# ENGINE-MARKER-V2-CASE12\n' >> "$src12/.claude/scripts/cts-sync.sh"
git -C "$src12" add -A && git -C "$src12" commit -q -m "v2, new engine"

out12=$(cd "$consumer12" && bash .claude/scripts/cts-sync.sh update --source "$src12" 2>&1)
exit12=$?
if [ "$exit12" -ne 0 ]; then
  fail "case 12: update exited non-zero ($exit12): $out12"
else
  assert_contains "$out12" "OWNERSHIP WARNING: .claude/scripts/cts-sync.sh" \
    "case 12: hand-edited self-script fires ownership warning"
  assert_contains "$out12" "cts-contribute" \
    "case 12: warning points at the contribute escape hatch"
  if grep -qxF "# ENGINE-MARKER-V2-CASE12" "$consumer12/.claude/scripts/cts-sync.sh"; then
    pass "case 12: hand-edited self-script still overwritten with upstream content"
  else
    fail "case 12: hand-edited self-script still overwritten with upstream content"
  fi
fi

# ---------------------------------------------------------------------------
# Case 13: self-script merely stale (never hand-edited since last sync) must
# NOT fire OWNERSHIP WARNING when an upstream update replaces it — that's the
# normal self-update-first path, not an ownership violation.
# ---------------------------------------------------------------------------
src13="$WORK/src13"; consumer13="$WORK/consumer13"
git_repo "$src13"
{ echo "AGENTS.md"; echo ".claude/scripts/"; } > "$src13/cts-payload.txt"
echo "agents" > "$src13/AGENTS.md"
seed_engine "$src13"
git -C "$src13" add -A && git -C "$src13" commit -q -m "v1"

git_repo "$consumer13"
seed_consumer_engine "$consumer13"
git -C "$consumer13" add -A && git -C "$consumer13" commit -q -m "bootstrap"
(cd "$consumer13" && bash .claude/scripts/cts-sync.sh init --source "$src13" --force >/dev/null 2>&1)

printf '\n# ENGINE-MARKER-V2-CASE13\n' >> "$src13/.claude/scripts/cts-sync.sh"
git -C "$src13" add -A && git -C "$src13" commit -q -m "v2, new engine"

out13=$(cd "$consumer13" && bash .claude/scripts/cts-sync.sh update --source "$src13" 2>&1)
exit13=$?
if [ "$exit13" -ne 0 ]; then
  fail "case 13: update exited non-zero ($exit13): $out13"
else
  assert_not_contains "$out13" "OWNERSHIP WARNING" \
    "case 13: merely-stale self-script does not fire ownership warning"
  assert_contains "$out13" "cts-sync engine updated; re-running with the new version" \
    "case 13: self-update-first still applies for the plain-stale case"
  if grep -qxF "# ENGINE-MARKER-V2-CASE13" "$consumer13/.claude/scripts/cts-sync.sh"; then
    pass "case 13: stale self-script replaced with upstream version"
  else
    fail "case 13: stale self-script replaced with upstream version"
  fi
fi

# ---------------------------------------------------------------------------
# Case 14: settings-merge type-mismatch guard — a security-boundary bypass.
# jq's deepmerge falls to "consumer value wins" on ANY shape mismatch, not
# just genuine scalar overrides: if the consumer's existing settings.json has
# `permissions` as a non-object (e.g. a stray string) or `permissions.deny`
# as a non-array, the merge would silently drop the entire CTS `permissions`
# subtree — including all four ownership-enforcement deny entries — while
# still reporting success. The engine must instead hard-fail (non-zero exit,
# clear error) and leave the consumer's settings.json untouched, rather than
# ship a config that looks merged but silently lost its deny rules.
# ---------------------------------------------------------------------------
src14="$WORK/src14"; consumer14="$WORK/consumer14"
git_repo "$src14"
mkdir -p "$src14/.cts"
{ echo "AGENTS.md"; echo ".claude/scripts/"; echo ".cts/settings.cts.json"; } > "$src14/cts-payload.txt"
echo "agents" > "$src14/AGENTS.md"
seed_engine "$src14"
printf '{"model":"opusplan","permissions":{"deny":["Edit(./rules/cts/**)","Write(./rules/cts/**)","Edit(./.cts/**)","Write(./.cts/**)"]}}\n' > "$src14/.cts/settings.cts.json"
git -C "$src14" add -A && git -C "$src14" commit -q -m "v1"

git_repo "$consumer14"
seed_consumer_engine "$consumer14"
git -C "$consumer14" add -A && git -C "$consumer14" commit -q -m "bootstrap"
(cd "$consumer14" && bash .claude/scripts/cts-sync.sh init --source "$src14" --force >/dev/null 2>&1)

if command -v jq >/dev/null 2>&1; then
  # Corrupt permissions into a type that would silently swallow the CTS
  # deny array under a naive deepmerge (string instead of object).
  echo '{"model":"custom","permissions":"none"}' > "$consumer14/.claude/settings.json"
  before14=$(cat "$consumer14/.claude/settings.json")
  git -C "$consumer14" add -A && git -C "$consumer14" commit -q -m "malformed permissions key"

  echo "agents v2" > "$src14/AGENTS.md"
  git -C "$src14" add -A && git -C "$src14" commit -q -m "v2"

  out14=$(cd "$consumer14" && bash .claude/scripts/cts-sync.sh update --source "$src14" 2>&1)
  exit14=$?
  if [ "$exit14" -eq 0 ]; then
    fail "case 14: type-mismatched permissions key should hard-fail the sync, but exited 0: $out14"
  else
    assert_contains "$out14" "would drop required CTS permissions.deny entries" \
      "case 14: type-mismatch produces a clear, actionable error instead of silent success"
    assert_file_equals "$consumer14/.claude/settings.json" "$before14" \
      "case 14: settings.json left untouched (not partially merged) on hard-fail"
  fi
else
  echo "skip: jq not available — case 14 (settings type-mismatch guard) skipped"
fi

# ---------------------------------------------------------------------------
# Case 15: self-update-first also fires on `init --force`, not just `update`
# — regression for the cts-setup "existing project" gap. A consumer that
# never ran the engine before (no .cts-version, no manifest — so this is
# NOT the ownership-violation case) but already has a stale copy of
# .claude/scripts/cts-sync.sh on disk (e.g. from a pre-two-layer bootstrap)
# follows the existing-project path and runs `init --force` directly,
# never `update`. Before the fix, the CMD=update guard meant `init --force`
# ran the payload copy under the OLD engine in-process; the self-update
# block never fired. Assert the engine replaces itself and re-execs BEFORE
# init's payload copy runs, so the copy that actually installs AGENTS.md
# etc. is the new engine, not the stale one.
# ---------------------------------------------------------------------------
src15="$WORK/src15"; consumer15="$WORK/consumer15"
git_repo "$src15"
{ echo "AGENTS.md"; echo ".claude/scripts/"; } > "$src15/cts-payload.txt"
echo "agents v2 (from new engine)" > "$src15/AGENTS.md"
seed_engine "$src15"
printf '\n# ENGINE-MARKER-V2-CASE15\n' >> "$src15/.claude/scripts/cts-sync.sh"
git -C "$src15" add -A && git -C "$src15" commit -q -m "v2, new engine"

git_repo "$consumer15"
seed_consumer_engine "$consumer15"
# Simulate the stale, never-before-synced state: an old engine binary is
# present (hand-placed / long-ago bootstrap), but no .cts-version or
# manifest exist yet, so this must NOT be treated as an ownership violation.
printf '\n# OLD-STALE-ENGINE-NO-MANIFEST\n' >> "$consumer15/.claude/scripts/cts-sync.sh"
echo "existing project's own agents notes" > "$consumer15/AGENTS.md"
git -C "$consumer15" add -A && git -C "$consumer15" commit -q -m "existing project, stale engine, never synced"

out15=$(cd "$consumer15" && bash .claude/scripts/cts-sync.sh init --source "$src15" --force 2>&1)
exit15=$?
if [ "$exit15" -ne 0 ]; then
  fail "case 15: init --force exited non-zero ($exit15): $out15"
else
  assert_not_contains "$out15" "OWNERSHIP WARNING" \
    "case 15: never-before-synced stale engine does not fire ownership warning"
  assert_contains "$out15" "cts-sync engine updated; re-running with the new version" \
    "case 15: self-update-first fires on init --force, not just update"
  if grep -qxF "# ENGINE-MARKER-V2-CASE15" "$consumer15/.claude/scripts/cts-sync.sh"; then
    pass "case 15: consumer's stale engine replaced with the new version"
  else
    fail "case 15: consumer's stale engine replaced with the new version"
  fi
  assert_file_equals "$consumer15/AGENTS.md" "agents v2 (from new engine)" \
    "case 15: init --force payload copy ran under the NEW engine (proves re-exec happened before the payload loop)"
fi

# ---------------------------------------------------------------------------
# Case 16: genuinely pre-refactor (pre-two-layer) engine on disk — not just
# "one version behind" (cases 5/12/13/15 all still have the self-update-first
# block, just different content), but a real pre-two-layer commit
# (a2204c8, the last commit before f449ee9's refactor) that has NO
# self-update-first mechanism at all and still contains the old 3-way-merge
# logic. Invoking `update` against it directly would run that old logic
# against the new payload and can leave `<<<<<<<` conflict markers in payload
# files instead of ever reaching self-update (this is the bug this task
# fixes: 2026-07-23-09). Since an already-running OLD script cannot execute
# code it doesn't contain, the fix cannot live inside cts-sync.sh itself — it
# is a preflight step documented in the cts-update/cts-setup skills (grep for
# the CTS_SYNC_REEXEC marker; if absent, replace the script from the
# resolved source BEFORE ever invoking it). This case proves that documented
# recipe: apply it, then run `update`, and assert a clean sync with zero
# conflict markers anywhere in the payload.
# ---------------------------------------------------------------------------
src16="$WORK/src16"; consumer16="$WORK/consumer16"
git_repo "$src16"
mkdir -p "$src16/rules/cts"
{ echo "AGENTS.md"; echo "rules/cts/"; echo ".claude/scripts/"; } > "$src16/cts-payload.txt"
echo "agents v1" > "$src16/AGENTS.md"
echo "workflow v1" > "$src16/rules/cts/workflow.md"
seed_engine "$src16"
git -C "$src16" add -A && git -C "$src16" commit -q -m "v1, current two-layer engine"

git_repo "$consumer16"
mkdir -p "$consumer16/.claude/scripts" "$consumer16/rules/cts"
git -C "$REPO_ROOT" show a2204c8:.claude/scripts/cts-sync.sh > "$consumer16/.claude/scripts/cts-sync.sh"
chmod +x "$consumer16/.claude/scripts/cts-sync.sh"
echo "agents v0, pre-refactor consumer state" > "$consumer16/AGENTS.md"
echo "workflow v0, pre-refactor consumer state" > "$consumer16/rules/cts/workflow.md"
git -C "$consumer16" add -A && git -C "$consumer16" commit -q -m "existing project, genuinely pre-refactor engine"

if grep -q 'CTS_SYNC_REEXEC' "$consumer16/.claude/scripts/cts-sync.sh"; then
  fail "case 16: fixture sanity check — pre-refactor engine unexpectedly has the self-update-first marker"
else
  pass "case 16: fixture sanity check — pre-refactor engine genuinely lacks the self-update-first marker"
fi

# Apply the documented preflight recipe (SKILL.md's stale-engine guard) before
# ever invoking the stale script.
if grep -q CTS_SYNC_REEXEC "$consumer16/.claude/scripts/cts-sync.sh"; then
  stale16=0
else
  stale16=1
fi
if [ "$stale16" -eq 1 ]; then
  cp "$src16/.claude/scripts/cts-sync.sh" "$consumer16/.claude/scripts/cts-sync.sh"
  chmod +x "$consumer16/.claude/scripts/cts-sync.sh"
fi

out16=$(cd "$consumer16" && bash .claude/scripts/cts-sync.sh update --source "$src16" 2>&1)
exit16=$?
if [ "$exit16" -ne 0 ]; then
  fail "case 16: update exited non-zero ($exit16) after applying the stale-engine preflight: $out16"
else
  assert_not_contains "$out16" "CONFLICT:" \
    "case 16: no old-model CONFLICT output after the preflight replaces the stale engine first"
  assert_file_equals "$consumer16/AGENTS.md" "agents v1" \
    "case 16: AGENTS.md cleanly overwritten with upstream content, no merge markers"
  assert_file_equals "$consumer16/rules/cts/workflow.md" "workflow v1" \
    "case 16: workflow.md cleanly overwritten with upstream content, no merge markers"
  if grep -rl '<<<<<<<' "$consumer16" >/dev/null 2>&1; then
    fail "case 16: no conflict markers left anywhere in the consumer tree"
  else
    pass "case 16: no conflict markers left anywhere in the consumer tree"
  fi
fi

# ---------------------------------------------------------------------------
# Case 17: case 16's fixture is a *never-before-synced* consumer (no
# .cts-version/.cts-source on disk) — is_locally_modified()/merge_one() in
# the OLD pre-refactor engine both require an OLD_SHA baseline
# (`[ -n "${OLD_SHA:-}" ] || return 1`) before they touch the 3-way-merge
# path at all; with no baseline, the old engine's `update` degrades to a
# plain copy_one() regardless of whether the stale-engine preflight ran —
# so case 16 alone cannot prove the preflight recipe is *necessary*: it
# would pass identically even if the preflight step were deleted. The real
# penny incident hit a consumer with a genuine pre-existing baseline (an
# established .cts-version from an earlier sync) and a locally hand-edited
# payload file that upstream had also since changed on the same line — the
# exact precondition merge_one() needs to run and emit `<<<<<<<` markers.
# This case reproduces that precondition directly (hand-writes .cts-version
# to a real ancestor commit, hand-edits AGENTS.md so it diverges from that
# baseline, then advances upstream's AGENTS.md on the same line) and proves
# both halves: (17a) without the preflight, the stale engine really does
# leave conflict markers — the negative control that makes 17b meaningful;
# (17b) with the documented preflight recipe applied first, the same
# precondition produces a clean overwrite instead.
# ---------------------------------------------------------------------------
mk_case17_src() {
  local dir="$1" line1="$2" extra="$3"
  git_repo "$dir"
  { echo "AGENTS.md"; echo ".claude/scripts/"; } > "$dir/cts-payload.txt"
  printf 'line-one %s\nline-two BASE\n%s' "$line1" "$extra" > "$dir/AGENTS.md"
  seed_engine "$dir"
  git -C "$dir" add -A && git -C "$dir" commit -q -m "$line1" >/dev/null
}

mk_case17_consumer() {
  local dir="$1" base_sha="$2"
  git_repo "$dir"
  mkdir -p "$dir/.claude/scripts"
  git -C "$REPO_ROOT" show a2204c8:.claude/scripts/cts-sync.sh > "$dir/.claude/scripts/cts-sync.sh"
  chmod +x "$dir/.claude/scripts/cts-sync.sh"
  echo "$base_sha" > "$dir/.cts-version"
  printf 'line-one LOCAL-EDIT\nline-two BASE\n' > "$dir/AGENTS.md"
  git -C "$dir" add -A && git -C "$dir" commit -q -m "long-ago baseline + local hand-edit, stale engine never replaced" >/dev/null
}

# 17a — negative control: same precondition, preflight skipped.
src17a="$WORK/src17a"; consumer17a="$WORK/consumer17a"
mk_case17_src "$src17a" "BASE" ""
base17a=$(git -C "$src17a" rev-parse HEAD)
mk_case17_consumer "$consumer17a" "$base17a"
printf 'line-one UPSTREAM-EDIT\nline-two BASE\nline-three NEW\n' > "$src17a/AGENTS.md"
git -C "$src17a" add -A && git -C "$src17a" commit -q -m v1 >/dev/null

out17a=$(cd "$consumer17a" && bash .claude/scripts/cts-sync.sh update --source "$src17a" 2>&1)
if grep -rq '<<<<<<<' "$consumer17a" 2>/dev/null; then
  pass "case 17a: negative control — genuinely stale engine + real baseline + colliding edit DOES leave conflict markers without the preflight (proves 17b's fix is load-bearing, not vacuous)"
else
  fail "case 17a: negative control — expected conflict markers WITHOUT the preflight (fixture no longer reproduces the bug; re-check precondition): $out17a"
fi

# 17b — same precondition, preflight applied first.
src17b="$WORK/src17b"; consumer17b="$WORK/consumer17b"
mk_case17_src "$src17b" "BASE" ""
base17b=$(git -C "$src17b" rev-parse HEAD)
mk_case17_consumer "$consumer17b" "$base17b"
printf 'line-one UPSTREAM-EDIT\nline-two BASE\nline-three NEW\n' > "$src17b/AGENTS.md"
git -C "$src17b" add -A && git -C "$src17b" commit -q -m v1 >/dev/null

if ! grep -q CTS_SYNC_REEXEC "$consumer17b/.claude/scripts/cts-sync.sh"; then
  cp "$src17b/.claude/scripts/cts-sync.sh" "$consumer17b/.claude/scripts/cts-sync.sh"
  chmod +x "$consumer17b/.claude/scripts/cts-sync.sh"
fi

out17b=$(cd "$consumer17b" && bash .claude/scripts/cts-sync.sh update --source "$src17b" 2>&1)
exit17b=$?
if [ "$exit17b" -ne 0 ]; then
  fail "case 17b: update exited non-zero ($exit17b) after applying the stale-engine preflight against a real-baseline fixture: $out17b"
else
  assert_not_contains "$out17b" "CONFLICT:" \
    "case 17b: no old-model CONFLICT output when the preflight replaces a genuinely stale engine ahead of a real baseline + colliding edit"
  if grep -rl '<<<<<<<' "$consumer17b" >/dev/null 2>&1; then
    fail "case 17b: no conflict markers left anywhere in the consumer tree (real-baseline fixture)"
  else
    pass "case 17b: no conflict markers left anywhere in the consumer tree (real-baseline fixture)"
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
