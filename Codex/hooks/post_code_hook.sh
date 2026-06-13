#!/bin/bash
#
# Post-Code Hook for Codex CLI (PostToolUse on file-editing tools)
#
# Thin wrapper that sources the shared post-code checks library.
# Codex passes JSON on stdin describing the tool call; anything this hook
# prints on stdout is fed back to Codex as additional context.
#
# Installed (and wired into ~/.codex/hooks.json) by ./install.sh
#

set -eo pipefail

SHARED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/shared"

# Read hook input from stdin (Codex sends JSON; tolerate empty input).
HOOK_INPUT=$(cat || true)

# Best-effort extraction of the edited file path. Codex's edit tools vary in
# shape across versions, so probe the common locations and fall back to empty
# (an empty FILE_PATH just means the checks run across the whole project).
FILE_PATH=""
if command -v jq &> /dev/null && [ -n "$HOOK_INPUT" ]; then
    FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '
        .tool_input.file_path // .tool_input.path // .tool_input.filename //
        .input.file_path // .file_path // empty' 2>/dev/null || true)
fi

export FILE_PATH

# Source shared library and run checks (always non-blocking).
source "$SHARED_DIR/post_code_checks.sh"
run_post_code_checks
exit 0
