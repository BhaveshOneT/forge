# Changelog

## 1.1.0 — 2026-03-11

### Added
- **Jira Integration**: `/forge:jira PROJ-123` fetches issue, enriches with Confluence, builds, ships PR, updates Jira
- **Board Sync**: `/forge:jira-sync` auto-picks highest-priority ready issue from a Jira board
- **Git Worktree Isolation**: Tier 2 & 3 sessions run in isolated worktrees — main branch never touched
- **SHIP Phase**: Pushes branch, creates PR via `gh`, adds Jira comment, transitions issue to "In Review"
- **Smart Grilling Reduction**: Jira issues with acceptance criteria skip redundant questions
- **Confluence Enrichment**: Linked/searched Confluence pages provide richer context
- **Mandatory Web Research (Parallel CLI)**: All agents use Parallel Search MCP for up-to-date web research — framework docs, API references, security advisories
- **Parallel MCP Integration**: Search MCP (low-latency) + Task MCP (deep research) + CLI fallback
- **Research protocol**: `skills/parallel-research/SKILL.md` — mandatory triggers, per-agent requirements, output format
- **Jira-aware TMUX dashboard**: Shows Jira issue key in header, extended phase list, PR URL in footer
- **Compaction resilience**: Recovery state captures Jira issue key, source, and worktree path
- **Config system**: `~/.claude/forge/config.json` for Atlassian, GitHub, and sync settings
- **PR body template**: Standardized PR description with Jira link, changes, test coverage
- **Jira requirements template**: Source-attributed requirements with acceptance criteria and Confluence context

## 1.0.0 — 2026-03-11

### Added
- 3-tier complexity routing (Simple / Medium / Complex)
- 4 staff-engineer agent personas: Explorer, Architect, Builder, Reviewer
- Structured context system: decisions.md, patterns.md, loop-learnings.md
- TMUX two-column dashboard for Tier 3 tasks
- Compaction resilience via pre-compact/post-compact hooks
- Destructive operation guard (PreToolUse hook)
- Build-review loop with per-iteration learning inheritance
- Persistent memory across sessions (~/.claude/forge/memory/)
- /forge, /forge:resume, /forge:status commands
