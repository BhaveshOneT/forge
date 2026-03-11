#!/usr/bin/env bash
# Forge: PreToolUse destructive operation guard
# Blocks dangerous commands that could destroy work.
# Exit 0 = allow, Exit 2 = block with message.

# Only check Bash commands
[ "$TOOL_NAME" = "Bash" ] || exit 0

# Extract the command from tool input
COMMAND="${TOOL_INPUT_COMMAND:-}"
[ -n "$COMMAND" ] || exit 0

# Destructive patterns to block
BLOCKED_PATTERNS=(
  "rm -rf /"
  "rm -rf ~"
  "rm -rf \$HOME"
  "git reset --hard"
  "git clean -fd"
  "git checkout -- ."
  "git push --force"
  "git push -f"
  "drop table"
  "DROP TABLE"
  "truncate table"
  "TRUNCATE TABLE"
  "> /dev/sda"
  "mkfs."
  "dd if="
)

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  if [[ "$COMMAND" == *"$pattern"* ]]; then
    echo "BLOCKED by Forge safety guard: Command contains '$pattern'"
    echo "If you need to run this command, ask the user to execute it manually."
    exit 2
  fi
done

# Allow the command
exit 0
