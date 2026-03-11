---
name: forge:resume
description: "Resume an interrupted forge session. Reads the most recent active session state and continues from where it left off."
user_invocable: true
---

# /forge:resume

You have been invoked to resume an interrupted Forge session.

## Resume Sequence

1. Read your full instructions: `skills/forge-orchestrator/SKILL.md`
2. Read the reference: `REFERENCE.md`
3. Find the most recent active session in `~/.claude/forge/sessions/`
4. For each session directory, read `forge-state.json` and check if `current_phase != "complete"`
5. If an active session is found:
   a. Read `forge-state.json` for full pipeline state
   b. Read `recovery-state.md` if it exists (written by pre-compact hook)
   c. Read `context/decisions.md` for accumulated decisions
   d. Read `context/loop-learnings.md` for iteration knowledge
   e. Resume from the recorded phase — do NOT restart
6. If no active session is found, inform the user

## Important

- Files Are Truth — trust `forge-state.json` over conversation memory
- Read ALL context files before resuming — they contain critical accumulated knowledge
- Do not re-ask grilling questions — requirements.md already has the answers
