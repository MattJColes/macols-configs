#!/bin/bash
#
# Post-Task Hook for OpenCode
#
# Thin wrapper that sources the shared post-task checks library.
# Called by the OpenCode plugin's session.idle handler for
# comprehensive end-of-session validation.
#
# EXIT CODES:
# - 0: All checks passed
# - 1: Critical issues found
#
# Install this hook using: ./install_hooks.sh
#

set -euo pipefail

SHARED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/shared"

# Source shared library and run checks
source "$SHARED_DIR/post_task_checks.sh"
run_post_task_checks || exit 0  # Nothing to check

# If critical issues found, report and exit 1
if [ ${#CRITICAL_ISSUES[@]} -gt 0 ]; then
    echo "Session validation found critical issues:"
    for issue in "${CRITICAL_ISSUES[@]}"; do
        echo "  - $issue"
    done
    echo ""
    echo "Please fix these issues before stopping."
    exit 1
fi

# All checks passed
if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo "Validation complete with notes:"
    for warning in "${WARNINGS[@]}"; do
        echo "  - $warning"
    done
fi

exit 0
