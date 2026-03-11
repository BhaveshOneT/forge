#!/usr/bin/env bash
# Forge Studio explicit teardown.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib/forge-common.sh
source "$SCRIPT_DIR/lib/forge-common.sh"

SESSION_DIR="${1:?Usage: tmux-teardown.sh <session-dir>}"
STATE_FILE="$SESSION_DIR/forge-state.json"

[ -f "$STATE_FILE" ] || {
  echo "Missing forge-state.json in $SESSION_DIR" >&2
  exit 1
}

SESSION_NAME="$(bash "$SCRIPT_DIR/studio-session.sh" name "$SESSION_DIR")"
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  bash "$SCRIPT_DIR/studio-session.sh" destroy "$SESSION_DIR"
fi

forge_update_json_file "$STATE_FILE" "
data['studio_status'] = 'complete'
data['studio_workspace_ready'] = False
"

rm -f "$SESSION_DIR/studio-layout.json" "$SESSION_DIR/studio-help.txt" "$SESSION_DIR/studio-activity.log"
echo "Forge Studio destroyed: $SESSION_NAME"
