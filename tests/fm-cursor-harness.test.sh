#!/usr/bin/env bash
# Behavior tests for the verified cursor-agent (Cursor Composer) crewmate adapter:
# launch template, the guarded global user hook + per-task registry, the semantic
# busy lifecycle its beforeSubmitPrompt/stop hooks drive, the stop-double-fire
# dedupe, the per-task commit-msg hook that strips cursor's agent trailer (wired
# via env-injected core.hooksPath, no cursor-config edit), teardown cleanup,
# detection, and session-lock holder recognition.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# shellcheck source=/dev/null
. "$ROOT/bin/fm-busy-lib.sh"

SPAWN="$ROOT/bin/fm-spawn.sh"
TEARDOWN="$ROOT/bin/fm-teardown.sh"
CURSOR_HOOK="$ROOT/bin/fm-cursor-turnend-hook.sh"
TMP_ROOT=$(fm_test_tmproot fm-cursor-harness)
PYTHON_BIN=$(command -v python3) || fail "test needs python3"
PYTHON_BIN_DIR=$(dirname "$PYTHON_BIN")
JQ_BIN=$(command -v jq) || fail "test needs jq"
BASE_PATH=${FM_TEST_BASE_PATH:-$PYTHON_BIN_DIR:/usr/bin:/bin:/usr/sbin:/sbin}

make_spawn_fakebin() {
  local dir=$1 fakebin
  fakebin=$(fm_fakebin "$dir")
  cat > "$fakebin/tmux" <<'SH'
#!/usr/bin/env bash
set -u
case "$*" in
  *"#{pane_current_path}"*) printf '%s\n' "${FM_FAKE_PANE_PATH:-}"; exit 0 ;;
esac
case "${1:-}" in
  display-message) printf 'firstmate\n'; exit 0 ;;
  list-windows) exit 0 ;;
  has-session|new-session|new-window|kill-window) exit 0 ;;
  send-keys)
    [ -n "${FM_FAKE_TEXT_LOG:-}" ] && printf '%s\n' "$*" >> "$FM_FAKE_TEXT_LOG"
    prev=
    for arg in "$@"; do
      if [ "$prev" = -l ]; then printf '%s\n' "$arg" >> "$FM_FAKE_LAUNCH_LOG"; break; fi
      prev=$arg
    done
    exit 0
    ;;
esac
exit 0
SH
  chmod +x "$fakebin/tmux"
  fm_fake_exit0 "$fakebin" treehouse gh-axi gh
  ln -s "$JQ_BIN" "$fakebin/jq"
  printf '%s\n' "$fakebin"
}

make_spawn_case() {  # <name> <id>
  local name=$1 id=$2 case_dir home proj wt fakebin
  case_dir="$TMP_ROOT/$name"
  home="$case_dir/home"
  proj="$case_dir/project"
  wt="$case_dir/wt"
  fakebin=$(make_spawn_fakebin "$case_dir/fake")
  mkdir -p "$home/data/$id" "$home/projects" "$home/state" "$home/config" "$home/.cursor"
  printf 'brief for cursor\n' > "$home/data/$id/brief.md"
  printf 'cursor\n' > "$home/config/crew-harness"
  fm_git_worktree "$proj" "$wt" "wt-$name"
  touch "$home/state/.last-watcher-beat"
  : > "$case_dir/launch.log"
  : > "$case_dir/text.log"
  printf '%s\n' "$case_dir|$home|$proj|$wt|$fakebin"
}

read_spawn_record() {
  IFS='|' read -r CASE_DIR HOME_DIR PROJ_DIR WT_DIR FAKEBIN_DIR <<EOF
$1
EOF
}

run_spawn() {  # <case_dir> <home> <proj> <wt> <fakebin> <id> [extra spawn args...]
  local case_dir=$1 home=$2 proj=$3 wt=$4 fakebin=$5 id=$6
  shift 6
  HOME="$home" FM_ROOT_OVERRIDE='' FM_HOME="$home" \
    FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
    FM_PROJECTS_OVERRIDE="$home/projects" FM_CONFIG_OVERRIDE="$home/config" \
    FM_SPAWN_NO_GUARD=1 FM_FAKE_PANE_PATH="$wt" TMUX="fake,1,0" \
    FM_FAKE_LAUNCH_LOG="$case_dir/launch.log" FM_FAKE_TEXT_LOG="$case_dir/text.log" \
    PATH="$fakebin:$BASE_PATH" \
    "$SPAWN" "$id" "$proj" --harness cursor --mode no-mistakes --yolo off "$@" 2>&1
}

# Feed one JSON hook payload to the installed global hook, as cursor would.
drive_hook() {  # <home> <hook-event> <generation_id> <workspace-root> [status]
  local home=$1 event=$2 genid=$3 root=$4 status=${5:-completed} payload
  if [ "$event" = stop ]; then
    payload=$(printf '{"hook_event_name":"stop","generation_id":"%s","status":"%s","workspace_roots":["%s"]}' \
      "$genid" "$status" "$root")
  else
    payload=$(printf '{"hook_event_name":"%s","generation_id":"%s","workspace_roots":["%s"]}' \
      "$event" "$genid" "$root")
  fi
  printf '%s' "$payload" | HOME="$home" PATH="$JQ_BIN_DIR:$BASE_PATH" \
    bash "$home/.cursor/fm-cursor-turnend.sh"
}
JQ_BIN_DIR=$(dirname "$JQ_BIN")

classify() { fm_busy_classify tmux fake:w cursor "$1" "$2"; }

test_cursor_spawn_installs_hook_registers_token_and_neutralizes_attribution() {
  local id rec out rc launch token meta
  id=cursor-spawn-z1
  rec=$(make_spawn_case spawn "$id")
  read_spawn_record "$rec"
  out=$(run_spawn "$CASE_DIR" "$HOME_DIR" "$PROJ_DIR" "$WT_DIR" "$FAKEBIN_DIR" "$id" \
    --model composer-2.5 --effort high)
  rc=$?
  expect_code 0 "$rc" "cursor spawn should succeed: $out"
  assert_contains "$out" "spawned $id harness=cursor" "cursor spawn did not report success"

  # Launch template: --force --trust --model, positional brief, NO effort flag,
  # NO turn-end placeholder, and cursor-agent as the last command (no trailing ;).
  launch=$(cat "$CASE_DIR/launch.log")
  assert_contains "$launch" "cursor-agent --force --trust --model 'composer-2.5' " \
    "cursor launch did not use --force --trust --model: $launch"
  assert_not_contains "$launch" "--effort" "cursor launch emitted a nonexistent effort flag"
  assert_not_contains "$launch" "__TURNEND__" "cursor launch retained a turn-end placeholder"
  assert_not_contains "$launch" "turn-ended" "cursor launch embedded a turn-end path"
  case "$launch" in
    *';') fail "cursor launch ended with a trailing command; pane would not report cursor-agent: $launch" ;;
  esac

  meta="$HOME_DIR/state/$id.meta"
  assert_grep 'harness=cursor' "$meta" "cursor meta lost its harness"
  assert_grep 'model=composer-2.5' "$meta" "cursor meta lost the requested model"
  assert_grep 'effort=high' "$meta" "cursor meta did not retain the unsupported effort axis"

  # Global user hook + entries for both events.
  assert_present "$HOME_DIR/.cursor/fm-cursor-turnend.sh" "cursor hook script was not installed"
  "$JQ_BIN" -e '.hooks.beforeSubmitPrompt[0].command | contains("fm-cursor-turnend.sh")' \
    "$HOME_DIR/.cursor/hooks.json" >/dev/null || fail "hooks.json lacks the beforeSubmitPrompt entry"
  "$JQ_BIN" -e '.hooks.stop[0].command | contains("fm-cursor-turnend.sh")' \
    "$HOME_DIR/.cursor/hooks.json" >/dev/null || fail "hooks.json lacks the stop entry"

  # Per-task registry token + pointer, with the turn-end path kept out of the pointer.
  assert_grep 'token=' "$WT_DIR/.fm-cursor-turnend" "cursor pointer did not contain a token"
  assert_no_grep "$id.turn-ended" "$WT_DIR/.fm-cursor-turnend" "cursor pointer exposed the turn-end path"
  token=$(sed -n 's/^token=//p' "$WT_DIR/.fm-cursor-turnend")
  assert_present "$HOME_DIR/.cursor/fm-turn-end.d/$token" "cursor registry entry was not written"
  assert_present "$HOME_DIR/state/$id.cursor-turnend-token" "cursor state token was not recorded"
  assert_grep "busyevent=$ROOT/bin/fm-busy-event.sh" "$HOME_DIR/.cursor/fm-turn-end.d/$token" \
    "cursor registry entry did not record this home's fm-busy-event path"

  local excl
  excl=$(git -C "$WT_DIR" rev-parse --git-path info/exclude)
  case "$excl" in /*) : ;; *) excl="$WT_DIR/$excl" ;; esac
  assert_grep '.fm-cursor-turnend' "$excl" "cursor pointer was not gitignored"

  # Attribution neutralization: a per-task commit-msg hook under state/, NOT the old
  # crash-inducing project .cursor/cli.json, wired for the worker via core.hooksPath.
  assert_absent "$WT_DIR/.cursor/cli.json" \
    "cursor still writes the project .cursor/cli.json that crashes the launch"
  local hookdir hook
  # fm-spawn resolves the hook dir under the canonicalized state path (STATE_REAL),
  # so mirror that here and match the shell-quoted value fm-spawn exports.
  hookdir="$(cd "$HOME_DIR/state" && pwd -P)/$id.cursor-git-hooks"
  hook="$hookdir/commit-msg"
  assert_present "$hook" "cursor commit-msg attribution hook was not installed"
  [ -x "$hook" ] || fail "cursor commit-msg hook is not executable"
  # The worker's git is pointed at the hook dir through the GIT_CONFIG_* env, sent
  # before launch on the same channel as GOTMPDIR.
  assert_grep 'export GIT_CONFIG_KEY_0=core.hooksPath' "$CASE_DIR/text.log" \
    "cursor spawn did not wire core.hooksPath into the worker env"
  assert_grep "GIT_CONFIG_VALUE_0='$hookdir'" "$CASE_DIR/text.log" \
    "cursor spawn did not point core.hooksPath at the per-task hook dir"

  # The hook strips only cursor's agent trailer and leaves every other line intact.
  local msgfile
  msgfile="$CASE_DIR/commit-msg-sample"
  {
    printf '%s\n\n' 'Add a feature'
    printf '%s\n' 'Co-authored-by: Real Person <human@example.com>'
    printf '%s\n' 'Co-authored-by: Cursor <cursoragent@cursor.com>'
  } > "$msgfile"
  "$hook" "$msgfile" || fail "cursor commit-msg hook exited nonzero"
  assert_no_grep 'cursoragent@cursor.com' "$msgfile" "hook left cursor's agent trailer in the message"
  assert_grep 'human@example.com' "$msgfile" "hook stripped a legitimate human co-author"
  assert_grep 'Add a feature' "$msgfile" "hook mangled the commit subject"
  # A message with no cursor trailer is passed through byte for byte.
  local clean
  clean="$CASE_DIR/commit-msg-clean"
  printf '%s\n\n%s\n' 'Fix bug' 'Signed-off-by: Dev <dev@example.com>' > "$clean"
  cp "$clean" "$clean.orig"
  "$hook" "$clean" || fail "cursor commit-msg hook exited nonzero on a clean message"
  cmp -s "$clean" "$clean.orig" || fail "hook altered a commit message with no cursor trailer"
  pass "fm-spawn: cursor installs its hook, registers a task token, and neutralizes commit attribution"
}

test_cursor_hook_busy_lifecycle_and_stop_dedupe() {
  local id rec out state token root turnend
  id=cursor-busy-z2
  rec=$(make_spawn_case busy "$id")
  read_spawn_record "$rec"
  out=$(run_spawn "$CASE_DIR" "$HOME_DIR" "$PROJ_DIR" "$WT_DIR" "$FAKEBIN_DIR" "$id")
  expect_code 0 $? "cursor spawn should succeed: $out"
  state="$HOME_DIR/state"
  turnend="$state/$id.turn-ended"

  # Seed after spawn: the launch brief is a submitted turn.
  out=$(classify "$id" "$state")
  [ "$out" = "busy fm-spawn" ] || fail "seed after spawn must be 'busy fm-spawn', got '$out'"

  # stop closes the turn: idle cursor-hook + the turn-end notification touch.
  rm -f "$turnend"
  drive_hook "$HOME_DIR" stop gen-A "$WT_DIR" completed || fail "stop hook drive failed"
  [ -f "$turnend" ] || fail "stop hook did not touch the turn-end marker"
  out=$(classify "$id" "$state")
  [ "$out" = "idle cursor-hook" ] || fail "stop must classify 'idle cursor-hook', got '$out'"

  # beforeSubmitPrompt opens the next turn.
  drive_hook "$HOME_DIR" beforeSubmitPrompt gen-B "$WT_DIR" || fail "beforeSubmitPrompt drive failed"
  out=$(classify "$id" "$state")
  [ "$out" = "busy cursor-hook" ] || fail "beforeSubmitPrompt must classify 'busy cursor-hook', got '$out'"

  # Interrupt double-fire: stop fires twice for one generation (aborted, then
  # error). The dedupe must touch the marker and apply idle exactly once.
  rm -f "$turnend"
  drive_hook "$HOME_DIR" stop gen-B "$WT_DIR" aborted || fail "aborted stop drive failed"
  [ -f "$turnend" ] || fail "the aborted stop must still wake firstmate"
  rm -f "$turnend"
  drive_hook "$HOME_DIR" stop gen-B "$WT_DIR" error || fail "error stop drive failed"
  [ -e "$turnend" ] && fail "the duplicate error stop for one generation was not deduped"
  out=$(classify "$id" "$state")
  [ "$out" = "idle cursor-hook" ] || fail "after the interrupt the task must be idle, got '$out'"
  pass "cursor hook opens on beforeSubmitPrompt, closes on stop, and dedupes the interrupt double-fire"
}

test_cursor_hook_requires_registered_workspace_token() {
  local id rec out state token turnend evil
  id=cursor-auth-z3
  rec=$(make_spawn_case auth "$id")
  read_spawn_record "$rec"
  out=$(run_spawn "$CASE_DIR" "$HOME_DIR" "$PROJ_DIR" "$WT_DIR" "$FAKEBIN_DIR" "$id")
  expect_code 0 $? "cursor spawn should succeed: $out"
  state="$HOME_DIR/state"
  turnend="$state/$id.turn-ended"
  token=$(sed -n 's/^token=//p' "$WT_DIR/.fm-cursor-turnend")

  # A workspace with no firstmate pointer is inert and silent.
  evil="$CASE_DIR/evil"
  mkdir -p "$evil"
  rm -f "$turnend"
  out=$(drive_hook "$HOME_DIR" stop gen-x "$evil" completed 2>&1)
  expect_code 0 $? "cursor hook must never block a tokenless session"
  [ -z "$out" ] || fail "cursor hook printed into a tokenless session: $out"
  assert_absent "$turnend" "a tokenless cursor workspace touched a task marker"

  # A pointer whose token is not on the first line is rejected.
  {
    printf '%s\n' 'ignored'
    printf 'token=%s\n' "$token"
  } > "$WT_DIR/.fm-cursor-turnend"
  rm -f "$turnend"
  drive_hook "$HOME_DIR" stop gen-y "$WT_DIR" completed
  assert_absent "$turnend" "cursor pointer accepted a token outside the first line"

  # The genuine registered pointer works.
  printf 'token=%s\n' "$token" > "$WT_DIR/.fm-cursor-turnend"
  rm -f "$turnend"
  drive_hook "$HOME_DIR" stop gen-z "$WT_DIR" completed
  assert_present "$turnend" "the registered cursor pointer did not touch the turn-end marker"
  pass "cursor global hook fires only for a workspace holding a firstmate registry token"
}

test_cursor_teardown_removes_pointer_registry_and_attribution() {
  local id rec out token
  id=cursor-teardown-z4
  rec=$(make_spawn_case teardown "$id")
  read_spawn_record "$rec"
  out=$(run_spawn "$CASE_DIR" "$HOME_DIR" "$PROJ_DIR" "$WT_DIR" "$FAKEBIN_DIR" "$id")
  expect_code 0 $? "cursor spawn should succeed before teardown: $out"
  token=$(sed -n 's/^token=//p' "$WT_DIR/.fm-cursor-turnend")
  # Simulate an accumulated stop-dedupe directory so teardown must clear it too.
  mkdir -p "$HOME_DIR/.cursor/fm-turn-end.d/$token.stops/gen-A"
  # spawn created the per-task attribution hook dir; teardown must remove it.
  assert_present "$HOME_DIR/state/$id.cursor-git-hooks/commit-msg" \
    "cursor attribution hook was not present before teardown"

  HOME="$HOME_DIR" FM_ROOT_OVERRIDE="$ROOT" FM_HOME="$HOME_DIR" \
    FM_STATE_OVERRIDE="$HOME_DIR/state" FM_DATA_OVERRIDE="$HOME_DIR/data" \
    FM_PROJECTS_OVERRIDE="$HOME_DIR/projects" FM_CONFIG_OVERRIDE="$HOME_DIR/config" \
    FM_SPAWN_NO_GUARD=1 PATH="$FAKEBIN_DIR:$BASE_PATH" \
    "$TEARDOWN" "$id" --force >/dev/null 2>&1 || fail "cursor teardown failed"

  assert_absent "$WT_DIR/.fm-cursor-turnend" "cursor pointer survived teardown"
  assert_absent "$HOME_DIR/state/$id.cursor-git-hooks" "cursor attribution hook dir survived teardown"
  assert_absent "$HOME_DIR/.cursor/fm-turn-end.d/$token" "cursor registry token survived teardown"
  assert_absent "$HOME_DIR/.cursor/fm-turn-end.d/$token.stops" "cursor stop-dedupe dir survived teardown"
  assert_absent "$HOME_DIR/state/$id.cursor-turnend-token" "cursor state token survived teardown"
  pass "fm-teardown: cursor pointer, registry token, dedupe dir, and attribution hook dir are removed"
}

test_cursor_hook_install_is_idempotent_and_preserves_foreign_hooks() {
  local home config count
  home="$TMP_ROOT/install-idem"
  config="$home/.cursor/hooks.json"
  mkdir -p "$home/.cursor"
  cat > "$config" <<'JSON'
{
  "version": 1,
  "notifications": true,
  "hooks": {
    "afterFileEdit": [ { "command": ".cursor/hooks/format.sh" } ]
  }
}
JSON
  HOME="$home" "$CURSOR_HOOK" install || fail "cursor hook install refused a realistic hooks.json"
  cp "$config" "$home/once.json"
  HOME="$home" "$CURSOR_HOOK" install || fail "second cursor hook install failed"
  cmp -s "$home/once.json" "$config" || fail "second cursor hook install changed hooks.json bytes"
  count=$("$JQ_BIN" '.hooks.stop | length' "$config")
  [ "$count" -eq 1 ] || fail "idempotent install left $count stop entries"
  "$JQ_BIN" -e '.hooks.afterFileEdit[0].command == ".cursor/hooks/format.sh" and .notifications == true' \
    "$config" >/dev/null || fail "install did not preserve the captain's foreign hook and keys"

  HOME="$home" "$CURSOR_HOOK" remove || fail "cursor hook removal failed"
  "$JQ_BIN" -e '.hooks.stop == null and .hooks.beforeSubmitPrompt == null' "$config" >/dev/null \
    || fail "removal left firstmate hook entries behind"
  "$JQ_BIN" -e '.hooks.afterFileEdit[0].command == ".cursor/hooks/format.sh"' "$config" >/dev/null \
    || fail "removal discarded the captain's foreign hook"
  assert_absent "$home/.cursor/fm-cursor-turnend.sh" "removal left the firstmate hook script"
  assert_absent "$home/.cursor/fm-turn-end.d" "removal left the firstmate registry"
  pass "cursor hook install is idempotent, preserves foreign hooks, and removal is clean"
}

test_cursor_hook_install_refuses_malformed_hooks_json() {
  local home config out rc
  home="$TMP_ROOT/install-malformed"
  config="$home/.cursor/hooks.json"
  mkdir -p "$home/.cursor"
  printf '{"hooks": [broken\n' > "$config"
  cp "$config" "$home/before.json"
  rc=0
  out=$(HOME="$home" "$CURSOR_HOOK" install 2>&1) || rc=$?
  [ "$rc" -ne 0 ] || fail "malformed hooks.json was accepted"
  assert_contains "$out" "not valid JSON" "malformed refusal lacked its concrete reason"
  cmp -s "$home/before.json" "$config" || fail "malformed refusal changed hooks.json bytes"
  assert_absent "$home/.cursor/fm-cursor-turnend.sh" "malformed refusal wrote the hook script"
  pass "cursor hook install refuses malformed hooks.json without writing"
}

test_cursor_detection_uses_ancestry_after_markers() {
  local dir fakebin cfg out
  dir="$TMP_ROOT/detection"
  fakebin=$(fm_fakebin "$dir")
  cfg="$dir/config"
  mkdir -p "$cfg"
  cat > "$fakebin/ps" <<'SH'
#!/usr/bin/env bash
set -u
field=
pid=
prev=
for arg in "$@"; do
  [ "$prev" = -o ] && field=$arg
  [ "$prev" = -p ] && pid=$arg
  prev=$arg
done
case "$field:$pid" in
  comm=:4242) printf '/home/u/.local/bin/cursor-agent\n' ;;
  comm=:*) printf '/bin/bash\n' ;;
  ppid=:4242) printf '1\n' ;;
  ppid=:*) printf '4242\n' ;;
  args=:*) printf 'bash\n' ;;
esac
SH
  chmod +x "$fakebin/ps"
  out=$(env -u CLAUDECODE -u PI_CODING_AGENT -u GROK_AGENT \
    PATH="$fakebin:$BASE_PATH" FM_CONFIG_OVERRIDE="$cfg" "$ROOT/bin/fm-harness.sh")
  [ "$out" = cursor ] || fail "cursor ancestry detection returned '$out'"
  out=$(CLAUDECODE=1 PATH="$fakebin:$BASE_PATH" FM_CONFIG_OVERRIDE="$cfg" "$ROOT/bin/fm-harness.sh")
  [ "$out" = claude ] || fail "verified env-marker precedence changed, got '$out'"
  pass "fm-harness: cursor-agent is detected by ancestry after env-marker precedence"
}

test_cursor_session_lock_identity() {
  local home fakebin out
  home="$TMP_ROOT/session-lock-home"
  fakebin=$(fm_fakebin "$TMP_ROOT/session-lock-fake")
  mkdir -p "$home/state"
  cat > "$fakebin/ps" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *"comm="*) printf '%s\n' '/home/u/.local/bin/cursor-agent'; exit 0 ;;
  *"args="*) printf '%s\n' 'cursor-agent'; exit 0 ;;
esac
exit 1
SH
  chmod +x "$fakebin/ps"
  FM_HOME="$home" PATH="$fakebin:$BASE_PATH" "$ROOT/bin/fm-lock.sh" \
    || fail "fm-lock did not acquire from cursor ancestry"
  printf '%s\n' "$$" > "$home/state/.lock"
  out=$(FM_HOME="$home" PATH="$fakebin:$BASE_PATH" "$ROOT/bin/fm-lock.sh" status)
  assert_contains "$out" "lock: held by live harness pid" \
    "fm-lock did not recognize cursor as a live holder"
  pass "fm-lock recognizes cursor ancestry and live lock holders"
}

test_cursor_spawn_installs_hook_registers_token_and_neutralizes_attribution
test_cursor_hook_busy_lifecycle_and_stop_dedupe
test_cursor_hook_requires_registered_workspace_token
test_cursor_teardown_removes_pointer_registry_and_attribution
test_cursor_hook_install_is_idempotent_and_preserves_foreign_hooks
test_cursor_hook_install_refuses_malformed_hooks_json
test_cursor_detection_uses_ancestry_after_markers
test_cursor_session_lock_identity

echo "all fm-cursor-harness tests passed"
