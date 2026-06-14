#!/bin/bash
#
# Post-Task Hook for Claude Code (Stop event)
#
# Thin wrapper that sources the shared post-task checks library.
#
# ADVISORY + CHANGE-GATED:
# - Skips entirely when the turn didn't touch code (clean working tree of code
#   files) — no point re-running the whole suite after a Q&A or docs-only turn.
# - When code did change, runs the checks and REPORTS findings to stderr, but
#   never blocks the stop. Claude already enforces per-edit via the PostToolUse
#   hook; a hard Stop block re-runs the full suite and traps on pre-existing
#   failures in code you never touched. Reporting keeps the signal without the
#   friction. (Re-enable blocking by emitting {"decision":"block","reason":...}
#   on stdout if you want the old behaviour back.)
#
# Claude Code passes JSON via stdin with session_id, transcript_path, cwd,
# permission_mode, hook_event_name, stop_hook_active.
#
# Install this hook using: ./install.sh --hooks-only
#

set -eo pipefail

SHARED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/shared"

# Drain stdin (Claude Code sends JSON; we don't need any field here).
cat > /dev/null 2>&1 || true

# Source shared library
source "$SHARED_DIR/post_task_checks.sh"

# Change gate: skip the whole battery when no code changed this turn.
code_changed || exit 0

run_post_task_checks || exit 0  # Nothing to check

# Advisory: surface findings to stderr (shown in the transcript), never block.
if [ ${#CRITICAL_ISSUES[@]} -gt 0 ]; then
    echo "Post-task validation found issues (advisory — not blocking):" >&2
    for issue in "${CRITICAL_ISSUES[@]}"; do
        echo "  - $issue" >&2
    done
fi

if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo "Validation notes:" >&2
    for warning in "${WARNINGS[@]}"; do
        echo "  - $warning" >&2
    done
fi

exit 0
