#!/bin/sh
set -eu

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "${GREEN}Claude Code Skills & MCP Installer${NC}\n"
printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
echo ""

# Default installation paths
CLAUDE_DIR="$HOME/.claude"
SKILLS_DIR="$CLAUDE_DIR/skills"
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -h, --help          Show this help message
    -s, --skills-only   Install only skills (skip MCPs)
    -m, --mcps-only     Install only MCPs (skip skills)
    -p, --project       Install skills to current project (.claude/skills/)
    --list              List available skills

EOF
}

list_skills() {
    printf "${BLUE}Available Skills:${NC}\n"
    echo ""
    for skill_dir in "$SCRIPT_DIR/skills"/*; do
        if [ -d "$skill_dir" ]; then
            skill_name=$(basename "$skill_dir")
            if [ -f "$skill_dir/SKILL.md" ]; then
                description=$(grep -A1 "^description:" "$skill_dir/SKILL.md" | head -1 | sed 's/^description: //')
                printf "  ${GREEN}%-25s${NC} %s\n" "$skill_name" "$description"
            fi
        fi
    done
    echo ""
}

install_skills() {
    target_dir="$1"

    # Clean existing skills for a fresh install
    if [ -d "$target_dir" ]; then
        printf "${YELLOW}Clearing existing skills in: $target_dir${NC}\n"
        rm -rf "$target_dir"
    fi

    printf "${BLUE}Installing skills to: $target_dir${NC}\n"
    mkdir -p "$target_dir"

    count=0
    for skill_dir in "$SCRIPT_DIR/skills"/*; do
        if [ -d "$skill_dir" ]; then
            skill_name=$(basename "$skill_dir")
            target_skill_dir="$target_dir/$skill_name"

            mkdir -p "$target_skill_dir"
            cp "$skill_dir/SKILL.md" "$target_skill_dir/SKILL.md"

            printf "  ${GREEN}✓${NC} %s\n" "$skill_name"
            count=$((count + 1))
        fi
    done

    printf "\n${GREEN}✓ Installed %d skills${NC}\n" "$count"
}

install_mcps() {
    printf "\n${BLUE}Installing MCP servers...${NC}\n"

    # Check for Node.js
    if ! command -v node >/dev/null 2>&1; then
        printf "${RED}Node.js not found. Please install Node.js first.${NC}\n"
        return 1
    fi

    # Check for npm
    if ! command -v npm >/dev/null 2>&1; then
        printf "${RED}npm not found. Please install npm.${NC}\n"
        return 1
    fi

    printf "${GREEN}✓ Node.js found: %s${NC}\n" "$(node --version)"
    printf "${GREEN}✓ npm found: %s${NC}\n" "$(npm --version)"

    # Check for uv (Python package manager, needed for DynamoDB MCP)
    if ! command -v uv >/dev/null 2>&1; then
        printf "${YELLOW}uv not found. Installing...${NC}\n"
        curl -LsSf https://astral.sh/uv/install.sh | sh
        PATH="$HOME/.cargo/bin:$PATH"
        export PATH
        if command -v uv >/dev/null 2>&1; then
            printf "${GREEN}✓ uv installed successfully${NC}\n"
        else
            printf "${YELLOW}⚠ uv installation may require shell restart${NC}\n"
        fi
    else
        printf "${GREEN}✓ uv found: %s${NC}\n" "$(uv --version)"
    fi

    # Install core MCP servers
    printf "\n${BLUE}Installing core MCP packages...${NC}\n"

    npm install -g @modelcontextprotocol/server-filesystem 2>/dev/null && printf "  ${GREEN}✓${NC} filesystem\n" || printf "  ${YELLOW}⚠${NC} filesystem (may already be installed)\n"
    npm install -g @modelcontextprotocol/server-sequential-thinking 2>/dev/null && printf "  ${GREEN}✓${NC} sequential-thinking\n" || printf "  ${YELLOW}⚠${NC} sequential-thinking\n"
    npm install -g @modelcontextprotocol/server-puppeteer 2>/dev/null && printf "  ${GREEN}✓${NC} puppeteer\n" || printf "  ${YELLOW}⚠${NC} puppeteer\n"
    npm install -g @playwright/mcp 2>/dev/null && printf "  ${GREEN}✓${NC} playwright\n" || printf "  ${YELLOW}⚠${NC} playwright\n"
    npm install -g @modelcontextprotocol/server-memory 2>/dev/null && printf "  ${GREEN}✓${NC} memory\n" || printf "  ${YELLOW}⚠${NC} memory\n"
    npm install -g @modelcontextprotocol/server-aws-kb-retrieval 2>/dev/null && printf "  ${GREEN}✓${NC} aws-kb-retrieval\n" || printf "  ${YELLOW}⚠${NC} aws-kb-retrieval\n"
    npm install -g @upstash/context7-mcp 2>/dev/null && printf "  ${GREEN}✓${NC} context7\n" || printf "  ${YELLOW}⚠${NC} context7\n"
    printf "  ${GREEN}✓${NC} dynamodb (installed on-demand via uvx)\n"

    printf "\n${GREEN}✓ MCP servers installed${NC}\n"

    # Configure MCPs via the official `claude mcp` CLI (writes to ~/.claude.json
    # at user scope). Writing to ~/.claude/settings.json does NOT register MCPs
    # with Claude Code — that was the prior bug.
    printf "\n${BLUE}Configuring MCP servers...${NC}\n"

    if ! command -v claude >/dev/null 2>&1; then
        printf "${RED}claude CLI not found. Install Claude Code first, then re-run.${NC}\n"
        return 1
    fi

    SRC_CONFIG="$SCRIPT_DIR/mcp-config.json"

    # List server names from mcp-config.json
    names=$(MCP_SRC_CONFIG="$SRC_CONFIG" node -e '
const fs = require("fs");
const src = JSON.parse(fs.readFileSync(process.env.MCP_SRC_CONFIG, "utf8"));
process.stdout.write(Object.keys(src.mcpServers).join("\n"));
')

    for name in $names; do
        # Extract the single-server JSON with $HOME expanded.
        server_json=$(MCP_SRC_CONFIG="$SRC_CONFIG" MCP_NAME="$name" MCP_HOME="$HOME" node -e '
const fs = require("fs");
const env = process.env;
const src = JSON.parse(fs.readFileSync(env.MCP_SRC_CONFIG, "utf8"));
const entryStr = JSON.stringify(src.mcpServers[env.MCP_NAME]);
process.stdout.write(entryStr.replace(/\$HOME/g, env.MCP_HOME));
')

        # Idempotent: remove any existing user-scope entry, then add fresh.
        claude mcp remove "$name" -s user >/dev/null 2>&1 || true
        if claude mcp add-json -s user "$name" "$server_json" >/dev/null 2>&1; then
            printf "  ${GREEN}✓${NC} %s\n" "$name"
        else
            printf "  ${RED}✗${NC} %s (claude mcp add-json failed)\n" "$name"
        fi
    done

    printf "\n${GREEN}✓ MCP configuration written to ~/.claude.json (user scope)${NC}\n"
    printf "\n${BLUE}Current MCP servers:${NC}\n"
    claude mcp list 2>&1 || true
}

# Parse arguments
INSTALL_SKILLS=true
INSTALL_MCPS=true
PROJECT_INSTALL=false

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -s|--skills-only)
            INSTALL_MCPS=false
            shift
            ;;
        -m|--mcps-only)
            INSTALL_SKILLS=false
            shift
            ;;
        -p|--project)
            PROJECT_INSTALL=true
            shift
            ;;
        --list)
            list_skills
            exit 0
            ;;
        *)
            printf "${RED}Unknown option: $1${NC}\n"
            usage
            exit 1
            ;;
    esac
done

# Install skills
if [ "$INSTALL_SKILLS" = true ]; then
    if [ "$PROJECT_INSTALL" = true ]; then
        install_skills "./.claude/skills"
    else
        install_skills "$SKILLS_DIR"
    fi
fi

# Install MCPs
if [ "$INSTALL_MCPS" = true ]; then
    install_mcps
fi

# Summary
echo ""
printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "${GREEN}Installation Complete!${NC}\n"
printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
echo ""

if [ "$INSTALL_SKILLS" = true ]; then
    printf "${YELLOW}Skills Usage:${NC}\n"
    echo "  Invoke skills with slash commands in Claude Code:"
    echo "    /architecture-expert  - System design and AWS architecture"
    echo "    /python-backend       - Python API development"
    echo "    /frontend-engineer    - React/TypeScript frontend"
    echo "    /code-reviewer        - Code quality and security review"
    echo "    /devops-engineer      - CI/CD and containerization"
    echo "  Use --list to see all available skills"
    echo ""
fi

if [ "$INSTALL_MCPS" = true ]; then
    printf "${YELLOW}MCP Servers:${NC}\n"
    echo "  MCPs are automatically available to Claude Code."
    echo "  Installed:"
    echo "    • filesystem          - File operations"
    echo "    • sequential-thinking - Complex problem-solving"
    echo "    • puppeteer           - Browser automation, screenshots"
    echo "    • playwright          - Cross-browser testing"
    echo "    • memory              - Persistent knowledge graph"
    echo "    • aws-kb              - AWS knowledge base retrieval"
    echo "    • context7            - Real-time library documentation"
    echo "    • dynamodb            - DynamoDB operations (via uvx)"
    echo ""
    printf "${YELLOW}Next Steps:${NC}\n"
    echo "  • Restart Claude Code to load the new configuration"
    echo "  • Configure AWS credentials (~/.aws/credentials) for aws-kb and dynamodb MCPs"
    echo "  • Configuration: ~/.claude.json (user scope)"
    echo ""
fi

printf "${GREEN}Done! 🎉${NC}\n"
