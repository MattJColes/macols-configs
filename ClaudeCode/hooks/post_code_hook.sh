#!/bin/bash
#
# Post-Code Hook for Claude Code
#
# Thin wrapper that sources the shared post-code checks library.
# Claude Code passes JSON via stdin with tool_name, tool_input, etc.
# Hook output on stdout is fed back to Claude as context.
#
# Install this hook using: ./install_hooks.sh
#

set -eo pipefail

SHARED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/shared"

# Read hook input from stdin (required - Claude Code sends JSON)
HOOK_INPUT=$(cat)

# Parse the file path from the hook input
FILE_PATH=""
if command -v jq &> /dev/null; then
    FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
else
    FILE_PATH=$(echo "$HOOK_INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//' || true)
fi

export FILE_PATH

# Source shared library and run checks
source "$SHARED_DIR/post_code_checks.sh"
run_post_code_checks
exit 0
