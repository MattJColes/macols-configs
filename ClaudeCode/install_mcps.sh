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
MCP_CONFIG_FILE="$SCRIPT_DIR/mcp-config.json"

# Ensure Node.js is in PATH (sources NVM/fnm if needed)
# shellcheck source=../shared/ensure_node.sh
source "$SHARED_DIR/ensure_node.sh"

echo -e "${GREEN}Installing MCP Servers for Claude Code...${NC}\n"
echo -e "${BLUE}Reads $MCP_CONFIG_FILE and registers each server via 'claude mcp add-json'${NC}"
echo -e "${BLUE}at user scope, so they're available in every Claude Code session.${NC}\n"

# Check claude CLI
if ! command -v claude &> /dev/null; then
    echo -e "${RED}claude CLI not found. Install Claude Code first: https://docs.claude.com/claude-code${NC}"
    exit 1
fi
echo -e "${GREEN}✓ claude CLI found${NC}"

# Check jq
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}jq not found. Installing...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]] && command -v brew &> /dev/null; then
        brew install jq
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt-get install -y jq
    else
        echo -e "${RED}Please install jq manually: https://stedolan.github.io/jq/${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✓ jq found: $(jq --version)${NC}"

# Check uv (for uvx-based MCP servers)
if ! command -v uv &> /dev/null; then
    echo -e "${YELLOW}uv not found. Installing...${NC}"
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
fi
if command -v uv &> /dev/null; then
    echo -e "${GREEN}✓ uv found: $(uv --version)${NC}"
else
    echo -e "${YELLOW}⚠ uv not on PATH yet — uvx-based MCPs (e.g. dynamodb) may fail until shell is reloaded${NC}"
fi

if [ ! -f "$MCP_CONFIG_FILE" ]; then
    echo -e "${RED}MCP config file not found: $MCP_CONFIG_FILE${NC}"
    exit 1
fi

echo -e "\n${BLUE}Registering MCP servers from mcp-config.json...${NC}\n"

# Iterate over each server in mcp-config.json and register it via `claude mcp add-json`.
# Expand $HOME (and other env vars) in args before passing to claude.
SERVER_NAMES=$(jq -r '.mcpServers | keys[]' "$MCP_CONFIG_FILE")

for name in $SERVER_NAMES; do
    echo -e "${BLUE}→ $name${NC}"

    # Extract this server's config and expand $HOME in args (the only shell var used).
    server_json=$(jq --arg name "$name" --arg home "$HOME" \
        '.mcpServers[$name] | walk(if type == "string" then gsub("\\$HOME"; $home) else . end)' \
        "$MCP_CONFIG_FILE")

    # Remove any existing server with this name (any scope) so install is idempotent.
    claude mcp remove "$name" >/dev/null 2>&1 || true

    if claude mcp add-json -s user "$name" "$server_json" >/dev/null; then
        echo -e "  ${GREEN}✓ registered${NC}"
    else
        echo -e "  ${RED}✗ failed to register${NC}"
    fi
done

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}MCP Installation Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${YELLOW}Currently registered MCP servers:${NC}"
claude mcp list || true

echo -e "\n${YELLOW}Next steps:${NC}"
echo "  • Restart Claude Code to load the new MCP servers"
echo "  • Run 'claude mcp list' any time to inspect registered servers"
echo "  • Edit mcp-config.json and re-run this script to update"
