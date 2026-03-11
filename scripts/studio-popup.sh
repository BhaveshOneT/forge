#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib/forge-common.sh
source "$SCRIPT_DIR/lib/forge-common.sh"

ACTION="${1:?Usage: studio-popup.sh <resolve|open> <session-dir> <target>}"
SESSION_DIR="${2:?Usage: studio-popup.sh <resolve|open> <session-dir> <target>}"
TARGET="${3:?Usage: studio-popup.sh <resolve|open> <session-dir> <target>}"

resolve_target() {
  case "$1" in
    requirements) printf '%s\n' "$SESSION_DIR/requirements.md" ;;
    plan) printf '%s\n' "$SESSION_DIR/plan.md" ;;
    issues) printf '%s\n' "$SESSION_DIR/review-issues.json" ;;
    decisions) printf '%s\n' "$SESSION_DIR/context/decisions.md" ;;
    learnings) printf '%s\n' "$SESSION_DIR/context/loop-learnings.md" ;;
    exploration)
      if [ -f "$SESSION_DIR/exploration.md" ]; then
        printf '%s\n' "$SESSION_DIR/exploration.md"
      elif [ -f "$SESSION_DIR/exploration-architecture.md" ]; then
        printf '%s\n' "$SESSION_DIR/exploration-architecture.md"
      else
        printf '%s\n' "$SESSION_DIR/exploration-code.md"
      fi
      ;;
    verify) printf '%s\n' "$SESSION_DIR/verify-result.json" ;;
    summary) printf '%s\n' "$SESSION_DIR/session-summary.md" ;;
    jira-context) printf '%s\n' "$SESSION_DIR/jira-context.json" ;;
    confluence) printf '%s\n' "$SESSION_DIR/confluence-context.md" ;;
    ship) printf '%s\n' "$SESSION_DIR/ship-result.json" ;;
    help) printf '%s\n' "$SESSION_DIR/studio-help.txt" ;;
    contracts) printf '%s\n' "$SESSION_DIR/contracts" ;;
    build-result)
      python3 - "$SESSION_DIR" <<'PY'
from pathlib import Path
import sys

session_dir = Path(sys.argv[1])
candidates = sorted(session_dir.glob("build-task-*-result.json")) or sorted(session_dir.glob("build-task-*.json"))
if candidates:
    print(candidates[-1])
PY
      ;;
    *) return 1 ;;
  esac
}

render_popup_command() {
  local target_path="${1:-}"
  if [ -z "$target_path" ] || [ ! -e "$target_path" ]; then
    printf "printf 'Forge Studio\\n\\nArtifact unavailable: %s\\n'; read -r -n 1 -s -p 'Press any key to close'" "$TARGET"
    return
  fi

  if [ -d "$target_path" ]; then
    printf "cd %s && ls -la | less" "$(forge_escape_shell_arg "$target_path")"
  else
    printf "less %s" "$(forge_escape_shell_arg "$target_path")"
  fi
}

TARGET_PATH="$(resolve_target "$TARGET" || true)"

case "$ACTION" in
  resolve)
    [ -n "$TARGET_PATH" ] || exit 1
    printf '%s\n' "$TARGET_PATH"
    ;;
  open)
    [ -n "${TMUX:-}" ] || {
      echo "Forge Studio popup requires tmux." >&2
      exit 1
    }
    bash "$SCRIPT_DIR/studio-help.sh" "$SESSION_DIR" >/dev/null
    POPUP_COMMAND="$(render_popup_command "$TARGET_PATH")"
    tmux display-popup -w 80% -h 80% -T "Forge Studio: $TARGET" -E "bash -lc $(printf '%q' "$POPUP_COMMAND")"
    ;;
  *)
    echo "Unknown action '$ACTION'" >&2
    exit 1
    ;;
esac
