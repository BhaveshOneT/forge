#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib/forge-common.sh
source "$SCRIPT_DIR/lib/forge-common.sh"

COMMAND="${1:?Usage: studio-session.sh <name|exists|create|attach|focus|destroy> ...}"

session_dir_for_name() {
  local session_name="${1:?session name required}"
  forge_tmux_option "$session_name" "@forge_session_dir"
}

resolve_session_name() {
  local session_dir="${1:-}"
  if [ -n "$session_dir" ]; then
    local state_file="$session_dir/forge-state.json"
    if [ -f "$state_file" ]; then
      local session_id
      session_id="$(forge_json_get "$state_file" "data.get('session_id', '')")"
      if [ -n "$session_id" ]; then
        forge_studio_session_name "$session_id"
        return
      fi
    fi
    forge_studio_session_name "$(basename "$session_dir")"
    return
  fi

  if [ -n "${TMUX:-}" ]; then
    tmux display-message -p '#{session_name}'
    return
  fi

  echo "Unable to resolve tmux session name." >&2
  exit 1
}

case "$COMMAND" in
  name)
    resolve_session_name "${2:?Usage: studio-session.sh name <session-dir>}"
    ;;
  exists)
    SESSION_NAME="$(resolve_session_name "${2:?Usage: studio-session.sh exists <session-dir>}")"
    tmux has-session -t "$SESSION_NAME" 2>/dev/null
    ;;
  create)
    SESSION_DIR="${2:?Usage: studio-session.sh create <session-dir> <project-dir>}"
    PROJECT_DIR="${3:?Usage: studio-session.sh create <session-dir> <project-dir>}"
    WORKSPACE_DIR="$(forge_resolve_workspace_dir "$PROJECT_DIR" "$SESSION_DIR")"
    SESSION_NAME="$(resolve_session_name "$SESSION_DIR")"
    if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
      tmux new-session -d -s "$SESSION_NAME" -c "$WORKSPACE_DIR"
    fi
    forge_tmux_set_option "$SESSION_NAME" "@forge_studio" "true"
    forge_tmux_set_option "$SESSION_NAME" "@forge_session_dir" "$SESSION_DIR"
    forge_tmux_set_option "$SESSION_NAME" "@forge_session_name" "$SESSION_NAME"
    printf '%s\n' "$SESSION_NAME"
    ;;
  attach)
    SESSION_DIR="${2:?Usage: studio-session.sh attach <session-dir>}"
    SESSION_NAME="$(resolve_session_name "$SESSION_DIR")"
    if [ -n "${TMUX:-}" ]; then
      tmux switch-client -t "$SESSION_NAME"
    elif forge_has_tty; then
      tmux attach-session -t "$SESSION_NAME"
    else
      printf 'Forge Studio session created detached: %s\n' "$SESSION_NAME"
      printf 'Attach manually from a real terminal: tmux attach -t %s\n' "$SESSION_NAME"
    fi
    ;;
  focus)
    ROLE="${2:?Usage: studio-session.sh focus <session-dir> <main|git|status>}"
    SESSION_DIR="${3:?Usage: studio-session.sh focus <session-dir> <main|git|status>}"
    SESSION_NAME="$(resolve_session_name "$SESSION_DIR")"
    PANE_ID="$(forge_tmux_option "$SESSION_NAME" "@forge_pane_${ROLE}")"
    [ -n "$PANE_ID" ] || {
      echo "No pane registered for role '$ROLE'" >&2
      exit 1
    }
    tmux select-pane -t "$PANE_ID"
    ;;
  focus-current)
    ROLE="${2:?Usage: studio-session.sh focus-current <main|git|status>}"
    SESSION_NAME="$(resolve_session_name)"
    SESSION_DIR="$(session_dir_for_name "$SESSION_NAME")"
    [ -n "$SESSION_DIR" ] || {
      echo "Current tmux session is not a Forge Studio session." >&2
      exit 1
    }
    "$0" focus "$ROLE" "$SESSION_DIR"
    ;;
  destroy)
    SESSION_DIR="${2:?Usage: studio-session.sh destroy <session-dir>}"
    SESSION_NAME="$(resolve_session_name "$SESSION_DIR")"
    tmux kill-session -t "$SESSION_NAME"
    ;;
  *)
    echo "Unknown command '$COMMAND'" >&2
    exit 1
    ;;
esac
