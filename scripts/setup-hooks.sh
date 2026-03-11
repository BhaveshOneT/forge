#!/usr/bin/env bash
# Forge: Validate bundled hook configuration.
# Plugin installs load hooks from hooks/hooks.json automatically.
# Usage: bash setup-hooks.sh

set -euo pipefail

FORGE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_HOOKS="$FORGE_DIR/hooks/hooks.json"
PROJECT_HOOKS="$FORGE_DIR/.claude/settings.json"

echo "Forge Hook Validation"
echo "====================="
echo "Plugin directory: $FORGE_DIR"
echo ""

if [ ! -f "$PLUGIN_HOOKS" ]; then
  echo "Missing plugin hook file: $PLUGIN_HOOKS" >&2
  exit 1
fi

if [ ! -f "$PROJECT_HOOKS" ]; then
  echo "Missing project-local hook file: $PROJECT_HOOKS" >&2
  exit 1
fi

echo "Bundled plugin hooks: $PLUGIN_HOOKS"
echo "Local development hooks: $PROJECT_HOOKS"
echo ""
echo "Runtime behavior:"
echo "  Installed plugin → hooks use \${CLAUDE_PLUGIN_ROOT}"
echo "  This repository → hooks use \${CLAUDE_PROJECT_DIR}"
echo ""
echo "No user-global Claude settings were modified."
echo "Validation complete."
