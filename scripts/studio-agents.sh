#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib/forge-common.sh
source "$SCRIPT_DIR/lib/forge-common.sh"

COMMAND="${1:?Usage: studio-agents.sh <register|note|complete|list> <session-dir> ...}"
SESSION_DIR="${2:?Usage: studio-agents.sh <register|note|complete|list> <session-dir> ...}"
STATE_FILE="$SESSION_DIR/forge-state.json"
AGENTS_DIR="$SESSION_DIR/agents"

[ -f "$STATE_FILE" ] || {
  echo "Missing forge-state.json in $SESSION_DIR" >&2
  exit 1
}

mkdir -p "$AGENTS_DIR"

refresh_layout_if_ready() {
  local session_name
  session_name="$(bash "$SCRIPT_DIR/studio-session.sh" name "$SESSION_DIR" 2>/dev/null || true)"
  if [ -n "$session_name" ] && tmux has-session -t "$session_name" 2>/dev/null; then
    bash "$SCRIPT_DIR/studio-layout.sh" refresh "$SESSION_DIR" >/dev/null 2>&1 || true
  fi
}

case "$COMMAND" in
  register)
    AGENT_ID="${3:?Usage: studio-agents.sh register <session-dir> <agent-id> <role> <name> <kind> [task]}"
    ROLE="${4:?Usage: studio-agents.sh register <session-dir> <agent-id> <role> <name> <kind> [task]}"
    NAME="${5:?Usage: studio-agents.sh register <session-dir> <agent-id> <role> <name> <kind> [task]}"
    KIND="${6:?Usage: studio-agents.sh register <session-dir> <agent-id> <role> <name> <kind> [task]}"
    TASK="${7:-}"
    LOG_FILE="$AGENTS_DIR/$AGENT_ID.log"
    : >"$LOG_FILE"
    {
      printf '[%s] %s registered (%s)\n' "$(forge_iso_timestamp)" "$NAME" "$ROLE"
      [ -n "$TASK" ] && printf '[%s] task: %s\n' "$(forge_iso_timestamp)" "$TASK"
    } >>"$LOG_FILE"
    AGENT_JSON="$(python3 - "$AGENT_ID" "$ROLE" "$NAME" "$KIND" "$TASK" "$LOG_FILE" "$(forge_iso_timestamp)" <<'PY'
import json
import sys

payload = {
    "id": sys.argv[1],
    "role": sys.argv[2],
    "name": sys.argv[3],
    "kind": sys.argv[4],
    "task": sys.argv[5],
    "status": "running",
    "log_file": sys.argv[6],
    "started_at": sys.argv[7],
}
print(json.dumps(payload))
PY
)"
    python3 - "$STATE_FILE" "$AGENT_JSON" <<'PY'
import json
import sys

state_path = sys.argv[1]
agent = json.loads(sys.argv[2])

with open(state_path, encoding="utf-8") as handle:
    state = json.load(handle)

agents = [item for item in state.get("active_agents", []) if item.get("id") != agent["id"]]
agents.append(agent)
state["active_agents"] = agents

with open(state_path, "w", encoding="utf-8") as handle:
    json.dump(state, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
    refresh_layout_if_ready
    printf '%s\n' "$LOG_FILE"
    ;;
  note)
    AGENT_ID="${3:?Usage: studio-agents.sh note <session-dir> <agent-id> <message>}"
    MESSAGE="${4:?Usage: studio-agents.sh note <session-dir> <agent-id> <message>}"
    LOG_FILE="$AGENTS_DIR/$AGENT_ID.log"
    printf '[%s] %s\n' "$(forge_iso_timestamp)" "$MESSAGE" >>"$LOG_FILE"
    ;;
  complete)
    AGENT_ID="${3:?Usage: studio-agents.sh complete <session-dir> <agent-id> <complete|failed|cancelled> [summary]}"
    STATUS="${4:?Usage: studio-agents.sh complete <session-dir> <agent-id> <complete|failed|cancelled> [summary]}"
    SUMMARY="${5:-}"
    LOG_FILE="$AGENTS_DIR/$AGENT_ID.log"
    [ -f "$LOG_FILE" ] || : >"$LOG_FILE"
    if [ -n "$SUMMARY" ]; then
      printf '[%s] %s\n' "$(forge_iso_timestamp)" "$SUMMARY" >>"$LOG_FILE"
    fi
    python3 - "$STATE_FILE" "$AGENT_ID" "$STATUS" "$(forge_iso_timestamp)" <<'PY'
import json
import sys

state_path, agent_id, status, finished_at = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
with open(state_path, encoding="utf-8") as handle:
    state = json.load(handle)

for agent in state.get("active_agents", []):
    if agent.get("id") == agent_id:
        agent["status"] = status
        agent["finished_at"] = finished_at
        break

with open(state_path, "w", encoding="utf-8") as handle:
    json.dump(state, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
    refresh_layout_if_ready
    ;;
  list)
    FILTER="${3:-all}"
    python3 - "$STATE_FILE" "$FILTER" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    state = json.load(handle)

agents = state.get("active_agents", [])
if sys.argv[2] == "active":
    agents = [item for item in agents if item.get("status") not in {"complete", "failed", "cancelled"}]
print(json.dumps(agents, indent=2))
PY
    ;;
  *)
    echo "Unknown command '$COMMAND'" >&2
    exit 1
    ;;
esac
