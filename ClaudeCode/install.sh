#!/usr/bin/env bash
#
# Unified installer for Claude Code — agents, skills, MCPs and hooks.
#
# By default installs everything. Use the flags below to install a subset.
#
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SHARED_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/shared"

# Ensure Node.js is in PATH (sources NVM/fnm if needed)
# shellcheck source=../shared/ensure_node.sh
if [ -f "$SHARED_DIR/ensure_node.sh" ]; then
    # shellcheck disable=SC1091
    source "$SHARED_DIR/ensure_node.sh"
fi

# Install targets
CLAUDE_DIR="$HOME/.claude"
AGENTS_DIR="$CLAUDE_DIR/agents"
SKILLS_DIR="$CLAUDE_DIR/skills"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
MCP_CONFIG_FILE="$SCRIPT_DIR/mcp-config.json"
HOOK_SCRIPT="$SCRIPT_DIR/hooks/post_code_hook.sh"
TASK_HOOK_SCRIPT="$SCRIPT_DIR/hooks/post_task_hook.sh"

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Installs Claude Code agents, skills, MCP servers and hooks.
Agents and skills are authored together under personas/<name>/
(SKILL.md, optional AGENT.md) and installed to their respective targets.
With no options, all four are installed.

Options:
    -h, --help        Show this help message
    --agents-only     Install only agents (and system CLAUDE.md)
    --skills-only     Install only skills
    --mcps-only       Install only MCP servers
    --hooks-only      Install only post-code/post-task hooks
    -p, --project     Install agents & skills to the current project
                      (./.claude/agents and ./.claude/skills)
    --list            List available personas and exit
EOF
}

list_skills() {
    printf "${BLUE}Available Personas:${NC}\n\n"
    for persona_dir in "$SCRIPT_DIR/personas"/*; do
        [ -d "$persona_dir" ] || continue
        persona_name=$(basename "$persona_dir")
        [ -f "$persona_dir/SKILL.md" ] || continue
        description=$(grep -m1 "^description:" "$persona_dir/SKILL.md" | sed 's/^description: //')
        [ -f "$persona_dir/AGENT.md" ] && marker="${CYAN}+agent${NC}" || marker="      "
        printf "  ${GREEN}%-25s${NC} %b  %s\n" "$persona_name" "$marker" "$description"
    done
    echo ""
}

install_agents() {
    target_dir="$1"

    if [ ! -d "$SCRIPT_DIR/personas" ]; then
        printf "${RED}Error: personas directory not found at %s${NC}\n" "$SCRIPT_DIR/personas"
        return 1
    fi

    if [ -d "$target_dir" ]; then
        printf "${YELLOW}Clearing existing agents in: %s${NC}\n" "$target_dir"
        rm -rf "$target_dir"
    fi
    mkdir -p "$target_dir"

    printf "${BLUE}Installing agents to: %s${NC}\n" "$target_dir"
    count=0
    for agent_file in "$SCRIPT_DIR/personas"/*/AGENT.md; do
        [ -f "$agent_file" ] || continue
        # Name the installed file after the agent's `name:` field (hyphenated),
        # falling back to the persona directory name.
        name=$(sed -n 's/^name:[[:space:]]*//p' "$agent_file" | head -1)
        [ -n "$name" ] || name=$(basename "$(dirname "$agent_file")")
        cp "$agent_file" "$target_dir/$name.md"
        printf "  ${GREEN}✓${NC} %s\n" "$name"
        count=$((count + 1))
    done
    printf "${GREEN}✓ Installed %d agents${NC}\n" "$count"

    # System-level Claude configuration (user scope only)
    if [ "$target_dir" = "$AGENTS_DIR" ] && [ -f "$SCRIPT_DIR/CLAUDE.md" ]; then
        cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
        printf "${GREEN}✓ Copied system CLAUDE.md to %s${NC}\n" "$CLAUDE_DIR/CLAUDE.md"
    fi
}

install_skills() {
    target_dir="$1"

    if [ -d "$target_dir" ]; then
        printf "${YELLOW}Clearing existing skills in: %s${NC}\n" "$target_dir"
        rm -rf "$target_dir"
    fi
    mkdir -p "$target_dir"

    printf "${BLUE}Installing skills to: %s${NC}\n" "$target_dir"
    count=0
    for persona_dir in "$SCRIPT_DIR/personas"/*; do
        [ -d "$persona_dir" ] || continue
        [ -f "$persona_dir/SKILL.md" ] || continue
        skill_name=$(basename "$persona_dir")
        mkdir -p "$target_dir/$skill_name"
        cp "$persona_dir/SKILL.md" "$target_dir/$skill_name/SKILL.md"
        printf "  ${GREEN}✓${NC} %s\n" "$skill_name"
        count=$((count + 1))
    done
    printf "${GREEN}✓ Installed %d skills${NC}\n" "$count"
}

install_mcps() {
    printf "${BLUE}Registering MCP servers from mcp-config.json...${NC}\n"

    if ! command -v claude &> /dev/null; then
        printf "${RED}claude CLI not found. Install Claude Code first: https://docs.claude.com/claude-code${NC}\n"
        return 1
    fi
    if ! command -v jq &> /dev/null; then
        printf "${YELLOW}jq not found. Installing...${NC}\n"
        if [[ "$OSTYPE" == "darwin"* ]] && command -v brew &> /dev/null; then
            brew install jq
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sudo apt-get install -y jq
        else
            printf "${RED}Please install jq manually: https://stedolan.github.io/jq/${NC}\n"
            return 1
        fi
    fi
    if ! command -v uv &> /dev/null; then
        printf "${YELLOW}uv not found. Installing (needed for uvx-based MCPs)...${NC}\n"
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    fi
    if [ ! -f "$MCP_CONFIG_FILE" ]; then
        printf "${RED}MCP config file not found: %s${NC}\n" "$MCP_CONFIG_FILE"
        return 1
    fi

    for name in $(jq -r '.mcpServers | keys[]' "$MCP_CONFIG_FILE"); do
        printf "${BLUE}→ %s${NC}\n" "$name"
        server_json=$(jq --arg name "$name" --arg home "$HOME" \
            '.mcpServers[$name] | walk(if type == "string" then gsub("\\$HOME"; $home) else . end)' \
            "$MCP_CONFIG_FILE")
        # Remove any existing server with this name (any scope) so install is idempotent.
        claude mcp remove "$name" >/dev/null 2>&1 || true
        if claude mcp add-json -s user "$name" "$server_json" >/dev/null; then
            printf "  ${GREEN}✓ registered${NC}\n"
        else
            printf "  ${RED}✗ failed to register${NC}\n"
        fi
    done
    printf "${GREEN}✓ MCP servers registered (run 'claude mcp list' to inspect)${NC}\n"
}

install_hooks() {
    printf "${BLUE}Installing post-code/post-task hooks...${NC}\n"

    for f in "$SHARED_DIR/post_code_checks.sh" "$SHARED_DIR/post_task_checks.sh" \
             "$HOOK_SCRIPT" "$TASK_HOOK_SCRIPT"; do
        if [ ! -f "$f" ]; then
            printf "${RED}Required file not found: %s${NC}\n" "$f"
            return 1
        fi
    done

    chmod +x "$HOOK_SCRIPT" "$TASK_HOOK_SCRIPT"
    mkdir -p "$CLAUDE_DIR"

    if ! command -v node &> /dev/null; then
        printf "${RED}Node.js required to write hooks configuration${NC}\n"
        return 1
    fi

    SETTINGS_FILE="$SETTINGS_FILE" \
    HOOK_SCRIPT="$HOOK_SCRIPT" \
    TASK_HOOK_SCRIPT="$TASK_HOOK_SCRIPT" \
    node -e '
const fs = require("fs");
const env = process.env;
let existing = {};
if (fs.existsSync(env.SETTINGS_FILE)) {
    try { existing = JSON.parse(fs.readFileSync(env.SETTINGS_FILE, "utf8")); } catch(e) {}
}
existing.hooks = {
    PostToolUse: [
        { matcher: "Edit|Write|NotebookEdit",
          hooks: [{ type: "command", command: env.HOOK_SCRIPT }] }
    ],
    Stop: [
        { hooks: [{ type: "command", command: env.TASK_HOOK_SCRIPT }] }
    ]
};
fs.writeFileSync(env.SETTINGS_FILE, JSON.stringify(existing, null, 2) + "\n");
'
    printf "${GREEN}✓ Hooks configuration written to %s${NC}\n" "$SETTINGS_FILE"
}

# Parse arguments
DO_AGENTS=true
DO_SKILLS=true
DO_MCPS=true
DO_HOOKS=true
PROJECT_INSTALL=false
SUBSET=false

set_subset() {
    if [ "$SUBSET" = false ]; then
        DO_AGENTS=false; DO_SKILLS=false; DO_MCPS=false; DO_HOOKS=false
        SUBSET=true
    fi
}

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --list) list_skills; exit 0 ;;
        --agents-only) set_subset; DO_AGENTS=true ;;
        --skills-only) set_subset; DO_SKILLS=true ;;
        --mcps-only)   set_subset; DO_MCPS=true ;;
        --hooks-only)  set_subset; DO_HOOKS=true ;;
        -p|--project)  PROJECT_INSTALL=true ;;
        *) printf "${RED}Unknown option: %s${NC}\n" "$1"; usage; exit 1 ;;
    esac
    shift
done

printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "${CYAN}Claude Code Installer${NC}\n"
printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"

if [ "$DO_AGENTS" = true ]; then
    if [ "$PROJECT_INSTALL" = true ]; then install_agents "./.claude/agents"; else install_agents "$AGENTS_DIR"; fi
    echo ""
fi
if [ "$DO_SKILLS" = true ]; then
    if [ "$PROJECT_INSTALL" = true ]; then install_skills "./.claude/skills"; else install_skills "$SKILLS_DIR"; fi
    echo ""
fi
if [ "$DO_MCPS" = true ]; then install_mcps; echo ""; fi
if [ "$DO_HOOKS" = true ]; then install_hooks; echo ""; fi

printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "${GREEN}Installation complete! 🎉${NC}\n"
printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"
echo "Next steps:"
echo "  • Restart Claude Code to load the new configuration"
echo "  • Agents are invoked automatically or via 'Use the <agent> agent ...'"
echo "  • Skills are available as slash commands (e.g. /python-backend)"
[ "$DO_MCPS" = true ] && echo "  • Configure AWS credentials (~/.aws/credentials) for aws-kb/dynamodb MCPs"
echo ""
