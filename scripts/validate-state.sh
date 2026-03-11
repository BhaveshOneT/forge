#!/usr/bin/env bash

set -euo pipefail

STATE_FILE="${1:?Usage: validate-state.sh <state-file>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

bash "$SCRIPT_DIR/validate-json.sh" "$ROOT_DIR/schemas/forge-state.schema.json" "$STATE_FILE"
