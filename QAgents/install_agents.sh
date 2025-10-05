#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Installing Amazon Q Developer CLI Agents...${NC}\n"

# Amazon Q Developer CLI agents directory
AGENTS_DIR="$HOME/.aws/amazonq/cli-agents"
mkdir -p "$AGENTS_DIR"

echo -e "${YELLOW}Installing agents to: $AGENTS_DIR${NC}\n"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_AGENTS_DIR="$SCRIPT_DIR/agents"

# Check if agents directory exists
if [[ ! -d "$SOURCE_AGENTS_DIR" ]]; then
  echo -e "${RED}Error: agents directory not found at $SOURCE_AGENTS_DIR${NC}"
  exit 1
fi

# Count JSON files
AGENT_COUNT=$(find "$SOURCE_AGENTS_DIR" -name "*.json" -type f | wc -l)

if [[ $AGENT_COUNT -eq 0 ]]; then
  echo -e "${RED}Error: No agent JSON files found in $SOURCE_AGENTS_DIR${NC}"
  exit 1
fi

echo -e "${BLUE}Found $AGENT_COUNT agent(s) to install${NC}\n"

# Copy all JSON agent files
echo -e "${GREEN}Installing agents:${NC}"
for agent_file in "$SOURCE_AGENTS_DIR"/*.json; do
  agent_name=$(basename "$agent_file")
  cp "$agent_file" "$AGENTS_DIR/$agent_name"
  echo -e "  ${GREEN}✓${NC} $agent_name"
done

echo -e "\n${GREEN}✓ Successfully installed $AGENT_COUNT agents${NC}\n"

echo -e "${YELLOW}Installed agents:${NC}"
echo "  • code-reviewer        - Security, architecture, and complexity review"
echo "  • frontend-engineer    - TypeScript/React development"
echo "  • python-backend       - Python 3.12 backend with databases"
echo "  • aws-cdk-expert       - AWS CDK infrastructure as code"
echo "  • devops-engineer      - CI/CD pipelines and security scanning"
echo "  • linux-specialist     - Shell scripting and system administration"
echo "  • python-test-engineer - Python testing with pytest"
echo "  • typescript-test-engineer - TypeScript testing with Jest/Playwright"
echo "  • product-manager      - Feature tracking and preservation"
echo "  • documentation-engineer - README, DEVELOPMENT, ARCHITECTURE docs"
echo "  • data-scientist       - Pandas, data analysis, and ML"
echo "  • ui-ux-designer       - Design systems and user experience"
echo "  • architecture-expert  - System architecture and design patterns"
echo "  • test-coordinator     - Test strategy and coordination"
echo "  • project-coordinator  - Project management and team coordination"

echo -e "\n${YELLOW}Agents directory: $AGENTS_DIR${NC}"

echo -e "\n${GREEN}Usage with Amazon Q Developer CLI:${NC}"
echo "  q chat                                    # Start Q chat session"
echo "  /agent list                               # List available agents"
echo "  /agent use code-reviewer                  # Use specific agent"
echo ""
echo "  Example prompts:"
echo "    \"Use code-reviewer to review my changes\""
echo "    \"Switch to frontend-engineer agent\""
echo "    \"Use python-backend to help with the API\""

echo -e "\n${GREEN}Managing agents:${NC}"
echo "  View installed agents:   ls $AGENTS_DIR"
echo "  Remove all agents:       rm -rf $AGENTS_DIR"
echo "  Reinstall:               bash $0"

echo -e "\n${GREEN}Done! 🎉${NC}"
echo -e "${BLUE}Tip: Amazon Q will automatically suggest relevant agents based on your task${NC}"
