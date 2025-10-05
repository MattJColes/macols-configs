#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Installing Model Context Protocol (MCP) Servers for Claude Code...${NC}\n"

# Check for required dependencies
echo -e "${BLUE}Checking system dependencies...${NC}\n"

# Check Node.js
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}Node.js not found. Installing...${NC}"

    # Detect OS and install Node.js
    if [[ "$OSTYPE" == "linux-gnu"* ]] || grep -qi microsoft /proc/version 2>/dev/null; then
        # Linux or WSL
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
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

    # Source the uv env
    export PATH="$HOME/.cargo/bin:$PATH"

    if command -v uv &> /dev/null; then
        echo -e "${GREEN}✓ uv installed successfully${NC}"
    else
        echo -e "${YELLOW}⚠ uv installation may require shell restart. Please run: source ~/.bashrc${NC}"
    fi
else
    echo -e "${GREEN}✓ uv found: $(uv --version)${NC}"
fi

# Git check removed - not needed without GitHub MCP

echo -e "\n${GREEN}Installing MCP servers...${NC}\n"

# Create global MCP directory
MCP_DIR="$HOME/.mcp/servers"
mkdir -p "$MCP_DIR"

# Install MCP servers globally
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

echo -e "${BLUE}Installing awslabs.dynamodb-mcp-server (Python)...${NC}"
# Python package installed via uvx on-demand, no pre-install needed

echo -e "\n${GREEN}✓ All MCP servers installed${NC}\n"

# Configure Claude Code
CLAUDE_CONFIG_DIR="$HOME/.claude"
CLAUDE_CONFIG_FILE="$CLAUDE_CONFIG_DIR/config.json"

mkdir -p "$CLAUDE_CONFIG_DIR"

echo -e "${YELLOW}Configuring MCP servers for Claude Code...${NC}\n"

# No credential prompts needed for these MCPs

# Create or update Claude config
cat > "$CLAUDE_CONFIG_FILE" << EOF
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
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
    },
    "puppeteer": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-puppeteer"]
    },
    "playwright": {
      "command": "npx",
      "args": ["-y", "@playwright/mcp"]
    },
    "memory": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"]
    },
    "aws-kb": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-aws-kb-retrieval"],
      "env": {
        "AWS_PROFILE": "default"
      }
    },
    "dynamodb": {
      "command": "uvx",
      "args": ["awslabs.dynamodb-mcp-server@latest"],
      "env": {
        "AWS_REGION": "us-east-1",
        "AWS_PROFILE": "default",
        "DDB-MCP-READONLY": "false"
      }
    }
  }
}
EOF

echo -e "${GREEN}✓ Claude Code configuration updated: $CLAUDE_CONFIG_FILE${NC}\n"

# Summary
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}MCP Installation Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${YELLOW}Installed MCP Servers:${NC}"
echo "  1. filesystem          - File operations for all agents"
echo "  2. sequential-thinking - Complex problem-solving, system design planning"
echo "  3. puppeteer           - Browser automation, screenshots, UI testing"
echo "  4. playwright          - Cross-browser testing, modern web automation"
echo "  5. memory              - Knowledge graph memory, maintains context across sessions"
echo "  6. aws                 - AWS service interactions (CDK, backend, DevOps)"
echo "  7. dynamodb            - DynamoDB operations (backend, data modeling)"

echo -e "\n${YELLOW}Configuration:${NC}"
echo "  Location: $CLAUDE_CONFIG_FILE"

echo -e "\n${YELLOW}Next Steps:${NC}"
echo "  • Ensure AWS credentials are configured (~/.aws/credentials)"
echo "  • Configure DynamoDB MCP by setting AWS_REGION if needed"
echo "  • Restart Claude Code to load MCP servers"
echo "  • Knowledge graph memory will be stored in ~/.claude/memory"

echo -e "\n${YELLOW}Usage:${NC}"
echo "  Claude Code agents will automatically use these MCPs when needed."
echo "  Examples:"
echo "    • All agents use Sequential Thinking for complex problem-solving"
echo "    • Architecture expert uses Sequential Thinking for system design"
echo "    • Test engineers use Puppeteer and Playwright for browser automation"
echo "    • Memory MCP maintains project context across all sessions"
echo "    • Python backend uses DynamoDB MCP for data modeling"

echo -e "\n${GREEN}Done! 🎉${NC}"
