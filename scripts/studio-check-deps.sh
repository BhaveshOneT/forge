#!/usr/bin/env bash

set -euo pipefail

REQUIRED_TOOLS=(tmux lazygit bash python3)
MISSING=()

for tool in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    MISSING+=("$tool")
  fi
done

if [ "${#MISSING[@]}" -gt 0 ]; then
  {
    echo "Forge Studio cannot start."
    echo "Missing required tools: ${MISSING[*]}"
    echo "Required: tmux lazygit bash python3"
  } >&2
  exit 1
fi

echo "Forge Studio dependencies ready."
