#!/usr/bin/env bash
# Forge Studio entrypoint.
# Creates or attaches to a dedicated tmux workspace for the Forge session.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib/forge-common.sh
source "$SCRIPT_DIR/lib/forge-common.sh"

SESSION_DIR="${1:?Usage: tmux-setup.sh <session-dir>}"
STATE_FILE="$SESSION_DIR/forge-state.json"

[ -f "$STATE_FILE" ] || {
  echo "Missing forge-state.json in $SESSION_DIR" >&2
  exit 1
}

bash "$SCRIPT_DIR/studio-check-deps.sh" >/dev/null

PROJECT_DIR="$(forge_json_get "$STATE_FILE" "data.get('project_dir', '')")"
TIER="$(forge_json_get "$STATE_FILE" "data.get('tier', 1)")"
MODE="$(forge_studio_mode_for_tier "$TIER")"
WORKSPACE_DIR="$(forge_resolve_workspace_dir "$PROJECT_DIR" "$SESSION_DIR")"
SESSION_NAME="$(bash "$SCRIPT_DIR/studio-session.sh" create "$SESSION_DIR" "$WORKSPACE_DIR")"

forge_update_json_file "$STATE_FILE" "
if data.get('execution_mode') not in ('prompt', 'jira'):
    data['execution_mode'] = 'jira' if data.get('source') == 'jira' else 'prompt'
data['studio_enabled'] = True
data['studio_session_name'] = '$SESSION_NAME'
data['studio_layout_mode'] = '$MODE'
data['studio_status'] = 'starting'
data['studio_workspace_ready'] = False
data['studio_persistent'] = True
data['studio_last_focus'] = 'main'
if 'studio_created_at' not in data:
    data['studio_created_at'] = '$(forge_iso_timestamp)'
"

bash "$SCRIPT_DIR/studio-help.sh" "$SESSION_DIR" >/dev/null
bash "$SCRIPT_DIR/studio-activity.sh" "$SESSION_DIR" >/dev/null
bash "$SCRIPT_DIR/studio-layout.sh" apply "$SESSION_DIR" "$MODE" "$WORKSPACE_DIR" >/dev/null

echo "Forge Studio ready: $SESSION_NAME"
bash "$SCRIPT_DIR/studio-session.sh" attach "$SESSION_DIR"
