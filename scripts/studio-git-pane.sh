#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib/forge-common.sh
source "$SCRIPT_DIR/lib/forge-common.sh"

SESSION_DIR="${1:?Usage: studio-git-pane.sh <session-dir>}"
STATE_FILE="$SESSION_DIR/forge-state.json"
LAYOUT_FILE="$SESSION_DIR/studio-layout.json"

if [ ! -f "$STATE_FILE" ]; then
  printf 'Forge Studio git pane\n\nWaiting for forge-state.json...\n'
  sleep 3600
  exit 0
fi

resolve_git_workspace() {
  local worktree_path=""
  local project_dir=""
  local layout_project_dir=""
  local candidate=""
  local repo_root=""

  worktree_path="$(forge_json_get "$STATE_FILE" "data.get('worktree_path', '')" 2>/dev/null || true)"
  project_dir="$(forge_json_get "$STATE_FILE" "data.get('project_dir', '')" 2>/dev/null || true)"
  if [ -f "$LAYOUT_FILE" ]; then
    layout_project_dir="$(forge_json_get "$LAYOUT_FILE" "data.get('project_dir', '')" 2>/dev/null || true)"
  fi

  for candidate in "$worktree_path" "$project_dir" "$layout_project_dir"; do
    if [ -n "$candidate" ] && [ -d "$candidate" ]; then
      if repo_root="$(forge_find_git_root "$candidate" 2>/dev/null)"; then
        printf '%s\n' "$repo_root"
        return 0
      fi
    fi
  done

  return 1
}

while true; do
  if GIT_WORKSPACE="$(resolve_git_workspace 2>/dev/null)"; then
    cd "$GIT_WORKSPACE"
    exec lazygit
  fi

  PROJECT_DIR="$(forge_json_get "$STATE_FILE" "data.get('project_dir', '')" 2>/dev/null || true)"
  WORKTREE_PATH="$(forge_json_get "$STATE_FILE" "data.get('worktree_path', '')" 2>/dev/null || true)"
  clear
  cat <<EOF
Forge Studio Git Pane
=====================

Git view unavailable.
Current project directory is not a git repository:
${PROJECT_DIR:-"(unset)"}

Worktree path:
${WORKTREE_PATH:-"(unset)"}

This pane remains reserved for git/navigation.
EOF
  sleep 5
done
