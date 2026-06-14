#!/bin/bash
#
# Post-Code Hook for Pi (post-tool / file write)
#
# Thin wrapper that sources the shared post-code checks library and runs the
# relevant tests/lint/security scans for the edited file. Invoked by the
# pi-checks extension on the `tool_result` event for write/edit tools.
#
# Advisory: prints findings to stdout (the extension surfaces them in the
# session) and always exits 0 — it never blocks the tool.
#
# Usage: post_code_hook.sh [edited_file_path]
#

set -eo pipefail

SHARED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/shared"

# Pi passes the edited file path as the first argument (optional).
export FILE_PATH="${1:-}"

source "$SHARED_DIR/post_code_checks.sh"
run_post_code_checks
exit 0
