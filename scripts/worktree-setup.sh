#!/usr/bin/env bash
# Forge: Session-level git worktree setup
# Creates an isolated worktree so all work happens off the main branch.
# Usage: worktree-setup.sh <session-id> <branch-name> <base-branch>

set -euo pipefail

SESSION_ID="${1:?Usage: worktree-setup.sh <session-id> <branch-name> <base-branch>}"
BRANCH_NAME="${2:?Usage: worktree-setup.sh <session-id> <branch-name> <base-branch>}"
BASE_BRANCH="${3:-main}"

WORKTREE_BASE="$HOME/.claude/forge/worktrees"
WORKTREE_PATH="$WORKTREE_BASE/$SESSION_ID"

# Ensure base directory exists
mkdir -p "$WORKTREE_BASE"

# Verify we're in a git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: Not inside a git repository" >&2
  exit 1
fi

# Ensure base branch exists locally
if ! git rev-parse --verify "$BASE_BRANCH" >/dev/null 2>&1; then
  echo "ERROR: Base branch '$BASE_BRANCH' does not exist" >&2
  exit 1
fi

# Create the worktree on a new branch from base
if git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME" "$BASE_BRANCH" 2>/dev/null; then
  echo "WORKTREE_PATH=$WORKTREE_PATH"
  echo "WORKTREE_BRANCH=$BRANCH_NAME"
  echo "OK"
else
  # Branch may already exist (resume scenario) — attach to it
  if git rev-parse --verify "$BRANCH_NAME" >/dev/null 2>&1; then
    git worktree add "$WORKTREE_PATH" "$BRANCH_NAME" 2>/dev/null || {
      echo "ERROR: Failed to create worktree for existing branch '$BRANCH_NAME'" >&2
      exit 1
    }
    echo "WORKTREE_PATH=$WORKTREE_PATH"
    echo "WORKTREE_BRANCH=$BRANCH_NAME"
    echo "OK (existing branch)"
  else
    echo "ERROR: Failed to create worktree" >&2
    exit 1
  fi
fi
