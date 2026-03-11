#!/usr/bin/env bash
# Forge: SessionStart(compact) Hook
# Injects recovery state as additionalContext after compaction.

FORGE_DIR="$HOME/.claude/forge"
SESSIONS_DIR="$FORGE_DIR/sessions"

# Find the most recent active session
for session_dir in "$SESSIONS_DIR"/*/; do
  [ -d "$session_dir" ] || continue
  state_file="$session_dir/forge-state.json"
  [ -f "$state_file" ] || continue

  phase=$(python3 -c "import json; print(json.load(open('$state_file'))['current_phase'])" 2>/dev/null)
  if [ "$phase" != "complete" ] && [ -n "$phase" ]; then
    RECOVERY_FILE="$session_dir/recovery-state.md"
    if [ -f "$RECOVERY_FILE" ]; then
      cat "$RECOVERY_FILE"
    else
      echo "Forge: Active session found at $session_dir but no recovery-state.md."
      echo "Read $state_file to resume."
    fi
    exit 0
  fi
done

# No active session
exit 0
