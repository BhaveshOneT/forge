#!/usr/bin/env bash

set -euo pipefail

SESSION_DIR="${1:?Usage: studio-agent-pane.sh <session-dir> <agent-id>}"
AGENT_ID="${2:?Usage: studio-agent-pane.sh <session-dir> <agent-id>}"
STATE_FILE="$SESSION_DIR/forge-state.json"
LOG_FILE="$SESSION_DIR/agents/$AGENT_ID.log"

[ -f "$STATE_FILE" ] || {
  echo "Waiting for forge-state.json..."
  sleep 3600
  exit 0
}

export STATE_FILE LOG_FILE AGENT_ID
while true; do
  if [ -t 1 ]; then
    clear
  fi
  python3 <<'PY'
import json
import os
from pathlib import Path

state_path = Path(os.environ["STATE_FILE"])
log_path = Path(os.environ["LOG_FILE"])
agent_id = os.environ["AGENT_ID"]

try:
    state = json.loads(state_path.read_text(encoding="utf-8"))
except Exception:
    print("Waiting for forge-state.json...")
    raise SystemExit(0)

agent = None
for item in state.get("active_agents", []):
    if item.get("id") == agent_id:
        agent = item
        break

if not agent:
    print("Forge Agent Pane")
    print("================")
    print()
    print(f"Agent {agent_id} is not registered.")
    raise SystemExit(0)

lines = []
if log_path.is_file():
    raw = log_path.read_text(encoding="utf-8").splitlines()
    lines = raw[-18:]

print("Forge Agent Pane")
print("================")
print()
print(f"Name:   {agent.get('name', agent_id)}")
print(f"Role:   {agent.get('role', 'unknown')}")
print(f"Kind:   {agent.get('kind', 'subagent')}")
print(f"Status: {agent.get('status', 'unknown')}")
task = agent.get("task") or "(no task summary)"
print(f"Task:   {task}")
print()
print("Recent activity")
print("---------------")
if lines:
    for line in lines:
        print(line)
else:
    print("Waiting for agent progress notes...")
PY
  sleep 2
done
