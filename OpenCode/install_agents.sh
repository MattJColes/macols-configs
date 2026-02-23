#!/bin/sh
set -eu

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "${GREEN}OpenCode Agents Installer${NC}\n"
printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_AGENTS_DIR="$SCRIPT_DIR/agents"

# Create user-level agents directory
OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
AGENTS_DIR="$OPENCODE_CONFIG_DIR/agents"
SYSTEM_DIR="$OPENCODE_CONFIG_DIR"

# Clean existing agents for a fresh install
if [ -d "$AGENTS_DIR" ]; then
    printf "${YELLOW}Clearing existing agents in: $AGENTS_DIR${NC}\n"
    rm -rf "$AGENTS_DIR"
fi

mkdir -p "$AGENTS_DIR"
mkdir -p "$SYSTEM_DIR"

printf "${BLUE}Installing agents to: $AGENTS_DIR${NC}\n"
echo ""

# Copy agent files from source directory
if [ -d "$SOURCE_AGENTS_DIR" ]; then
    AGENT_COUNT=0
    printf "${GREEN}Installing agents:${NC}\n"

    for agent_file in "$SOURCE_AGENTS_DIR"/*.md; do
        if [ -f "$agent_file" ]; then
            agent_name=$(basename "$agent_file")
            # Skip README files
            if [ "$agent_name" = "README.md" ]; then
                continue
            fi
            cp "$agent_file" "$AGENTS_DIR/$agent_name"
            # Extract agent name without extension for display
            display_name=$(basename "$agent_name" .md)
            printf "  ${GREEN}✓${NC} %s\n" "$display_name"
            AGENT_COUNT=$((AGENT_COUNT + 1))
        fi
    done

    printf "\n${GREEN}✓ Installed %d agents${NC}\n" "$AGENT_COUNT"
else
    printf "${RED}Error: Source agents directory not found at $SOURCE_AGENTS_DIR${NC}\n"
    exit 1
fi

# Create system-level OpenCode configuration
printf "\n${BLUE}Creating system-level configuration...${NC}\n"
cat > "$SYSTEM_DIR/opencode.md" << 'EOF'
# System-Level OpenCode

You are a system-level OpenCode assistant focused on minimal, robust software development.

## Core Principles

### Code Development
- **Minimal Changes**: Make the smallest possible changes to introduce features without affecting unrelated components
- **Type Safety**: Use types when available to catch errors at compile time and improve code clarity
- **Simple Testing**: Write straightforward tests that validate input/output behavior without complex mocking
- **Clear Documentation**: Provide docstrings for public functions, explain non-obvious decisions, and document API usage

### Testing Strategy
- Focus on integration-style tests that verify actual behavior
- Test public interfaces rather than internal implementation details
- Prefer real dependencies over mocks when feasible
- Validate both happy path and edge cases
- Ensure tests are readable and maintainable

### Code Style
- Use descriptive names for functions, variables, and types
- Keep functions small and focused on a single responsibility
- Avoid unnecessary complexity and over-engineering
- Comment only when code intent isn't obvious from the implementation itself

## Development Approach

1. **Understand Requirements**: Clarify what needs to be accomplished and why
2. **Identify Minimal Changes**: Determine the smallest set of modifications needed
3. **Write Types First**: Define interfaces and types to guide implementation
4. **Implement Simply**: Write straightforward code without premature optimization
5. **Test Behavior**: Verify the implementation works as expected with simple tests
6. **Document Decisions**: Explain choices that aren't immediately obvious

## Quality Standards

- Code should be immediately understandable to other developers
- Tests should provide confidence that the code works correctly
- Changes should be reversible and non-disruptive
- Documentation should be sufficient for someone to use and maintain the code
EOF

printf "${GREEN}✓ Created system configuration${NC}\n"

# Summary
echo ""
printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "${GREEN}Installation Complete!${NC}\n"
printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
echo ""

printf "${YELLOW}Installed Agents:${NC}\n"
echo "  • architecture-expert    - System design and AWS architecture"
echo "  • cdk-expert-python      - AWS CDK with Python"
echo "  • cdk-expert-ts          - AWS CDK with TypeScript"
echo "  • code-reviewer          - Code quality and security review"
echo "  • data-scientist         - Data analysis and ML"
echo "  • devops-engineer        - CI/CD and containerization"
echo "  • documentation-engineer - Technical documentation"
echo "  • frontend-engineer-ts   - React/TypeScript frontend"
echo "  • frontend-engineer-dart - Flutter/Dart frontend"
echo "  • linux-specialist       - Shell scripting and system admin"
echo "  • product-manager        - Feature planning and roadmaps"
echo "  • project-coordinator    - Task orchestration and Memory Bank"
echo "  • python-backend-agent   - Python API development"
echo "  • python-test-engineer   - Python testing with pytest"
echo "  • security-specialist    - Application security"
echo "  • test-coordinator       - Test strategy and coverage"
echo "  • ts-test-engineer       - TypeScript/React testing"
echo "  • ui-ux-designer         - UI/UX design and accessibility"
echo ""

printf "${YELLOW}Configuration Files:${NC}\n"
echo "  • Agents directory: $AGENTS_DIR"
echo "  • System config: $SYSTEM_DIR/opencode.md"
echo ""

printf "${YELLOW}Usage:${NC}\n"
echo "  OpenCode will automatically use these agents when appropriate."
echo "  Agents can load skills on-demand via the skill tool."
echo ""

printf "${YELLOW}Next Steps:${NC}\n"
echo "  • Restart OpenCode to load the new agents"
echo "  • Use agents by referencing them in your prompts"
echo "  • Install skills with: ./install_skills.sh"
echo ""

printf "${GREEN}Done!${NC}\n"
