#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib/forge-common.sh
source "$SCRIPT_DIR/lib/forge-common.sh"

SESSION_DIR="${1:?Usage: studio-git-pane.sh <session-dir>}"
STATE_FILE="$SESSION_DIR/forge-state.json"

if [ ! -f "$STATE_FILE" ]; then
  printf 'Forge Studio git pane\n\nWaiting for forge-state.json...\n'
  sleep 3600
  exit 0
fi

PROJECT_DIR="$(forge_json_get "$STATE_FILE" "data.get('project_dir', '')")"

if [ -n "$PROJECT_DIR" ] && git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  cd "$PROJECT_DIR"
  exec lazygit
fi

while true; do
  clear
  cat <<EOF
Forge Studio Git Pane
=====================

Git view unavailable.
Current project directory is not a git repository:
${PROJECT_DIR:-"(unset)"}

This pane remains reserved for git/navigation.
EOF
  sleep 5
done
