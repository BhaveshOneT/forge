#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=./lib/forge-common.sh
source "$SCRIPT_DIR/lib/forge-common.sh"

COMMAND="${1:?Usage: studio-layout.sh <apply|refresh|toggle> <session-dir> [mode] [project-dir]}"
SESSION_DIR="${2:?Usage: studio-layout.sh <apply|refresh|toggle> <session-dir> [mode] [project-dir]}"
LAYOUT_FILE="$SESSION_DIR/studio-layout.json"
STATE_FILE="$SESSION_DIR/forge-state.json"

apply_bindings() {
  tmux bind-key g if-shell -F '#{==:#{@forge_studio},true}' "run-shell 'bash \"$SCRIPT_DIR/studio-session.sh\" focus-current git'" ""
  tmux bind-key s if-shell -F '#{==:#{@forge_studio},true}' "run-shell 'bash \"$SCRIPT_DIR/studio-session.sh\" focus-current status'" ""
  tmux bind-key c if-shell -F '#{==:#{@forge_studio},true}' "run-shell 'bash \"$SCRIPT_DIR/studio-session.sh\" focus-current main'" ""
  tmux bind-key r if-shell -F '#{==:#{@forge_studio},true}' "run-shell 'bash \"$SCRIPT_DIR/studio-popup.sh\" open \"#{@forge_session_dir}\" requirements'" ""
  tmux bind-key p if-shell -F '#{==:#{@forge_studio},true}' "run-shell 'bash \"$SCRIPT_DIR/studio-popup.sh\" open \"#{@forge_session_dir}\" plan'" ""
  tmux bind-key i if-shell -F '#{==:#{@forge_studio},true}' "run-shell 'bash \"$SCRIPT_DIR/studio-popup.sh\" open \"#{@forge_session_dir}\" issues'" ""
  tmux bind-key d if-shell -F '#{==:#{@forge_studio},true}' "run-shell 'bash \"$SCRIPT_DIR/studio-popup.sh\" open \"#{@forge_session_dir}\" decisions'" ""
  tmux bind-key l if-shell -F '#{==:#{@forge_studio},true}' "run-shell 'bash \"$SCRIPT_DIR/studio-popup.sh\" open \"#{@forge_session_dir}\" learnings'" ""
  tmux bind-key e if-shell -F '#{==:#{@forge_studio},true}' "run-shell 'bash \"$SCRIPT_DIR/studio-popup.sh\" open \"#{@forge_session_dir}\" exploration'" ""
  tmux bind-key v if-shell -F '#{==:#{@forge_studio},true}' "run-shell 'bash \"$SCRIPT_DIR/studio-popup.sh\" open \"#{@forge_session_dir}\" verify'" ""
  tmux bind-key j if-shell -F '#{==:#{@forge_studio},true}' "run-shell 'bash \"$SCRIPT_DIR/studio-popup.sh\" open \"#{@forge_session_dir}\" jira-context'" ""
  tmux bind-key o if-shell -F '#{==:#{@forge_studio},true}' "run-shell 'bash \"$SCRIPT_DIR/studio-popup.sh\" open \"#{@forge_session_dir}\" confluence'" ""
  tmux bind-key h if-shell -F '#{==:#{@forge_studio},true}' "run-shell 'bash \"$SCRIPT_DIR/studio-popup.sh\" open \"#{@forge_session_dir}\" ship'" ""
  tmux bind-key \? if-shell -F '#{==:#{@forge_studio},true}' "run-shell 'bash \"$SCRIPT_DIR/studio-popup.sh\" open \"#{@forge_session_dir}\" help'" ""
  tmux bind-key m if-shell -F '#{==:#{@forge_studio},true}' "run-shell 'bash \"$SCRIPT_DIR/studio-layout.sh\" toggle \"#{@forge_session_dir}\"'" ""
}

start_pane_program() {
  local pane_id="${1:?pane id required}"
  local command_text="${2:?command text required}"
  tmux respawn-pane -k -t "$pane_id" "bash -lc $(printf '%q' "$command_text")"
}

active_agent_specs() {
  local mode="${1:?mode required}"
  python3 - "$STATE_FILE" "$mode" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    state = json.load(handle)

mode = sys.argv[2]
max_agents = 0
if mode == "build":
    max_agents = 1
elif mode == "swarm":
    max_agents = 4

running = []
for agent in state.get("active_agents", []):
    if agent.get("status") in {"complete", "failed", "cancelled"}:
        continue
    running.append(agent)

for agent in running[:max_agents]:
    agent_id = (agent.get("id") or "").replace("\t", " ")
    name = (agent.get("name") or agent_id or "agent").replace("\t", " ")
    print(f"{agent_id}\t{name}")
PY
}

create_agent_panes() {
  local session_name="${1:?session name required}"
  local mode="${2:?mode required}"
  local workspace_dir="${3:?workspace dir required}"
  local git_pane="${4:?git pane required}"
  local -a agent_specs=()
  local -a agent_panes=()
  local current_target pane_id agent_id agent_name

  while IFS= read -r line; do
    [ -n "$line" ] && agent_specs+=("$line")
  done < <(active_agent_specs "$mode")
  [ "${#agent_specs[@]}" -gt 0 ] || return 0

  pane_id="$(tmux split-window -P -F '#{pane_id}' -v -p 68 -t "$git_pane" -c "$workspace_dir")"
  agent_panes+=("$pane_id")
  current_target="$pane_id"

  local idx
  for ((idx = 1; idx < ${#agent_specs[@]}; idx++)); do
    pane_id="$(tmux split-window -P -F '#{pane_id}' -v -p 50 -t "$current_target" -c "$workspace_dir")"
    agent_panes+=("$pane_id")
    current_target="$pane_id"
  done

  local agent_metadata="[]"
  for idx in "${!agent_specs[@]}"; do
    agent_id="${agent_specs[$idx]%%$'\t'*}"
    agent_name="${agent_specs[$idx]#*$'\t'}"
    tmux select-pane -t "${agent_panes[$idx]}" -T "Forge Agent: $agent_name"
    start_pane_program "${agent_panes[$idx]}" "\"$SCRIPT_DIR/studio-agent-pane.sh\" \"$SESSION_DIR\" \"$agent_id\""
    agent_metadata="$(python3 - "$agent_metadata" "$agent_id" "${agent_panes[$idx]}" "$agent_name" <<'PY'
import json
import sys

items = json.loads(sys.argv[1])
items.append({
    "agent_id": sys.argv[2],
    "pane_id": sys.argv[3],
    "title": sys.argv[4],
})
print(json.dumps(items))
PY
)"
  done

  printf '%s\n' "$agent_metadata"
}

apply_layout() {
  local mode="${1:?mode required}"
  local project_dir="${2:?project dir required}"
  local session_name="${3:?session name required}"
  local tier="${4:?tier required}"
  local workspace_dir
  local right_percent=30
  local bottom_lines=14

  workspace_dir="$(forge_resolve_workspace_dir "$project_dir" "$SESSION_DIR")"

  case "$mode" in
    focus)
      right_percent=24
      bottom_lines=12
      ;;
    build)
      right_percent=30
      bottom_lines=14
      ;;
    swarm)
      right_percent=34
      bottom_lines=16
      ;;
    *)
      echo "Unsupported layout mode '$mode'" >&2
      exit 1
      ;;
  esac

  local panes
  panes="$(tmux list-panes -t "$session_name:0" -F '#{pane_id}')"
  local main_pane
  main_pane="$(printf '%s\n' "$panes" | head -n1)"
  printf '%s\n' "$panes" | tail -n +2 | while read -r extra_pane; do
    [ -n "$extra_pane" ] && tmux kill-pane -t "$extra_pane"
  done

  tmux select-pane -t "$main_pane" -T "Forge Studio: Claude"
  tmux send-keys -t "$main_pane" C-l
  local git_pane
  git_pane="$(tmux split-window -P -F '#{pane_id}' -h -p "$right_percent" -t "$main_pane" -c "$workspace_dir")"
  local status_pane
  status_pane="$(tmux split-window -P -F '#{pane_id}' -v -l "$bottom_lines" -t "$main_pane" -c "$workspace_dir")"
  local agent_metadata="[]"

  tmux select-pane -t "$main_pane" -T "Forge Studio: Claude"
  tmux select-pane -t "$git_pane" -T "Forge Studio: Git"
  tmux select-pane -t "$status_pane" -T "Forge Studio: Status"

  start_pane_program "$git_pane" "\"$SCRIPT_DIR/studio-git-pane.sh\" \"$SESSION_DIR\""
  start_pane_program "$status_pane" "while true; do bash \"$SCRIPT_DIR/tmux-render.sh\" \"$SESSION_DIR\"; sleep 2; done"
  agent_metadata="$(create_agent_panes "$session_name" "$mode" "$workspace_dir" "$git_pane" || true)"
  [ -n "$agent_metadata" ] || agent_metadata="[]"
  tmux select-pane -t "$main_pane"

  forge_tmux_set_option "$session_name" "@forge_layout_mode" "$mode"
  forge_tmux_set_option "$session_name" "@forge_pane_main" "$main_pane"
  forge_tmux_set_option "$session_name" "@forge_pane_git" "$git_pane"
  forge_tmux_set_option "$session_name" "@forge_pane_status" "$status_pane"
  forge_tmux_set_option "$session_name" "@forge_tier" "$tier"
  apply_bindings

  LAYOUT_JSON="$(python3 - "$session_name" "$mode" "$workspace_dir" "$main_pane" "$git_pane" "$status_pane" <<'PY'
import json
import sys

payload = {
    "session_name": sys.argv[1],
    "layout_mode": sys.argv[2],
    "project_dir": sys.argv[3],
    "panes": {
        "main": sys.argv[4],
        "git": sys.argv[5],
        "status": sys.argv[6],
    },
}
print(json.dumps(payload))
PY
)"
  LAYOUT_JSON="$(python3 - "$LAYOUT_JSON" "$agent_metadata" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
payload["agent_panes"] = json.loads(sys.argv[2])
print(json.dumps(payload))
PY
)"
  forge_write_json "$LAYOUT_FILE" "$LAYOUT_JSON"
  bash "$SCRIPT_DIR/validate-json.sh" "$ROOT_DIR/schemas/studio-layout.schema.json" "$LAYOUT_FILE" >/dev/null

  forge_update_json_file "$STATE_FILE" "
if data.get('execution_mode') not in ('prompt', 'jira'):
    data['execution_mode'] = 'jira' if data.get('source') == 'jira' else 'prompt'
data['studio_enabled'] = True
data['studio_session_name'] = '$session_name'
data['studio_layout_mode'] = '$mode'
data['studio_status'] = 'active'
data['studio_panes'] = {'main': '$main_pane', 'git': '$git_pane', 'status': '$status_pane'}
data['studio_workspace_ready'] = True
if 'studio_created_at' not in data:
    data['studio_created_at'] = '$(forge_iso_timestamp)'
data['studio_persistent'] = True
data.setdefault('studio_last_focus', 'main')
"
}

toggle_layout() {
  local session_name="${1:?session name required}"
  local current_mode next_mode
  current_mode="$(forge_tmux_option "$session_name" "@forge_layout_mode")"
  case "$current_mode" in
    focus) next_mode="build" ;;
    build) next_mode="swarm" ;;
    *) next_mode="focus" ;;
  esac
  printf '%s\n' "$next_mode"
}

bash "$SCRIPT_DIR/studio-check-deps.sh" >/dev/null
[ -f "$STATE_FILE" ] || {
  echo "Missing forge-state.json for Studio layout." >&2
  exit 1
}

SESSION_NAME="$(bash "$SCRIPT_DIR/studio-session.sh" name "$SESSION_DIR")"
PROJECT_DIR_DEFAULT="$(forge_json_get "$STATE_FILE" "data.get('project_dir', '')")"
TIER="$(forge_json_get "$STATE_FILE" "data.get('tier', 1)")"

case "$COMMAND" in
  apply)
    MODE="${3:?Usage: studio-layout.sh apply <session-dir> <mode> [project-dir]}"
    PROJECT_DIR="${4:-$PROJECT_DIR_DEFAULT}"
    apply_layout "$MODE" "$PROJECT_DIR" "$SESSION_NAME" "$TIER"
    ;;
  refresh)
    MODE="${3:-$(forge_json_get "$STATE_FILE" "data.get('studio_layout_mode', 'focus')")}"
    PROJECT_DIR="${4:-$PROJECT_DIR_DEFAULT}"
    apply_layout "$MODE" "$PROJECT_DIR" "$SESSION_NAME" "$TIER"
    ;;
  toggle)
    MODE="$(toggle_layout "$SESSION_NAME")"
    PROJECT_DIR="${3:-$PROJECT_DIR_DEFAULT}"
    apply_layout "$MODE" "$PROJECT_DIR" "$SESSION_NAME" "$TIER"
    ;;
  *)
    echo "Unknown studio-layout command '$COMMAND'" >&2
    exit 1
    ;;
esac
