#!/usr/bin/env bash
# tests/fm-supervision-events.test.sh - unit tests for the watcher's native
# event-wait splice (event_wait_or_sleep in bin/fm-watch.sh and
# handle_push_transition in bin/fm-push-transition-lib.sh). The watcher's source
# guard lets this file source it to load
# the functions WITHOUT acquiring the singleton lock or entering the blocking
# loop; wake/sleep and the backend dispatchers are overridden so the exemptions,
# capability memo, and fail-closed disable are asserted deterministically with no
# real herdr, watcher process, or blocking sleeps.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP=$(fm_test_tmproot fm-supervision-events)
STATE_DIR="$TMP/state"
mkdir -p "$STATE_DIR"

# Source the watcher with an isolated state/home. The guard returns before the
# lock/loop, so only the functions load.
export FM_STATE_OVERRIDE="$STATE_DIR"
export FM_ROOT_OVERRIDE="$ROOT"
# Production modules are independently linted canonical roots. Keep this test's
# ShellCheck context local while preserving its unchanged runtime source path.
# shellcheck source=/dev/null
. "$ROOT/bin/fm-watch.sh"

# Overrides: capture wake reasons and neutralize real sleeps (POLL is 15s).
WAKE_LOG="$TMP/wakes"
SLEEP_LOG="$TMP/sleeps"
wake() { printf '%s\n' "$1" >> "$WAKE_LOG"; return 0; }
sleep() { printf 'SLEEP\n' >> "$SLEEP_LOG"; }

reset_state() {
  rm -f "$STATE_DIR"/*.meta "$STATE_DIR"/*.status "$STATE_DIR"/.wake-queue \
    "$STATE_DIR"/.wake-queue.seq "$STATE_DIR"/.watch-triage.log \
    "$STATE_DIR"/.herdr-escalated-* "$TMP"/panes "$TMP"/wtcalls "$TMP"/wtcalled 2>/dev/null || true
  : > "$WAKE_LOG"
  : > "$SLEEP_LOG"
  _event_cap_key=""
  _event_cap_ok=0
  _event_cap_fails=0
}

mkrec() {  # <pane_id> <status>
  fm_transition_record "$1" "wG" "" "$2" claude
}

# --- handle_push_transition: enqueue + wake for a non-paused blocked crew -----

reset_state
fm_write_meta "$STATE_DIR/tk1.meta" "window=default:wG:pQ" "backend=herdr" "kind=ship"
handle_push_transition herdr default "$(mkrec wG:pQ blocked)"
[ -e "$STATE_DIR/.wake-queue" ] || fail "handle_push_transition should enqueue a wake for a blocked crew"
grep -q 'stale' "$STATE_DIR/.wake-queue" || fail "the enqueued wake must be a stale record: $(cat "$STATE_DIR/.wake-queue")"
grep -q 'default:wG:pQ' "$STATE_DIR/.wake-queue" || fail "the stale record must name the crew's window"
grep -q 'herdr: agent blocked' "$STATE_DIR/.wake-queue" || fail "the stale payload must name the herdr-blocked cause"
[ -s "$WAKE_LOG" ] || fail "handle_push_transition must wake the supervisor for a blocked crew"
[ -e "$STATE_DIR/.herdr-escalated-default_wG_pQ" ] || fail "handle_push_transition must commit dedupe only after enqueue"
pass "handle_push_transition: a blocked crew enqueues a stale wake naming its window and wakes the supervisor"

reset_state
fm_write_meta "$STATE_DIR/tk1.meta" "window=default:wG:pQ" "backend=herdr" "kind=ship"
(
  # shellcheck disable=SC2329 # Runtime override called by the isolated production owner.
  fm_wake_append() { return 1; }
  handle_push_transition herdr default "$(mkrec wG:pQ blocked)"
) >/dev/null 2>&1 || true
[ ! -e "$STATE_DIR/.herdr-escalated-default_wG_pQ" ] || fail "a failed durable enqueue must leave the blocked edge eligible for reconnect reconciliation"
pass "handle_push_transition: enqueue failure cannot commit the Herdr dedupe marker"

# --- handle_push_transition: absorb (no wake, no enqueue) for a declared pause -

reset_state
fm_write_meta "$STATE_DIR/tk2.meta" "window=default:wG:pQ" "backend=herdr" "kind=ship"
printf 'paused: waiting on the upstream release\n' > "$STATE_DIR/tk2.status"
handle_push_transition herdr default "$(mkrec wG:pQ blocked)"
if [ -e "$STATE_DIR/.wake-queue" ] && grep -q 'stale' "$STATE_DIR/.wake-queue"; then
  fail "a declared-pause crew must NOT be fast-escalated: $(cat "$STATE_DIR/.wake-queue")"
fi
[ ! -s "$WAKE_LOG" ] || fail "a declared-pause crew must not wake the supervisor from the event fast-path"
grep -q 'absorbed push' "$STATE_DIR/.watch-triage.log" 2>/dev/null || fail "the paused absorb should be logged to the triage log"
pass "handle_push_transition: a declared-pause crew is absorbed (no fast wake), left to the poll loop's long cadence"

# --- handle_push_transition: absorb for a verified captain-held transfer -------

reset_state
fm_write_meta "$STATE_DIR/tk2h.meta" "window=default:wG:pQ" "backend=herdr" "kind=ship"
printf 'captain-held [key=route]: tracked by task-decision-route\n' > "$STATE_DIR/tk2h.status"
handle_push_transition herdr default "$(mkrec wG:pQ blocked)"
if [ -e "$STATE_DIR/.wake-queue" ] && grep -q 'stale' "$STATE_DIR/.wake-queue"; then
  fail "a captain-held crew must NOT be fast-escalated: $(cat "$STATE_DIR/.wake-queue")"
fi
[ ! -s "$WAKE_LOG" ] || fail "a captain-held crew must not wake the supervisor from the event fast-path"
grep -q 'absorbed push' "$STATE_DIR/.watch-triage.log" 2>/dev/null || fail "the captain-held absorb should be logged to the triage log"
pass "handle_push_transition: a captain-held crew is absorbed (no fast wake), left to the poll loop's long cadence"

# --- event_wait_or_sleep: secondmate windows are excluded from the pane list --

reset_state
fm_write_meta "$STATE_DIR/tk3.meta" "window=default:wG:pQ" "backend=herdr" "kind=ship"
fm_write_meta "$STATE_DIR/sm1.meta" "window=default:wA:pS" "backend=herdr" "kind=secondmate"
# shellcheck disable=SC2329 # Runtime overrides called by the isolated watcher.
fm_backend_events_capable() { return 0; }
# shellcheck disable=SC2329 # Runtime overrides called by the isolated watcher.
fm_backend_wait_transition() { shift 4; printf '%s\n' "$*" > "$TMP/panes"; return 1; }
event_wait_or_sleep
PANES=$(cat "$TMP/panes" 2>/dev/null || true)
case "$PANES" in *"default:wG:pQ"*) : ;; *) fail "the ship window must be in the event pane list, got '$PANES'" ;; esac
case "$PANES" in *"default:wA:pS"*) fail "a kind=secondmate window must be EXCLUDED from the event pane list, got '$PANES'" ;; *) : ;; esac
pass "event_wait_or_sleep: herdr windows go on the event pane list, but kind=secondmate endpoints are excluded"

reset_state
fm_write_meta "$STATE_DIR/tk3.meta" "window=default:wG:pQ" "backend=herdr" "kind=ship"
CAP_CALLS=0
# shellcheck disable=SC2329 # Runtime overrides called by the isolated watcher.
fm_backend_events_capable() { CAP_CALLS=$((CAP_CALLS + 1)); return 0; }
# shellcheck disable=SC2329 # Runtime overrides called by the isolated watcher.
fm_backend_wait_transition() {
  [ "${FM_BACKEND_EVENTS_CAPABILITY_CONFIRMED:-0}" = 1 ] || fail "cached capability verdict was not passed to the wait"
  return 1
}
event_wait_or_sleep
event_wait_or_sleep
[ "$CAP_CALLS" = 1 ] || fail "capability probe must be memoized across waits, got $CAP_CALLS calls"
pass "event_wait_or_sleep: one cached capability probe owns validation across bounded waits"

# --- event_wait_or_sleep: a tmux-only home never runs the event path ----------

reset_state
fm_write_meta "$STATE_DIR/tk4.meta" "window=fmses:fm-tk4" "kind=ship"   # no backend= -> tmux
# shellcheck disable=SC2329 # Runtime override called by the isolated watcher.
fm_backend_wait_transition() { printf 'CALLED\n' > "$TMP/wtcalled"; return 1; }
event_wait_or_sleep
[ ! -e "$TMP/wtcalled" ] || fail "a tmux-only home must never invoke the event wait path"
grep -q 'SLEEP' "$SLEEP_LOG" || fail "a tmux-only home must sleep POLL exactly as before"
pass "event_wait_or_sleep: a home with no push-capable window is inert (sleeps POLL, never touches the event path)"

# --- event_wait_or_sleep: runtime failures disable the event path (fail-closed)

reset_state
fm_write_meta "$STATE_DIR/tk5.meta" "window=default:wG:pQ" "backend=herdr" "kind=ship"
export EVENT_CAP_FAIL_MAX=2
# shellcheck disable=SC2329 # Runtime overrides called by the isolated watcher.
fm_backend_events_capable() { return 0; }
# shellcheck disable=SC2329 # Runtime overrides called by the isolated watcher.
fm_backend_wait_transition() { printf 'WT\n' >> "$TMP/wtcalls"; return 2; }
: > "$TMP/wtcalls"
event_wait_or_sleep   # fails=1
event_wait_or_sleep   # fails=2 -> disable
event_wait_or_sleep   # disabled: sleeps without calling wait_transition
WTN=$(wc -l < "$TMP/wtcalls" | tr -d '[:space:]')
[ "$WTN" = 2 ] || fail "after EVENT_CAP_FAIL_MAX connect failures the event path must be disabled for the process (expected 2 wait_transition calls, got $WTN)"
pass "event_wait_or_sleep: consecutive event-path failures disable the fast-path and revert to pure polling (fail-closed)"

# --- wake_enqueue: a transient enqueue failure is non-fatal to supervision -----
# Root-cause fix for Quidge/firstmate#2: a wake-append blip under contention must
# not turn into a supervision-killing exit. wake_enqueue retries the recoverable
# failure and, if it clears, returns 0 without ever exiting the watcher.

reset_state
A_CALLS="$TMP/wake-enqueue-A-calls"
: > "$A_CALLS"
(
  fail_left=2
  # shellcheck disable=SC2329 # Runtime override consumed by the isolated watcher.
  fm_wake_append() {
    printf 'x\n' >> "$A_CALLS"
    if [ "$fail_left" -gt 0 ]; then fail_left=$((fail_left - 1)); return 1; fi
    return 0
  }
  FM_WAKE_APPEND_RETRIES=5 wake_enqueue signal task.status "signal: retry-then-succeed"
  printf 'rc=%s\n' "$?" > "$TMP/wake-enqueue-A-rc"
  printf 'survived\n' > "$TMP/wake-enqueue-A-survived"
)
[ -f "$TMP/wake-enqueue-A-survived" ] || fail "wake_enqueue exited the watcher on a transient enqueue failure"
grep -q 'rc=0' "$TMP/wake-enqueue-A-rc" || fail "wake_enqueue must return 0 once a transient failure clears (got $(cat "$TMP/wake-enqueue-A-rc" 2>/dev/null))"
A_ATTEMPTS=$(wc -l < "$A_CALLS" | tr -d '[:space:]')
[ "$A_ATTEMPTS" -eq 3 ] || fail "wake_enqueue must retry until success (expected 3 attempts, got $A_ATTEMPTS)"
pass "wake_enqueue retries a transient enqueue failure and succeeds without tearing supervision down"

# --- wake_enqueue: a persistent transient failure defers, non-fatal + logged ---

reset_state
(
  # shellcheck disable=SC2329 # Runtime override consumed by the isolated watcher.
  fm_wake_append() { return 1; }
  FM_WAKE_APPEND_RETRIES=3 wake_enqueue stale default:wG:pQ "stale: default:wG:pQ"
  printf 'rc=%s\n' "$?" > "$TMP/wake-enqueue-B-rc"
  printf 'survived\n' > "$TMP/wake-enqueue-B-survived"
)
[ -f "$TMP/wake-enqueue-B-survived" ] || fail "wake_enqueue exited the watcher on a persistent transient failure"
grep -q 'rc=1' "$TMP/wake-enqueue-B-rc" || fail "wake_enqueue must return 1 (defer) on a persistent transient failure (got $(cat "$TMP/wake-enqueue-B-rc" 2>/dev/null))"
grep -q 'wake enqueue deferred' "$STATE_DIR/.watch-triage.log" 2>/dev/null || fail "a deferred enqueue must be recorded in the triage log"
pass "wake_enqueue defers non-fatally on a persistent transient failure and logs it, keeping supervision alive"

# --- wake_enqueue: an invalid wake kind is a code defect and stays fail-closed --

reset_state
(
  wake_enqueue bogus-kind k "payload" 2>/dev/null
  printf 'survived\n' > "$TMP/wake-enqueue-C-survived"
)
C_RC=$?
[ ! -f "$TMP/wake-enqueue-C-survived" ] || fail "wake_enqueue must fail closed (exit) on an invalid wake kind, not continue"
[ "$C_RC" -ne 0 ] || fail "wake_enqueue must exit non-zero on an invalid wake kind"
pass "wake_enqueue fails closed (loud non-zero exit) on an invalid wake kind - a genuine code defect stays fatal"

# --- watcher stale path: a deferred enqueue leaves the suppressor unadvanced ----
# Proves the loop-level regression: on a persistent enqueue failure the stale
# path neither kills the watcher nor advances .stale-*, so the same hash is
# re-detected and retried on the next poll instead of being silently swallowed.

reset_state
fm_write_meta "$STATE_DIR/tkstale.meta" "window=default:wS:pS" "kind=ship"
STALE_KEY=$(printf '%s' "default:wS:pS" | tr ':/.' '___')
rm -f "$STATE_DIR/.stale-$STALE_KEY"
(
  # shellcheck disable=SC2329 # Runtime override consumed by the isolated watcher.
  fm_wake_append() { return 1; }
  FM_WAKE_APPEND_RETRIES=2 surface_nonterminal_stale "default:wS:pS" "hash-abc123"
  printf 'survived\n' > "$TMP/wake-enqueue-D-survived"
)
[ -f "$TMP/wake-enqueue-D-survived" ] || fail "surface_nonterminal_stale exited the watcher on a persistent enqueue failure"
[ ! -e "$STATE_DIR/.stale-$STALE_KEY" ] || fail "a deferred stale enqueue must NOT advance the .stale-* suppressor (so the next poll retries)"
pass "the stale path keeps its suppressor unadvanced and the watcher alive when the enqueue defers"

echo "# fm-supervision-events.test.sh: all assertions passed"
