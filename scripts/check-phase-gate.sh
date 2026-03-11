#!/usr/bin/env bash

set -euo pipefail

PHASE="${1:?Usage: check-phase-gate.sh <phase> <session-dir>}"
SESSION_DIR="${2:?Usage: check-phase-gate.sh <phase> <session-dir>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_FILE="$SESSION_DIR/forge-state.json"

fail() {
  echo "Gate failed [$PHASE]: $*" >&2
  exit 1
}

require_file() {
  local file_path="${1:?file path required}"
  [ -f "$file_path" ] || fail "missing file $file_path"
}

require_dir() {
  local dir_path="${1:?dir path required}"
  [ -d "$dir_path" ] || fail "missing directory $dir_path"
}

require_heading() {
  local file_path="${1:?file path required}"
  local heading="${2:?heading required}"
  grep -Fq "$heading" "$file_path" || fail "$file_path is missing heading '$heading'"
}

require_nonempty_file() {
  local file_path="${1:?file path required}"
  [ -s "$file_path" ] || fail "$file_path is empty"
}

latest_build_result() {
  local latest=""
  shopt -s nullglob
  local candidates=("$SESSION_DIR"/build-task-*-result.json "$SESSION_DIR"/build-task-*.json)
  shopt -u nullglob
  [ "${#candidates[@]}" -gt 0 ] || return 1
  printf '%s\n' "${candidates[@]}" | sort | tail -n 1
}

require_at_least_one_url() {
  local file_path="${1:?file path required}"
  grep -Eq 'https?://[^ )]+' "$file_path" || fail "$file_path does not contain a source URL"
}

require_array_empty_or_high_confidence() {
  local file_path="${1:?file path required}"
  python3 - "$file_path" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    items = json.load(handle)

for item in items:
    if item["confidence"] < 80:
        print(f"confidence below threshold: {item['confidence']}", file=sys.stderr)
        sys.exit(1)
PY
}

require_file "$STATE_FILE"
bash "$SCRIPT_DIR/validate-state.sh" "$STATE_FILE" >/dev/null

case "$PHASE" in
  classify)
    python3 - "$STATE_FILE" <<'PY' || fail "forge-state.json is missing classification fields"
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    state = json.load(handle)

score = state.get("complexity_score")
project_type = state.get("project_type")
if not isinstance(score, int) or score < 0 or score > 16:
    raise SystemExit(1)
if project_type not in {"greenfield", "brownfield"}:
    raise SystemExit(1)
PY
    ;;
  grill|synthesize)
    require_file "$SESSION_DIR/requirements.md"
    require_nonempty_file "$SESSION_DIR/requirements.md"
    require_heading "$SESSION_DIR/requirements.md" "## Task"
    require_heading "$SESSION_DIR/requirements.md" "## Functional Requirements"
    require_heading "$SESSION_DIR/requirements.md" "## Constraints"
    if ! grep -Fq "## Acceptance Criteria" "$SESSION_DIR/requirements.md" &&
      ! grep -Fq "## Acceptance Criteria (from Jira)" "$SESSION_DIR/requirements.md"; then
      fail "requirements.md is missing an acceptance criteria section"
    fi
    ;;
  explore)
    require_file "$SESSION_DIR/exploration.md"
    require_nonempty_file "$SESSION_DIR/exploration.md"
    require_heading "$SESSION_DIR/exploration.md" "## Project Overview"
    require_heading "$SESSION_DIR/exploration.md" "## Conventions"
    require_heading "$SESSION_DIR/exploration.md" "## Relevant Files"
    require_heading "$SESSION_DIR/exploration.md" "## Test Approach"
    require_heading "$SESSION_DIR/exploration.md" "## Web Research"
    require_heading "$SESSION_DIR/exploration.md" "## Risks & Concerns"
    require_file "$SESSION_DIR/context/patterns.md"
    require_nonempty_file "$SESSION_DIR/context/patterns.md"
    grep -Fq "### Pattern:" "$SESSION_DIR/context/patterns.md" ||
      fail "patterns.md must contain at least one documented pattern"
    ;;
  architect)
    require_file "$SESSION_DIR/plan.md"
    require_nonempty_file "$SESSION_DIR/plan.md"
    require_heading "$SESSION_DIR/plan.md" "## Architecture"
    require_heading "$SESSION_DIR/plan.md" "## Research Citations"
    require_heading "$SESSION_DIR/plan.md" "## Contracts"
    require_heading "$SESSION_DIR/plan.md" "## Tasks"
    require_heading "$SESSION_DIR/plan.md" "## Risks & Mitigations"
    require_at_least_one_url "$SESSION_DIR/plan.md"
    require_dir "$SESSION_DIR/contracts"
    ;;
  build)
    BUILD_RESULT_FILE="$(latest_build_result)" || fail "missing build-task result artifact"
    bash "$SCRIPT_DIR/validate-json.sh" "$ROOT_DIR/schemas/build-task-result.schema.json" "$BUILD_RESULT_FILE" >/dev/null
    python3 - "$BUILD_RESULT_FILE" <<'PY' || fail "build result does not represent a passing build"
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    result = json.load(handle)

if result["status"] != "complete":
    raise SystemExit(1)
if not result["compiled"] or not result["tests_passed"]:
    raise SystemExit(1)
PY
    ;;
  review)
    require_file "$SESSION_DIR/review-issues.json"
    bash "$SCRIPT_DIR/validate-json.sh" "$ROOT_DIR/schemas/review-issues.schema.json" "$SESSION_DIR/review-issues.json" >/dev/null
    require_array_empty_or_high_confidence "$SESSION_DIR/review-issues.json" ||
      fail "review issues must have confidence >= 80"
    ;;
  verify)
    require_file "$SESSION_DIR/verify-result.json"
    bash "$SCRIPT_DIR/validate-json.sh" "$ROOT_DIR/schemas/verify-result.schema.json" "$SESSION_DIR/verify-result.json" >/dev/null
    python3 - "$SESSION_DIR/verify-result.json" <<'PY' || fail "verify-result.json does not represent a passing verification gate"
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    result = json.load(handle)

if result["overall_status"] != "passed":
    raise SystemExit(1)
if not result["build_passed"]:
    raise SystemExit(1)
if result["lint_configured"] and not result["lint_passed"]:
    raise SystemExit(1)
if result["typecheck_configured"] and not result["typecheck_passed"]:
    raise SystemExit(1)
if not result["tests_passed"] or not result["requirements_checked"]:
    raise SystemExit(1)
if result["requirements_gaps"]:
    raise SystemExit(1)
PY
    ;;
  compound)
    require_file "$SESSION_DIR/session-summary.md"
    require_nonempty_file "$SESSION_DIR/session-summary.md"
    ;;
  jira_fetch)
    require_file "$SESSION_DIR/jira-context.json"
    bash "$SCRIPT_DIR/validate-json.sh" "$ROOT_DIR/schemas/jira-context.schema.json" "$SESSION_DIR/jira-context.json" >/dev/null
    ;;
  confluence_enrich)
    require_file "$SESSION_DIR/confluence-context.md"
    require_nonempty_file "$SESSION_DIR/confluence-context.md"
    ;;
  ship)
    require_file "$SESSION_DIR/ship-result.json"
    bash "$SCRIPT_DIR/validate-json.sh" "$ROOT_DIR/schemas/ship-result.schema.json" "$SESSION_DIR/ship-result.json" >/dev/null
    ;;
  *)
    fail "unsupported phase '$PHASE'"
    ;;
esac
