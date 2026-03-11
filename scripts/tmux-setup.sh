#!/usr/bin/env bash
# Forge: TMUX dashboard setup (Tier 3 only)
# Creates a status pane showing session progress with two-column layout.
# Usage: bash tmux-setup.sh <session-dir>

SESSION_DIR="${1:?Usage: tmux-setup.sh <session-dir>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PANE_ID_FILE="$SESSION_DIR/tmux-pane-id"

# Only works inside tmux
if [ -z "$TMUX" ]; then
  echo "Not in a tmux session. Skipping dashboard setup."
  exit 0
fi

SCRIPT_DIR_Q="$(printf '%q' "$SCRIPT_DIR")"
SESSION_DIR_Q="$(printf '%q' "$SESSION_DIR")"

# Create a bottom pane (16 lines) for the two-column dashboard
PANE_ID="$(
  tmux split-window -P -F '#{pane_id}' -v -l 16 \
    "FORGE_SCRIPT_DIR=$SCRIPT_DIR_Q FORGE_SESSION_DIR=$SESSION_DIR_Q bash -lc 'while true; do bash \"\$FORGE_SCRIPT_DIR/tmux-render.sh\" \"\$FORGE_SESSION_DIR\"; sleep 3; done'"
)"
tmux select-pane -t 0  # Return focus to main pane
printf '%s\n' "$PANE_ID" > "$PANE_ID_FILE"

echo "Forge dashboard started in bottom pane."
