#!/usr/bin/env bash
# Forge: Session-level git worktree teardown
# Removes worktree after session. Keeps branch if a PR exists, deletes if not.
# Usage: worktree-teardown.sh <session-id> [--force]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib/forge-common.sh
source "$SCRIPT_DIR/lib/forge-common.sh"

SESSION_ID="${1:?Usage: worktree-teardown.sh <session-id> [--force]}"
FORCE="${2:-}"

if ! forge_is_safe_identifier "$SESSION_ID"; then
  echo "ERROR: Refusing to use unsafe session id '$SESSION_ID'" >&2
  exit 1
fi

WORKTREE_BASE="$HOME/.claude/forge/worktrees"
WORKTREE_PATH="$HOME/.claude/forge/worktrees/$SESSION_ID"

# Nothing to do if worktree doesn't exist
if [ ! -d "$WORKTREE_PATH" ]; then
  echo "Worktree already removed: $WORKTREE_PATH"
  exit 0
fi

# Get the branch name before removing
BRANCH_NAME=$(git -C "$WORKTREE_PATH" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
COMMON_GIT_DIR="$(git -C "$WORKTREE_PATH" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
[ -n "$COMMON_GIT_DIR" ] || {
  echo "ERROR: Failed to determine the repository for $WORKTREE_PATH" >&2
  exit 1
}
REPO_DIR="$(cd "$COMMON_GIT_DIR/.." && pwd -P)"

# Remove the worktree
if [ "$FORCE" = "--force" ]; then
  git -C "$REPO_DIR" worktree remove --force "$WORKTREE_PATH"
else
  git -C "$REPO_DIR" worktree remove "$WORKTREE_PATH" 2>/dev/null || {
    echo "WARN: Clean remove failed, forcing..." >&2
    git -C "$REPO_DIR" worktree remove --force "$WORKTREE_PATH"
  }
fi

# Prune stale worktree entries
git -C "$REPO_DIR" worktree prune 2>/dev/null || true

# Check if a PR exists for this branch — if not, delete the branch
if [ -n "$BRANCH_NAME" ] && [ "$BRANCH_NAME" != "HEAD" ]; then
  if command -v gh >/dev/null 2>&1; then
    PR_COUNT=$(
      (
        cd "$REPO_DIR"
        gh pr list --head "$BRANCH_NAME" --json number --jq 'length'
      ) 2>/dev/null || echo "0"
    )
    if [ "$PR_COUNT" = "0" ]; then
      git -C "$REPO_DIR" branch -D "$BRANCH_NAME" 2>/dev/null &&
        echo "Deleted branch: $BRANCH_NAME (no PR)" || true
    else
      echo "Kept branch: $BRANCH_NAME (PR exists)"
    fi
  else
    echo "Kept branch: $BRANCH_NAME (gh CLI not available to check PRs)"
  fi
fi

echo "OK"
