#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Installing Model Context Protocol (MCP) Servers for Amazon Q Developer...${NC}\n"

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

# Check git
if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}⚠ git not found. GitHub MCP will not work without git.${NC}"
    read -p "Install git now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [[ "$OSTYPE" == "linux-gnu"* ]] || grep -qi microsoft /proc/version 2>/dev/null; then
            sudo apt-get install -y git
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            brew install git
        fi
    fi
else
    echo -e "${GREEN}✓ git found: $(git --version | head -n1)${NC}"
fi

echo -e "\n${GREEN}Installing MCP servers...${NC}\n"

# Create global MCP directory
MCP_DIR="$HOME/.mcp/servers"
mkdir -p "$MCP_DIR"

# Install MCP servers globally
echo -e "${BLUE}Installing @modelcontextprotocol/server-filesystem...${NC}"
npm install -g @modelcontextprotocol/server-filesystem

echo -e "${BLUE}Installing @modelcontextprotocol/server-github...${NC}"
npm install -g @modelcontextprotocol/server-github

echo -e "${BLUE}Installing @modelcontextprotocol/server-aws...${NC}"
npm install -g @modelcontextprotocol/server-aws

echo -e "${BLUE}Installing @modelcontextprotocol/server-postgres...${NC}"
npm install -g @modelcontextprotocol/server-postgres

echo -e "${BLUE}Installing @modelcontextprotocol/server-brave-search...${NC}"
npm install -g @modelcontextprotocol/server-brave-search

echo -e "\n${GREEN}✓ All MCP servers installed${NC}\n"

# Configure Amazon Q Developer
Q_CONFIG_DIR="$HOME/.aws/amazonq"
Q_CONFIG_FILE="$Q_CONFIG_DIR/mcp-config.json"

mkdir -p "$Q_CONFIG_DIR"

echo -e "${YELLOW}Configuring MCP servers for Amazon Q Developer...${NC}\n"

# Prompt for credentials
echo -e "${BLUE}GitHub MCP Configuration:${NC}"
echo "To use the GitHub MCP, you need a GitHub Personal Access Token."
echo "Create one at: https://github.com/settings/tokens (needs 'repo' scope)"
read -p "Enter GitHub Personal Access Token (or press Enter to skip): " GITHUB_TOKEN
echo

echo -e "${BLUE}Brave Search MCP Configuration:${NC}"
echo "To use Brave Search MCP, you need a Brave Search API key."
echo "Get one at: https://brave.com/search/api/"
read -p "Enter Brave Search API Key (or press Enter to skip): " BRAVE_API_KEY
echo

# Create or update Q Developer config
cat > "$Q_CONFIG_FILE" << EOF
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
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      }
    },
    "aws": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-aws"],
      "env": {
        "AWS_PROFILE": "default"
      }
    },
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "POSTGRES_CONNECTION_STRING": "postgresql://localhost/mydb"
      }
    },
    "brave-search": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-brave-search"],
      "env": {
        "BRAVE_API_KEY": "${BRAVE_API_KEY}"
      }
    }
  }
}
EOF

echo -e "${GREEN}✓ Amazon Q Developer configuration updated: $Q_CONFIG_FILE${NC}\n"

# Summary
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}MCP Installation Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${YELLOW}Installed MCP Servers:${NC}"
echo "  1. filesystem    - File operations for all agents"
echo "  2. github        - PR/issue management (DevOps, code reviewer)"
echo "  3. aws           - AWS service interactions (CDK, backend, DevOps)"
echo "  4. postgres      - Database operations (backend, test engineers)"
echo "  5. brave-search  - Latest docs/troubleshooting (all agents)"

echo -e "\n${YELLOW}Configuration:${NC}"
echo "  Location: $Q_CONFIG_FILE"

echo -e "\n${YELLOW}Next Steps:${NC}"
if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "  • Add GitHub token to config for GitHub MCP"
fi
if [[ -z "$BRAVE_API_KEY" ]]; then
    echo "  • Add Brave API key to config for search MCP"
fi
echo "  • Update POSTGRES_CONNECTION_STRING in config for your database"
echo "  • Ensure AWS credentials are configured (~/.aws/credentials)"
echo "  • Restart Amazon Q Developer to load MCP servers"

echo -e "\n${YELLOW}Usage:${NC}"
echo "  Amazon Q Developer agents will automatically use these MCPs when needed."
echo "  Examples:"
echo "    • Python backend will use AWS MCP for DynamoDB operations"
echo "    • DevOps engineer will use GitHub MCP for PR management"
echo "    • All agents will use Brave Search for latest documentation"

echo -e "\n${GREEN}Done! 🎉${NC}"
