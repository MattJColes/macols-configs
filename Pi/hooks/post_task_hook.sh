#!/bin/bash
#
# Post-Task Hook for Pi (agent_end / turn complete)
#
# Thin wrapper that sources the shared post-task checks library. Invoked by the
# pi-checks extension on the `agent_end` event when the agent finishes
# responding to a prompt.
#
# ADVISORY + CHANGE-GATED, matching the Claude Code wrapper:
# - Skips entirely when the turn didn't touch code (clean working tree of code
#   files) so a Q&A or docs-only turn doesn't trigger the whole suite.
# - When code changed, runs the checks and prints findings to stdout (the
#   extension surfaces them in the session). Never blocks.
#

set -eo pipefail

SHARED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/shared"

source "$SHARED_DIR/post_task_checks.sh"

# Change gate: skip the whole battery when the turn didn't touch code.
code_changed || exit 0

run_post_task_checks || exit 0  # Nothing to check

if [ ${#CRITICAL_ISSUES[@]} -gt 0 ]; then
    echo "Post-task validation found issues (advisory — not blocking):"
    for issue in "${CRITICAL_ISSUES[@]}"; do
        echo "  - $issue"
    done
fi

if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo "Validation notes:"
    for warning in "${WARNINGS[@]}"; do
        echo "  - $warning"
    done
fi

exit 0
