#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=./lib/forge-common.sh
source "$SCRIPT_DIR/lib/forge-common.sh"

COMMAND="${1:?Usage: studio-layout.sh <apply|toggle> <session-dir> [mode] [project-dir]}"
SESSION_DIR="${2:?Usage: studio-layout.sh <apply|toggle> <session-dir> [mode] [project-dir]}"
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

  tmux select-pane -t "$main_pane" -T "Forge Studio: Claude"
  tmux select-pane -t "$git_pane" -T "Forge Studio: Git"
  tmux select-pane -t "$status_pane" -T "Forge Studio: Status"

  start_pane_program "$git_pane" "\"$SCRIPT_DIR/studio-git-pane.sh\" \"$SESSION_DIR\""
  start_pane_program "$status_pane" "while true; do bash \"$SCRIPT_DIR/tmux-render.sh\" \"$SESSION_DIR\"; sleep 2; done"
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
