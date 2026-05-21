#!/bin/bash
set -eu

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Installing Kiro CLI Agents & Skills...${NC}\n"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_AGENTS_DIR="$SCRIPT_DIR/agents"
SOURCE_SKILLS_DIR="$SCRIPT_DIR/skills"

# Kiro CLI directories
AGENTS_DIR="$HOME/.kiro/agents"
SKILLS_DIR="$HOME/.kiro/skills"

# Clean existing agents and skills for a fresh install
if [ -d "$AGENTS_DIR" ]; then
    echo -e "${YELLOW}Clearing existing agents in: $AGENTS_DIR${NC}"
    rm -rf "$AGENTS_DIR"
fi
if [ -d "$SKILLS_DIR" ]; then
    echo -e "${YELLOW}Clearing existing skills in: $SKILLS_DIR${NC}"
    rm -rf "$SKILLS_DIR"
fi

mkdir -p "$AGENTS_DIR" "$SKILLS_DIR"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Install Agents
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo -e "${YELLOW}Installing agents to: $AGENTS_DIR${NC}\n"

if [ ! -d "$SOURCE_AGENTS_DIR" ]; then
  echo -e "${RED}Error: agents directory not found at $SOURCE_AGENTS_DIR${NC}"
  exit 1
fi

AGENT_COUNT=$(find "$SOURCE_AGENTS_DIR" -name "*.json" -type f | wc -l)

if [ "$AGENT_COUNT" -eq 0 ]; then
  echo -e "${RED}Error: No agent JSON files found in $SOURCE_AGENTS_DIR${NC}"
  exit 1
fi

echo -e "${BLUE}Found $AGENT_COUNT agent(s) to install${NC}\n"

echo -e "${GREEN}Installing agents:${NC}"
for agent_file in "$SOURCE_AGENTS_DIR"/*.json; do
  agent_name=$(basename "$agent_file")
  # Copy and expand $HOME in filesystem MCP args
  sed "s|\\\$HOME|$HOME|g" "$agent_file" > "$AGENTS_DIR/$agent_name"
  echo -e "  ${GREEN}✓${NC} $agent_name"
done

echo -e "\n${GREEN}✓ Installed $AGENT_COUNT agents${NC}\n"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Install Skills
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

if [ -d "$SOURCE_SKILLS_DIR" ]; then
  echo -e "${YELLOW}Installing skills to: $SKILLS_DIR${NC}\n"

  SKILL_COUNT=0
  echo -e "${GREEN}Installing skills:${NC}"
  for skill_dir in "$SOURCE_SKILLS_DIR"/*/; do
    skill_name=$(basename "$skill_dir")
    mkdir -p "$SKILLS_DIR/$skill_name"
    cp "$skill_dir/SKILL.md" "$SKILLS_DIR/$skill_name/SKILL.md"
    echo -e "  ${GREEN}✓${NC} $skill_name"
    SKILL_COUNT=$((SKILL_COUNT + 1))
  done

  echo -e "\n${GREEN}✓ Installed $SKILL_COUNT skills${NC}\n"
else
  echo -e "${YELLOW}No skills directory found, skipping skills installation.${NC}\n"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Summary
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${YELLOW}Architecture:${NC}"
echo "  Agents use per-agent MCP configs (only load MCPs they need)"
echo "  Skills use progressive loading (metadata at startup, full content on-demand)"
echo ""

echo -e "${YELLOW}Installed agents:${NC}"
echo "  • architecture-expert     - AWS architecture, caching, scaling"
echo "  • cdk-expert-ts           - AWS CDK TypeScript infrastructure"
echo "  • cdk-expert-python       - AWS CDK Python infrastructure"
echo "  • code-reviewer           - Security, architecture, complexity review"
echo "  • data-scientist          - Pandas, ML, ETL, data lakes"
echo "  • devops-engineer         - CI/CD pipelines and security scanning"
echo "  • documentation-engineer  - README, ARCHITECTURE docs, Mermaid"
echo "  • frontend-engineer-ts    - TypeScript/React development"
echo "  • frontend-engineer-dart  - Flutter/Dart development"
echo "  • linux-specialist        - Shell scripting and system administration"
echo "  • product-manager         - Feature tracking and preservation"
echo "  • project-coordinator     - Project management and coordination"
echo "  • python-backend          - Python 3.12 backend with databases"
echo "  • python-test-engineer    - Python testing with pytest"
echo "  • security-specialist     - Threat modeling, OWASP, AWS hardening"
echo "  • test-coordinator        - Test strategy and coordination"
echo "  • typescript-test-engineer - TypeScript testing with Jest/Playwright"
echo "  • ui-ux-designer          - Design systems and user experience"

echo -e "\n${YELLOW}Standalone skills (no paired agent):${NC}"
echo "  • writing-style           - Matt's personal writing style for messages and emails"

echo -e "\n${YELLOW}Directories:${NC}"
echo "  Agents: $AGENTS_DIR"
echo "  Skills: $SKILLS_DIR"

echo -e "\n${GREEN}Usage:${NC}"
echo "  kiro chat                    # Start Kiro chat session"
echo "  /agent list                  # List available agents"
echo "  /agent use code-reviewer     # Use specific agent"

echo -e "\n${GREEN}Managing:${NC}"
echo "  Reinstall:  bash $0"
echo "  Remove all: rm -rf $AGENTS_DIR $SKILLS_DIR"

echo -e "\n${GREEN}Done! 🎉${NC}"
