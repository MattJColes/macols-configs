#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SHARED_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/shared"

# Ensure Node.js is in PATH (sources NVM/fnm if needed)
# shellcheck source=../shared/ensure_node.sh
source "$SHARED_DIR/ensure_node.sh"

echo -e "${GREEN}Installing Model Context Protocol (MCP) Servers for OpenCode...${NC}\n"

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
    echo -e "${GREEN}OK Node.js found: $(node --version)${NC}"
fi

# Check npm
if ! command -v npm &> /dev/null; then
    echo -e "${RED}npm not found. Please install npm.${NC}"
    exit 1
else
    echo -e "${GREEN}OK npm found: $(npm --version)${NC}"
fi

# Check uv (Python package manager)
if ! command -v uv &> /dev/null; then
    echo -e "${YELLOW}uv not found. Installing...${NC}"
    curl -LsSf https://astral.sh/uv/install.sh | sh

    # Source the uv env
    export PATH="$HOME/.cargo/bin:$PATH"

    if command -v uv &> /dev/null; then
        echo -e "${GREEN}OK uv installed successfully${NC}"
    else
        echo -e "${YELLOW}Warning: uv installation may require shell restart. Please run: source ~/.bashrc${NC}"
    fi
else
    echo -e "${GREEN}OK uv found: $(uv --version)${NC}"
fi

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

echo -e "${BLUE}Installing @upstash/context7-mcp...${NC}"
npm install -g @upstash/context7-mcp

echo -e "${BLUE}Installing awslabs.dynamodb-mcp-server (Python)...${NC}"
# Python package installed via uvx on-demand, no pre-install needed

# Check for Dart SDK (required for dart MCP server, built into Dart 3.9+)
if command -v dart &> /dev/null; then
    echo -e "${GREEN}OK Dart MCP (built into Dart SDK: $(dart --version 2>&1 | head -1))${NC}"
else
    echo -e "${YELLOW}Warning: Dart SDK not found - install Dart 3.9+ for Flutter/Dart MCP server${NC}"
fi

echo -e "\n${GREEN}OK All MCP servers installed${NC}\n"

# Configure OpenCode
OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
OPENCODE_MCP_CONFIG="$OPENCODE_CONFIG_DIR/mcp.json"

mkdir -p "$OPENCODE_CONFIG_DIR"

# Clean existing MCP config for a fresh install
if [ -f "$OPENCODE_MCP_CONFIG" ]; then
    echo -e "${YELLOW}Clearing existing MCP config: $OPENCODE_MCP_CONFIG${NC}"
    rm -f "$OPENCODE_MCP_CONFIG"
fi

echo -e "${YELLOW}Configuring MCP servers for OpenCode...${NC}\n"

# Create or update OpenCode config
cat > "$OPENCODE_MCP_CONFIG" << EOF
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
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"]
    },
    "dynamodb": {
      "command": "uvx",
      "args": ["awslabs.dynamodb-mcp-server@latest"],
      "env": {
        "AWS_REGION": "ap-southeast-2",
        "AWS_PROFILE": "default",
        "DDB-MCP-READONLY": "false"
      }
    },
    "dart": {
      "command": "dart",
      "args": ["mcp-server"]
    }
  }
}
EOF

echo -e "${GREEN}OK OpenCode MCP configuration updated: $OPENCODE_MCP_CONFIG${NC}\n"

# Summary
echo -e "${GREEN}--------------------------------------------${NC}"
echo -e "${GREEN}MCP Installation Complete for OpenCode!${NC}"
echo -e "${GREEN}--------------------------------------------${NC}\n"

echo -e "${YELLOW}Installed MCP Servers:${NC}"
echo "  1. filesystem          - File operations for all agents"
echo "  2. sequential-thinking - Complex problem-solving, system design planning"
echo "  3. puppeteer           - Browser automation, screenshots, UI testing"
echo "  4. playwright          - Cross-browser testing, modern web automation"
echo "  5. memory              - Knowledge graph memory, maintains context across sessions"
echo "  6. aws-kb              - AWS Knowledge Base retrieval"
echo "  7. context7            - Real-time version-specific documentation"
echo "  8. dynamodb            - DynamoDB operations (backend, data modeling)"
echo "  9. dart                - Dart/Flutter MCP server (project context, tools)"

echo -e "\n${YELLOW}Configuration:${NC}"
echo "  Location: $OPENCODE_MCP_CONFIG"

echo -e "\n${YELLOW}Next Steps:${NC}"
echo "  - Run ./install_skills.sh to install agent skills"
echo "  - Ensure AWS credentials are configured (~/.aws/credentials)"
echo "  - Configure DynamoDB MCP by setting AWS_REGION if needed"
echo "  - Restart OpenCode to load MCP servers"
echo "  - Run ./configure_lmstudio.sh to set up GLM4.7-Air via LM Studio"

echo -e "\n${GREEN}Done!${NC}"
