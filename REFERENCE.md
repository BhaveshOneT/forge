# Forge — Phase Protocols & Reference

Detailed phase protocols, dispatch templates, gate conditions, and the backtrack decision matrix. The Manager (SKILL.md) references this for all phase execution details.

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

---

## Phase: GRILL

**Action**: Manager asks questions directly via `AskUserQuestion` (no subagent).

ALL questions in ONE call. After response, write `requirements.md`.

**Gate**: Requirements written with clear scope, acceptance criteria, and constraints.

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

**After both complete**: Manager merges into `exploration.md`.

**Gate**: `exploration.md` exists with sections: conventions, patterns, relevant files, test approach. `context/patterns.md` populated.

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

**After both complete**: Manager merges into `review-issues.json`, deduplicating by file+line.

**Gate**: 0 critical issues. If critical → backtrack per matrix.

---

## Phase: VERIFY (Tier 3 only)

**Action**: Manager runs directly (no subagent):
1. Build the project
2. Run linter (if configured)
3. Run type checker (if configured)
4. Run full test suite
5. Check requirements line-by-line against requirements.md

**Gate**: ALL checks pass. If any fail → backtrack per matrix.

---

## Phase: COMPOUND

**Action**: Manager runs directly:
1. Write `session-summary.md` from template
2. Extract learnings to `~/.claude/forge/memory/MEMORY.md`
3. Tear down TMUX if active
4. Mark session complete

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
EXPLORE backtrack    → re-run ARCHITECT → BUILD → REVIEW → VERIFY
ARCHITECT backtrack  → re-run BUILD → REVIEW → VERIFY
BUILD backtrack      → re-run REVIEW → VERIFY
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
| Explorer | Files analyzed, patterns documented, conventions found |
| Architect | tier1_sources≥1 (0.4) + contracts_defined (0.3) + alternatives_compared (0.2) + risks_documented (0.1) |
| Builder | Compiles, tests pass, follows contracts, matches plan task |
| Reviewer | Issue count by severity (independently counted), confidence ≥80 only |

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
  "tmux_active": false
}
```
