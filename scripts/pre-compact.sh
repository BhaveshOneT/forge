#!/usr/bin/env bash
# Forge: PreCompact Hook
# Snapshots current state before context compaction so the Manager can resume.
# Captures structured context (decisions, loop-learnings) instead of raw transcripts.

FORGE_DIR="$HOME/.claude/forge"
SESSIONS_DIR="$FORGE_DIR/sessions"

# Find the most recent active session (not marked complete)
ACTIVE_SESSION=""
for session_dir in "$SESSIONS_DIR"/*/; do
  [ -d "$session_dir" ] || continue
  state_file="$session_dir/forge-state.json"
  [ -f "$state_file" ] || continue

  phase=$(python3 -c "import json; print(json.load(open('$state_file'))['current_phase'])" 2>/dev/null)
  if [ "$phase" != "complete" ] && [ -n "$phase" ]; then
    ACTIVE_SESSION="$session_dir"
    break
  fi
done

# No active session — nothing to snapshot
[ -z "$ACTIVE_SESSION" ] && exit 0

STATE_FILE="$ACTIVE_SESSION/forge-state.json"
DECISIONS_FILE="$ACTIVE_SESSION/context/decisions.md"
LEARNINGS_FILE="$ACTIVE_SESSION/context/loop-learnings.md"
RECOVERY_FILE="$ACTIVE_SESSION/recovery-state.md"

# Read current state
PHASE=$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['current_phase'])" 2>/dev/null)
ATTEMPT=$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['phase_attempt'])" 2>/dev/null)
BACKTRACKS=$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['total_backtracks'])" 2>/dev/null)
TIER=$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['tier'])" 2>/dev/null)
LOOP=$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['build_review_loop'])" 2>/dev/null)
CHECKPOINT=$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('checkpoint', 'unknown'))" 2>/dev/null)
SESSION_ID=$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['session_id'])" 2>/dev/null)

# Capture last 20 lines of decisions for context
RECENT_DECISIONS=""
if [ -f "$DECISIONS_FILE" ]; then
  RECENT_DECISIONS=$(tail -20 "$DECISIONS_FILE")
fi

# Capture last 15 lines of loop-learnings
RECENT_LEARNINGS=""
if [ -f "$LEARNINGS_FILE" ]; then
  RECENT_LEARNINGS=$(tail -15 "$LEARNINGS_FILE")
fi

# Write recovery state
cat > "$RECOVERY_FILE" << EOF
# Forge Recovery State

**Session**: $SESSION_ID
**Session directory**: $ACTIVE_SESSION
**Tier**: $TIER
**Phase**: $PHASE (attempt $ATTEMPT)
**Total backtracks**: $BACKTRACKS
**Build-Review loop**: $LOOP
**Checkpoint**: $CHECKPOINT

## Recovery Instructions

You are The Forge Manager. Context was compacted. Resume your work:

1. Read the full state: $STATE_FILE
2. Read SKILL.md and REFERENCE.md for protocol details
3. You were in the **$PHASE** phase (attempt $ATTEMPT), Tier $TIER
4. Resume from where you left off — do NOT restart the pipeline
5. Read context/decisions.md and context/loop-learnings.md for accumulated knowledge

## Recent Decisions
$RECENT_DECISIONS

## Recent Loop Learnings
$RECENT_LEARNINGS
EOF

exit 0
