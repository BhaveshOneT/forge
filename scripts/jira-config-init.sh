#!/usr/bin/env bash
# Forge: Initialize Jira/Confluence/GitHub config
# Creates ~/.claude/forge/config.json with sensible defaults.
# Usage: jira-config-init.sh [--force]

set -euo pipefail

FORCE="${1:-}"
CONFIG_DIR="$HOME/.claude/forge"
CONFIG_FILE="$CONFIG_DIR/config.json"

mkdir -p "$CONFIG_DIR"

if [ -f "$CONFIG_FILE" ] && [ "$FORCE" != "--force" ]; then
  echo "Config already exists: $CONFIG_FILE"
  echo "Use --force to overwrite."
  exit 0
fi

cat > "$CONFIG_FILE" << 'JSONEOF'
{
  "atlassian": {
    "cloud_id": null,
    "site_url": null
  },
  "jira": {
    "default_project": null,
    "ready_statuses": ["To Do", "Ready for Dev"],
    "in_progress_status": "In Progress",
    "in_review_status": "In Review",
    "branch_prefix": "forge",
    "auto_transition": true,
    "board_id": null
  },
  "confluence": {
    "default_space_key": null,
    "fetch_linked_pages": true,
    "max_child_depth": 1
  },
  "github": {
    "default_base_branch": "main",
    "pr_draft": false,
    "pr_labels": ["forge-automated"],
    "pr_reviewers": []
  },
  "sync": {
    "mode": "single",
    "max_issues_per_run": 1,
    "priority_order": ["Highest", "High", "Medium", "Low", "Lowest"]
  }
}
JSONEOF

echo "Created config: $CONFIG_FILE"
echo ""
echo "Next steps:"
echo "  1. Set up Atlassian MCP server:"
echo "     claude mcp add --transport sse atlassian https://mcp.atlassian.com/v1/sse"
echo "  2. Edit $CONFIG_FILE to set your cloud_id, site_url, and default_project"
echo "  3. Run: /forge:jira PROJ-123"
