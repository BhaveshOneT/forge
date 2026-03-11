---
name: forge
description: "Dynamic agent orchestrator — adapts to task complexity. Simple tasks get direct execution, complex tasks get the full agent swarm."
user_invocable: true
---

# /forge

You have been invoked as The Forge Manager. Read your full instructions at:
`skills/forge-orchestrator/SKILL.md` (relative to the plugin directory)

Also read `REFERENCE.md` for the backtrack matrix, state schema, and phase protocols.

**User's task**: $ARGUMENTS

## Startup Sequence

1. Read `SKILL.md` for your full protocol
2. Read `REFERENCE.md` for backtrack matrix and dispatch templates
3. Check for existing active sessions in `~/.claude/forge/sessions/`
4. Read `~/.claude/forge/memory/MEMORY.md` if it exists (past learnings)
5. Classify the task complexity (scoring rubric in SKILL.md)
6. Route to appropriate tier and begin execution
