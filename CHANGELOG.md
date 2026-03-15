# Changelog

## 1.6.0 — 2026-03-15

### Added
- 16 new destructive guard patterns: dangerous file removal, branch deletion on main/master, stash clearing, database drops, chmod 777, system shutdown/reboot
- Enriched JSON schemas: jira-context gains priority/labels/subtasks/acceptance_criteria; ship-result gains commit_sha/pr_title/base_branch; build-task-result gains error_output and test counts; verify-result gains detailed error arrays; review-issues category uses an enum for consistency
- Error recovery guidance in all 4 agent instructions (Explorer, Architect, Builder, Reviewer)
- Parallel agent merge strategy in SKILL.md (explorer merge, reviewer dedup by file+line)
- Phase transition quick reference table in REFERENCE.md
- Category enum reference in Reviewer instructions matching the schema
- Task decomposition guidelines in Architect instructions
- 5 new test suites: extended destructive guard, schema validation, common library, phase gate negatives, popup resolve

### Fixed
- Studio layout now uses absolute column/line sizes instead of percentages for tmux 3.4+ compatibility
- Studio session creation sets default terminal size (-x 200 -y 50) for headless environments
- Process substitution in studio-layout.sh replaced with heredoc for environments lacking /dev/fd
- Worktree setup handles path collisions gracefully (reuses valid worktrees, prunes stale ones)
- Pre-compact recovery reads all state fields with safe fallbacks and includes project_dir
- Studio dependency tests now use properly isolated PATH

## 1.5.0 — 2026-03-11

### Added
- Agent-aware Forge Studio runtime with per-agent registration, progress logs, and dedicated tmux panes
- `scripts/studio-agents.sh` for registering, updating, and completing active agents
- `scripts/studio-agent-pane.sh` for live per-agent pane rendering in build and swarm layouts

### Changed
- Swarm mode now creates separate panes for active agents instead of showing only a static status box
- Build mode can surface the current active subagent when the manager registers it
- Manager and agent docs now describe how subagents should keep Forge Studio updated through agent logs

## 1.4.2 — 2026-03-11

### Fixed
- Forge Studio git pane now re-resolves the workspace path instead of getting stuck on a stale non-repository `project_dir`
- Git pane prefers the active worktree and launches `lazygit` as soon as a valid git root is available
- README now documents how to manually attach to Forge Studio with `tmux attach -t ...`

## 1.4.1 — 2026-03-11

### Fixed
- Forge Studio no longer fails in non-interactive subprocess environments when `tmux attach` cannot use a real TTY
- Studio now creates the tmux session detached and prints a manual attach command instead of surfacing a terminal error

## 1.4.0 — 2026-03-11

### Added
- Formal `execution_mode` support for both default prompt-driven sessions and Jira-driven sessions
- Mode-aware Forge Studio rendering, help text, activity summaries, and popup targets
- Jira popup targets for `jira-context.json`, `confluence-context.md`, and `ship-result.json`

### Changed
- `/forge` is now documented explicitly as prompt mode while `/forge:jira` and `/forge:jira-sync` are Jira mode
- Forge Studio now shows entry mode separately from layout mode
- Compatibility fallback keeps older sessions working by inferring Jira mode from legacy `source: "jira"`

## 1.3.0 — 2026-03-11

### Added
- Forge Studio, a tmux-based terminal IDE workspace for every Forge run
- Required dependency validation for `tmux`, `lazygit`, `bash`, and `python3`
- Dedicated Studio session, layout, popup, help, activity, and git pane scripts
- Studio layout schema and Forge state Studio metadata

### Changed
- Replaced the old Tier 3-only dashboard with persistent Forge Studio layouts for all tiers
- Updated docs and manager instructions to treat Forge Studio as the default UX

## 1.2.0 — 2026-03-11

### Added
- State validation via `scripts/validate-state.sh` and `schemas/forge-state.schema.json`
- Phase gate enforcement via `scripts/check-phase-gate.sh`
- JSON schemas for builder, reviewer, verify, Jira context, and ship artifacts
- Regression coverage for state validation and phase gate checks

### Changed
- Tightened manager and agent prompts to treat artifact schemas and gate scripts as authoritative

## 1.1.1 — 2026-03-11

### Fixed
- Packaged hooks correctly for plugin installs via `hooks/hooks.json` and `${CLAUDE_PLUGIN_ROOT}`
- Updated repo-local development hooks to use `${CLAUDE_PROJECT_DIR}`
- Hardened destructive guard parsing to read structured hook payloads and emit block messages on stderr
- Fixed compact recovery to resume the newest active session instead of the first directory match
- Reduced recovery prompt-injection risk by treating restored notes as untrusted excerpts
- Hardened worktree teardown to reject unsafe session ids and operate against the owning repository explicitly
- Fixed TMUX dashboard teardown to target the Forge pane instead of assuming pane index `1`
- Aligned marketplace metadata with the plugin version

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
