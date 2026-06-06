#!/bin/bash
#
# Pre-Deploy Hook for Claude Code (PreToolUse on Bash)
#
# Guards `cdk deploy` / `cdk destroy`. The biggest CDK-specific danger is a
# Construct ID rename that looks like a harmless refactor but forces resource
# replacement/destruction. This hook pauses such commands and asks the user to
# confirm they reviewed `cdk diff` for replacements before proceeding.
#
# Hard safety belongs in hooks, not CLAUDE.md — CLAUDE.md rules are
# model-interpreted and degrade as context grows.
#
# PreToolUse protocol: emit JSON on stdout with hookSpecificOutput.
#   permissionDecision "ask"   -> surface a confirmation prompt to the user
#   permissionDecision "allow" -> proceed without prompting
# Anything else (or no output) falls through to normal permission handling.
#
# Claude Code passes JSON via stdin with tool_name and tool_input.command.
#

set -eo pipefail

HOOK_INPUT=$(cat)

# Extract the Bash command being run.
COMMAND=""
TOOL_NAME=""
if command -v jq &> /dev/null; then
    TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)
    COMMAND=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
else
    TOOL_NAME=$(echo "$HOOK_INPUT" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//' || true)
    COMMAND=$(echo "$HOOK_INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"command"[[:space:]]*:[[:space:]]*"//;s/"$//' || true)
fi

# Only act on Bash tool calls.
if [ "$TOOL_NAME" != "Bash" ]; then
    exit 0
fi

# Match `cdk deploy` / `cdk destroy`, including `npx cdk deploy`, `cdk deploy --all`,
# `cdk destroy '*'`, etc. Allow `cdk diff`/`cdk synth` through untouched.
if echo "$COMMAND" | grep -Eq '(^|[^[:alnum:]_-])cdk[[:space:]]+(deploy|destroy)([[:space:]]|$)'; then
    REASON="cdk deploy/destroy detected. Renaming a Construct ID forces resource REPLACEMENT/DESTRUCTION — confirm you reviewed 'cdk diff' for replacements (look for 'requires replacement' and resources marked for removal) before approving."
    if command -v jq &> /dev/null; then
        jq -n --arg reason "$REASON" '{
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                permissionDecision: "ask",
                permissionDecisionReason: $reason
            }
        }'
    else
        python3 -c "import json,sys; print(json.dumps({'hookSpecificOutput':{'hookEventName':'PreToolUse','permissionDecision':'ask','permissionDecisionReason':sys.argv[1]}}))" "$REASON"
    fi
    exit 0
fi

# Not a deploy/destroy — no opinion, fall through to normal handling.
exit 0
