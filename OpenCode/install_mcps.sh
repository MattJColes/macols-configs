#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

echo -e "\n${GREEN}OK All MCP servers installed${NC}\n"

# Configure OpenCode
# Per https://opencode.ai/docs/mcp-servers/ and /docs/config/:
#   MCP servers go in ~/.config/opencode/opencode.json under the `mcp` key.
#   Per-server shape: {type:"local", command:[...], enabled:true, environment:{...}}.
OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
OPENCODE_CONFIG_FILE="$OPENCODE_CONFIG_DIR/opencode.json"
OPENCODE_LEGACY_MCP="$OPENCODE_CONFIG_DIR/mcp.json"

mkdir -p "$OPENCODE_CONFIG_DIR"

echo -e "${YELLOW}Configuring MCP servers for OpenCode...${NC}\n"

# Merge into opencode.json via node. Only the `mcp` key is replaced; other
# keys (model, provider, permission, tools, ...) are preserved.
OPENCODE_CONFIG_FILE="$OPENCODE_CONFIG_FILE" \
OPENCODE_HOME="$HOME" \
node -e '
const fs = require("fs");
const env = process.env;
const home = env.OPENCODE_HOME;

const mcp = {
  filesystem: {
    type: "local",
    command: ["npx", "-y", "@modelcontextprotocol/server-filesystem", home],
    enabled: true,
  },
  "sequential-thinking": {
    type: "local",
    command: ["npx", "-y", "@modelcontextprotocol/server-sequential-thinking"],
    enabled: true,
  },
  puppeteer: {
    type: "local",
    command: ["npx", "-y", "@modelcontextprotocol/server-puppeteer"],
    enabled: true,
  },
  playwright: {
    type: "local",
    command: ["npx", "-y", "@playwright/mcp"],
    enabled: true,
  },
  memory: {
    type: "local",
    command: ["npx", "-y", "@modelcontextprotocol/server-memory"],
    enabled: true,
  },
  "aws-kb": {
    type: "local",
    command: ["npx", "-y", "@modelcontextprotocol/server-aws-kb-retrieval"],
    enabled: true,
    environment: { AWS_PROFILE: "default" },
  },
  context7: {
    type: "local",
    command: ["npx", "-y", "@upstash/context7-mcp@latest"],
    enabled: true,
  },
  dynamodb: {
    type: "local",
    command: ["uvx", "awslabs.dynamodb-mcp-server@latest"],
    enabled: true,
    environment: {
      AWS_REGION: "ap-southeast-2",
      AWS_PROFILE: "default",
      "DDB-MCP-READONLY": "false",
    },
  },
};

let existing = {};
if (fs.existsSync(env.OPENCODE_CONFIG_FILE)) {
  try { existing = JSON.parse(fs.readFileSync(env.OPENCODE_CONFIG_FILE, "utf8")); } catch (e) {}
}
existing["$schema"] = existing["$schema"] || "https://opencode.ai/config.json";
existing.mcp = mcp;
fs.writeFileSync(env.OPENCODE_CONFIG_FILE, JSON.stringify(existing, null, 2) + "\n");
'

echo -e "${GREEN}OK OpenCode MCP configuration updated: $OPENCODE_CONFIG_FILE${NC}"

# Clean up stale pre-spec mcp.json left by earlier versions of this script.
if [ -f "$OPENCODE_LEGACY_MCP" ]; then
    rm -f "$OPENCODE_LEGACY_MCP"
    echo -e "${YELLOW}Removed legacy $OPENCODE_LEGACY_MCP${NC}"
fi
echo ""

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

echo -e "\n${YELLOW}Configuration:${NC}"
echo "  Location: $OPENCODE_CONFIG_FILE (merged into \"mcp\" key)"

echo -e "\n${YELLOW}Next Steps:${NC}"
echo "  - Run ./install_skills.sh to install agent skills"
echo "  - Ensure AWS credentials are configured (~/.aws/credentials)"
echo "  - Configure DynamoDB MCP by setting AWS_REGION if needed"
echo "  - Restart OpenCode to load MCP servers"

echo -e "\n${GREEN}Done!${NC}"
