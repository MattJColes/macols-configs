#!/bin/bash
#
# Pre-Deploy Hook for Codex CLI (PreToolUse on the shell tool)
#
# Guards `cdk deploy` / `cdk destroy`. The biggest CDK-specific danger is a
# Construct ID rename that looks like a harmless refactor but forces resource
# replacement/destruction. This hook surfaces a loud reminder to review
# `cdk diff` for replacements before such a command runs.
#
# This wrapper is ADVISORY: it prints the warning (stderr is shown to you,
# stdout is fed back to Codex) and exits 0 so Codex's own approval_policy
# remains the gate that actually prompts before the command executes.
#
# Codex passes JSON on stdin with the tool name and its input.
#

set -eo pipefail

HOOK_INPUT=$(cat || true)

# Extract the shell command. Codex's shell tool input may be a string or an
# argv array (e.g. ["bash","-lc","..."]), so handle both.
COMMAND=""
if command -v jq &> /dev/null && [ -n "$HOOK_INPUT" ]; then
    COMMAND=$(echo "$HOOK_INPUT" | jq -r '
        (.tool_input.command // .input.command // .command // empty) |
        if type == "array" then join(" ") else . end' 2>/dev/null || true)
fi

# Match `cdk deploy` / `cdk destroy`, including `npx cdk deploy`, `cdk deploy --all`,
# `cdk destroy '*'`, etc. Allow `cdk diff`/`cdk synth` through untouched.
if echo "$COMMAND" | grep -Eq '(^|[^[:alnum:]_-])cdk[[:space:]]+(deploy|destroy)([[:space:]]|$)'; then
    cat >&2 << 'EOF'
⚠️  cdk deploy/destroy detected.
    Renaming a Construct ID forces resource REPLACEMENT/DESTRUCTION.
    Confirm you reviewed 'cdk diff' for replacements (look for
    'requires replacement' and resources marked for removal) before approving.
EOF
fi

# Advisory only — never block; Codex's approval_policy handles the prompt.
exit 0
