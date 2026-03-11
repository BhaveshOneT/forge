# Forge — Phase Protocols & Reference

Detailed phase protocols, dispatch templates, gate conditions, and the backtrack decision matrix. The Manager (SKILL.md) references this for all phase execution details.

---

## Execution Map

This is the shortest accurate description of how Forge runs.

```text
/forge "..."              /forge:jira ...
      |                         |
      +------ execution mode ---+
                  |
                  +--> prompt
                  `--> jira
                         |
                         v
                     CLASSIFY
                         |
                         +--> Tier 1
                         +--> Tier 2
                         `--> Tier 3
                              |
                              v
                    Forge Studio layout
                    focus / build / swarm
```

## State Ownership

```text
forge-state.json          authoritative phase + retry state
requirements.md           accepted scope and constraints
context/decisions.md      why choices were made
context/patterns.md       conventions discovered during exploration
context/loop-learnings.md lessons from each build/review cycle
studio-layout.json        Studio pane metadata and mode
```

Recovery rule: files are truth, conversation is cache.

## Execution Modes

Forge has two entry modes:

- `prompt` -> standard pasted user prompt via `/forge "..."`
- `jira` -> Jira or board-driven flow via `/forge:jira ...` and `/forge:jira-sync`

Execution mode is separate from:

- `tier` -> orchestration depth
- `studio_layout_mode` -> tmux workspace density

Compatibility rule:
- use `execution_mode` when present
- otherwise infer `jira` from `source == "jira"`
- otherwise default to `prompt`

## Forge Studio

Forge Studio is the default tmux workspace for every tier.

```text
dependencies -> studio-check-deps.sh
session      -> tmux-setup.sh / studio-session.sh
layout       -> studio-layout.sh
agents       -> studio-agents.sh / studio-agent-pane.sh
status pane  -> tmux-render.sh + studio-activity.sh
popups       -> studio-popup.sh
cleanup      -> tmux-teardown.sh
```

Runtime requirements:
- `tmux`
- `lazygit`
- `bash`
- `python3`

There is no degraded non-Studio mode.

Studio is mode-aware:
- `prompt` sessions emphasize requirements, plan, exploration, decisions, and loop learnings
- `jira` sessions emphasize Jira context, Confluence context, shipping, PR state, and the extended Jira pipeline

Studio is also agent-aware:
- build mode can surface the current active subagent in its own pane
- swarm mode creates separate panes for active agents from `active_agents`
- each agent pane tails `session_dir/agents/<agent-id>.log`

Attach behavior:
- if Forge is running inside a real terminal, `tmux-setup.sh` attaches or switches to the Studio session
- if Forge is running in a non-TTY subprocess, the Studio session is created detached and Forge prints a manual `tmux attach -t ...` command instead of failing

Popup targets:
- prompt oriented: `requirements`, `plan`, `issues`, `decisions`, `learnings`, `exploration`, `verify`
- jira oriented: `jira-context`, `confluence`, `ship`

## Enforced Checks

Forge now has scriptable validation for the artifacts the prompts talk about:

```text
forge-state.json        -> bash scripts/validate-state.sh <state-file>
phase artifacts         -> bash scripts/check-phase-gate.sh <phase> <session-dir>
builder output JSON     -> schemas/build-task-result.schema.json
reviewer output JSON    -> schemas/review-issues.schema.json
verify output JSON      -> schemas/verify-result.schema.json
```

---

## Phase: CLASSIFY

**Action**: Manager scores directly (no subagent).

| Signal | 0 pts | 2 pts | 4 pts |
|--------|-------|-------|-------|
| Clarity | < 2 sentences, single action | 2-5 sentences, some ambiguity | > 5 sentences or very vague |
| Scope | Single file | Multi-file, same module | Cross-module or new feature |
| Keywords | "fix", "rename", "update" | "add", "implement", "create" | "build", "redesign", "system" |
| Project | Greenfield | Small brownfield (<50 files) | Large brownfield (50+ files) |

Also detect project type: check for `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `pom.xml`, `build.gradle`, `Makefile`, `.git`. None → greenfield. Any → brownfield.

**Output**: Set `tier`, `complexity_score`, `project_type` in `forge-state.json`.

**Enforcement**:
- Validate with `bash scripts/validate-state.sh {session_dir}/forge-state.json`

---

## Phase: GRILL

**Action**: Manager asks questions directly via `AskUserQuestion` (no subagent).

ALL questions in ONE call. After response, write `requirements.md`.

**Gate**: Requirements written with clear scope, acceptance criteria, and constraints.

**Enforcement**:
- `bash scripts/check-phase-gate.sh grill {session_dir}`

---

## Phase: EXPLORE

### Tier 2 — Single Explorer
**Agent**: forge-explorer | **Model**: sonnet | **Mode**: foreground

```
Read your instructions at: {plugin_dir}/agents/forge-explorer.md

Session directory: {session_dir}
Requirements: {session_dir}/requirements.md
Project directory: {project_dir}
Focus: Full analysis — structure, conventions, relevant files, patterns.

Write output to: {session_dir}/exploration.md
Write patterns to: {session_dir}/context/patterns.md
```

### Tier 3 — Parallel Explorers
Launch 2 explorers concurrently via `Agent` tool:

Before dispatch:
- register `explorer-a` and `explorer-b` with `bash scripts/studio-agents.sh register ...`
- include the agent id and log path in the prompt
- tell the agent to append progress notes with `bash scripts/studio-agents.sh note ...`

**Explorer A — Architecture & Patterns**:
```
Read your instructions at: {plugin_dir}/agents/forge-explorer.md

Session directory: {session_dir}
Requirements: {session_dir}/requirements.md
Project directory: {project_dir}
Focus: project structure, architecture patterns, conventions, import style, error handling.

Write output to: {session_dir}/exploration-architecture.md
Write patterns to: {session_dir}/context/patterns.md
```

**Explorer B — Relevant Code & Features**:
```
Read your instructions at: {plugin_dir}/agents/forge-explorer.md

Session directory: {session_dir}
Requirements: {session_dir}/requirements.md
Project directory: {project_dir}
Focus: files to modify, similar features as templates, shared utilities, test structure.

Write output to: {session_dir}/exploration-code.md
```

**After both complete**: Manager merges into `exploration.md` and marks both agents complete with `bash scripts/studio-agents.sh complete ...`.

**Gate**: `exploration.md` exists with sections: conventions, patterns, relevant files, test approach. `context/patterns.md` populated.

**Enforcement**:
- `bash scripts/check-phase-gate.sh explore {session_dir}`

---

## Phase: ARCHITECT (Tier 3 only)

**Agent**: forge-architect | **Model**: opus | **Mode**: foreground

```
Read your instructions at: {plugin_dir}/agents/forge-architect.md

Session directory: {session_dir}
Requirements: {session_dir}/requirements.md
Exploration: {session_dir}/exploration.md
Patterns: {session_dir}/context/patterns.md
Decisions: {session_dir}/context/decisions.md

Create implementation plan with research citations.
Define shared contracts in: {session_dir}/contracts/
Write plan to: {session_dir}/plan.md
Update: {session_dir}/context/decisions.md

{if backtrack}
BACKTRACK from {source_phase}. Read diagnostic: {session_dir}/diagnostics/backtrack-{NNN}.json
Revise ONLY the section identified.
{/if}
```

**Gate**: `plan.md` exists with task decomposition, file map, research citations (≥1 tier-1 source), `contracts/` created. Plan auto-approved (full autonomy after grilling).

**Enforcement**:
- `bash scripts/check-phase-gate.sh architect {session_dir}`

---

## Phase: BUILD

**Agent**: forge-builder | **Model**: opus | **Mode**: foreground (sequential per task)

```
Read your instructions at: {plugin_dir}/agents/forge-builder.md

Session directory: {session_dir}
Task: {task_number} of {total_tasks}
Task description: {task_description}
Files to create/modify: {file_list}

Read loop-learnings FIRST: {session_dir}/context/loop-learnings.md
Read patterns: {session_dir}/context/patterns.md
Read decisions: {session_dir}/context/decisions.md
{if tier3}Read plan: {session_dir}/plan.md
Read contracts: {session_dir}/contracts/{/if}

Implement the task. Write tests alongside implementation.
Update: {session_dir}/context/decisions.md with implementation choices.

{if backtrack}
BACKTRACK. Read diagnostic: {session_dir}/diagnostics/backtrack-{NNN}.json
Read loop-learnings for accumulated knowledge.
Fix ONLY the issue identified.
{/if}
{if review_issues}
REVIEW LOOP iteration {N}. Read issues: {session_dir}/review-issues.json
Read loop-learnings: {session_dir}/context/loop-learnings.md
Address ALL critical and major issues. Do not refactor unrelated code.
{/if}
```

**Gate**: Implementation compiles/runs without errors. `build-task-N-result.json` shows success. Tests pass.

**Enforcement**:
- Builder writes `build-task-N-result.json` conforming to `schemas/build-task-result.schema.json`
- `bash scripts/check-phase-gate.sh build {session_dir}`

---

## Phase: REVIEW

### Tier 2 — Single Reviewer
**Agent**: forge-reviewer | **Model**: opus | **Mode**: foreground

```
Read your instructions at: {plugin_dir}/agents/forge-reviewer.md

Session directory: {session_dir}
Requirements: {session_dir}/requirements.md
Loop learnings: {session_dir}/context/loop-learnings.md

Review all implementation files. Report issues scoring >= 80 confidence.
Write issues to: {session_dir}/review-issues.json
```

### Tier 3 — Parallel Reviewers

Before dispatch:
- register both reviewer agents with `bash scripts/studio-agents.sh register ...`
- include the agent id and log path in the prompt
- tell the agent to append progress notes with `bash scripts/studio-agents.sh note ...`

**Reviewer A — Bugs & Security**:
```
Read your instructions at: {plugin_dir}/agents/forge-reviewer.md

Session directory: {session_dir}
Requirements: {session_dir}/requirements.md
Plan: {session_dir}/plan.md
Contracts: {session_dir}/contracts/
Loop learnings: {session_dir}/context/loop-learnings.md

Focus: bugs, logic errors, security vulnerabilities, crash risks, data loss.
Write issues to: {session_dir}/review-issues-bugs.json
```

**Reviewer B — Plan Alignment & Quality**:
```
Read your instructions at: {plugin_dir}/agents/forge-reviewer.md

Session directory: {session_dir}
Requirements: {session_dir}/requirements.md
Plan: {session_dir}/plan.md
Contracts: {session_dir}/contracts/
Loop learnings: {session_dir}/context/loop-learnings.md

Focus: plan alignment, contract compliance, missing requirements, code quality.
Write issues to: {session_dir}/review-issues-alignment.json
```

**After both complete**: Manager merges into `review-issues.json`, deduplicating by file+line, then marks both agents complete with `bash scripts/studio-agents.sh complete ...`.

**Gate**: 0 critical issues. If critical → backtrack per matrix.

**Enforcement**:
- Reviewer writes `review-issues.json` conforming to `schemas/review-issues.schema.json`
- `bash scripts/check-phase-gate.sh review {session_dir}`

---

## Phase: VERIFY (Tier 3 only)

**Action**: Manager runs directly (no subagent):
1. Build the project
2. Run linter (if configured)
3. Run type checker (if configured)
4. Run full test suite
5. Check requirements line-by-line against requirements.md

**Artifact**:
- Write `{session_dir}/verify-result.json` conforming to `schemas/verify-result.schema.json`

**Gate**: ALL checks pass. If any fail → backtrack per matrix.

**Enforcement**:
- `bash scripts/check-phase-gate.sh verify {session_dir}`

---

## Phase: COMPOUND

**Action**: Manager runs directly:
1. Write `session-summary.md` from template
2. Extract learnings to `~/.claude/forge/memory/MEMORY.md`
3. Mark Forge Studio complete but keep the workspace alive
4. Clean up worktree (Tier 2 & 3): `bash scripts/worktree-teardown.sh <session-id>`, set `worktree_cleaned: true` in forge-state.json
5. Mark session complete

```text
COMPOUND
   |
   +--> write session-summary.md
   +--> append distilled learnings to memory
   +--> leave Forge Studio alive for inspection
   `--> remove worktree if one was created
```

**Enforcement**:
- `bash scripts/check-phase-gate.sh compound {session_dir}`

---

## Backtrack Decision Matrix

> **The matrix is authoritative.** Agent recommendations are advisory — the Manager always follows the matrix.

```
FAILURE POINT  | FAILURE TYPE              | BACKTRACK TARGET
───────────────┼───────────────────────────┼──────────────────
EXPLORE        | Incomplete analysis        | → EXPLORE (retry, max 2)
ARCHITECT      | Codebase mismatch          | → EXPLORE (re-analyze)
ARCHITECT      | Missing requirements       | → USER (escalate)
BUILD          | Contract mismatch          | → ARCHITECT (fix)
BUILD          | Compilation failure        | → BUILD (retry, max 2)
REVIEW         | Critical bugs              | → BUILD (with issues)
REVIEW         | Plan misalignment          | → ARCHITECT (revise)
VERIFY         | Build/lint/test fails      | → BUILD (with error)
VERIFY         | Requirement not met        | → ARCHITECT (revise)
```

### Cascade Rules

Backtracking to an earlier phase re-runs all subsequent phases:
```
EXPLORE fail
   |
   `--> EXPLORE -> ARCHITECT -> BUILD -> REVIEW -> VERIFY

ARCHITECT fail
   |
   `--> ARCHITECT -> BUILD -> REVIEW -> VERIFY

BUILD fail
   |
   `--> BUILD -> REVIEW -> VERIFY
```

## Jira Artifact Gates

```text
JIRA_FETCH         -> jira-context.json      -> check-phase-gate.sh jira_fetch
CONFLUENCE_ENRICH  -> confluence-context.md  -> check-phase-gate.sh confluence_enrich
SYNTHESIZE         -> requirements.md        -> check-phase-gate.sh synthesize
SHIP               -> ship-result.json       -> check-phase-gate.sh ship
```

### Safety Limits

- **Max 2 retries** per backtrack target
- **Max 8 total backtracks** per session
- **Build-Review loop**: max 2 iterations (Tier 2), max 3 (Tier 3)
- After limits: escalate to user with full diagnostic

---

## Diagnostic Bundle Format

```json
{
  "backtrack_id": 1,
  "timestamp": "2026-03-11T14:30:00Z",
  "from_phase": "review",
  "to_phase": "build",
  "failure_type": "critical_bug",
  "description": "Missing error handler for WebSocket disconnect",
  "evidence": {
    "file": "src/ws-handler.ts",
    "line": 45,
    "snippet": "ws.on('message', ...) // no error/close handler",
    "suggestion": "Add ws.on('error') and ws.on('close') handlers"
  },
  "root_cause": "Builder did not account for connection lifecycle events",
  "previous_attempts": 0,
  "context_files": ["src/ws-handler.ts", "contracts/types.ts"]
}
```

---

## Confidence Scoring

| Agent | Metrics |
|-------|---------|
| Explorer | Files analyzed, patterns documented, conventions found, **web research performed** |
| Architect | tier1_sources≥1 (0.4) + contracts_defined (0.3) + alternatives_compared (0.2) + risks_documented (0.1). **All citations must be real URLs from Parallel search.** |
| Builder | Compiles, tests pass, follows contracts, matches plan task |
| Reviewer | Issue count by severity (independently counted), confidence ≥80 only |

---

## Mandatory Web Research Protocol (Parallel CLI)

All Tier 2 & 3 sessions MUST use web research via Parallel. Full protocol in `skills/parallel-research/SKILL.md`.

### Tools (priority order)

1. **Parallel Search MCP** — `https://search-mcp.parallel.ai/mcp` — low-latency, optimized for agents
2. **Parallel Task MCP** — `https://task-mcp.parallel.ai/mcp` — deep research, async, enrichment
3. **`parallel-cli search`** — via Bash tool, fallback when MCP unavailable
4. **WebSearch / Context7** — last resort

### Per-Agent Requirements

| Agent | Minimum Research | What to Search |
|-------|-----------------|---------------|
| Explorer | ≥1 search per session | Framework docs, dependency versions, known issues |
| Architect | ≥1 search per technology decision | Official docs, comparisons, OWASP, best practices |
| Builder | Before every external API/unfamiliar library | Current API docs, auth patterns, error solutions |
| Reviewer | Security-sensitive code | Current best practices, known vulnerabilities |

### Agent Dispatch Addition

When dispatching any agent in Tier 2+, append to the prompt:
```
Web research is MANDATORY. Use Parallel Search MCP for up-to-date information.
Fallback: parallel-cli search via Bash, then WebSearch.
Read skills/parallel-research/SKILL.md for the full protocol.
Document all research in context/decisions.md with real URLs.
```

### Research Output Format

```markdown
### Web Research: [Topic]
**Query**: [what was searched]
**Source**: [URL]
**Finding**: [key takeaway]
**Impact**: [how this affects the implementation]
```

### Setup

```bash
bash scripts/parallel-setup.sh
```

Installs CLI, adds both MCP servers, verifies authentication.

---

## forge-state.json Schema

```json
{
  "session_id": "forge-YYYYMMDD-HHmmss",
  "tier": 2,
  "complexity_score": 6,
  "project_type": "brownfield",
  "project_dir": "/absolute/path",
  "user_request": "original request",
  "execution_mode": "prompt",
  "current_phase": "build",
  "phase_attempt": 1,
  "total_backtracks": 0,
  "build_review_loop": 0,
  "tokens_estimate": 0,
  "phase_history": [
    {"phase": "classify", "confidence": 1.0, "status": "complete"}
  ],
  "backtrack_history": [],
  "build_tasks": [],
  "active_agents": [],
  "checkpoint": "Building task 2 of 4...",
  "tmux_active": false,

  // --- Worktree fields (Tier 2 & 3) ---
  "worktree_path": "~/.claude/forge/worktrees/forge-20260311-143022",
  "worktree_branch": "forge/PROJ-123-add-user-auth",
  "worktree_created": true,
  "worktree_cleaned": false,

  // --- Jira fields (execution_mode == "jira" only) ---
  "execution_mode": "jira",
  "source": "jira",
  "jira_issue_key": "PROJ-123",
  "jira_issue_type": "Story",
  "jira_priority": "High",
  "grilling_override": "minimal",
  "ship_result": {
    "branch": "forge/PROJ-123-add-user-auth",
    "pr_url": "https://github.com/org/repo/pull/42",
    "pr_number": 42,
    "jira_comment_added": true,
    "jira_transitioned": true
  }
}
```

---

## Git Worktree Lifecycle Protocol

### Setup (Session Initialization)

Tier 2 & 3 sessions create an isolated worktree:

```bash
# Create worktree for session
bash scripts/worktree-setup.sh <session-id> <branch-name> <base-branch>
# Output: WORKTREE_PATH=~/.claude/forge/worktrees/<session-id>
```

- **Branch naming**: `forge/<session-id>` (normal) or `forge/<ISSUE-KEY>-<slug>` (Jira)
- **Base branch**: from `config.github.default_base_branch` (default: `main`)
- All agents receive the worktree path as `project_dir`

### Agent Dispatch with Worktrees

All agent dispatch templates use `{project_dir}` which points to the worktree. For Tier 3 parallel agents, also set `isolation: "worktree"` in the Agent tool call for sub-isolation.

### Teardown (COMPOUND Phase)

```bash
# Clean up worktree after session
bash scripts/worktree-teardown.sh <session-id>
# Removes worktree dir. Keeps branch if PR exists, deletes if not.
```

### Abort/Failure Cleanup

```bash
# Force remove on failure
bash scripts/worktree-teardown.sh <session-id> --force
```

---

## Jira Adapter Phase Protocols

These phases are defined in `skills/jira-adapter/SKILL.md`. The Manager executes them directly (no subagent).

### Phase: JIRA_FETCH (state key: `jira_fetch`)

**Action**: Manager calls Atlassian MCP tools directly.

```
1. getAccessibleAtlassianResources() → cloudId (cached after first call)
2. getJiraIssue(cloudId, issueKey) → issue data
3. getJiraIssueRemoteIssueLinks(cloudId, issueKey) → linked Confluence pages
4. [If Epic] searchJiraIssuesUsingJql(cloudId, "'Epic Link' = KEY") → child stories
```

**Output**: `{session_dir}/jira-context.json`
**Gate**: jira-context.json has summary + description + issue_type

### Phase: CONFLUENCE_ENRICH (state key: `confluence_enrich`)

**Action**: Manager calls Atlassian MCP tools directly.

```
1. [Per linked page] getConfluencePage(cloudId, pageId)
2. [Per page] getConfluencePageDescendants(cloudId, pageId, depth=1)
3. [Fallback] searchConfluenceUsingCql(cloudId, "type=page AND space=KEY AND title~'...'")
```

**Output**: `{session_dir}/confluence-context.md`
**Gate**: Always passes (no Confluence is acceptable)

### Phase: SYNTHESIZE (state key: `synthesize`)

**Action**: Manager merges Jira + Confluence into requirements.md.

Uses `templates/jira-requirements.md`. Sets `grilling_override` in forge-state.json:
- `"minimal"` (0-1 Qs): has acceptance criteria + rich description/Confluence
- `"standard"`: basic description only
- `"confirm_scope"` (1 Q): epic with subtasks

**Output**: `{session_dir}/requirements.md`
**Gate**: requirements.md has ≥1 functional requirement

### Phase: SHIP (state key: `ship`)

**Action**: Manager pushes branch, creates PR, updates Jira.

```
1. Ensure all changes committed on worktree branch
2. git push -u origin <branch>
3. gh pr create --title "[KEY] summary" --body "..." --base <base_branch>
4. addCommentToJiraIssue(cloudId, issueKey, "PR: <url>")
5. getTransitionsForJiraIssue(cloudId, issueKey) → find "In Review"
6. transitionJiraIssue(cloudId, issueKey, {id: transition_id})
```

**Output**: `{session_dir}/ship-result.json`
**Gate**: PR created (URL in ship-result.json). Jira updates are best-effort.

---

## Extended Backtrack Matrix (Jira Phases)

```
FAILURE POINT      | FAILURE TYPE              | BACKTRACK TARGET
───────────────────┼───────────────────────────┼──────────────────
JIRA_FETCH         | Issue not found           | → USER (abort)
JIRA_FETCH         | Auth failure              | → USER (fix MCP config)
CONFLUENCE_ENRICH  | Page fetch failed          | → SKIP (non-blocking)
SYNTHESIZE         | Insufficient context       | → USER (add requirements)
SHIP               | Branch conflict            | → SHIP (retry with suffix)
SHIP               | PR creation failed         | → USER (manual PR)
SHIP               | Jira transition fail       | → LOG (non-blocking)
```
