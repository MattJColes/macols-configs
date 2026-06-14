#!/bin/bash
#
# Post-Task Hook for Codex CLI (Stop event)
#
# Thin wrapper that sources the shared post-task checks library and runs a
# comprehensive validation pass when Codex finishes a turn.
#
# This wrapper is ADVISORY: it reports test/lint/security failures on stdout
# (which Codex feeds back as context to act on) but never hard-blocks. Hard
# enforcement on Codex comes from approval_policy / sandbox_mode, not from a
# hook decision schema that varies between Codex versions.
#
# Installed (and wired into ~/.codex/hooks.json) by ./install.sh
#

set -eo pipefail

SHARED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/shared"

# Drain stdin (Codex sends JSON; we don't need any field from it here).
cat > /dev/null 2>&1 || true

# Source shared library and run checks.
source "$SHARED_DIR/post_task_checks.sh"

# Change gate: skip the whole battery when the turn didn't touch code.
code_changed || exit 0

run_post_task_checks || exit 0  # Nothing to check

if [ ${#CRITICAL_ISSUES[@]} -gt 0 ]; then
    echo "Post-task validation found critical issues — please fix before finishing:"
    for issue in "${CRITICAL_ISSUES[@]}"; do
        echo "  - ${issue}"
    done
fi

if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo "Validation notes:" >&2
    for warning in "${WARNINGS[@]}"; do
        echo "  - $warning" >&2
    done
fi

exit 0
