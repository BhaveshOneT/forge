#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local haystack="${1:?haystack required}"
  local needle="${2:?needle required}"
  [[ "$haystack" == *"$needle"* ]] || fail "expected to find '$needle'"
}

assert_not_contains() {
  local haystack="${1:?haystack required}"
  local needle="${2:?needle required}"
  [[ "$haystack" != *"$needle"* ]] || fail "did not expect to find '$needle'"
}

assert_file_contains() {
  local file_path="${1:?file path required}"
  local needle="${2:?needle required}"
  assert_contains "$(cat "$file_path")" "$needle"
}

write_state() {
  local file_path="${1:?file path required}"
  local session_id="${2:?session id required}"
  local phase="${3:?phase required}"
  local checkpoint="${4:-resume me}"

  cat >"$file_path" <<EOF
{
  "session_id": "$session_id",
  "current_phase": "$phase",
  "phase_attempt": 1,
  "total_backtracks": 0,
  "tier": 2,
  "build_review_loop": 0,
  "execution_mode": "prompt",
  "checkpoint": "$checkpoint",
  "source": "",
  "jira_issue_key": "",
  "worktree_path": ""
}
EOF
}

set_state_field() {
  local file_path="${1:?file path required}"
  local python_update="${2:?python update required}"

  python3 - "$file_path" "$python_update" <<'PY'
import json
import sys

path = sys.argv[1]
update = sys.argv[2]

with open(path, encoding="utf-8") as handle:
    data = json.load(handle)

namespace = {"data": data}
exec(update, {"__builtins__": {}}, namespace)
data = namespace["data"]

with open(path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
}

run_destructive_guard_tests() {
  local stdout_file stderr_file status
  stdout_file="$(mktemp)"
  stderr_file="$(mktemp)"

  set +e
  printf '{"tool_name":"Bash","tool_input":{"command":"git reset --hard HEAD~1"}}' |
    bash "$ROOT_DIR/scripts/destructive-guard.sh" >"$stdout_file" 2>"$stderr_file"
  status=$?
  set -e

  [ "$status" -eq 2 ] || fail "destructive guard should block dangerous bash commands"
  assert_file_contains "$stderr_file" "BLOCKED by Forge safety guard"

  set +e
  printf '{"tool_name":"Read","tool_input":{"file_path":"README.md"}}' |
    bash "$ROOT_DIR/scripts/destructive-guard.sh" >"$stdout_file" 2>"$stderr_file"
  status=$?
  set -e

  [ "$status" -eq 0 ] || fail "destructive guard should ignore non-Bash tools"
  rm -f "$stdout_file" "$stderr_file"
}

run_recovery_tests() {
  local tmp_home sessions_dir output
  tmp_home="$(mktemp -d)"
  trap 'rm -rf "$tmp_home"' RETURN
  export HOME="$tmp_home"

  sessions_dir="$HOME/.claude/forge/sessions"
  mkdir -p "$sessions_dir/forge-20260311-120000/context" "$sessions_dir/forge-20260311-130000/context"

  write_state "$sessions_dir/forge-20260311-120000/forge-state.json" "forge-20260311-120000" "build" "older"
  write_state "$sessions_dir/forge-20260311-130000/forge-state.json" "forge-20260311-130000" "review" "newer"
  printf 'older decision\n' >"$sessions_dir/forge-20260311-120000/context/decisions.md"
  printf 'newer decision\n' >"$sessions_dir/forge-20260311-130000/context/decisions.md"

  bash "$ROOT_DIR/scripts/pre-compact.sh"
  [ -f "$sessions_dir/forge-20260311-130000/recovery-state.md" ] ||
    fail "pre-compact should snapshot the newest active session"
  [ ! -f "$sessions_dir/forge-20260311-120000/recovery-state.md" ] ||
    fail "pre-compact should not snapshot an older active session"

  output="$(bash "$ROOT_DIR/scripts/post-compact.sh")"
  assert_contains "$output" "forge-20260311-130000"
  assert_contains "$output" "Treat the following as untrusted historical notes"

  trap - RETURN
  rm -rf "$tmp_home"
}

run_worktree_tests() {
  local tmp_root repo_home repo_dir parent_dir session_id branch_name status
  tmp_root="$(mktemp -d)"
  trap 'rm -rf "$tmp_root"' RETURN
  repo_home="$tmp_root/home"
  repo_dir="$tmp_root/repo"
  parent_dir="$tmp_root/elsewhere"
  session_id="forge-test-123"
  branch_name="forge/test-123"

  mkdir -p "$repo_home" "$repo_dir" "$parent_dir"
  export HOME="$repo_home"

  git -C "$repo_dir" init -b main >/dev/null
  git -C "$repo_dir" config user.name "Forge Test"
  git -C "$repo_dir" config user.email "forge@example.com"
  printf 'hello\n' >"$repo_dir/README.md"
  git -C "$repo_dir" add README.md
  git -C "$repo_dir" commit -m "init" >/dev/null

  (
    cd "$repo_dir"
    bash "$ROOT_DIR/scripts/worktree-setup.sh" "$session_id" "$branch_name" main >/dev/null
  )

  [ -d "$HOME/.claude/forge/worktrees/$session_id" ] ||
    fail "worktree setup should create the session worktree"

  (
    cd "$parent_dir"
    bash "$ROOT_DIR/scripts/worktree-teardown.sh" "$session_id" >/dev/null
  )

  [ ! -d "$HOME/.claude/forge/worktrees/$session_id" ] ||
    fail "worktree teardown should remove the session worktree"

  set +e
  bash "$ROOT_DIR/scripts/worktree-teardown.sh" "../escape" >/dev/null 2>&1
  status=$?
  set -e
  [ "$status" -ne 0 ] || fail "worktree teardown should reject unsafe session ids"

  trap - RETURN
  rm -rf "$tmp_root"
}

run_validation_tests() {
  local tmp_root session_dir
  tmp_root="$(mktemp -d)"
  trap 'rm -rf "$tmp_root"' RETURN
  session_dir="$tmp_root/session"
  mkdir -p "$session_dir/context" "$session_dir/contracts"

  write_state "$session_dir/forge-state.json" "forge-20260311-140000" "verify" "validate"
  set_state_field "$session_dir/forge-state.json" $'data["complexity_score"] = 8\ndata["project_type"] = "brownfield"\ndata["project_dir"] = "/tmp/project"'

  cat >"$session_dir/requirements.md" <<'EOF'
# Requirements — forge-20260311-140000

## Task
Validate a session

## Functional Requirements
- [ ] Something real

## Constraints
- Keep it deterministic

## Acceptance Criteria
- [ ] Works
EOF

  cat >"$session_dir/exploration.md" <<'EOF'
# Exploration: Full

## Project Overview
- Framework: none

## Conventions
- Naming: simple

## Relevant Files
- README.md

## Test Approach
- Test framework: bash

## Web Research
- **Query**: bash testing
- **Source**: https://example.com/bash
- **Finding**: good enough
- **Impact**: validates the gate

## Risks & Concerns
- none
EOF

  cat >"$session_dir/context/patterns.md" <<'EOF'
### Pattern: Minimal
**Found in**: README.md
**Convention**: Keep examples concise
**Apply to**: Tests
EOF

  cat >"$session_dir/plan.md" <<'EOF'
# Implementation Plan

## Architecture
Simple.

## Research Citations
- Bash: https://example.com/bash

## Contracts
- None

## Tasks
### Task 1: Validate
- **Files**: `README.md`
- **Description**: Validate output
- **Dependencies**: None
- **Acceptance**: Gate passes

## Risks & Mitigations
- **Risk**: None
EOF

  cat >"$session_dir/build-task-1-result.json" <<'EOF'
{
  "task_number": 1,
  "status": "complete",
  "files_created": [],
  "files_modified": ["README.md"],
  "tests_written": ["tests/run.sh"],
  "compiled": true,
  "tests_passed": true,
  "notes": "validated"
}
EOF

  cat >"$session_dir/review-issues.json" <<'EOF'
[]
EOF

  cat >"$session_dir/verify-result.json" <<'EOF'
{
  "build_passed": true,
  "lint_configured": false,
  "lint_passed": false,
  "typecheck_configured": false,
  "typecheck_passed": false,
  "tests_passed": true,
  "requirements_checked": true,
  "requirements_gaps": [],
  "overall_status": "passed",
  "notes": "all checks passed"
}
EOF

  cat >"$session_dir/session-summary.md" <<'EOF'
# Session Summary
Done.
EOF

  bash "$ROOT_DIR/scripts/validate-state.sh" "$session_dir/forge-state.json"
  bash "$ROOT_DIR/scripts/check-phase-gate.sh" classify "$session_dir"
  bash "$ROOT_DIR/scripts/check-phase-gate.sh" grill "$session_dir"
  bash "$ROOT_DIR/scripts/check-phase-gate.sh" explore "$session_dir"
  bash "$ROOT_DIR/scripts/check-phase-gate.sh" architect "$session_dir"
  bash "$ROOT_DIR/scripts/check-phase-gate.sh" build "$session_dir"
  bash "$ROOT_DIR/scripts/check-phase-gate.sh" review "$session_dir"
  bash "$ROOT_DIR/scripts/check-phase-gate.sh" verify "$session_dir"
  bash "$ROOT_DIR/scripts/check-phase-gate.sh" compound "$session_dir"

  set_state_field "$session_dir/forge-state.json" 'data["current_phase"] = "bad-phase"'

  set +e
  bash "$ROOT_DIR/scripts/validate-state.sh" "$session_dir/forge-state.json" >/dev/null 2>&1
  local status=$?
  set -e
  [ "$status" -ne 0 ] || fail "validate-state should reject invalid phase names"

  write_state "$session_dir/forge-state.json" "forge-20260311-140000" "verify" "validate"
  set_state_field "$session_dir/forge-state.json" 'data["execution_mode"] = "broken"'
  set +e
  bash "$ROOT_DIR/scripts/validate-state.sh" "$session_dir/forge-state.json" >/dev/null 2>&1
  status=$?
  set -e
  [ "$status" -ne 0 ] || fail "validate-state should reject invalid execution modes"

  trap - RETURN
  rm -rf "$tmp_root"
}

run_studio_dependency_tests() {
  local tmp_root fake_bin status output
  tmp_root="$(mktemp -d)"
  trap 'rm -rf "$tmp_root"' RETURN
  fake_bin="$tmp_root/bin"
  mkdir -p "$fake_bin"

  # Create a controlled PATH with only the tools we want
  ln -s "$(command -v bash)" "$fake_bin/bash"
  ln -s "$(command -v python3)" "$fake_bin/python3"
  ln -s "$(command -v env)" "$fake_bin/env" 2>/dev/null || true
  ln -s "$(command -v tmux)" "$fake_bin/tmux"
  printf '#!/usr/bin/env bash\nexit 0\n' >"$fake_bin/lazygit"
  chmod +x "$fake_bin/lazygit"

  PATH="$fake_bin" bash "$ROOT_DIR/scripts/studio-check-deps.sh" >/dev/null

  rm -f "$fake_bin/lazygit"
  set +e
  output="$(PATH="$fake_bin" bash "$ROOT_DIR/scripts/studio-check-deps.sh" 2>&1)"
  status=$?
  set -e
  [ "$status" -ne 0 ] || fail "studio-check-deps should fail without lazygit"
  assert_contains "$output" "Missing required tools: lazygit"

  printf '#!/usr/bin/env bash\nexit 0\n' >"$fake_bin/lazygit"
  chmod +x "$fake_bin/lazygit"
  rm -f "$fake_bin/tmux"
  set +e
  output="$(PATH="$fake_bin" bash "$ROOT_DIR/scripts/studio-check-deps.sh" 2>&1)"
  status=$?
  set -e
  [ "$status" -ne 0 ] || fail "studio-check-deps should fail without tmux"
  assert_contains "$output" "Missing required tools: tmux"

  trap - RETURN
  rm -rf "$tmp_root"
}

run_studio_runtime_tests() {
  local tmp_root fake_bin repo_dir repo_dir_real session_dir gitpane_session_dir jira_session_dir state_file gitpane_state_file jira_state_file session_name other_session render_output popup_path help_output jira_render_output jira_help_output attach_output agent_log pane_titles pane_count
  tmp_root="$(mktemp -d)"
  trap 'rm -rf "$tmp_root"' RETURN
  fake_bin="$tmp_root/bin"
  repo_dir="$tmp_root/repo"
  session_dir="$tmp_root/session"
  gitpane_session_dir="$tmp_root/gitpane-session"
  jira_session_dir="$tmp_root/jira-session"
  mkdir -p "$fake_bin" "$repo_dir" "$session_dir/context" "$session_dir/contracts" "$gitpane_session_dir/context" "$gitpane_session_dir/contracts" "$jira_session_dir/context" "$jira_session_dir/contracts"

  ln -s "$(command -v tmux)" "$fake_bin/tmux"
  cat >"$fake_bin/lazygit" <<'EOF'
#!/usr/bin/env bash
printf 'fake lazygit %s\n' "$PWD" >>"${FORGE_STUDIO_TEST_LOG:-/tmp/forge-studio-lazygit.log}"
sleep 2
EOF
  chmod +x "$fake_bin/lazygit"

  git -C "$repo_dir" init -b main >/dev/null
  git -C "$repo_dir" config user.name "Forge Studio Test"
  git -C "$repo_dir" config user.email "studio@example.com"
  printf 'hi\n' >"$repo_dir/README.md"
  git -C "$repo_dir" add README.md
  git -C "$repo_dir" commit -m "init" >/dev/null
  repo_dir_real="$(git -C "$repo_dir" rev-parse --show-toplevel)"

  state_file="$session_dir/forge-state.json"
  write_state "$state_file" "forge-20260311-150000" "build" "studio"
  set_state_field "$state_file" $'data["tier"] = 2\ndata["complexity_score"] = 6\ndata["project_type"] = "brownfield"\ndata["project_dir"] = "'"$repo_dir"$'"\ndata["user_request"] = "Build studio"\ndata["phase_history"] = [{"phase": "classify", "status": "complete", "confidence": 0.9}]\ndata["build_tasks"] = [{"status": "complete"}, {"status": "running"}]'

  cat >"$session_dir/requirements.md" <<'EOF'
# Requirements
## Task
Build studio
## Functional Requirements
- [ ] Workspace
## Constraints
- Terminal only
## Acceptance Criteria
- [ ] Works
EOF
  cat >"$session_dir/plan.md" <<'EOF'
# Implementation Plan

## Architecture
Studio

## Research Citations
- tmux: https://example.com/tmux

## Contracts
- none

## Tasks
### Task 1: Studio
- **Files**: `scripts/tmux-setup.sh`
- **Description**: Create studio
- **Dependencies**: None
- **Acceptance**: Layout exists

## Risks & Mitigations
- **Risk**: none
EOF
  cat >"$session_dir/context/decisions.md" <<'EOF'
### [BUILDER] — now
**Decision**: studio
EOF
  cat >"$session_dir/context/loop-learnings.md" <<'EOF'
### Iteration 1
**Built**: studio
EOF
  cat >"$session_dir/exploration.md" <<'EOF'
# Exploration: Studio

## Project Overview
- Framework: shell

## Conventions
- bash

## Relevant Files
- scripts/tmux-setup.sh

## Test Approach
- bash

## Web Research
- **Query**: tmux layout
- **Source**: https://example.com/tmux
- **Finding**: good
- **Impact**: okay

## Risks & Concerns
- none
EOF
  cat >"$session_dir/review-issues.json" <<'EOF'
[]
EOF
  cat >"$session_dir/verify-result.json" <<'EOF'
{
  "build_passed": true,
  "lint_configured": false,
  "lint_passed": false,
  "typecheck_configured": false,
  "typecheck_passed": false,
  "tests_passed": true,
  "requirements_checked": true,
  "requirements_gaps": [],
  "overall_status": "passed",
  "notes": "good"
}
EOF
  cat >"$session_dir/session-summary.md" <<'EOF'
# Session Summary
Good.
EOF

  export FORGE_STUDIO_TEST_LOG="$tmp_root/lazygit.log"
  PATH="$fake_bin:/usr/bin:/bin" bash "$ROOT_DIR/scripts/studio-check-deps.sh" >/dev/null
  session_name="$(PATH="$fake_bin:/usr/bin:/bin" bash "$ROOT_DIR/scripts/studio-session.sh" create "$session_dir" "$repo_dir")"
  assert_contains "$session_name" "forge-forge-20260311-150000"
  PATH="$fake_bin:/usr/bin:/bin" bash "$ROOT_DIR/scripts/studio-layout.sh" apply "$session_dir" build "$repo_dir" >/dev/null

  [ -f "$session_dir/studio-layout.json" ] || fail "studio-layout.json should exist"
  bash "$ROOT_DIR/scripts/validate-json.sh" "$ROOT_DIR/schemas/studio-layout.schema.json" "$session_dir/studio-layout.json" >/dev/null
  bash "$ROOT_DIR/scripts/validate-state.sh" "$state_file" >/dev/null
  assert_file_contains "$state_file" '"studio_layout_mode": "build"'
  assert_file_contains "$state_file" '"studio_session_name": "forge-forge-20260311-150000"'
  assert_file_contains "$state_file" '"execution_mode": "prompt"'

  popup_path="$(bash "$ROOT_DIR/scripts/studio-popup.sh" resolve "$session_dir" plan)"
  assert_contains "$popup_path" "$session_dir/plan.md"
  popup_path="$(bash "$ROOT_DIR/scripts/studio-popup.sh" resolve "$session_dir" help || true)"
  [ -z "$popup_path" ] || true

  bash "$ROOT_DIR/scripts/studio-help.sh" "$session_dir" >/dev/null
  help_output="$(bash "$ROOT_DIR/scripts/studio-help.sh" "$session_dir" --print)"
  assert_contains "$help_output" "Execution mode: prompt"
  assert_contains "$help_output" "Prompt mode emphasis"
  popup_path="$(bash "$ROOT_DIR/scripts/studio-popup.sh" resolve "$session_dir" help)"
  assert_contains "$popup_path" "$session_dir/studio-help.txt"

  render_output="$(bash "$ROOT_DIR/scripts/tmux-render.sh" "$session_dir")"
  assert_contains "$render_output" "Forge Studio"
  assert_contains "$render_output" "entry=prompt layout=build status=active"
  attach_output="$(PATH="$fake_bin:/usr/bin:/bin" bash "$ROOT_DIR/scripts/studio-session.sh" attach "$session_dir")"
  assert_contains "$attach_output" "Forge Studio session created detached: $session_name"
  assert_contains "$attach_output" "tmux attach -t $session_name"

  agent_log="$(PATH="$fake_bin:/usr/bin:/bin" bash "$ROOT_DIR/scripts/studio-agents.sh" register "$session_dir" "builder-1" "builder" "Builder-1" "subagent" "Implement task 1")"
  [ -f "$agent_log" ] || fail "studio-agents register should create an agent log"
  PATH="$fake_bin:/usr/bin:/bin" bash "$ROOT_DIR/scripts/studio-agents.sh" note "$session_dir" "builder-1" "working on contract wiring"
  assert_file_contains "$agent_log" "working on contract wiring"
  pane_titles="$(tmux list-panes -t "$session_name:0" -F '#{pane_title}')"
  assert_contains "$pane_titles" "Forge Agent: Builder-1"
  assert_file_contains "$session_dir/studio-layout.json" '"agent_id": "builder-1"'
  PATH="$fake_bin:/usr/bin:/bin" bash "$ROOT_DIR/scripts/studio-agents.sh" complete "$session_dir" "builder-1" "complete" "task finished"
  pane_titles="$(tmux list-panes -t "$session_name:0" -F '#{pane_title}')"
  assert_not_contains "$pane_titles" "Forge Agent: Builder-1"

  PATH="$fake_bin:/usr/bin:/bin" bash "$ROOT_DIR/scripts/studio-layout.sh" apply "$session_dir" swarm "$repo_dir" >/dev/null
  PATH="$fake_bin:/usr/bin:/bin" bash "$ROOT_DIR/scripts/studio-agents.sh" register "$session_dir" "explorer-a" "explorer" "Explorer-A" "team" "Map architecture" >/dev/null
  PATH="$fake_bin:/usr/bin:/bin" bash "$ROOT_DIR/scripts/studio-agents.sh" register "$session_dir" "explorer-b" "explorer" "Explorer-B" "team" "Map relevant code" >/dev/null
  pane_titles="$(tmux list-panes -t "$session_name:0" -F '#{pane_title}')"
  assert_contains "$pane_titles" "Forge Agent: Explorer-A"
  assert_contains "$pane_titles" "Forge Agent: Explorer-B"
  pane_count="$(tmux list-panes -t "$session_name:0" | wc -l | tr -d ' ')"
  [ "$pane_count" -ge 5 ] || fail "swarm mode should create separate panes for active agents"
  render_output="$(bash "$ROOT_DIR/scripts/tmux-render.sh" "$session_dir")"
  assert_contains "$render_output" "AGENT SWARM"
  assert_contains "$render_output" "Explorer-A: Map architecture"
  PATH="$fake_bin:/usr/bin:/bin" bash "$ROOT_DIR/scripts/studio-agents.sh" complete "$session_dir" "explorer-a" "complete" "architecture mapped" >/dev/null
  PATH="$fake_bin:/usr/bin:/bin" bash "$ROOT_DIR/scripts/studio-agents.sh" complete "$session_dir" "explorer-b" "complete" "code mapped" >/dev/null

  gitpane_state_file="$gitpane_session_dir/forge-state.json"
  write_state "$gitpane_state_file" "forge-20260311-155500" "build" "git pane"
  set_state_field "$gitpane_state_file" $'data["project_dir"] = "/Users/bhaveshy"\ndata["worktree_path"] = "'"$repo_dir"$'"'
  PATH="$fake_bin:/usr/bin:/bin" bash "$ROOT_DIR/scripts/studio-git-pane.sh" "$gitpane_session_dir" >/dev/null 2>&1
  assert_file_contains "$FORGE_STUDIO_TEST_LOG" "fake lazygit $repo_dir_real"

  jira_state_file="$jira_session_dir/forge-state.json"
  write_state "$jira_state_file" "forge-20260311-160000" "ship" "jira studio"
  set_state_field "$jira_state_file" $'data["execution_mode"] = "jira"\ndata["source"] = "jira"\ndata["tier"] = 2\ndata["project_type"] = "brownfield"\ndata["project_dir"] = "'"$repo_dir"$'"\ndata["user_request"] = "Ship jira issue"\ndata["jira_issue_key"] = "PROJ-123"\ndata["ship_result"] = {"pr_url": "https://example.com/pr/123"}'
  cat >"$jira_session_dir/jira-context.json" <<'EOF'
{
  "key": "PROJ-123",
  "summary": "Ship jira issue",
  "description": "Jira flow",
  "issue_type": "Story"
}
EOF
  cat >"$jira_session_dir/confluence-context.md" <<'EOF'
# Confluence Context
Useful design notes.
EOF
  cat >"$jira_session_dir/ship-result.json" <<'EOF'
{
  "branch": "forge/PROJ-123-ship",
  "pr_url": "https://example.com/pr/123",
  "jira_comment_added": true,
  "jira_transitioned": false
}
EOF
  bash "$ROOT_DIR/scripts/studio-help.sh" "$jira_session_dir" >/dev/null
  jira_help_output="$(bash "$ROOT_DIR/scripts/studio-help.sh" "$jira_session_dir" --print)"
  assert_contains "$jira_help_output" "Execution mode: jira"
  assert_contains "$jira_help_output" "Jira mode artifacts"
  assert_contains "$jira_help_output" "j  Open Jira context popup"
  popup_path="$(bash "$ROOT_DIR/scripts/studio-popup.sh" resolve "$jira_session_dir" jira-context)"
  assert_contains "$popup_path" "$jira_session_dir/jira-context.json"
  popup_path="$(bash "$ROOT_DIR/scripts/studio-popup.sh" resolve "$jira_session_dir" confluence)"
  assert_contains "$popup_path" "$jira_session_dir/confluence-context.md"
  popup_path="$(bash "$ROOT_DIR/scripts/studio-popup.sh" resolve "$jira_session_dir" ship)"
  assert_contains "$popup_path" "$jira_session_dir/ship-result.json"
  jira_render_output="$(bash "$ROOT_DIR/scripts/tmux-render.sh" "$jira_session_dir")"
  assert_contains "$jira_render_output" "entry=jira layout=unknown status=inactive"
  assert_contains "$jira_render_output" "Jira: PROJ-123"

  other_session="not-forge-studio"
  tmux new-session -d -s "$other_session" -c "$repo_dir"
  PATH="$fake_bin:/usr/bin:/bin" bash "$ROOT_DIR/scripts/tmux-teardown.sh" "$session_dir" >/dev/null
  if tmux has-session -t "$session_name" 2>/dev/null; then
    fail "tmux-teardown should destroy the targeted Forge Studio session"
  fi
  tmux has-session -t "$other_session" 2>/dev/null ||
    fail "tmux-teardown should not destroy unrelated tmux sessions"
  tmux kill-session -t "$other_session" >/dev/null 2>&1 || true

  PATH="$ROOT_DIR/scripts:$PATH" bash -lc 'source "'"$ROOT_DIR"'/scripts/lib/forge-common.sh"; [ "$(forge_studio_mode_for_tier 1)" = "focus" ] && [ "$(forge_studio_mode_for_tier 2)" = "build" ] && [ "$(forge_studio_mode_for_tier 3)" = "swarm" ]'
  PATH="$ROOT_DIR/scripts:$PATH" bash -lc 'source "'"$ROOT_DIR"'/scripts/lib/forge-common.sh"; [ "$(forge_resolve_workspace_dir "" "'"$session_dir"'")" = "'"$session_dir"'" ]'
  PATH="$ROOT_DIR/scripts:$PATH" bash -lc 'source "'"$ROOT_DIR"'/scripts/lib/forge-common.sh"; [ "$(forge_find_git_root "'"$repo_dir"'")" = "'"$repo_dir_real"'" ]'
  PATH="$ROOT_DIR/scripts:$PATH" bash -lc 'source "'"$ROOT_DIR"'/scripts/lib/forge-common.sh"; [ "$(forge_execution_mode_from_state "'"$state_file"'")" = "prompt" ]'
  PATH="$ROOT_DIR/scripts:$PATH" bash -lc 'source "'"$ROOT_DIR"'/scripts/lib/forge-common.sh"; [ "$(forge_execution_mode_from_state "'"$jira_state_file"'")" = "jira" ]'

  set_state_field "$jira_state_file" 'data.pop("execution_mode", None)'
  PATH="$ROOT_DIR/scripts:$PATH" bash -lc 'source "'"$ROOT_DIR"'/scripts/lib/forge-common.sh"; [ "$(forge_execution_mode_from_state "'"$jira_state_file"'")" = "jira" ]'

  trap - RETURN
  rm -rf "$tmp_root"
}

run_metadata_tests() {
  assert_file_contains "$ROOT_DIR/.claude-plugin/plugin.json" '"version": "1.5.0"'
  assert_file_contains "$ROOT_DIR/.claude-plugin/marketplace.json" '"version": "1.5.0"'
  assert_file_contains "$ROOT_DIR/.claude-plugin/plugin.json" '"hooks": "./hooks/hooks.json"'
  assert_file_contains "$ROOT_DIR/hooks/hooks.json" '${CLAUDE_PLUGIN_ROOT}'
  assert_file_contains "$ROOT_DIR/.claude/settings.json" '${CLAUDE_PROJECT_DIR}'
}

run_destructive_guard_tests
run_recovery_tests
run_worktree_tests
run_validation_tests
run_studio_dependency_tests
run_studio_runtime_tests
run_metadata_tests

echo "All tests passed."
