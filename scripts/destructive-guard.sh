#!/usr/bin/env bash
# Forge: PreToolUse destructive operation guard
# Blocks dangerous commands that could destroy work.
# Exit 0 = allow, Exit 2 = block with message.

set -euo pipefail

FORGE_HOOK_PAYLOAD="$(cat || true)"
export FORGE_HOOK_PAYLOAD

python3 <<'PY'
import json
import os
import sys

try:
    payload = json.loads(os.environ.get("FORGE_HOOK_PAYLOAD", ""))
except Exception:
    sys.exit(0)

if payload.get("tool_name") != "Bash":
    sys.exit(0)

tool_input = payload.get("tool_input") or {}
command = tool_input.get("command") or ""
if not command:
    sys.exit(0)

patterns = (
    "rm -rf /",
    "rm -rf ~",
    "rm -rf $home",
    "rm -rf .",
    "git reset --hard",
    "git clean -fd",
    "git clean -fx",
    "git checkout -- .",
    "git push --force",
    "git push -f",
    "git branch -d main",
    "git branch -d master",
    "git branch -D main",
    "git branch -D master",
    "git stash drop",
    "git stash clear",
    "drop table",
    "drop database",
    "truncate table",
    "> /dev/sda",
    "mkfs.",
    "dd if=",
    "chmod -r 777",
    "chmod 777 /",
    ":(){ :|:&",
    "shutdown",
    "reboot",
    "init 0",
    "init 6",
)

command_lower = command.casefold()
for pattern in patterns:
    if pattern.casefold() in command_lower:
        print(
            f"BLOCKED by Forge safety guard: command matches '{pattern}'",
            file=sys.stderr,
        )
        print(
            "If you need to run this command, have the user execute it manually.",
            file=sys.stderr,
        )
        sys.exit(2)

sys.exit(0)
PY
