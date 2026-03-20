#!/bin/bash
#
# Post-Task Hook for Kiro CLI
#
# Thin wrapper that sources the shared post-task checks library.
# Runs on the "stop" event for comprehensive validation.
#
# EXIT CODES:
# - 0: All checks passed
# - 2: Critical issues found, BLOCK operation
#
# Kiro passes JSON via stdin with hook_event_name and cwd.
# Hook output on stderr is fed back as feedback.
#
# Install this hook using: ./install_hooks.sh
#

set -euo pipefail

SHARED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/shared"

# Read hook input from stdin (required - Kiro sends JSON)
HOOK_INPUT=$(cat)

# Parse cwd and change to working directory
CWD=""
if command -v jq &> /dev/null; then
    CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
fi

if [ -n "$CWD" ] && [ -d "$CWD" ]; then
    cd "$CWD"
fi

# Check stop_hook_active to prevent infinite loops
STOP_HOOK_ACTIVE="false"
if command -v jq &> /dev/null; then
    STOP_HOOK_ACTIVE=$(echo "$HOOK_INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo "false")
else
    if echo "$HOOK_INPUT" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
        STOP_HOOK_ACTIVE="true"
    fi
fi

if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
    exit 0
fi

# Source shared library and run checks
source "$SHARED_DIR/post_task_checks.sh"
run_post_task_checks || exit 0  # Nothing to check

# If critical issues found, BLOCK operation
if [ ${#CRITICAL_ISSUES[@]} -gt 0 ]; then
    echo "Session stop blocked due to critical issues:" >&2
    for issue in "${CRITICAL_ISSUES[@]}"; do
        echo "  - $issue" >&2
    done
    echo "" >&2
    echo "Please fix these issues before stopping." >&2
    exit 2
fi

# All checks passed
if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo "Session validation complete with notes:" >&2
    for warning in "${WARNINGS[@]}"; do
        echo "  - $warning" >&2
    done
fi

exit 0
