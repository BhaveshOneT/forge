# Forge — Dynamic Agent Orchestrator

A Claude Code plugin that adapts to task complexity. Simple tasks get direct execution, medium tasks get 3 agents, complex tasks get the full swarm with a TMUX dashboard.

## Installation

```bash
# Via Claude Code marketplace (when published)
# Or manually:
git clone https://github.com/BhaveshY/forge.git ~/.claude/plugins/forge
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

## Session Data

```
~/.claude/forge/sessions/<id>/
├── forge-state.json          # Pipeline state machine
├── requirements.md           # Grilling output
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

## Comparison with Knight Manager

| Dimension | Knight Manager | Forge |
|-----------|---------------|-------|
| Agents | 9 (always all) | 4 (only when needed) |
| Phases | 10 (fixed) | 3-8 (adaptive) |
| User gates | Plan approval required | Full autonomy after grilling |
| Context | shared-notes.md (freeform) | Structured artifacts (decisions, patterns, learnings) |
| TMUX | Single column | Two-column with agent status |
| Token range | ~200-300k always | ~5k-300k depending on tier |

## License

MIT
