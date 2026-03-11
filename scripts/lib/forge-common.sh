#!/usr/bin/env bash

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
