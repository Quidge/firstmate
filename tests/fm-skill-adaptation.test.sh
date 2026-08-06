#!/usr/bin/env bash
# tests/fm-skill-adaptation.test.sh - offline behavioral tests for the
# rebasing-adapted-skill provenance script, focused on the read-only `audit`
# subcommand. Every audit run reads its pinned base from a local cache tree
# (SKILL_ADAPTATION_BASE_DIR) instead of the network, so the deterministic
# `ours - base` diff, the two rot classifications, the exit codes, and the -q
# predicate are all exercised through the real executable with no live GitHub.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SCRIPT="$ROOT/.agents/skills/rebasing-adapted-skill/scripts/skill-adaptation.py"

# The script runs under `uv run`; skip cleanly on a runner without uv.
command -v uv >/dev/null 2>&1 || { echo "skip: uv not found"; exit 0; }

TMP_ROOT=$(fm_test_tmproot fm-skill-adaptation)
SHA=0123456789abcdef0123456789abcdef01234567
ATTR="https://github.com/org/repo/tree/$SHA/skills/foo"

# write_adaptation <skill-dir> <attr-url...> then bullet lines on stdin.
write_adaptation() {
  local sk=$1
  shift
  {
    printf -- '---\nattributions:\n'
    local url
    for url in "$@"; do
      printf -- '- %s\n' "$url"
    done
    printf -- '---\n\n## Deviations\n\n'
    cat
  } >"$sk/ADAPTATION.md"
}

# fresh_case <name> echoes a self-contained case dir with SKILL.md, an empty
# base cache for the pinned attribution, and a matching upstream SKILL.md.
fresh_case() {
  local dir base
  dir="$TMP_ROOT/$1/skill"
  base="$TMP_ROOT/$1/base/org/repo/$SHA/skills/foo"
  mkdir -p "$dir" "$base"
  printf 'upstream line\n' >"$base/SKILL.md"
  printf 'upstream line\n' >"$dir/SKILL.md"
  printf '%s\n' "$dir"
}

# audit_case <name> [extra args...]: run audit with the fixture's base cache.
audit_case() {
  local name=$1
  shift
  OUT=$(SKILL_ADAPTATION_BASE_DIR="$TMP_ROOT/$name/base" \
    "$SCRIPT" audit "$TMP_ROOT/$name/skill" "$@" 2>&1)
  RC=$?
}

test_clean() {
  local sk
  sk=$(fresh_case clean)
  write_adaptation "$sk" "$ATTR" </dev/null
  audit_case clean
  expect_code 0 "$RC" "clean skill audits green"
  assert_contains "$OUT" "clean:" "clean audit reports the clean verdict"
  pass "audit: base == ours with no deviations is clean (exit 0)"
}

test_undeclared_modified() {
  local sk
  sk=$(fresh_case mod)
  printf 'local edit\n' >"$sk/SKILL.md"
  write_adaptation "$sk" "$ATTR" </dev/null
  audit_case mod
  expect_code 1 "$RC" "undeclared modified drift fails"
  assert_contains "$OUT" "UNDECLARED DRIFT" "modified drift is flagged undeclared"
  assert_contains "$OUT" "modified" "modified difference is presented with its kind"
  assert_contains "$OUT" "SKILL.md" "the drifted path is named"
  pass "audit: local edit with no bullet is undeclared drift (exit 1)"
}

test_undeclared_removed() {
  local sk base
  sk=$(fresh_case rm)
  base="$TMP_ROOT/rm/base/org/repo/$SHA/skills/foo"
  printf 'upstream ref\n' >"$base/reference.md"
  # ours never had reference.md -> a base file removed locally.
  write_adaptation "$sk" "$ATTR" </dev/null
  audit_case rm
  expect_code 1 "$RC" "undeclared removed drift fails"
  assert_contains "$OUT" "UNDECLARED DRIFT" "removed drift is flagged undeclared"
  assert_contains "$OUT" "removed" "removed difference is presented with its kind"
  assert_contains "$OUT" "reference.md" "the removed path is named"
  pass "audit: a base file missing locally is undeclared drift (exit 1)"
}

test_stale_bullet() {
  local sk
  sk=$(fresh_case stale)
  # base == ours, but a deviation is declared -> the bullet maps to nothing.
  write_adaptation "$sk" "$ATTR" <<<'- keep our stricter opening line'
  audit_case stale
  expect_code 1 "$RC" "stale bullet fails"
  assert_contains "$OUT" "STALE DEVIATIONS" "declared bullet over no diff is stale"
  assert_contains "$OUT" "keep our stricter opening line" "the stale bullet is shown"
  pass "audit: a bullet with no matching difference is stale (exit 1)"
}

test_mixed_presents_both_sides() {
  local sk
  sk=$(fresh_case mixed)
  printf 'local edit\n' >"$sk/SKILL.md"
  write_adaptation "$sk" "$ATTR" <<<'- we keep a stricter opening line in SKILL.md'
  audit_case mixed
  # Both a difference and a bullet exist: the script cannot match them, so it
  # presents both sides and defers to the agent (exit 0, no provable rot).
  expect_code 0 "$RC" "mixed state exits 0 (deferred to agent)"
  assert_contains "$OUT" "correlate:" "mixed state asks the agent to correlate"
  assert_contains "$OUT" "modified" "mixed state still presents the difference"
  assert_contains "$OUT" "we keep a stricter opening line" "mixed state shows the bullet"
  assert_not_contains "$OUT" "UNDECLARED DRIFT" "mixed state is not auto-classified as drift"
  assert_not_contains "$OUT" "STALE DEVIATIONS" "mixed state is not auto-classified as stale"
  pass "audit: differences plus bullets present both sides for the agent (exit 0)"
}

test_placeholder_bullet_is_not_a_deviation() {
  local sk
  sk=$(fresh_case stub)
  # The unedited template placeholder must not count as a declared deviation.
  write_adaptation "$sk" "$ATTR" <<<'- <intentional difference from upstream; delete this bullet if none>'
  audit_case stub
  expect_code 0 "$RC" "placeholder-only ledger over a clean tree is clean"
  assert_contains "$OUT" "clean:" "placeholder bullet is ignored as no deviation"
  pass "audit: an angle-bracket placeholder bullet is not a declaration"
}

test_sentinel_no_deviations_is_clean() {
  local sk
  sk=$(fresh_case sentinel_clean)
  # base == ours (a verbatim vendor) with the "no deviations" sentinel: the
  # single literal line means zero deviations, so it must audit clean, not stale.
  write_adaptation "$sk" "$ATTR" <<<'- no current deviations'
  audit_case sentinel_clean
  expect_code 0 "$RC" "the no-deviations sentinel over a clean tree is clean"
  assert_contains "$OUT" "clean:" "sentinel is treated as zero declared deviations"
  assert_contains "$OUT" "no current deviations" "sentinel line is echoed in the report"
  assert_contains "$OUT" "sentinel:" "the report explains the sentinel"
  assert_not_contains "$OUT" "STALE DEVIATIONS" "sentinel is never a stale bullet"
  pass "audit: a sole '- no current deviations' sentinel audits clean (exit 0)"
}

test_sentinel_with_drift_is_undeclared() {
  local sk
  sk=$(fresh_case sentinel_drift)
  printf 'local edit\n' >"$sk/SKILL.md"
  # The sentinel declares zero deviations, so a real local edit under it is
  # undeclared drift the next rebase would revert - not a covered change.
  write_adaptation "$sk" "$ATTR" <<<'- no current deviations'
  audit_case sentinel_drift
  expect_code 1 "$RC" "drift under the sentinel is undeclared"
  assert_contains "$OUT" "UNDECLARED DRIFT" "sentinel does not cover a real difference"
  pass "audit: real drift under the sentinel is undeclared drift (exit 1)"
}

test_sentinel_beside_real_bullet_is_not_collapsed() {
  local sk stubbed
  sk=$(fresh_case sentinel_plus)
  # The sentinel only means "none" when it is the section's ONLY bullet; beside a
  # real bullet both are ordinary declarations, stale here over a clean tree.
  write_adaptation "$sk" "$ATTR" <<<$'- no current deviations\n- keep our stricter opening line'
  audit_case sentinel_plus
  expect_code 1 "$RC" "sentinel beside another bullet is not the empty sentinel"
  assert_contains "$OUT" "STALE DEVIATIONS" "both bullets are real declarations over no diff"
  assert_contains "$OUT" "no current deviations" "the non-collapsed sentinel bullet is shown"

  stubbed=$(fresh_case sentinel_plus_stub)
  write_adaptation "$stubbed" "$ATTR" <<<$'- no current deviations\n- <intentional difference from upstream>'
  audit_case sentinel_plus_stub
  expect_code 1 "$RC" "a placeholder beside the sentinel prevents collapse"
  assert_contains "$OUT" "STALE DEVIATIONS" "placeholder filtering cannot create a sentinel"
  pass "audit: the sentinel collapses only when it is the sole bullet"
}

test_star_sentinel_is_not_collapsed() {
  local sk
  sk=$(fresh_case sentinel_star)
  write_adaptation "$sk" "$ATTR" <<<'* no current deviations'
  audit_case sentinel_star
  expect_code 1 "$RC" "a star-marked near-miss is an ordinary deviation"
  assert_contains "$OUT" "STALE DEVIATIONS" "star marker does not form the literal sentinel"
  assert_not_contains "$OUT" "sentinel:" "star near-miss is not reported as the sentinel"
  pass "audit: a star-marked sentinel near-miss is rejected"
}

test_padded_sentinel_is_not_collapsed() {
  local sk
  sk=$(fresh_case sentinel_padded)
  write_adaptation "$sk" "$ATTR" <<<' - no current deviations '
  audit_case sentinel_padded
  expect_code 1 "$RC" "a whitespace-padded near-miss is an ordinary deviation"
  assert_contains "$OUT" "STALE DEVIATIONS" "padding does not form the literal sentinel"
  assert_not_contains "$OUT" "sentinel:" "padded near-miss is not reported as the sentinel"
  pass "audit: a whitespace-padded sentinel near-miss is rejected"
}

test_variant_heading_is_not_the_ledger() {
  local sk
  sk=$(fresh_case variant_heading)
  printf 'local edit\n' >"$sk/SKILL.md"
  printf -- '---\nattributions:\n- %s\n---\n\n### deviations\n\n- keep the local edit\n' \
    "$ATTR" >"$sk/ADAPTATION.md"
  audit_case variant_heading
  expect_code 1 "$RC" "variant deviation heading does not declare a deviation"
  assert_contains "$OUT" "UNDECLARED DRIFT" "variant heading leaves drift undeclared"
  assert_not_contains "$OUT" "keep the local edit" "variant heading bullet is ignored"
  pass "audit: only the exact ## Deviations heading identifies the ledger"
}

test_quiet_predicate() {
  local sk
  sk=$(fresh_case quiet_ok)
  write_adaptation "$sk" "$ATTR" </dev/null
  audit_case quiet_ok -q
  expect_code 0 "$RC" "quiet clean audit exits 0"
  assert_not_contains "$OUT" "clean" "quiet mode prints nothing on success"
  [ -z "$OUT" ] || fail "quiet clean audit emitted output: $OUT"

  local bad
  bad=$(fresh_case quiet_bad)
  printf 'local edit\n' >"$bad/SKILL.md"
  write_adaptation "$bad" "$ATTR" </dev/null
  audit_case quiet_bad -q
  expect_code 1 "$RC" "quiet drift audit exits 1"
  [ -z "$OUT" ] || fail "quiet drift audit emitted output: $OUT"
  pass "audit -q: silent predicate, non-zero on provable rot"
}

test_fetch_failure_fails_loudly() {
  local sk
  sk=$(fresh_case fetch)
  write_adaptation "$sk" "$ATTR" </dev/null
  # Point the cache at an empty tree with no matching base -> must fail, not
  # silently report "clean".
  OUT=$(SKILL_ADAPTATION_BASE_DIR="$TMP_ROOT/does-not-exist" \
    "$SCRIPT" audit "$sk" 2>&1)
  RC=$?
  expect_code 3 "$RC" "unfetchable base returns the dedicated fetch code"
  assert_contains "$OUT" "no cached base tree" "fetch failure names the missing base"
  pass "audit: an unreachable base fails loudly (exit 3), never clean"
}

test_skill_less_base_fails_loudly() {
  local sk base
  sk=$(fresh_case skill_less)
  base="$TMP_ROOT/skill_less/base/org/repo/$SHA/skills/foo"
  rm "$base/SKILL.md"
  printf 'upstream ref\n' >"$base/reference.md"
  write_adaptation "$sk" "$ATTR" </dev/null
  audit_case skill_less
  expect_code 3 "$RC" "base without SKILL.md returns the dedicated fetch code"
  assert_contains "$OUT" "pinned base tree has no SKILL.md" "invalid base names the missing root file"
  pass "audit: a SKILL.md-less base fails loudly (exit 3), never clean"
}

test_cache_path_escape_fails_loudly() {
  local sk outside escaped_attr
  sk=$(fresh_case cache_escape)
  outside="$TMP_ROOT/cache_escape/base/org/repo/outside"
  mkdir -p "$outside"
  printf 'upstream line\n' >"$outside/SKILL.md"
  escaped_attr="https://github.com/org/repo/tree/$SHA/skills/%2E%2E/%2E%2E/outside"
  write_adaptation "$sk" "$escaped_attr" </dev/null
  audit_case cache_escape
  expect_code 3 "$RC" "decoded cache path escape returns the dedicated fetch code"
  assert_contains "$OUT" "invalid cached base path" "cache escape is rejected explicitly"
  pass "audit: decoded attribution paths cannot escape the SHA cache root"
}

test_multi_attribution_drift() {
  local sk base2
  sk=$(fresh_case multi)
  local sha2=abcdefabcdefabcdefabcdefabcdefabcdefabcd
  local attr2="https://github.com/org/two/tree/$sha2/skills/bar"
  base2="$TMP_ROOT/multi/base/org/two/$sha2/skills/bar"
  mkdir -p "$base2"
  printf 'upstream line\n' >"$base2/SKILL.md"
  printf 'bar upstream\n' >"$base2/EXTRA.md"
  printf 'bar local edit\n' >"$sk/EXTRA.md"
  write_adaptation "$sk" "$ATTR" "$attr2" </dev/null
  audit_case multi
  expect_code 1 "$RC" "drift under a second attribution fails"
  assert_contains "$OUT" "EXTRA.md" "second attribution's drift is reported"
  assert_contains "$OUT" "$attr2" "the offending attribution is named on the diff line"
  pass "audit: drift is found across every pinned attribution"
}

test_hard_errors() {
  OUT=$("$SCRIPT" audit "$TMP_ROOT/nope" 2>&1)
  RC=$?
  expect_code 128 "$RC" "missing skill dir is a hard path error"

  local sk
  sk=$(fresh_case badpin)
  printf -- '---\nattributions:\n- https://example.com/not-a-tree-url\n---\n' >"$sk/ADAPTATION.md"
  audit_case badpin
  expect_code 1 "$RC" "invalid pin cannot be audited"
  assert_contains "$OUT" "must be a GitHub tree URL" "invalid pin explains itself"

  # A dir with SKILL.md but no ADAPTATION.md at all.
  fresh_case nopin >/dev/null
  audit_case nopin
  expect_code 1 "$RC" "a non-adapted dir cannot be audited"
  assert_contains "$OUT" "missing ADAPTATION.md" "absent provenance is named"
  pass "audit: hard path, invalid pin, and missing provenance each fail distinctly"
}

test_validate_passes_on_the_new_skill_dir() {
  # The machinery skill itself is firstmate-own (no ADAPTATION.md), so we
  # validate a freshly scaffolded adapted dir to exercise validate-skill-dir.
  local sk
  sk=$(fresh_case validate)
  "$SCRIPT" template "$ATTR" >"$sk/ADAPTATION.md"
  "$SCRIPT" validate-skill-dir "$sk" >/dev/null 2>&1
  expect_code 0 "$?" "scaffolded ADAPTATION.md validates"
  pass "validate-skill-dir: a scaffolded adapted skill is structurally valid"
}

test_clean
test_undeclared_modified
test_undeclared_removed
test_stale_bullet
test_mixed_presents_both_sides
test_placeholder_bullet_is_not_a_deviation
test_sentinel_no_deviations_is_clean
test_sentinel_with_drift_is_undeclared
test_sentinel_beside_real_bullet_is_not_collapsed
test_star_sentinel_is_not_collapsed
test_padded_sentinel_is_not_collapsed
test_variant_heading_is_not_the_ledger
test_quiet_predicate
test_fetch_failure_fails_loudly
test_skill_less_base_fails_loudly
test_cache_path_escape_fails_loudly
test_multi_attribution_drift
test_hard_errors
test_validate_passes_on_the_new_skill_dir
