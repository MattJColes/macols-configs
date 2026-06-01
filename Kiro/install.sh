#!/usr/bin/env bash
#
# Unified installer for Kiro CLI — agents, skills, MCPs and hooks.
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
KIRO_DIR="$HOME/.kiro"
AGENTS_DIR="$KIRO_DIR/agents"
SKILLS_DIR="$KIRO_DIR/skills"
SETTINGS_DIR="$KIRO_DIR/settings"
HOOKS_FILE="$SETTINGS_DIR/hooks.json"
HOOK_SCRIPT="$SCRIPT_DIR/hooks/post_code_hook.sh"
TASK_HOOK_SCRIPT="$SCRIPT_DIR/hooks/post_task_hook.sh"

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Installs Kiro CLI agents, skills, MCP packages and hooks.
With no options, all four are installed.

Options:
    -h, --help            Show this help message
    --agents-only         Install only agents
    --skills-only         Install only skills
    --mcps-only           Install only MCP server packages
    --hooks-only          Install only post-code/post-task hooks
    --with-global-config  When installing MCPs, also write ~/.kiro/settings/mcp.json
                          (fallback for the kiro_default agent; custom agents use
                          their own per-agent mcpServers config)
    --list                List available skills and exit
EOF
}

list_skills() {
    printf "${BLUE}Available Skills:${NC}\n\n"
    for skill_dir in "$SCRIPT_DIR/skills"/*; do
        [ -d "$skill_dir" ] || continue
        skill_name=$(basename "$skill_dir")
        if [ -f "$skill_dir/SKILL.md" ]; then
            description=$(grep -m1 "^description:" "$skill_dir/SKILL.md" | sed 's/^description: //')
            printf "  ${GREEN}%-25s${NC} %s\n" "$skill_name" "$description"
        fi
    done
    echo ""
}

install_agents() {
    if [ ! -d "$SCRIPT_DIR/agents" ]; then
        printf "${RED}Error: agents directory not found at %s${NC}\n" "$SCRIPT_DIR/agents"
        return 1
    fi

    if [ -d "$AGENTS_DIR" ]; then
        printf "${YELLOW}Clearing existing agents in: %s${NC}\n" "$AGENTS_DIR"
        rm -rf "$AGENTS_DIR"
    fi
    mkdir -p "$AGENTS_DIR"

    printf "${BLUE}Installing agents to: %s${NC}\n" "$AGENTS_DIR"
    count=0
    for agent_file in "$SCRIPT_DIR/agents"/*.json; do
        [ -f "$agent_file" ] || continue
        agent_name=$(basename "$agent_file")
        # Copy and expand $HOME in per-agent MCP args
        sed "s|\\\$HOME|$HOME|g" "$agent_file" > "$AGENTS_DIR/$agent_name"
        printf "  ${GREEN}✓${NC} %s\n" "$agent_name"
        count=$((count + 1))
    done
    if [ "$count" -eq 0 ]; then
        printf "${RED}Error: no agent JSON files found in %s${NC}\n" "$SCRIPT_DIR/agents"
        return 1
    fi
    printf "${GREEN}✓ Installed %d agents${NC}\n" "$count"
}

install_skills() {
    if [ ! -d "$SCRIPT_DIR/skills" ]; then
        printf "${YELLOW}No skills directory found, skipping.${NC}\n"
        return 0
    fi

    if [ -d "$SKILLS_DIR" ]; then
        printf "${YELLOW}Clearing existing skills in: %s${NC}\n" "$SKILLS_DIR"
        rm -rf "$SKILLS_DIR"
    fi
    mkdir -p "$SKILLS_DIR"

    printf "${BLUE}Installing skills to: %s${NC}\n" "$SKILLS_DIR"
    count=0
    for skill_dir in "$SCRIPT_DIR/skills"/*/; do
        [ -d "$skill_dir" ] || continue
        skill_name=$(basename "$skill_dir")
        mkdir -p "$SKILLS_DIR/$skill_name"
        cp "$skill_dir/SKILL.md" "$SKILLS_DIR/$skill_name/SKILL.md"
        printf "  ${GREEN}✓${NC} %s\n" "$skill_name"
        count=$((count + 1))
    done
    printf "${GREEN}✓ Installed %d skills${NC}\n" "$count"
}

install_mcps() {
    printf "${BLUE}Installing MCP server packages...${NC}\n"
    printf "${BLUE}Agents use per-agent MCP configs; this installs the npm/Python packages they launch via npx/uvx.${NC}\n"

    if ! command -v node &> /dev/null; then
        printf "${YELLOW}Node.js not found. Installing...${NC}\n"
        if [[ "$OSTYPE" == "linux-gnu"* ]] || grep -qi microsoft /proc/version 2>/dev/null; then
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
            sudo apt-get install -y nodejs
        elif [[ "$OSTYPE" == "darwin"* ]] && command -v brew &> /dev/null; then
            brew install node
        else
            printf "${RED}Please install Node.js manually: https://nodejs.org/${NC}\n"
            return 1
        fi
    fi
    printf "${GREEN}✓ Node.js: %s${NC}\n" "$(node --version)"

    if ! command -v npm &> /dev/null; then
        printf "${RED}npm not found. Please install npm.${NC}\n"
        return 1
    fi

    if ! command -v uv &> /dev/null; then
        printf "${YELLOW}uv not found. Installing...${NC}\n"
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    fi
    command -v uv &> /dev/null && printf "${GREEN}✓ uv: %s${NC}\n" "$(uv --version)"

    mkdir -p "$HOME/.mcp/servers"
    for pkg in \
        @modelcontextprotocol/server-filesystem \
        @modelcontextprotocol/server-sequential-thinking \
        @modelcontextprotocol/server-puppeteer \
        @playwright/mcp \
        @modelcontextprotocol/server-memory \
        @modelcontextprotocol/server-aws-kb-retrieval \
        @upstash/context7-mcp; do
        printf "${BLUE}→ %s${NC}\n" "$pkg"
        npm install -g "$pkg" >/dev/null 2>&1 && printf "  ${GREEN}✓${NC}\n" || printf "  ${YELLOW}⚠ (may already be installed)${NC}\n"
    done
    printf "  ${GREEN}✓${NC} dynamodb / mempalace (Python via uvx, on-demand)\n"
    if command -v dart &> /dev/null; then
        printf "  ${GREEN}✓${NC} dart (built into Dart SDK)\n"
    else
        printf "  ${YELLOW}⚠${NC} dart (install Dart 3.9+ for the Flutter/Dart MCP)\n"
    fi
    printf "${GREEN}✓ MCP server packages installed${NC}\n"

    if [ "$WRITE_GLOBAL_CONFIG" = true ]; then
        mkdir -p "$SETTINGS_DIR"
        KIRO_MCP_CONFIG="$SETTINGS_DIR/mcp.json"
        [ -f "$KIRO_MCP_CONFIG" ] && rm -f "$KIRO_MCP_CONFIG"
        printf "${YELLOW}Writing global MCP fallback config: %s${NC}\n" "$KIRO_MCP_CONFIG"
        cat > "$KIRO_MCP_CONFIG" << EOF
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "$HOME"]
    },
    "memory": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"]
    },
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"]
    },
    "dart": {
      "command": "dart",
      "args": ["mcp-server"]
    },
    "mempalace": {
      "command": "uvx",
      "args": ["--from", "mempalace", "mempalace-mcp"]
    }
  }
}
EOF
        printf "${GREEN}✓ Global MCP config written${NC}\n"
    fi
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
    mkdir -p "$SETTINGS_DIR"
    [ -f "$HOOKS_FILE" ] && rm -f "$HOOKS_FILE"

    cat > "$HOOKS_FILE" << EOF
{
  "hooks": {
    "postToolUse": [
      {
        "matcher": "fs_write|write",
        "command": "$HOOK_SCRIPT"
      }
    ],
    "stop": [
      {
        "command": "$TASK_HOOK_SCRIPT"
      }
    ]
  }
}
EOF
    printf "${GREEN}✓ Hooks configuration written to %s${NC}\n" "$HOOKS_FILE"
    printf "${YELLOW}Note:${NC} IDE hooks are configured via the Command Palette (Kiro: Open Hooks Configuration).\n"
}

# Parse arguments
DO_AGENTS=true
DO_SKILLS=true
DO_MCPS=true
DO_HOOKS=true
WRITE_GLOBAL_CONFIG=false
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
        --with-global-config) WRITE_GLOBAL_CONFIG=true ;;
        *) printf "${RED}Unknown option: %s${NC}\n" "$1"; usage; exit 1 ;;
    esac
    shift
done

printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "${CYAN}Kiro CLI Installer${NC}\n"
printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"

if [ "$DO_AGENTS" = true ]; then install_agents; echo ""; fi
if [ "$DO_SKILLS" = true ]; then install_skills; echo ""; fi
if [ "$DO_MCPS" = true ]; then install_mcps; echo ""; fi
if [ "$DO_HOOKS" = true ]; then install_hooks; echo ""; fi

printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "${GREEN}Installation complete! 🎉${NC}\n"
printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"
echo "Next steps:"
echo "  • Restart Kiro CLI to pick up agents, skills and packages"
echo "  • '/agent list' to see agents, '/agent use <name>' to switch"
[ "$DO_MCPS" = true ] && echo "  • Ensure AWS credentials are configured (~/.aws/credentials)"
echo ""
