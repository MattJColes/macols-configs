#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Claude Code Skills & MCP Installer${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Default installation paths
CLAUDE_DIR="$HOME/.claude"
SKILLS_DIR="$CLAUDE_DIR/skills"
CONFIG_FILE="$CLAUDE_DIR/settings.json"

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
    echo -e "${BLUE}Available Skills:${NC}"
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
    local target_dir="$1"
    
    echo -e "${BLUE}Installing skills to: $target_dir${NC}"
    mkdir -p "$target_dir"
    
    local count=0
    for skill_dir in "$SCRIPT_DIR/skills"/*; do
        if [ -d "$skill_dir" ]; then
            skill_name=$(basename "$skill_dir")
            target_skill_dir="$target_dir/$skill_name"
            
            mkdir -p "$target_skill_dir"
            cp "$skill_dir/SKILL.md" "$target_skill_dir/SKILL.md"
            
            echo -e "  ${GREEN}✓${NC} $skill_name"
            ((count++))
        fi
    done
    
    echo -e "\n${GREEN}✓ Installed $count skills${NC}"
}

install_mcps() {
    echo -e "\n${BLUE}Installing MCP servers...${NC}"
    
    # Check for Node.js
    if ! command -v node &> /dev/null; then
        echo -e "${RED}Node.js not found. Please install Node.js first.${NC}"
        return 1
    fi
    
    # Check for npm
    if ! command -v npm &> /dev/null; then
        echo -e "${RED}npm not found. Please install npm.${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Node.js found: $(node --version)${NC}"
    echo -e "${GREEN}✓ npm found: $(npm --version)${NC}"
    
    # Install core MCP servers
    echo -e "\n${BLUE}Installing MCP packages...${NC}"
    
    npm install -g @modelcontextprotocol/server-filesystem 2>/dev/null && echo -e "  ${GREEN}✓${NC} filesystem" || echo -e "  ${YELLOW}⚠${NC} filesystem (may already be installed)"
    npm install -g @modelcontextprotocol/server-sequential-thinking 2>/dev/null && echo -e "  ${GREEN}✓${NC} sequential-thinking" || echo -e "  ${YELLOW}⚠${NC} sequential-thinking"
    npm install -g @modelcontextprotocol/server-puppeteer 2>/dev/null && echo -e "  ${GREEN}✓${NC} puppeteer" || echo -e "  ${YELLOW}⚠${NC} puppeteer"
    npm install -g @playwright/mcp 2>/dev/null && echo -e "  ${GREEN}✓${NC} playwright" || echo -e "  ${YELLOW}⚠${NC} playwright"
    npm install -g @modelcontextprotocol/server-memory 2>/dev/null && echo -e "  ${GREEN}✓${NC} memory" || echo -e "  ${YELLOW}⚠${NC} memory"
    npm install -g @modelcontextprotocol/server-aws-kb-retrieval 2>/dev/null && echo -e "  ${GREEN}✓${NC} aws-kb-retrieval" || echo -e "  ${YELLOW}⚠${NC} aws-kb-retrieval"
    npm install -g @upstash/context7-mcp 2>/dev/null && echo -e "  ${GREEN}✓${NC} context7" || echo -e "  ${YELLOW}⚠${NC} context7"
    
    echo -e "\n${GREEN}✓ MCP servers installed${NC}"
    
    # Configure MCPs if config doesn't exist
    if [ ! -f "$CLAUDE_DIR/settings.json" ]; then
        echo -e "\n${BLUE}Creating MCP configuration...${NC}"
        mkdir -p "$CLAUDE_DIR"
        cp "$SCRIPT_DIR/mcp-config.json" "$CLAUDE_DIR/settings.json"
        # Replace $HOME with actual path
        sed -i "s|\$HOME|$HOME|g" "$CLAUDE_DIR/settings.json" 2>/dev/null || \
        sed -i '' "s|\$HOME|$HOME|g" "$CLAUDE_DIR/settings.json"
        echo -e "${GREEN}✓ MCP configuration created: $CLAUDE_DIR/settings.json${NC}"
    else
        echo -e "\n${YELLOW}MCP configuration already exists: $CLAUDE_DIR/settings.json${NC}"
        echo -e "${YELLOW}To update, merge with: $SCRIPT_DIR/mcp-config.json${NC}"
    fi
}

# Parse arguments
INSTALL_SKILLS=true
INSTALL_MCPS=true
PROJECT_INSTALL=false

while [[ $# -gt 0 ]]; do
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
            echo -e "${RED}Unknown option: $1${NC}"
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
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ "$INSTALL_SKILLS" = true ]; then
    echo -e "${YELLOW}Skills Usage:${NC}"
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
    echo -e "${YELLOW}MCP Servers:${NC}"
    echo "  MCPs are automatically available to Claude Code."
    echo "  Key MCPs installed:"
    echo "    • context7      - Real-time library documentation"
    echo "    • memory        - Persistent knowledge graph"
    echo "    • playwright    - Browser automation for testing"
    echo "    • filesystem    - File operations"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  • Restart Claude Code to load the new configuration"
    echo "  • Configure AWS credentials if using aws-kb or dynamodb MCPs"
    echo ""
fi

echo -e "${GREEN}Done! 🎉${NC}"
