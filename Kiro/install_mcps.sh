#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse flags
WRITE_GLOBAL_CONFIG=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --with-global-config)
            WRITE_GLOBAL_CONFIG=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Installs MCP server npm/Python packages so agents can use them via npx/uvx."
            echo ""
            echo "Options:"
            echo "  --with-global-config  Also write ~/.kiro/settings/mcp.json (optional)"
            echo "  -h, --help            Show this help message"
            echo ""
            echo "Note: Agents now include per-agent MCP configs. The global mcp.json is"
            echo "only needed if you use Kiro without custom agents (kiro_default agent)."
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${GREEN}Installing MCP Server Packages for Kiro CLI...${NC}\n"
echo -e "${BLUE}Agents use per-agent MCP configs. This script installs the npm/Python${NC}"
echo -e "${BLUE}packages so they're available when agents launch MCP servers via npx/uvx.${NC}\n"

# Check for required dependencies
echo -e "${BLUE}Checking system dependencies...${NC}\n"

# Check Node.js
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}Node.js not found. Installing...${NC}"

    if [[ "$OSTYPE" == "linux-gnu"* ]] || grep -qi microsoft /proc/version 2>/dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            brew install node
        else
            echo -e "${RED}Homebrew not found. Please install Node.js manually: https://nodejs.org/${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Unsupported OS. Please install Node.js manually: https://nodejs.org/${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ Node.js found: $(node --version)${NC}"
fi

# Check npm
if ! command -v npm &> /dev/null; then
    echo -e "${RED}npm not found. Please install npm.${NC}"
    exit 1
else
    echo -e "${GREEN}✓ npm found: $(npm --version)${NC}"
fi

# Check uv (Python package manager)
if ! command -v uv &> /dev/null; then
    echo -e "${YELLOW}uv not found. Installing...${NC}"
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.cargo/bin:$PATH"

    if command -v uv &> /dev/null; then
        echo -e "${GREEN}✓ uv installed successfully${NC}"
    else
        echo -e "${YELLOW}⚠ uv installation may require shell restart. Please run: source ~/.bashrc${NC}"
    fi
else
    echo -e "${GREEN}✓ uv found: $(uv --version)${NC}"
fi

echo -e "\n${GREEN}Installing MCP server packages...${NC}\n"

# Create global MCP directory
MCP_DIR="$HOME/.mcp/servers"
mkdir -p "$MCP_DIR"

# Install core MCP server packages
echo -e "${BLUE}Installing @modelcontextprotocol/server-filesystem...${NC}"
npm install -g @modelcontextprotocol/server-filesystem

echo -e "${BLUE}Installing @modelcontextprotocol/server-sequential-thinking...${NC}"
npm install -g @modelcontextprotocol/server-sequential-thinking

echo -e "${BLUE}Installing @modelcontextprotocol/server-puppeteer...${NC}"
npm install -g @modelcontextprotocol/server-puppeteer

echo -e "${BLUE}Installing @playwright/mcp...${NC}"
npm install -g @playwright/mcp

echo -e "${BLUE}Installing @modelcontextprotocol/server-memory...${NC}"
npm install -g @modelcontextprotocol/server-memory

echo -e "${BLUE}Installing @modelcontextprotocol/server-aws-kb-retrieval...${NC}"
npm install -g @modelcontextprotocol/server-aws-kb-retrieval

echo -e "${BLUE}Installing @upstash/context7-mcp...${NC}"
npm install -g @upstash/context7-mcp

# Optional MCPs
INSTALL_GITHUB=false
INSTALL_GITLAB=false

# Auto-skip interactive prompts if stdin is not a terminal
if [ -t 0 ]; then
    read -p "$(echo -e "${YELLOW}Install GitHub MCP? [y/N]: ${NC}")" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        INSTALL_GITHUB=true
        echo -e "${BLUE}Installing @modelcontextprotocol/server-github...${NC}"
        npm install -g @modelcontextprotocol/server-github
    fi

    read -p "$(echo -e "${YELLOW}Install GitLab MCP? [y/N]: ${NC}")" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        INSTALL_GITLAB=true
        echo -e "${BLUE}Installing @modelcontextprotocol/server-gitlab...${NC}"
        npm install -g @modelcontextprotocol/server-gitlab
    fi
fi

echo -e "${BLUE}DynamoDB MCP (Python via uvx) - no pre-install needed${NC}"

echo -e "\n${GREEN}✓ All MCP server packages installed${NC}\n"

# Optionally write global mcp.json
if [ "$WRITE_GLOBAL_CONFIG" = true ]; then
    KIRO_SETTINGS_DIR="$HOME/.kiro/settings"
    KIRO_MCP_CONFIG="$KIRO_SETTINGS_DIR/mcp.json"
    mkdir -p "$KIRO_SETTINGS_DIR"

    # Clean existing MCP config for a fresh install
    if [ -f "$KIRO_MCP_CONFIG" ]; then
        echo -e "${YELLOW}Clearing existing MCP config: $KIRO_MCP_CONFIG${NC}"
        rm -f "$KIRO_MCP_CONFIG"
    fi

    echo -e "${YELLOW}Writing minimal global MCP config: $KIRO_MCP_CONFIG${NC}\n"
    echo -e "${BLUE}Note: This is a fallback for the kiro_default agent only.${NC}"
    echo -e "${BLUE}Custom agents use their own per-agent mcpServers config.${NC}\n"

    cat > "$KIRO_MCP_CONFIG" << EOF
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "$HOME"
      ]
    },
    "memory": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"]
    },
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"]
    }
  }
}
EOF

    echo -e "${GREEN}✓ Global MCP config written: $KIRO_MCP_CONFIG${NC}\n"
fi

# Summary
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}MCP Package Installation Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${YELLOW}Installed MCP Packages:${NC}"
echo "  1. filesystem          - File operations"
echo "  2. sequential-thinking - Complex problem-solving"
echo "  3. puppeteer           - Browser automation"
echo "  4. playwright          - Cross-browser testing"
echo "  5. memory              - Knowledge graph memory"
echo "  6. aws-kb              - AWS Knowledge Base retrieval"
echo "  7. context7            - Real-time library documentation"
echo "  8. dynamodb            - DynamoDB operations (via uvx, on-demand)"
echo "  9. dart                - Dart/Flutter MCP server (project context, tools)"
if [ "$INSTALL_GITHUB" = true ]; then
    echo " 10. github              - GitHub repository operations"
fi
if [ "$INSTALL_GITLAB" = true ]; then
    echo " 11. gitlab              - GitLab repository operations"
fi

echo -e "\n${YELLOW}Architecture:${NC}"
echo "  Each agent defines its own mcpServers in its JSON config."
echo "  Agents set includeMcpJson: false to avoid loading global MCPs."
echo "  Only the MCPs an agent needs are started when switching to it."
if [ "$WRITE_GLOBAL_CONFIG" = false ]; then
    echo ""
    echo "  To also write a global fallback config, run:"
    echo "    bash $0 --with-global-config"
fi

echo -e "\n${YELLOW}Next Steps:${NC}"
echo "  • Ensure AWS credentials are configured (~/.aws/credentials)"
echo "  • Restart Kiro CLI to pick up installed packages"

echo -e "\n${GREEN}Done! 🎉${NC}"
