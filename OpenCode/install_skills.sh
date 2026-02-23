#!/bin/sh
set -eu

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "${GREEN}OpenCode Skills & Agents Installer${NC}\n"
printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
echo ""

# Default installation paths
OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
SKILLS_DIR="$OPENCODE_CONFIG_DIR/skills"
AGENTS_DIR="$OPENCODE_CONFIG_DIR/agents"

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -h, --help      Show this help message
    -p, --project   Install skills to current project (.opencode/skills/)
    --list          List available skills

EOF
}

list_skills() {
    printf "${BLUE}Available Skills:${NC}\n"
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

install_skills_to_dir() {
    target_dir="$1"
    label="$2"

    # Clean existing skills for a fresh install
    if [ -d "$target_dir" ]; then
        printf "${YELLOW}Clearing existing ${label} in: $target_dir${NC}\n"
        rm -rf "$target_dir"
    fi

    printf "${BLUE}Installing ${label} to: $target_dir${NC}\n"
    mkdir -p "$target_dir"

    count=0
    for skill_dir in "$SCRIPT_DIR/skills"/*; do
        if [ -d "$skill_dir" ]; then
            skill_name=$(basename "$skill_dir")
            target_skill_dir="$target_dir/$skill_name"

            mkdir -p "$target_skill_dir"
            cp "$skill_dir/SKILL.md" "$target_skill_dir/SKILL.md"

            printf "  ${GREEN}✓${NC} %s\n" "$skill_name"
            count=$((count + 1))
        fi
    done

    printf "\n${GREEN}✓ Installed %d ${label}${NC}\n" "$count"
}

install_agents_to_dir() {
    target_dir="$1"
    label="$2"

    # Clean existing agents for a fresh install
    if [ -d "$target_dir" ]; then
        printf "${YELLOW}Clearing existing ${label} in: $target_dir${NC}\n"
        rm -rf "$target_dir"
    fi

    printf "${BLUE}Installing ${label} to: $target_dir${NC}\n"
    mkdir -p "$target_dir"

    count=0
    for agent_file in "$SCRIPT_DIR/agents"/*.md; do
        if [ -f "$agent_file" ]; then
            agent_name=$(basename "$agent_file")
            # Skip README files
            if [ "$agent_name" = "README.md" ]; then
                continue
            fi
            cp "$agent_file" "$target_dir/$agent_name"
            display_name=$(basename "$agent_name" .md)

            printf "  ${GREEN}✓${NC} %s\n" "$display_name"
            count=$((count + 1))
        fi
    done

    printf "\n${GREEN}✓ Installed %d ${label}${NC}\n" "$count"
}

# Parse arguments
PROJECT_INSTALL=false

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
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
            printf "${RED}Unknown option: $1${NC}\n"
            usage
            exit 1
            ;;
    esac
done

# Install skills and agents
if [ "$PROJECT_INSTALL" = true ]; then
    install_skills_to_dir "./.opencode/skills" "skills"
    install_agents_to_dir "./.opencode/agents" "agents"
else
    install_skills_to_dir "$SKILLS_DIR" "skills"
    install_agents_to_dir "$AGENTS_DIR" "agents"
fi

# Summary
echo ""
printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "${GREEN}Installation Complete!${NC}\n"
printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
echo ""

printf "${YELLOW}Skills & Agents Usage:${NC}\n"
echo "  Skills and agents are automatically available to OpenCode."
echo "  Agents can load skills on-demand via the skill tool."
echo ""
echo "  Available as skills (/):"
echo "    /architecture-expert    - System design and AWS architecture"
echo "    /cdk-expert-python      - AWS CDK with Python"
echo "    /cdk-expert-ts          - AWS CDK with TypeScript"
echo "    /code-reviewer          - Code quality and security review"
echo "    /data-scientist         - Data analysis and ML"
echo "    /devops-engineer        - CI/CD and containerization"
echo "    /documentation-engineer - Technical documentation"
echo "    /frontend-engineer-ts   - React/TypeScript frontend"
echo "    /frontend-engineer-dart - Flutter/Dart frontend"
echo "    /linux-specialist       - Shell scripting and system admin"
echo "    /product-manager        - Feature planning and roadmaps"
echo "    /project-coordinator    - Task orchestration and Memory Bank"
echo "    /python-backend         - Python API development"
echo "    /python-test-engineer   - Python testing with pytest"
echo "    /security-specialist    - Application security"
echo "    /test-coordinator       - Test strategy and coverage"
echo "    /typescript-test-engineer - TypeScript/React testing"
echo "    /ui-ux-designer         - UI/UX design and accessibility"
echo ""
echo "  Available as agents (via Task tool):"
echo "    • Same specialized agents as above"
echo "    • Use Task tool with subagent_type matching agent names"
echo ""
echo "  Use --list to see all available skills with descriptions"
echo ""

printf "${YELLOW}Next Steps:${NC}\n"
echo "  • Restart OpenCode to load skills and agents"
if [ "$PROJECT_INSTALL" = true ]; then
    echo "  • Skills installed to: ./.opencode/skills/"
    echo "  • Agents installed to: ./.opencode/agents/"
else
    echo "  • Skills installed to: $SKILLS_DIR"
    echo "  • Agents installed to: $AGENTS_DIR"
fi
echo ""

printf "${GREEN}Done!${NC}\n"
