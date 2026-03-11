#!/usr/bin/env bash
# Forge: Set up Parallel CLI and MCP servers for mandatory web research
# Usage: parallel-setup.sh [--cli-only | --mcp-only]

set -euo pipefail

MODE="${1:-all}"

echo "=== Forge: Parallel Research Setup ==="
echo ""

# --- CLI Setup ---
if [ "$MODE" = "all" ] || [ "$MODE" = "--cli-only" ]; then
  echo "--- Parallel CLI ---"

  if command -v parallel-cli >/dev/null 2>&1; then
    echo "✓ parallel-cli is already installed"
    parallel-cli update --check 2>/dev/null || true
  else
    echo "Installing parallel-cli..."
    if command -v brew >/dev/null 2>&1; then
      brew install parallel-web/tap/parallel-cli
    elif command -v pip3 >/dev/null 2>&1; then
      pip3 install parallel-web-tools
    else
      curl -fsSL https://parallel.ai/install.sh | bash
    fi

    if command -v parallel-cli >/dev/null 2>&1; then
      echo "✓ parallel-cli installed successfully"
    else
      echo "✗ Installation failed. Install manually:"
      echo "  brew install parallel-web/tap/parallel-cli"
      echo "  OR: pip install parallel-web-tools"
      echo "  OR: curl -fsSL https://parallel.ai/install.sh | bash"
    fi
  fi

  # Check authentication
  echo ""
  if parallel-cli auth >/dev/null 2>&1; then
    echo "✓ parallel-cli is authenticated"
  else
    echo "✗ Not authenticated. Run one of:"
    echo "  parallel-cli login"
    echo "  parallel-cli login --device   (for headless/SSH)"
    echo "  export PARALLEL_API_KEY=\"your_key\"  (from platform.parallel.ai)"
  fi
  echo ""
fi

# --- MCP Server Setup ---
if [ "$MODE" = "all" ] || [ "$MODE" = "--mcp-only" ]; then
  echo "--- Parallel MCP Servers ---"

  if ! command -v claude >/dev/null 2>&1; then
    echo "✗ claude CLI not found. Add MCP servers manually to your client config."
    echo "  Search MCP: https://search-mcp.parallel.ai/mcp"
    echo "  Task MCP:   https://task-mcp.parallel.ai/mcp"
  else
    # Add Search MCP (low-latency web search)
    echo "Adding Parallel Search MCP..."
    claude mcp add --transport http "Parallel-Search-MCP" https://search-mcp.parallel.ai/mcp 2>/dev/null && \
      echo "✓ Parallel-Search-MCP added" || \
      echo "  (already exists or failed — check with: claude mcp list)"

    # Add Task MCP (deep research + enrichment)
    echo "Adding Parallel Task MCP..."
    claude mcp add --transport http "Parallel-Task-MCP" https://task-mcp.parallel.ai/mcp 2>/dev/null && \
      echo "✓ Parallel-Task-MCP added" || \
      echo "  (already exists or failed — check with: claude mcp list)"

    echo ""
    echo "After adding, use /mcp in Claude Code to complete browser auth."
  fi
  echo ""
fi

echo "=== Setup Complete ==="
echo ""
echo "Quick test:"
echo "  parallel-cli search 'test query' --json | head -5"
echo ""
echo "Docs: https://docs.parallel.ai/integrations/cli"
