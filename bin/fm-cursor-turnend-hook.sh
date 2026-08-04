#!/usr/bin/env bash
# Install or remove Firstmate's guarded cursor-agent crew turn-end + busy hook.
#
# This command is the sole owner of the edit to $HOME/.cursor/hooks.json. That
# file is JSON, so it carries no comment markers the way Kimi's TOML region does;
# Firstmate's entries are instead identified structurally, by a command that runs
# the Firstmate-owned hook script fm-cursor-turnend.sh. install validates the
# existing hooks.json (a regular non-symlink file holding a JSON object), adds or
# replaces exactly one Firstmate entry for beforeSubmitPrompt (busy) and one for
# stop (turn-end/idle), and preserves every foreign hook and top-level key.
# remove excises only Firstmate's entries. A missing, malformed, symlinked, or
# non-object hooks.json is refused without a write. Writes are atomic and skipped
# when the serialized result is byte-identical, so a repeat install is a no-op.
#
# The installed hook always exits 0 and stays silent. Because user hooks run from
# $HOME/.cursor (NOT the worktree), it reads the task worktree from the payload's
# workspace_roots[], not cwd: it looks for a .fm-cursor-turnend pointer in one of
# those roots, and only when the pointer names a Firstmate-created token in
# $HOME/.cursor/fm-turn-end.d/ does it write the task's busy/idle event through
# fm-busy-event.sh and touch its turn-end marker. It dedupes stop by
# generation_id, because an interrupted cursor turn fires stop twice (aborted
# then error) for one generation.
#
# Usage:
#   fm-cursor-turnend-hook.sh install
#   fm-cursor-turnend-hook.sh remove
set -u

case "${1:-}" in
  install|remove) ACTION=$1 ;;
  -h|--help)
    sed -n '2,32{s/^# \{0,1\}//;p;}' "$0"
    exit 0
    ;;
  *)
    printf 'usage: %s install|remove\n' "${0##*/}" >&2
    exit 2
    ;;
esac

if [ -z "${HOME:-}" ]; then
  printf 'fm-cursor-turnend-hook: refused: HOME is unset.\n' >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  printf 'fm-cursor-turnend-hook: refused: python3 is required to edit hooks.json.\n' >&2
  exit 1
fi
if [ "$ACTION" = install ] && ! command -v jq >/dev/null 2>&1; then
  printf 'fm-cursor-turnend-hook: refused: jq is required by the installed cursor turn-end hook.\n' >&2
  exit 1
fi

python3 - "$ACTION" "$HOME/.cursor" <<'PY'
import json
import os
import shutil
import stat
import sys
import tempfile

ACTION = sys.argv[1]
CONFIG_DIR = sys.argv[2]
CONFIG = os.path.join(CONFIG_DIR, "hooks.json")
HOOK = os.path.join(CONFIG_DIR, "fm-cursor-turnend.sh")
REGISTRY = os.path.join(CONFIG_DIR, "fm-turn-end.d")
EVENTS = ("beforeSubmitPrompt", "stop")
# The structural identity of a Firstmate entry: its command runs this script.
HOOK_NAME = "fm-cursor-turnend.sh"

HOOK_BYTES = b'''#!/usr/bin/env bash
# Firstmate cursor turn-end + busy hook. Managed by fm-cursor-turnend-hook.sh.
# Deliberately passive: every path is silent and exits zero. Guarded per task by
# a .fm-cursor-turnend pointer in one of the payload's workspace_roots and a
# matching token in $HOME/.cursor/fm-turn-end.d/. stop is deduped by
# generation_id to absorb cursor's interrupt double-fire (aborted then error).
set +e
exec >/dev/null 2>&1
payload=
IFS= read -r payload || [ -n "$payload" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0
[ -n "${HOME:-}" ] || exit 0
event=$(printf '%s' "$payload" | jq -er '.hook_event_name | strings' 2>/dev/null) || exit 0
case "$event" in beforeSubmitPrompt|stop) : ;; *) exit 0 ;; esac
roots=$(printf '%s' "$payload" | jq -r '.workspace_roots[]? | strings' 2>/dev/null) || exit 0
pointer=
while IFS= read -r root; do
  [ -n "$root" ] || continue
  case "$root" in /*) : ;; *) continue ;; esac
  if [ -f "$root/.fm-cursor-turnend" ]; then pointer="$root/.fm-cursor-turnend"; break; fi
done <<ROOTS
$roots
ROOTS
[ -n "$pointer" ] || exit 0
first=
IFS= read -r -n 256 first < "$pointer" 2>/dev/null || [ -n "$first" ] || exit 0
case "$first" in token=*) token=${first#token=} ;; *) exit 0 ;; esac
case "$token" in fm.????????????) : ;; *) exit 0 ;; esac
case "$token" in *[!A-Za-z0-9._-]*) exit 0 ;; esac
reg="$HOME/.cursor/fm-turn-end.d/$token"
[ -f "$reg" ] || exit 0
turnend= statedir= taskid= gen= busyevent=
while IFS= read -r line; do
  case "$line" in
    turnend=*) turnend=${line#turnend=} ;;
    statedir=*) statedir=${line#statedir=} ;;
    id=*) taskid=${line#id=} ;;
    gen=*) gen=${line#gen=} ;;
    busyevent=*) busyevent=${line#busyevent=} ;;
  esac
done < "$reg"
case "$turnend" in /*.turn-ended) : ;; *) turnend= ;; esac
case "$statedir" in /*) : ;; *) statedir= ;; esac
case "$busyevent" in /*fm-busy-event.sh) : ;; *) busyevent= ;; esac
case "$gen" in ''|*[!A-Za-z0-9._-]*) gen= ;; esac
case "$taskid" in ''|*[!A-Za-z0-9._-]*) taskid= ;; esac
apply_busy() {  # <state> <event-token>
  [ -n "$busyevent" ] && [ -n "$statedir" ] && [ -n "$taskid" ] && [ -n "$gen" ] || return 0
  [ -x "$busyevent" ] || return 0
  "$busyevent" apply "$statedir" "$taskid" "$1" --gen "$gen" --source cursor-hook --event "$2" 2>/dev/null || true
}
case "$event" in
  beforeSubmitPrompt)
    apply_busy busy before-submit-prompt
    ;;
  stop)
    genid=$(printf '%s' "$payload" | jq -er '.generation_id | strings' 2>/dev/null) || genid=
    case "$genid" in *[!A-Za-z0-9._-]*) genid= ;; esac
    if [ -n "$genid" ]; then
      stops="$reg.stops"
      mkdir -p "$stops" 2>/dev/null || true
      mkdir "$stops/$genid" 2>/dev/null || exit 0
    fi
    [ -n "$turnend" ] && touch -- "$turnend" 2>/dev/null || true
    apply_busy idle stop
    ;;
esac
exit 0
'''


def refuse(reason):
    print(f"fm-cursor-turnend-hook: refused: {reason}", file=sys.stderr)
    raise SystemExit(1)


def regular_not_symlink(path, label):
    try:
        info = os.lstat(path)
    except FileNotFoundError:
        return None
    if stat.S_ISLNK(info.st_mode) or not stat.S_ISREG(info.st_mode):
        refuse(f"{label} is not a regular non-symlink file at {path}.")
    return info


def our_command():
    # A single-quoted absolute path is safe for the shell cursor runs the
    # command with, and stable across Firstmate homes because HOME is shared.
    quoted = "'" + HOOK.replace("'", "'\\''") + "'"
    return "bash " + quoted


def is_ours(entry):
    return (
        isinstance(entry, dict)
        and isinstance(entry.get("command"), str)
        and HOOK_NAME in entry["command"]
    )


def load_config():
    info = regular_not_symlink(CONFIG, "cursor hooks.json")
    if info is None:
        return None, {}
    with open(CONFIG, "rb") as stream:
        raw = stream.read()
    if raw.strip() == b"":
        return raw, {}
    try:
        parsed = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        refuse(f"hooks.json is not valid JSON: {error}.")
    if not isinstance(parsed, dict):
        refuse("hooks.json is not a JSON object.")
    hooks = parsed.get("hooks")
    if hooks is not None and not isinstance(hooks, dict):
        refuse("hooks.json has an unexpected non-object 'hooks' value.")
    for event in EVENTS:
        existing = (hooks or {}).get(event)
        if existing is not None and not isinstance(existing, list):
            refuse(f"hooks.json has an unexpected non-array '{event}' hook list.")
    return raw, parsed


def serialize(obj):
    return (json.dumps(obj, indent=2, sort_keys=True) + "\n").encode("utf-8")


def atomic_write(path, data, mode):
    fd, temporary = tempfile.mkstemp(prefix=f".{os.path.basename(path)}.", dir=os.path.dirname(path))
    try:
        os.fchmod(fd, mode)
        with os.fdopen(fd, "wb") as stream:
            fd = -1
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    except Exception:
        if fd >= 0:
            os.close(fd)
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise


def ensure_hook_script():
    existing = regular_not_symlink(HOOK, "Firstmate hook script")
    need_write = True
    if existing is not None:
        with open(HOOK, "rb") as stream:
            need_write = stream.read() != HOOK_BYTES
        if not need_write and stat.S_IMODE(existing.st_mode) != 0o700:
            need_write = True
    if need_write:
        atomic_write(HOOK, HOOK_BYTES, 0o700)


try:
    if not os.path.isdir(CONFIG_DIR) or os.path.islink(CONFIG_DIR):
        refuse(f"cursor config directory is missing or unexpected at {CONFIG_DIR}.")
    raw, parsed = load_config()

    if ACTION == "install":
        # Registry directory the installed hook resolves task tokens through.
        if os.path.lexists(REGISTRY):
            info = os.lstat(REGISTRY)
            if stat.S_ISLNK(info.st_mode) or not stat.S_ISDIR(info.st_mode):
                refuse(f"Firstmate registry is not a regular directory at {REGISTRY}.")
        os.makedirs(REGISTRY, mode=0o700, exist_ok=True)
        os.chmod(REGISTRY, 0o700)
        ensure_hook_script()

        candidate = dict(parsed)
        candidate.setdefault("version", 1)
        hooks = dict(candidate.get("hooks") or {})
        command = our_command()
        for event in EVENTS:
            kept = [e for e in list(hooks.get(event, [])) if not is_ours(e)]
            kept.append({"command": command, "type": "command"})
            hooks[event] = kept
        candidate["hooks"] = hooks
        data = serialize(candidate)
        mode = stat.S_IMODE(os.lstat(CONFIG).st_mode) if raw is not None else 0o644
        if raw != data:
            atomic_write(CONFIG, data, mode)
    else:
        if raw is not None:
            candidate = dict(parsed)
            hooks = dict(candidate.get("hooks") or {})
            for event in EVENTS:
                if event in hooks:
                    kept = [e for e in list(hooks.get(event, [])) if not is_ours(e)]
                    if kept:
                        hooks[event] = kept
                    else:
                        del hooks[event]
            candidate["hooks"] = hooks
            # If nothing but Firstmate's own scaffolding remains, remove the file
            # so a home Firstmate created is left as it was found (absent).
            leftover_keys = set(candidate.keys()) - {"version", "hooks"}
            if not hooks and not leftover_keys:
                os.unlink(CONFIG)
            else:
                data = serialize(candidate)
                if raw != data:
                    atomic_write(CONFIG, data, stat.S_IMODE(os.lstat(CONFIG).st_mode))
        if os.path.lexists(HOOK):
            regular_not_symlink(HOOK, "Firstmate hook script")
            os.unlink(HOOK)
        if os.path.lexists(REGISTRY):
            info = os.lstat(REGISTRY)
            if stat.S_ISLNK(info.st_mode) or not stat.S_ISDIR(info.st_mode):
                refuse(f"Firstmate registry is not a regular directory at {REGISTRY}.")
            shutil.rmtree(REGISTRY)
except OSError as error:
    refuse(f"filesystem operation failed: {error}.")
PY
