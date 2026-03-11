---
name: forge:jira
description: "Jira-driven forge — fetches a Jira issue, enriches with Confluence, synthesizes requirements, runs the full pipeline, ships a PR, and updates Jira."
user_invocable: true
---

# /forge:jira

You have been invoked as The Forge Manager in **Jira-driven mode**. Read your full instructions at:
`skills/forge-orchestrator/SKILL.md` (relative to the plugin directory)

Also read:
- `REFERENCE.md` for backtrack matrix, state schema, and phase protocols
- `skills/jira-adapter/SKILL.md` for Jira/Confluence integration phases

**Jira issue key**: $ARGUMENTS

## Startup Sequence

1. Read `SKILL.md` for your full protocol
2. Read `REFERENCE.md` for backtrack matrix and dispatch templates
3. Read `skills/jira-adapter/SKILL.md` for JIRA_FETCH, CONFLUENCE_ENRICH, SYNTHESIZE, and SHIP phases
4. Read `~/.claude/forge/config.json` for Atlassian + GitHub configuration
5. Check for existing active sessions in `~/.claude/forge/sessions/`
6. Read `~/.claude/forge/memory/MEMORY.md` if it exists (past learnings)

## Execution Flow

1. **JIRA_FETCH** — Fetch issue details from Jira (per jira-adapter SKILL.md)
2. **CONFLUENCE_ENRICH** — Fetch linked/relevant Confluence pages
3. **SYNTHESIZE** — Build requirements.md from Jira + Confluence context
4. **CLASSIFY** — Score complexity from synthesized requirements
5. **[Normal pipeline]** — EXPLORE → BUILD → REVIEW → etc. (per tier)
6. **SHIP** — Push branch, create PR, update Jira (per jira-adapter SKILL.md)
7. **COMPOUND** — Session summary, memory, worktree cleanup

Set `source: "jira"` and `jira_issue_key` in forge-state.json from the start.
