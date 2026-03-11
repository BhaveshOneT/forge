#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib/forge-common.sh
source "$SCRIPT_DIR/lib/forge-common.sh"

SESSION_DIR="${1:?Usage: studio-help.sh <session-dir> [--print]}"
PRINT_ONLY="${2:-}"
STATE_FILE="$SESSION_DIR/forge-state.json"
HELP_FILE="$SESSION_DIR/studio-help.txt"
LAYOUT_MODE="unknown"
EXECUTION_MODE="prompt"

if [ -f "$STATE_FILE" ]; then
  LAYOUT_MODE="$(forge_json_get "$STATE_FILE" "data.get('studio_layout_mode', 'unknown')")"
  EXECUTION_MODE="$(forge_execution_mode_from_state "$STATE_FILE")"
fi

cat >"$HELP_FILE" <<EOF
Forge Studio
============

Execution mode: $EXECUTION_MODE
Layout mode: $LAYOUT_MODE

Keybindings (tmux prefix + key)
  g  Focus git pane
  s  Focus status pane
  c  Focus main Claude pane
  r  Open requirements popup
  p  Open plan popup
  i  Open review issues popup
  d  Open decisions popup
  l  Open loop learnings popup
  e  Open exploration popup
  v  Open verify popup
  m  Toggle layout mode
  ?  Open this help popup

Agent panes
  Tier 2 can show the current subagent in build mode
  Tier 3 swarm mode creates separate panes for active agents
  Agent panes follow the active_agents list in forge-state.json
EOF

if [ "$EXECUTION_MODE" = "jira" ]; then
  cat >>"$HELP_FILE" <<'EOF'
  j  Open Jira context popup
  o  Open Confluence context popup
  h  Open ship result popup

Jira mode artifacts
  jira-context.json
  confluence-context.md
  ship-result.json
EOF
else
  cat >>"$HELP_FILE" <<'EOF'

Prompt mode emphasis
  requirements.md
  plan.md
  context/decisions.md
  context/loop-learnings.md
  exploration.md
EOF
fi

if [ "$PRINT_ONLY" = "--print" ]; then
  cat "$HELP_FILE"
else
  printf '%s\n' "$HELP_FILE"
fi
