#!/usr/bin/env bash
#
# Post-install verification for a single CLI.
#
# Usage: tests/verify_install.sh <claudecode|codex|opencode|pi>
#
# Asserts that the installer placed files in the expected locations and that
# the CLI reports a configured state via non-auth introspection. Exits non-zero
# if any HARD check fails. Live introspection that may need network/auth (e.g.
# `claude mcp list`) is treated as SOFT (warn only); MCP wiring is asserted from
# the persisted config files instead.
#
# Tildes below appear inside human-readable check labels, not paths.
# shellcheck disable=SC2088
set -uo pipefail

TOOL="${1:-}"
FAILED=0

green() { printf '\033[0;32m  ✓ %s\033[0m\n' "$1"; }
red()   { printf '\033[0;31m  ✗ %s\033[0m\n' "$1"; FAILED=1; }
warn()  { printf '\033[1;33m  ⚠ %s\033[0m\n' "$1"; }

# pass <desc> <test-command...>
pass() { if eval "$2"; then green "$1"; else red "$1"; fi; }
# soft <desc> <test-command...>
soft() { if eval "$2"; then green "$1"; else warn "$1 (soft)"; fi; }

count_gt0() { [ "$(find "$1" -maxdepth "${3:-2}" -name "${2}" 2>/dev/null | wc -l)" -gt 0 ]; }
has_jq() { command -v jq &> /dev/null; }

verify_claudecode() {
    local d="$HOME/.claude"
    soft "claude --version" "command -v claude >/dev/null && claude --version >/dev/null 2>&1"
    pass "agents in ~/.claude/agents/*.md"        "count_gt0 '$d/agents' '*.md' 1"
    pass "skills in ~/.claude/skills/*/SKILL.md"  "count_gt0 '$d/skills' 'SKILL.md' 3"
    pass "~/.claude/CLAUDE.md is System-Level Claude" "grep -q 'System-Level Claude' '$d/CLAUDE.md'"
    pass "~/.claude/bin/claude-launch is executable" "[ -x '$d/bin/claude-launch' ]"
    if has_jq; then
        pass "settings.json has PostToolUse hook"  "jq -e '.hooks.PostToolUse[0].hooks[0].command' '$d/settings.json' >/dev/null"
        pass "~/.claude.json has filesystem MCP"    "jq -e '.mcpServers.filesystem' '$HOME/.claude.json' >/dev/null 2>&1"
    else
        warn "jq not available — skipping JSON assertions"
    fi
    soft "claude mcp list shows filesystem" "command -v claude >/dev/null && claude mcp list 2>/dev/null | grep -q filesystem"
}

verify_codex() {
    local d="$HOME/.codex"
    soft "codex --version" "command -v codex >/dev/null && codex --version >/dev/null 2>&1"
    pass "prompts in ~/.codex/prompts/*.md"       "count_gt0 '$d/prompts' '*.md' 1"
    pass "~/.codex/AGENTS.md is System-Level Codex" "grep -q 'System-Level Codex' '$d/AGENTS.md'"
    if has_jq; then
        pass "hooks.json has PostToolUse hook"     "jq -e '.PostToolUse[0].hooks[0].command' '$d/hooks.json' >/dev/null"
    fi
    soft "codex mcp list shows filesystem" "command -v codex >/dev/null && codex mcp list 2>/dev/null | grep -q filesystem"
}

verify_opencode() {
    local d="$HOME/.config/opencode"
    soft "opencode --version" "command -v opencode >/dev/null && opencode --version >/dev/null 2>&1"
    pass "agents in ~/.config/opencode/agents/*.md"       "count_gt0 '$d/agents' '*.md' 1"
    pass "skills in ~/.config/opencode/skills/*/SKILL.md" "count_gt0 '$d/skills' 'SKILL.md' 3"
    pass "~/.config/opencode/AGENTS.md is System-Level OpenCode" "grep -q 'System-Level OpenCode' '$d/AGENTS.md'"
    pass "plugins/post_code_hook_plugin.mjs exists" "[ -f '$d/plugins/post_code_hook_plugin.mjs' ]"
    if has_jq; then
        pass "opencode.json has filesystem MCP under .mcp" "jq -e '.mcp.filesystem' '$d/opencode.json' >/dev/null"
    fi
}

verify_pi() {
    local d="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
    soft "pi --version" "command -v pi >/dev/null && pi --version >/dev/null 2>&1"
    pass "skills in ~/.pi/agent/skills/*/SKILL.md" "count_gt0 '$d/skills' 'SKILL.md' 3"
    pass "~/.pi/agent/AGENTS.md is System-Level Pi" "grep -q 'System-Level Pi' '$d/AGENTS.md'"
    pass "extensions/pi-checks.ts exists" "[ -f '$d/extensions/pi-checks.ts' ]"
}

printf '\n=== Verifying %s ===\n' "$TOOL"
case "$TOOL" in
    claudecode) verify_claudecode ;;
    codex)      verify_codex ;;
    opencode)   verify_opencode ;;
    pi)         verify_pi ;;
    *) echo "Usage: $0 <claudecode|codex|opencode|pi>"; exit 2 ;;
esac

if [ "$FAILED" -eq 0 ]; then
    printf '\033[0;32m=== %s: all hard checks passed ===\033[0m\n\n' "$TOOL"
else
    printf '\033[0;31m=== %s: one or more hard checks FAILED ===\033[0m\n\n' "$TOOL"
fi
exit "$FAILED"
