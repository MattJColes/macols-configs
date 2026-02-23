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

    # Optional MCPs
    INSTALL_GITHUB=false
    INSTALL_GITLAB=false

    printf "\n"
    printf "${YELLOW}Install GitHub MCP? [y/N]: ${NC}"
    read -r REPLY
    case "$REPLY" in
        [Yy]*)
            INSTALL_GITHUB=true
            npm install -g @modelcontextprotocol/server-github 2>/dev/null && printf "  ${GREEN}✓${NC} github\n" || printf "  ${YELLOW}⚠${NC} github\n"
            ;;
    esac

    printf "${YELLOW}Install GitLab MCP? [y/N]: ${NC}"
    read -r REPLY
    case "$REPLY" in
        [Yy]*)
            INSTALL_GITLAB=true
            npm install -g @modelcontextprotocol/server-gitlab 2>/dev/null && printf "  ${GREEN}✓${NC} gitlab\n" || printf "  ${YELLOW}⚠${NC} gitlab\n"
            ;;
    esac

    printf "\n${GREEN}✓ MCP servers installed${NC}\n"

    # Configure MCPs
    printf "\n${BLUE}Configuring MCP servers...${NC}\n"
    mkdir -p "$CLAUDE_DIR"

    # Build config from mcp-config.json, extracting core servers
    # and optionally adding GitHub/GitLab
    CONFIG_FILE="$CLAUDE_DIR/settings.json"
    SRC_CONFIG="$SCRIPT_DIR/mcp-config.json"

    if command -v node >/dev/null 2>&1; then
        # Use node to properly merge JSON config
        GITHUB_TOKEN=""
        GITLAB_TOKEN=""
        GITLAB_API_URL="https://gitlab.com"

        if [ "$INSTALL_GITHUB" = true ]; then
            printf "${YELLOW}Enter GitHub Personal Access Token (or press Enter to skip): ${NC}"
            read -r GITHUB_TOKEN
        fi

        if [ "$INSTALL_GITLAB" = true ]; then
            printf "${YELLOW}Enter GitLab Personal Access Token (or press Enter to skip): ${NC}"
            read -r GITLAB_TOKEN
            printf "${YELLOW}Enter GitLab API URL [https://gitlab.com]: ${NC}"
            read -r GITLAB_API_URL_INPUT
            if [ -n "$GITLAB_API_URL_INPUT" ]; then
                GITLAB_API_URL="$GITLAB_API_URL_INPUT"
            fi
        fi

        MCP_SRC_CONFIG="$SRC_CONFIG" \
        MCP_CONFIG_FILE="$CONFIG_FILE" \
        MCP_HOME="$HOME" \
        MCP_INSTALL_GITHUB="$INSTALL_GITHUB" \
        MCP_INSTALL_GITLAB="$INSTALL_GITLAB" \
        MCP_GITHUB_TOKEN="$GITHUB_TOKEN" \
        MCP_GITLAB_TOKEN="$GITLAB_TOKEN" \
        MCP_GITLAB_API_URL="$GITLAB_API_URL" \
        node -e '
const fs = require("fs");
const env = process.env;
const src = JSON.parse(fs.readFileSync(env.MCP_SRC_CONFIG, "utf8"));
const config = { mcpServers: { ...src.mcpServers } };

// Replace $HOME placeholder with actual path
const configStr = JSON.stringify(config);
const expanded = configStr.replace(/\$HOME/g, env.MCP_HOME);
const result = JSON.parse(expanded);

// Add optional MCPs
if (env.MCP_INSTALL_GITHUB === "true") {
    result.mcpServers.github = {
        ...src.optionalMcpServers.github,
        env: { GITHUB_PERSONAL_ACCESS_TOKEN: env.MCP_GITHUB_TOKEN }
    };
}
if (env.MCP_INSTALL_GITLAB === "true") {
    result.mcpServers.gitlab = {
        ...src.optionalMcpServers.gitlab,
        env: {
            GITLAB_PERSONAL_ACCESS_TOKEN: env.MCP_GITLAB_TOKEN,
            GITLAB_API_URL: env.MCP_GITLAB_API_URL
        }
    };
}

// Merge with existing settings if present
let existing = {};
if (fs.existsSync(env.MCP_CONFIG_FILE)) {
    try { existing = JSON.parse(fs.readFileSync(env.MCP_CONFIG_FILE, "utf8")); } catch(e) {}
}
existing.mcpServers = result.mcpServers;

fs.writeFileSync(env.MCP_CONFIG_FILE, JSON.stringify(existing, null, 2) + "\n");
'
        printf "${GREEN}✓ MCP configuration written: $CONFIG_FILE${NC}\n"
    else
        printf "${RED}Node.js required for config generation${NC}\n"
        return 1
    fi
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
    echo "    /frontend-engineer-ts   - React/TypeScript frontend"
    echo "    /frontend-engineer-dart - Flutter/Dart frontend"
    echo "    /code-reviewer          - Code quality and security review"
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
    echo "  • Configuration: ~/.claude/settings.json"
    echo ""
fi

printf "${GREEN}Done! 🎉${NC}\n"
