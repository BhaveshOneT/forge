#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib/forge-common.sh
source "$SCRIPT_DIR/lib/forge-common.sh"

SESSION_DIR="${1:?Usage: studio-help.sh <session-dir> [--print]}"
PRINT_ONLY="${2:-}"
STATE_FILE="$SESSION_DIR/forge-state.json"
HELP_FILE="$SESSION_DIR/studio-help.txt"
MODE="unknown"

if [ -f "$STATE_FILE" ]; then
  MODE="$(forge_json_get "$STATE_FILE" "data.get('studio_layout_mode', 'unknown')")"
fi

cat >"$HELP_FILE" <<EOF
Forge Studio
============

Mode: $MODE

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
EOF

if [ "$PRINT_ONLY" = "--print" ]; then
  cat "$HELP_FILE"
else
  printf '%s\n' "$HELP_FILE"
fi
