#!/bin/bash
#
# Install Post-Code Hooks for Claude Code and Kiro CLI
#
# This script sets up hooks that run automatically after coding tasks:
# - Tests (pytest, jest/mocha)
# - Security scans (bandit)
# - Package vulnerability checks (pip-audit, npm audit)
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_SCRIPT="$SCRIPT_DIR/post_code_hook.sh"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║      Post-Code Hook Installer for Claude & Kiro            ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Make hook script executable
chmod +x "$HOOK_SCRIPT"

# Check for required tools and provide installation instructions
echo -e "${BLUE}Checking for required tools...${NC}\n"

MISSING_TOOLS=()

# Python tools
if command -v python3 &> /dev/null || command -v python &> /dev/null; then
    log_success "Python found"

    if command -v pytest &> /dev/null; then
        log_success "pytest found"
    else
        log_warning "pytest not found"
        MISSING_TOOLS+=("pytest (pip install pytest)")
    fi

    if command -v bandit &> /dev/null; then
        log_success "bandit found"
    else
        log_warning "bandit not found (security scanning)"
        MISSING_TOOLS+=("bandit (pip install bandit)")
    fi

    if command -v pip-audit &> /dev/null; then
        log_success "pip-audit found"
    else
        log_warning "pip-audit not found (vulnerability scanning)"
        MISSING_TOOLS+=("pip-audit (pip install pip-audit)")
    fi
else
    log_warning "Python not found - Python checks will be skipped"
fi

# Node.js tools
if command -v node &> /dev/null; then
    log_success "Node.js found"

    if command -v npm &> /dev/null; then
        log_success "npm found"
    else
        log_warning "npm not found"
    fi
else
    log_warning "Node.js not found - JavaScript checks will be skipped"
fi

# AWS CDK
if command -v cdk &> /dev/null; then
    log_success "AWS CDK found"
else
    log_warning "AWS CDK not found (npm install -g aws-cdk)"
fi

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Missing recommended tools:${NC}"
    for tool in "${MISSING_TOOLS[@]}"; do
        echo "  - $tool"
    done
    echo ""
    echo "Install all Python tools with:"
    echo "  pip install pytest bandit pip-audit"
    echo ""
fi

# Create Claude Code hooks configuration
setup_claude_hooks() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Setting up Claude Code Hooks${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    local claude_config_dir="$HOME/.claude"
    mkdir -p "$claude_config_dir"

    local settings_file="$claude_config_dir/settings.json"

    # Create hooks configuration
    # Claude Code uses a settings.json file for hooks configuration
    if [ -f "$settings_file" ]; then
        log_info "Existing settings.json found"
        log_warning "Please manually add the following hook configuration to your settings:"
    else
        log_info "Creating new settings.json with hooks configuration"
    fi

    echo ""
    echo -e "${BLUE}Add this to your Claude Code settings (~/.claude/settings.json):${NC}"
    echo ""
    cat << EOF
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write|NotebookEdit",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOK_SCRIPT"
          }
        ]
      }
    ]
  }
}
EOF
    echo ""
    log_info "Or use Claude Code's /hooks command to configure hooks interactively"
}

# Create Kiro CLI hooks configuration
setup_kiro_hooks() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Setting up Kiro CLI Hooks${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    local kiro_config_dir="$HOME/.kiro/settings"
    mkdir -p "$kiro_config_dir"

    echo ""
    echo -e "${BLUE}Add this to your Kiro CLI settings (~/.kiro/settings/hooks.json):${NC}"
    echo ""
    cat << EOF
{
  "hooks": {
    "postTask": [
      {
        "name": "test-and-security-scan",
        "description": "Run tests and security scans after code changes",
        "command": "$HOOK_SCRIPT",
        "enabled": true,
        "triggers": ["fs_write", "execute_bash"]
      }
    ]
  }
}
EOF
    echo ""
}

# Create project-level hook configuration example
create_project_hook_example() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Project-Level Hook Configuration${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    echo ""
    echo -e "${BLUE}For project-level configuration, create .claude/settings.json in your project:${NC}"
    echo ""
    cat << 'EOF'
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash -c './scripts/run_tests.sh'"
          }
        ]
      }
    ]
  }
}
EOF
    echo ""
    echo -e "${BLUE}Or for Kiro, create .kiro/hooks.json in your project:${NC}"
    echo ""
    cat << 'EOF'
{
  "hooks": {
    "postTask": [
      {
        "name": "run-tests",
        "command": "./scripts/run_tests.sh",
        "enabled": true
      }
    ]
  }
}
EOF
}

# Create a simple project test script
create_project_test_script() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Optional: Create Project Test Script${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    echo ""
    echo "Would you like to create a sample project test script?"
    echo "This can be customized for each project."
    echo ""

    # Auto-skip if non-interactive
    if [ ! -t 0 ]; then
        echo "Skipping (non-interactive mode)"
        return
    fi

    read -p "Create sample script? (y/n) " -r REPLY
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        local script_path="./scripts/run_tests.sh"
        mkdir -p "./scripts"

        cat > "$script_path" << 'SCRIPT'
#!/bin/bash
# Project test and security scan script
# Customize this for your project

set -e

echo "Running project tests and security scans..."

# Python tests
if [ -f "pyproject.toml" ] || [ -f "requirements.txt" ]; then
    echo "Running Python tests..."
    pytest -v --tb=short || true

    echo "Running security scan..."
    bandit -r src/ -ll || true

    echo "Checking for vulnerabilities..."
    pip-audit || true
fi

# Node.js tests
if [ -f "package.json" ]; then
    echo "Running Node.js tests..."
    npm test || true

    echo "Checking for vulnerabilities..."
    npm audit || true
fi

# CDK tests
if [ -f "cdk.json" ]; then
    echo "Running CDK synth..."
    cdk synth --quiet || true
fi

echo "Done!"
SCRIPT
        chmod +x "$script_path"
        log_success "Created $script_path"
    fi
}

# Main
main() {
    setup_claude_hooks
    setup_kiro_hooks
    create_project_hook_example
    create_project_test_script

    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    Setup Complete!                         ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Hook script location: $HOOK_SCRIPT"
    echo ""
    echo "Next steps:"
    echo "  1. Add hook configuration to Claude Code or Kiro CLI settings"
    echo "  2. Install missing tools (if any)"
    echo "  3. Test by making a code change in your project"
    echo ""
    echo "To run the hook manually:"
    echo "  $HOOK_SCRIPT"
    echo ""
}

main "$@"
