#!/usr/bin/env bash
# Forge: TMUX dashboard teardown
# Kills the dashboard pane when the session completes.

set -euo pipefail

SESSION_DIR="${1:-}"
PANE_ID_FILE=""
PANE_ID=""

if [ -z "$TMUX" ]; then
  exit 0
fi

if [ -n "$SESSION_DIR" ]; then
  PANE_ID_FILE="$SESSION_DIR/tmux-pane-id"
  if [ -f "$PANE_ID_FILE" ]; then
    PANE_ID="$(tr -d '[:space:]' < "$PANE_ID_FILE")"
  fi
fi

if [ -z "$PANE_ID" ]; then
  SEARCH_PATTERN='tmux-render.sh'
  if [ -n "$SESSION_DIR" ]; then
    SEARCH_PATTERN="$SEARCH_PATTERN.*$SESSION_DIR"
  fi

  PANE_ID="$(
    tmux list-panes -a -F '#{pane_id} #{pane_start_command}' |
      awk -v pattern="$SEARCH_PATTERN" '$0 ~ pattern { print $1; exit }'
  )"
fi

if [ -n "$PANE_ID" ]; then
  tmux kill-pane -t "$PANE_ID" 2>/dev/null || true
fi

if [ -n "$PANE_ID_FILE" ] && [ -f "$PANE_ID_FILE" ]; then
  rm -f "$PANE_ID_FILE"
fi

echo "Forge dashboard stopped."
