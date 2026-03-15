#!/usr/bin/env bash
# Forge Studio renderer for the persistent status pane.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib/forge-common.sh
source "$SCRIPT_DIR/lib/forge-common.sh"

SESSION_DIR="${1:?Usage: tmux-render.sh <session-dir>}"
STATE_FILE="$SESSION_DIR/forge-state.json"
ACTIVITY_FILE="$SESSION_DIR/studio-activity.log"

[ -f "$STATE_FILE" ] || { echo "Waiting for forge-state.json..."; exit 0; }
bash "$SCRIPT_DIR/studio-activity.sh" "$SESSION_DIR" >/dev/null 2>&1 || true

if [ -t 1 ]; then
  clear
fi
export STATE_FILE ACTIVITY_FILE
python3 <<'PYEOF'
import json
import os
import sys
from pathlib import Path

try:
    with open(os.environ["STATE_FILE"], encoding="utf-8") as handle:
        state = json.load(handle)
except Exception:
    print("Waiting for forge-state.json...")
    sys.exit(0)

activity_lines = []
activity_path = Path(os.environ["ACTIVITY_FILE"])
if activity_path.is_file():
    activity_lines = [line.strip() for line in activity_path.read_text(encoding="utf-8").splitlines() if line.strip()]

session_id = state.get("session_id", "unknown")
tier = state.get("tier", "?")
phase = state.get("current_phase", "unknown")
project_type = state.get("project_type", "unknown")
checkpoint = state.get("checkpoint", "")
layout_mode = state.get("studio_layout_mode", "unknown")
studio_status = state.get("studio_status", "inactive")
request = state.get("user_request", "Forge session")[:60]
loop = state.get("build_review_loop", 0)
backtracks = state.get("total_backtracks", 0)
execution_mode = state.get("execution_mode")
if execution_mode not in {"prompt", "jira"}:
    execution_mode = "jira" if state.get("source") == "jira" else "prompt"
jira_key = state.get("jira_issue_key", "")
tokens = state.get("tokens_estimate", 0)

if execution_mode == "jira":
    if tier == 3:
        phases = ["jira_fetch", "confluence_enrich", "synthesize", "classify", "grill", "explore", "architect", "build", "review", "verify", "ship", "compound"]
    else:
        phases = ["jira_fetch", "confluence_enrich", "synthesize", "classify", "grill", "explore", "build", "review", "ship", "compound"]
else:
    phases = ["classify", "grill", "explore", "build", "review", "compound"] if tier != 3 else ["classify", "grill", "explore", "architect", "build", "review", "verify", "compound"]

history = {item.get("phase"): item for item in state.get("phase_history", [])}
agents = state.get("active_agents", [])
build_tasks = state.get("build_tasks", [])
ship_result = state.get("ship_result", {})
running_agents = [item for item in agents if item.get("status") not in {"complete", "failed", "cancelled"}]
completed_agents = [item for item in agents if item.get("status") == "complete"]

def fmt_phase_line(name):
    entry = history.get(name, {})
    if name == phase:
        return f"[>] {name.upper():<16} live"
    if entry.get("status") == "complete":
        conf = entry.get("confidence")
        suffix = f"{conf:.2f}" if isinstance(conf, (int, float)) else "done"
        return f"[x] {name.upper():<16} {suffix}"
    if entry.get("status") == "failed":
        return f"[!] {name.upper():<16} failed"
    return f"[ ] {name.upper():<16} waiting"

lines = []
lines.append("┌" + "─" * 74 + "┐")
header = f" Forge Studio v1.6.0: {session_id}"
header_right = f"entry={execution_mode} layout={layout_mode} status={studio_status}"
header_left_width = max(1, 74 - len(header_right))
header_left = header[:header_left_width].ljust(header_left_width)
lines.append(f"│{header_left}{header_right}│")
lines.append(f"│ Task: {request:<65}│")
if jira_key:
    lines.append(f"│ Jira: {jira_key:<65}│")
else:
    lines.append(f"│{' ':74}│")
lines.append(f"│ Tier: {tier}  Project: {project_type:<14} Phase: {phase:<14} │")
lines.append(f"│ Loop: {loop:<3} Backtracks: {backtracks:<3} Tokens: ~{tokens // 1000:<4}k Agents: {len(running_agents):<2}/{len(agents):<2} {' ':10}│")
lines.append("├" + "─" * 36 + "┬" + "─" * 37 + "┤")
right_header = "AGENT SWARM" if running_agents else "IDE HINTS"
lines.append(f"│ {'PIPELINE':<34} │ {right_header:<35} │")

hint_lines = []
if running_agents:
    for agent in running_agents[:4]:
        task = (agent.get("task") or "").strip()
        if task:
            hint_lines.append(f"{agent.get('name', '?')}: {task[:20]}")
        else:
            hint_lines.append(f"{agent.get('name', '?')}: {agent.get('status', 'idle')}")
    if completed_agents:
        hint_lines.append(f"completed agents: {len(completed_agents)}")
elif build_tasks:
    completed = sum(1 for item in build_tasks if item.get("status") == "complete")
    hint_lines.append(f"build tasks: {completed}/{len(build_tasks)} complete")

if execution_mode == "jira":
    artifact_map = [
        ("j", "jira-context.json"),
        ("o", "confluence-context.md"),
        ("r", "requirements.md"),
        ("p", "plan.md"),
        ("h", "ship-result.json"),
        ("i", "review-issues.json"),
        ("v", "verify-result.json"),
    ]
else:
    artifact_map = [
        ("r", "requirements.md"),
        ("p", "plan.md"),
        ("i", "review-issues.json"),
        ("d", "decisions"),
        ("l", "learnings"),
        ("e", "exploration"),
        ("v", "verify-result.json"),
    ]
for key, label in artifact_map:
    hint_lines.append(f"prefix+{key} {label}")

if checkpoint:
    hint_lines.append(f"checkpoint: {checkpoint[:28]}")
for line in activity_lines[:3]:
    hint_lines.append(line[:35])

while len(hint_lines) < len(phases):
    hint_lines.append("")

for idx, phase_name in enumerate(phases):
    left = fmt_phase_line(phase_name)
    right = hint_lines[idx] if idx < len(hint_lines) else ""
    lines.append(f"│ {left:<34} │ {right:<35} │")

lines.append("├" + "─" * 36 + "┴" + "─" * 37 + "┤")
git_line = " prefix+g git  prefix+s status  prefix+c main  prefix+m layout "
lines.append(f"│{git_line:<74}│")
if ship_result.get("pr_url"):
    pr_line = f" PR: {ship_result['pr_url']}"[:74]
    lines.append(f"│{pr_line:<74}│")
else:
    lines.append(f"│{' ':74}│")
lines.append("└" + "─" * 74 + "┘")
print("\n".join(lines))
PYEOF
