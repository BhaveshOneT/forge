#!/usr/bin/env bash
# Forge: One-time hook installation
# Adds forge hooks to the user's Claude Code settings.
# Usage: bash setup-hooks.sh

set -euo pipefail

FORGE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

echo "Forge Hook Setup"
echo "================"
echo "Plugin directory: $FORGE_DIR"
echo ""

# Check if settings file exists
if [ ! -f "$CLAUDE_SETTINGS" ]; then
  echo "No Claude settings found at $CLAUDE_SETTINGS"
  echo "Creating minimal settings with forge hooks..."
  mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
  cat > "$CLAUDE_SETTINGS" << 'EOF'
{
  "hooks": {}
}
EOF
fi

echo "Forge hooks are configured in .claude/settings.json within the plugin directory."
echo "They will be active when the forge plugin is installed."
echo ""
echo "Hook configuration:"
echo "  PreToolUse  → destructive-guard.sh (blocks dangerous operations)"
echo "  PreCompact  → pre-compact.sh (snapshots state before compaction)"
echo "  SessionStart(compact) → post-compact.sh (injects recovery context)"
echo ""
echo "To install the plugin, add it via Claude Code marketplace or symlink:"
echo "  ln -s $FORGE_DIR ~/.claude/plugins/forge"
echo ""
echo "Setup complete."
