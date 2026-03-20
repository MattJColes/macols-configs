#!/bin/bash
#
# Post-Code Hook for Kiro CLI
#
# Thin wrapper that sources the shared post-code checks library.
# Called by Kiro CLI's postToolUse hook system.
# Stdin may or may not contain data depending on the caller.
#
# Install this hook using: ./install_hooks.sh
#

set -euo pipefail

SHARED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/shared"

# Drain stdin safely (some callers pipe data, some don't)
HOOK_INPUT=""
if [ ! -t 0 ]; then
    if command -v gtimeout &> /dev/null; then
        HOOK_INPUT=$(gtimeout 1 cat 2>/dev/null || true)
    elif command -v timeout &> /dev/null; then
        HOOK_INPUT=$(timeout 1 cat 2>/dev/null || true)
    else
        HOOK_INPUT=$(cat 2>/dev/null || true)
    fi
fi

# Try to parse file path from stdin if JSON was provided
FILE_PATH=""
if [ -n "$HOOK_INPUT" ] && command -v jq &> /dev/null; then
    FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
fi

export FILE_PATH

# Source shared library and run checks
source "$SHARED_DIR/post_code_checks.sh"
run_post_code_checks
exit 0
