#!/usr/bin/env bash
# Credentialed behavior regression for the captain-invocable careen skill.
#
# This drives Pi's public skill-loading interface over a disposable Firstmate
# home and verifies both the captain-facing receipt and persisted boundaries.
set -eu

if [ "${FM_CAREEN_LIVE_E2E:-0}" != 1 ]; then
  echo "skip: set FM_CAREEN_LIVE_E2E=1 to run the credentialed Pi careen regression"
  exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODEL=${FM_CAREEN_LIVE_MODEL:-openai-codex/gpt-5.6-sol}

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local haystack=$1 needle=$2 message=$3
  case "$haystack" in
    *"$needle"*) ;;
    *) fail "$message" ;;
  esac
}

command -v pi >/dev/null 2>&1 || fail "pi not found"

LAB=$(mktemp -d "${TMPDIR:-/tmp}/fm-careen-live.XXXXXX")
HOME_FIXTURE="$LAB/home"
CAPTAIN="$HOME_FIXTURE/data/captain.md"
SHARED="$HOME_FIXTURE/data/captain-shared.md"
LEARNINGS="$HOME_FIXTURE/data/learnings.md"
PROJECT_AGENTS="$HOME_FIXTURE/projects/acme/AGENTS.md"
TODAY=$(date -u +%F)

cleanup() {
  rm -rf "$LAB"
}
trap cleanup EXIT

mkdir -p "$HOME_FIXTURE/data" "$HOME_FIXTURE/projects/acme"
cat >"$CAPTAIN" <<EOF
# Captain preferences

- Keep local work summaries concise.
- On this workstation, the quill CLI fails unless TMPDIR is set. <!--a:$TODAY-->
EOF
cat >"$SHARED" <<'EOF'
# Shared captain preferences

- Keep user-facing errors concise in every home.
- On this workstation, the ink CLI truncates payloads over 4 KB.
EOF
cat >"$LEARNINGS" <<'EOF'
# Learnings

- In project acme, prefix every command with `direnv exec .`.
EOF
cat >"$PROJECT_AGENTS" <<'EOF'
# Project agent instructions

- Preserve this sentinel exactly: PROJECT_UNCHANGED.
EOF

project_before=$(cat "$PROJECT_AGENTS")
out=$(
  cd "$HOME_FIXTURE" &&
    FM_HOME="$HOME_FIXTURE" FM_ROOT_OVERRIDE="$ROOT" \
      pi --print --approve --no-session --no-context-files --no-extensions \
      --no-skills --skill "$ROOT/.agents/skills" --tools read,bash,edit,write \
      --model "$MODEL" --thinking high \
      "Invoke the careen skill for this disposable Firstmate home. Load careen and every owner it directs you to. Examine only data/captain.md, data/captain-shared.md, data/learnings.md, and projects/acme/AGENTS.md. Apply every autonomous direct move that careen authorizes, preserve every propose-first item in place, and do not write the project repo. The acme direnv rule is stranger-safe, project-intrinsic, and needed every project session. Finish with exactly these machine-readable receipt lines, filling the expected integer counts: RESULT direct_moves=<n> proposals=<n>; MOVE source=data/captain.md destination=data/learnings.md; PROPOSAL source=data/captain-shared.md destination=data/learnings.md; PROPOSAL source=data/learnings.md destination=projects/acme/AGENTS.md; PROJECT_WRITES=<n>. Do not emit any other RESULT, MOVE, PROPOSAL, or PROJECT_WRITES lines."
) || fail "Pi skill run failed"

captain_after=$(cat "$CAPTAIN")
shared_after=$(cat "$SHARED")
learnings_after=$(cat "$LEARNINGS")
project_after=$(cat "$PROJECT_AGENTS")

assert_contains "$out" "RESULT direct_moves=1 proposals=2" "receipt did not account for one move and two proposals"
assert_contains "$out" "MOVE source=data/captain.md destination=data/learnings.md" "receipt omitted the autonomous home-local fact move"
assert_contains "$out" "PROPOSAL source=data/captain-shared.md destination=data/learnings.md" "receipt omitted the propose-first shared-file removal"
assert_contains "$out" "PROPOSAL source=data/learnings.md destination=projects/acme/AGENTS.md" "receipt omitted the propose-first project route"
assert_contains "$out" "PROJECT_WRITES=0" "receipt did not report the project write boundary"

case "$captain_after" in
  *"quill CLI fails"*) fail "home-local fact remained on the preference ladder" ;;
esac
assert_contains "$captain_after" "Keep local work summaries concise." "home-local preference did not remain in captain.md"
assert_contains "$learnings_after" "quill CLI fails unless TMPDIR is set." "home-local fact did not move to learnings.md"
assert_contains "$learnings_after" "quill CLI fails unless TMPDIR is set. <!--a:$TODAY-->" "home-local fact lost its aging marker during relocation"
# shellcheck disable=SC2016
assert_contains "$learnings_after" 'prefix every command with `direnv exec .`.' "project-side proposal was removed before approval"
assert_contains "$shared_after" "ink CLI truncates payloads over 4 KB." "captain-shared removal happened before approval"
[ "$project_after" = "$project_before" ] || fail "careen wrote the project repo directly"

printf '%s\n' "$out"
printf 'STATE captain_fact_moved=yes shared_removal_deferred=yes project_route_deferred=yes project_unchanged=yes\n'
printf 'ok - careen routes by kind while preserving propose-first and project-write boundaries\n'
