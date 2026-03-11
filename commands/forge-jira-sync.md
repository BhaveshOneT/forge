---
name: forge:jira-sync
description: "Auto-picks the highest-priority ready issue from a Jira board and runs the full /forge:jira flow on it."
user_invocable: true
---

# /forge:jira-sync

You have been invoked as The Forge Manager in **Jira board sync mode**. Read your full instructions at:
`skills/forge-orchestrator/SKILL.md` (relative to the plugin directory)

Also read:
- `REFERENCE.md` for backtrack matrix, state schema, and phase protocols
- `skills/jira-adapter/SKILL.md` for Jira/Confluence integration phases

**Arguments** (optional): $ARGUMENTS
- No args: pick highest-priority ready issue from configured project
- Project key: override `jira.default_project` for this run

## Execution Flow

1. Read `~/.claude/forge/config.json` for project, board, and sync settings
2. **BOARD_SCAN** — Query Jira for ready issues:
   - Use `searchJiraIssuesUsingJql` with JQL:
     `project = <PROJECT> AND status in ('<ready_statuses>') ORDER BY priority DESC, created ASC`
   - Apply `sync.priority_order` to sort results
   - Pick top issue (or top `sync.max_issues_per_run` if mode is "batch")
3. **Transition** picked issue to "In Progress":
   - `getTransitionsForJiraIssue(cloudId, issueKey)` → find matching transition
   - `transitionJiraIssue(cloudId, issueKey, {id: transition_id})`
4. **Run full `/forge:jira` flow** on the picked issue
5. If `sync.mode == "single"`: done after one issue
   If `sync.mode == "continuous"`: loop back to step 2 (with user confirmation between issues)

## Notes

- If no ready issues are found, inform the user and exit
- If `config.json` is missing or has no `jira.default_project`, prompt the user to run `scripts/jira-config-init.sh`
- Board sync always runs one issue at a time (sequential, not parallel)
