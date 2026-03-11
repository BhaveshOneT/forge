#!/usr/bin/env bash
# Forge: TMUX dashboard setup (Tier 3 only)
# Creates a status pane showing session progress with two-column layout.
# Usage: bash tmux-setup.sh <session-dir>

SESSION_DIR="${1:?Usage: tmux-setup.sh <session-dir>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Only works inside tmux
if [ -z "$TMUX" ]; then
  echo "Not in a tmux session. Skipping dashboard setup."
  exit 0
fi

# Create a bottom pane (16 lines) for the two-column dashboard
tmux split-window -v -l 16 "bash -c 'while true; do bash \"$SCRIPT_DIR/tmux-render.sh\" \"$SESSION_DIR\"; sleep 3; done'"
tmux select-pane -t 0  # Return focus to main pane

echo "Forge dashboard started in bottom pane."
