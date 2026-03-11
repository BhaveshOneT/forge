#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib/forge-common.sh
source "$SCRIPT_DIR/lib/forge-common.sh"

SESSION_DIR="${1:?Usage: studio-activity.sh <session-dir>}"
STATE_FILE="$SESSION_DIR/forge-state.json"
ACTIVITY_FILE="$SESSION_DIR/studio-activity.log"

[ -f "$STATE_FILE" ] || {
  printf 'Waiting for forge-state.json...\n' | tee "$ACTIVITY_FILE"
  exit 0
}

PHASE="$(forge_json_get "$STATE_FILE" "data.get('current_phase', 'unknown')")"
CHECKPOINT="$(forge_json_get "$STATE_FILE" "data.get('checkpoint', 'No checkpoint yet')")"
LAYOUT_MODE="$(forge_json_get "$STATE_FILE" "data.get('studio_layout_mode', 'unknown')")"
TIER="$(forge_json_get "$STATE_FILE" "data.get('tier', '?')")"
EXECUTION_MODE="$(forge_execution_mode_from_state "$STATE_FILE")"
SUMMARY_TARGET="none"
if [ "$EXECUTION_MODE" = "jira" ] && [ -f "$SESSION_DIR/jira-context.json" ]; then
  SUMMARY_TARGET="jira-context.json"
elif [ "$EXECUTION_MODE" = "jira" ] && [ -f "$SESSION_DIR/confluence-context.md" ]; then
  SUMMARY_TARGET="confluence-context.md"
elif [ "$EXECUTION_MODE" = "jira" ] && [ -f "$SESSION_DIR/ship-result.json" ]; then
  SUMMARY_TARGET="ship-result.json"
elif [ -f "$SESSION_DIR/review-issues.json" ]; then
  SUMMARY_TARGET="review-issues.json"
elif [ -f "$SESSION_DIR/plan.md" ]; then
  SUMMARY_TARGET="plan.md"
elif [ -f "$SESSION_DIR/requirements.md" ]; then
  SUMMARY_TARGET="requirements.md"
fi

cat >"$ACTIVITY_FILE" <<EOF
$(forge_iso_timestamp) phase=$PHASE tier=$TIER mode=$EXECUTION_MODE layout=$LAYOUT_MODE
checkpoint: $CHECKPOINT
artifact: $SUMMARY_TARGET
EOF

cat "$ACTIVITY_FILE"
