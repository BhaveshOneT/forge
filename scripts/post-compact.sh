#!/usr/bin/env bash
# Forge: SessionStart(compact) Hook
# Injects recovery state as additionalContext after compaction.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib/forge-common.sh
source "$SCRIPT_DIR/lib/forge-common.sh"

FORGE_DIR="$HOME/.claude/forge"
SESSIONS_DIR="$FORGE_DIR/sessions"

ACTIVE_SESSION="$(forge_latest_active_session "$SESSIONS_DIR" 2>/dev/null || true)"
[ -z "$ACTIVE_SESSION" ] && exit 0

STATE_FILE="$ACTIVE_SESSION/forge-state.json"
RECOVERY_FILE="$ACTIVE_SESSION/recovery-state.md"

if [ -f "$RECOVERY_FILE" ]; then
  cat "$RECOVERY_FILE"
else
  echo "Forge: Active session found at $ACTIVE_SESSION but no recovery-state.md."
  echo "Read $STATE_FILE to resume."
fi

exit 0
