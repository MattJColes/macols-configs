#!/bin/bash
#
# Post-Task Hook for Claude Code
#
# Thin wrapper that sources the shared post-task checks library.
# Runs on the Stop event for comprehensive validation before Claude stops.
#
# BLOCKING:
# - Output JSON {"decision": "block", "reason": "..."} on stdout to prevent stopping
# - No decision field = allow Claude to stop normally
#
# Claude Code passes JSON via stdin with session_id, transcript_path, cwd,
# permission_mode, hook_event_name, stop_hook_active.
#
# Install this hook using: ./install_hooks.sh
#

set -eo pipefail

SHARED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/shared"

# Read hook input from stdin (required - Claude Code sends JSON)
HOOK_INPUT=$(cat)

# Parse stop_hook_active to prevent infinite loops
STOP_HOOK_ACTIVE="false"
if command -v jq &> /dev/null; then
    STOP_HOOK_ACTIVE=$(echo "$HOOK_INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo "false")
else
    if echo "$HOOK_INPUT" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
        STOP_HOOK_ACTIVE="true"
    fi
fi

# Prevent infinite loops: if we already blocked once, allow stop
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
    exit 0
fi

# Source shared library and run checks
source "$SHARED_DIR/post_task_checks.sh"
run_post_task_checks || exit 0  # Nothing to check

# If critical issues found, BLOCK stop and feed reason back to Claude
if [ ${#CRITICAL_ISSUES[@]} -gt 0 ]; then
    local_reason="Stop blocked — critical issues found:"
    for issue in "${CRITICAL_ISSUES[@]}"; do
        local_reason="${local_reason}"$'\n'"  - ${issue}"
    done
    local_reason="${local_reason}"$'\n\n'"Please fix these issues before stopping."

    if command -v jq &> /dev/null; then
        jq -n --arg reason "$local_reason" '{"decision": "block", "reason": $reason}'
    else
        python3 -c "import json,sys; print(json.dumps({'decision':'block','reason':sys.argv[1]}))" "$local_reason"
    fi
    exit 0
fi

# All checks passed — allow stop (no decision field = allow)
if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo "Validation complete with notes:" >&2
    for warning in "${WARNINGS[@]}"; do
        echo "  - $warning" >&2
    done
fi

exit 0
