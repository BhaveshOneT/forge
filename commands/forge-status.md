---
name: forge:status
description: "Show the current state of all forge sessions — active and completed."
user_invocable: true
---

# /forge:status

Display the status of forge sessions.

## Execution

1. List all directories in `~/.claude/forge/sessions/`
2. For each session, read `forge-state.json`
3. Display a summary table:

```
Session ID              | Tier | Phase     | Backtracks | Loop | Status
────────────────────────┼──────┼───────────┼────────────┼──────┼────────
forge-20260311-143022   | 3    | build     | 1/8        | #1   | ACTIVE
forge-20260310-091500   | 2    | complete  | 0/8        | #0   | DONE
forge-20260309-160000   | 1    | complete  | 0/8        | #0   | DONE
```

4. For the active session (if any), also show:
   - Current checkpoint message
   - Last 3 entries from `context/decisions.md`
   - Active agents
   - Task: the original user request

5. If no sessions exist, say "No forge sessions found."
