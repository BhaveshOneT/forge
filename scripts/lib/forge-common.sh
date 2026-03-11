#!/usr/bin/env bash

forge_repo_root() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  cd "$script_dir/.." && pwd
}

forge_json_get() {
  local file_path="${1:?file path required}"
  local expression="${2:?python expression required}"

  python3 - "$file_path" "$expression" <<'PY'
import json
import sys

file_path, expression = sys.argv[1], sys.argv[2]
with open(file_path, encoding="utf-8") as handle:
    data = json.load(handle)

value = eval(expression, {"__builtins__": {}}, {"data": data})
if value is None:
    sys.exit(1)

if isinstance(value, bool):
    print("true" if value else "false")
else:
    print(value)
PY
}

forge_latest_active_session() {
  local sessions_dir="${1:?sessions dir required}"

  python3 - "$sessions_dir" <<'PY'
import json
import pathlib
import sys

sessions_dir = pathlib.Path(sys.argv[1])
if not sessions_dir.exists():
    sys.exit(1)

candidates = []
for session_dir in sessions_dir.iterdir():
    if not session_dir.is_dir():
        continue

    state_file = session_dir / "forge-state.json"
    if not state_file.is_file():
        continue

    try:
        with state_file.open(encoding="utf-8") as handle:
            state = json.load(handle)
    except Exception:
        continue

    phase = state.get("current_phase")
    if not phase or phase == "complete":
        continue

    session_id = state.get("session_id") or session_dir.name
    candidates.append((session_id, session_dir))

if not candidates:
    sys.exit(1)

candidates.sort(key=lambda item: item[0], reverse=True)
print(candidates[0][1])
PY
}

forge_is_safe_identifier() {
  local identifier="${1:-}"

  [[ -n "$identifier" ]] &&
    [[ "$identifier" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] &&
    [[ "$identifier" != *".."* ]] &&
    [[ "$identifier" != */* ]]
}

forge_recent_excerpt() {
  local file_path="${1:?file path required}"
  local line_count="${2:-20}"

  python3 - "$file_path" "$line_count" <<'PY'
import pathlib
import re
import sys

file_path = pathlib.Path(sys.argv[1])
line_count = int(sys.argv[2])

if not file_path.is_file():
    print("(none)")
    sys.exit(0)

text = file_path.read_text(encoding="utf-8")
lines = [line for line in text.splitlines() if line.strip()]
excerpt = "\n".join(lines[-line_count:]) if lines else "(none)"
excerpt = re.sub(r"[^\x09\x0A\x0D\x20-\x7E]", "?", excerpt)
excerpt = excerpt.replace("```", "'''")
excerpt = excerpt[:2500] if excerpt else "(none)"
print(excerpt or "(none)")
PY
}

forge_write_json() {
  local file_path="${1:?file path required}"
  local json_payload="${2:?json payload required}"

  python3 - "$file_path" "$json_payload" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(sys.argv[2])
path.parent.mkdir(parents=True, exist_ok=True)
with path.open("w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
}

forge_update_json_file() {
  local file_path="${1:?file path required}"
  local python_update="${2:?python update required}"

  python3 - "$file_path" "$python_update" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
update = sys.argv[2]

if path.exists():
    with path.open(encoding="utf-8") as handle:
        data = json.load(handle)
else:
    data = {}

namespace = {"data": data}
exec(update, {"__builtins__": {}}, namespace)
data = namespace["data"]

path.parent.mkdir(parents=True, exist_ok=True)
with path.open("w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
}

forge_iso_timestamp() {
  python3 - <<'PY'
from datetime import datetime, timezone
print(datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"))
PY
}

forge_studio_mode_for_tier() {
  local tier="${1:?tier required}"

  case "$tier" in
    1) printf '%s\n' "focus" ;;
    2) printf '%s\n' "build" ;;
    3) printf '%s\n' "swarm" ;;
    *) return 1 ;;
  esac
}

forge_studio_session_name() {
  local session_id="${1:?session id required}"
  printf 'forge-%s\n' "$session_id"
}

forge_execution_mode_from_state() {
  local state_file="${1:?state file required}"

  python3 - "$state_file" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    data = json.load(handle)

mode = data.get("execution_mode")
if mode in {"prompt", "jira"}:
    print(mode)
    sys.exit(0)

if data.get("source") == "jira":
    print("jira")
else:
    print("prompt")
PY
}

forge_is_jira_mode() {
  local state_file="${1:?state file required}"
  [ "$(forge_execution_mode_from_state "$state_file")" = "jira" ]
}

forge_resolve_workspace_dir() {
  local requested_dir="${1:-}"
  local fallback_dir="${2:-}"

  if [ -n "$requested_dir" ] && [ -d "$requested_dir" ]; then
    printf '%s\n' "$requested_dir"
    return
  fi

  if [ -n "$fallback_dir" ] && [ -d "$fallback_dir" ]; then
    printf '%s\n' "$fallback_dir"
    return
  fi

  printf '%s\n' "$(forge_repo_root)"
}

forge_tmux_option() {
  local target="${1:?target required}"
  local option_name="${2:?option name required}"
  tmux show-option -t "$target" -qv "$option_name"
}

forge_tmux_set_option() {
  local target="${1:?target required}"
  local option_name="${2:?option name required}"
  local option_value="${3:?option value required}"
  tmux set-option -t "$target" -q "$option_name" "$option_value"
}

forge_escape_shell_arg() {
  printf '%q' "${1:-}"
}

forge_has_tty() {
  [ -t 0 ] && [ -t 1 ]
}

forge_find_git_root() {
  local path="${1:-}"

  while [ -n "$path" ] && [ "$path" != "/" ]; do
    if git -C "$path" rev-parse --show-toplevel >/dev/null 2>&1; then
      git -C "$path" rev-parse --show-toplevel
      return 0
    fi
    path="$(dirname "$path")"
  done

  return 1
}
