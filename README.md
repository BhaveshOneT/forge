# Forge — Dynamic Agent Orchestrator

A Claude Code plugin that adapts to task complexity. Simple tasks get direct execution, medium tasks get 3 agents, complex tasks get the full swarm with a TMUX dashboard.

## Mental Model

Forge is a manager prompt plus a small shell runtime. The manager scores the task, chooses the lightest execution path that can still do the job safely, and persists state to disk so interrupted sessions resume from files instead of chat history.

```text
user request
    |
    v
+-----------+
| CLASSIFY  | clarity + scope + keywords + repo size
+-----------+
    |
    +--> Tier 1: manager executes directly
    |
    +--> Tier 2: Explorer -> Builder -> Reviewer
    |
    `--> Tier 3: Explorer x2 -> Architect -> Builder -> Reviewer x2 -> Verify
```

## Installation

```bash
# Via Claude Code marketplace (when published)
# Or manually:
git clone https://github.com/BhaveshOneT/forge.git ~/.claude/plugins/forge
```

### Hook Layout

The runtime has two hook entry points on purpose:

```text
installed plugin
  hooks/hooks.json
      |
      `--> ${CLAUDE_PLUGIN_ROOT}/scripts/*.sh

local repo development
  .claude/settings.json
      |
      `--> ${CLAUDE_PROJECT_DIR}/scripts/*.sh
```

Plugin installs use `hooks/hooks.json`. The repo-local `.claude/settings.json` exists so you can exercise the same scripts while developing Forge itself.

To validate the packaged hook wiring:

```bash
bash ~/.claude/plugins/forge/scripts/setup-hooks.sh
```

## Usage

```
/forge "fix the typo in the README"           → Tier 1: direct execution
/forge "add user authentication to the API"   → Tier 2: Explorer → Builder → Reviewer
/forge "build a real-time chat system"         → Tier 3: full swarm + TMUX dashboard
```

### Commands

| Command | Description |
|---------|-------------|
| `/forge "<task>"` | Start a new task |
| `/forge:jira PROJ-123` | Build from a Jira issue |
| `/forge:jira-sync` | Auto-pick highest-priority ready issue |
| `/forge:resume` | Resume an interrupted session |
| `/forge:status` | Show session status |

## Architecture

### 3-Tier Complexity Routing

Every request is classified on 4 signals (clarity, scope, keywords, project state) scored 0-16:

| Tier | Score | Agents | TMUX | Session |
|------|-------|--------|------|---------|
| **Simple** | 0-3 | 0 | No | No |
| **Medium** | 4-8 | 3 (sequential) | No | Yes |
| **Complex** | 9+ | 6 (parallel) | Yes | Yes |

```text
score 0-3       score 4-8                 score 9-16
   |               |                          |
 Tier 1          Tier 2                     Tier 3
 direct          explore -> build ->       explore -> architect
 execution       review                    -> build -> review -> verify
```

### 4 Agent Personas

| Agent | Role | Model | Notes |
|-------|------|-------|-------|
| **Explorer** | Codebase analyst | sonnet | Read-only, maps terrain |
| **Architect** | System designer | opus | Plans, contracts, research citations |
| **Builder** | Implementation | opus | Code + tests, follows plan exactly |
| **Reviewer** | Code review | opus | Bugs, security, quality (merged Reviewer + Deslopifier) |

### Structured Context (not transcripts)

Instead of passing raw conversation transcripts between agents (~500+ lines), Forge uses structured knowledge artifacts (~60 lines for 3 iterations):

- **`context/decisions.md`** — Decision log with evidence and rejected alternatives
- **`context/patterns.md`** — Discovered codebase conventions
- **`context/loop-learnings.md`** — Per-iteration build-review learnings

Each iteration's Builder reads ALL previous learnings, avoiding repeated mistakes.

```text
context/
├── decisions.md       implementation choices + evidence
├── patterns.md        existing codebase conventions
└── loop-learnings.md  lessons from each review cycle
```

### Build-Review Loop

```
Iteration 1: Builder implements → Reviewer finds issues → Manager logs learnings
Iteration 2: Builder reads learnings → avoids previous mistakes → Reviewer re-checks
Iteration 3: Builder has 2 iterations of knowledge → highly targeted fixes
```

Max iterations: 2 (Tier 2), 3 (Tier 3).

### Backtrack Matrix

When a phase fails, the Manager consults a decision matrix to route to the correct recovery target:

```
EXPLORE fail   → retry EXPLORE (max 2)
ARCHITECT fail → re-EXPLORE or escalate to user
BUILD fail     → fix ARCHITECT or retry BUILD
REVIEW fail    → re-BUILD with issues, or revise ARCHITECT
VERIFY fail    → re-BUILD or revise ARCHITECT
```

Safety limits: max 2 retries per target, max 8 total backtracks.

## Jira Integration

Close the loop: **Jira defines WHAT to build** → **Confluence provides context** → **Forge does the work** → **GitHub gets a PR** → **Jira gets updated**. All autonomous. You never leave Jira.

### Prerequisites

1. Set up the Atlassian MCP server:
   ```bash
   claude mcp add --transport sse atlassian https://mcp.atlassian.com/v1/sse
   ```
2. Initialize config:
   ```bash
   bash ~/.claude/plugins/forge/scripts/jira-config-init.sh
   ```
3. Edit `~/.claude/forge/config.json` with your `cloud_id`, `site_url`, and `default_project`

### Usage

```
/forge:jira PROJ-123                    → Fetch issue → enrich → build → PR → update Jira
/forge:jira-sync                        → Auto-pick highest-priority ready issue from board
```

### Flow

```
/forge:jira PROJ-123
    │
    ▼
JIRA_FETCH (getJiraIssue) → jira-context.json
    │
    ▼
CONFLUENCE_ENRICH (getConfluencePage, searchConfluenceUsingCql) → confluence-context.md
    │
    ▼
SYNTHESIZE → requirements.md (with smart grilling reduction)
    │
    ▼
[existing pipeline: CLASSIFY → EXPLORE → BUILD → REVIEW → ...]
    │
    ▼
SHIP → git push + gh pr create + jira_add_comment + jira_transition_issue
    │
    ▼
COMPOUND → session-summary.md + memory + clean up worktree
```

### Smart Grilling Reduction

Since the user already wrote the Jira ticket, Forge reduces redundant questions:

| Condition | Questions Asked |
|-----------|----------------|
| Has acceptance criteria + Confluence/rich description | 0-1 (minimal) |
| Basic description only | Tier defaults (standard) |
| Epic with subtasks | 1 — confirm which subtasks to implement |

### Configuration

Config lives at `~/.claude/forge/config.json`:

| Section | Key Fields |
|---------|------------|
| `atlassian` | `cloud_id`, `site_url` |
| `jira` | `default_project`, `ready_statuses`, `auto_transition`, `branch_prefix` |
| `confluence` | `default_space_key`, `fetch_linked_pages`, `max_child_depth` |
| `github` | `default_base_branch`, `pr_draft`, `pr_labels`, `pr_reviewers` |
| `sync` | `mode` (single/continuous), `max_issues_per_run`, `priority_order` |

## Mandatory Web Research (Parallel CLI)

Every Tier 2+ session uses [Parallel CLI](https://docs.parallel.ai/integrations/cli) for web research. No more stale training data — agents verify everything against live web results.

### Setup

```bash
bash ~/.claude/plugins/forge/scripts/parallel-setup.sh
```

This installs `parallel-cli`, adds both MCP servers (Search + Task), and verifies auth.

### How It Works

| Agent | What Gets Searched | Tool |
|-------|--------------------|------|
| **Explorer** | Framework docs, dependency versions, known issues | Parallel Search MCP |
| **Architect** | Official docs, comparisons, OWASP, security | Parallel Search MCP + Task MCP |
| **Builder** | Current API docs, auth patterns, error solutions | Parallel Search MCP |
| **Reviewer** | Security best practices, known vulnerabilities | Parallel Search MCP |

### Tools (Priority Order)

1. **Parallel Search MCP** (`search-mcp.parallel.ai/mcp`) — low-latency, agent-optimized
2. **Parallel Task MCP** (`task-mcp.parallel.ai/mcp`) — deep research, async
3. **`parallel-cli search`** via Bash — fallback
4. **WebSearch / Context7** — last resort

All research findings are documented with real URLs in `context/decisions.md`.

## Git Worktree Isolation

All Tier 2 & 3 sessions run in isolated git worktrees. Main branch is never modified during work — only SHIP creates the PR.

### Why Worktrees

- **Peace of mind**: Main branch untouched until PR merge
- **Parallel safety**: Tier 3 parallel agents can't conflict
- **Easy abort**: If session fails, just delete the worktree
- **Multi-issue**: Each Jira issue gets its own isolated workspace

### Lifecycle

```
repo/main
   |
   +--> Session Init
   |      git worktree add ~/.claude/forge/worktrees/<id> -b forge/<branch>
   |
   +--> During Work
   |      all edits happen in the worktree
   |
   +--> SHIP
   |      git push from worktree
   |      gh pr create
   |
   `--> COMPOUND
          git worktree remove
          keep branch if a PR exists
```

Tier 1 (simple tasks, 0-3 complexity) skips worktrees — overhead isn't worth it for single-file fixes.

## TMUX Dashboard (Tier 3)

Inside tmux, a two-column dashboard shows pipeline progress and agent status:

```
┌──────────────────────────────────────────────────────────────┐
│ FORGE: forge-20260311-143022                          opus/4 │
│ Task: "Build real-time chat with WebSocket support"          │
│ Tier: COMPLEX │ Project: brownfield │ Tokens: ~45k           │
├──────────────────────────────┬───────────────────────────────┤
│ PIPELINE                     │ AGENTS                        │
│ [✓] GRILL      0.92         │ Explorer-A  ✓ DONE            │
│ [✓] EXPLORE    0.88         │ Explorer-B  ✓ DONE            │
│ [→] ARCHITECT  .... working │ Architect   → RUNNING         │
│ [ ] BUILD      ----         │ Builder       IDLE            │
│ [ ] REVIEW     ----         │ Reviewer-A    IDLE            │
│ [ ] VERIFY     ----         │ Reviewer-B    IDLE            │
├──────────────────────────────┴───────────────────────────────┤
│ Backtracks: 0/8 │ Loop: build→review #0 │ Confidence: 0.88  │
│ Architect researching WebSocket patterns via Context7...      │
└──────────────────────────────────────────────────────────────┘
```

Outside tmux, inline status lines are printed after each phase.

## Compaction Resilience

Forge survives Claude Code context compaction:
- **Pre-compact hook**: Snapshots state + recent decisions + loop learnings to `recovery-state.md`
- **Post-compact hook**: Injects recovery context so the Manager resumes seamlessly

```text
active session
    |
    +--> PreCompact
    |      write recovery-state.md from forge-state.json
    |
    `--> SessionStart(compact)
           inject recovery-state.md
           resume from recorded phase
```

## Safety Model

The runtime safety story is deliberately small and mechanical:

- `scripts/destructive-guard.sh` blocks obviously destructive Bash tool calls before execution.
- Tier 2 and Tier 3 sessions work in git worktrees rather than the main checkout.
- Recovery always re-reads `forge-state.json`; chat memory is not the source of truth.
- TMUX cleanup records the Forge pane id so teardown only targets the dashboard pane.
- `tests/run.sh` exercises the shell behaviors most likely to regress.

## Session Data

```
~/.claude/forge/sessions/<id>/
├── forge-state.json          # Pipeline state machine
├── requirements.md           # Grilling output
├── jira-context.json         # Raw Jira issue data (Jira sessions)
├── confluence-context.md     # Extracted Confluence content (Jira sessions)
├── ship-result.json          # Branch, PR URL, Jira status (Jira sessions)
├── plan.md                   # Architect output (Tier 3)
├── contracts/                # Shared types (Tier 3)
├── context/
│   ├── decisions.md          # Structured decision log
│   ├── patterns.md           # Discovered codebase patterns
│   └── loop-learnings.md     # Per-iteration learnings
├── diagnostics/
│   └── backtrack-NNN.json    # Failure diagnostics
└── session-summary.md        # Written at completion
```

## Token Efficiency

| Mechanism | Savings |
|-----------|---------|
| Structured context vs transcripts | ~8x fewer tokens |
| Tier routing | 0 agents for simple tasks |
| Explorer on sonnet | ~3x cheaper for exploration |
| Loop-learnings inheritance | Fewer iterations needed |
| 4 agents instead of 9 | ~30% less prompt overhead |

## License

MIT
