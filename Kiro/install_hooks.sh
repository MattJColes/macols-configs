#!/bin/bash
#
# Install Post-Code Hooks for Kiro CLI
#
# This script sets up hooks that run automatically after coding tasks:
# - Tests (pytest, jest/mocha, flutter test)
# - Linters (ruff for Python, eslint for JS/TS, dart analyze for Dart)
# - Type checking (mypy for Python)
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
HOOK_SCRIPT="$SCRIPT_DIR/hooks/post_code_hook.sh"
TASK_HOOK_SCRIPT="$SCRIPT_DIR/hooks/post_task_hook.sh"

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
echo -e "${CYAN}║          Post-Code Hook Installer for Kiro CLI            ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ ! -f "$HOOK_SCRIPT" ]; then
    log_error "Hook script not found at $HOOK_SCRIPT"
    exit 1
fi

if [ ! -f "$TASK_HOOK_SCRIPT" ]; then
    log_error "Task hook script not found at $TASK_HOOK_SCRIPT"
    exit 1
fi

# Make hook scripts executable
chmod +x "$HOOK_SCRIPT"
chmod +x "$TASK_HOOK_SCRIPT"

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

    if command -v mypy &> /dev/null; then
        log_success "mypy found"
    else
        log_warning "mypy not found (type checking)"
        MISSING_TOOLS+=("mypy (pip install mypy)")
    fi

    if command -v ruff &> /dev/null; then
        log_success "ruff found"
    else
        log_warning "ruff not found (linting)"
        MISSING_TOOLS+=("ruff (pip install ruff)")
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

    if command -v npx &> /dev/null; then
        log_success "npx found (for eslint)"
    else
        log_warning "npx not found - ESLint checks will be skipped"
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

# Flutter/Dart
if command -v flutter &> /dev/null; then
    log_success "Flutter found"
else
    log_warning "Flutter not found - Flutter checks will be skipped"
fi

if command -v dart &> /dev/null; then
    log_success "Dart found"
else
    log_warning "Dart not found - Dart analysis will be skipped"
fi

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Missing recommended tools:${NC}"
    for tool in "${MISSING_TOOLS[@]}"; do
        echo "  - $tool"
    done
    echo ""
    echo "Install all Python tools with:"
    echo "  pip install pytest bandit pip-audit mypy ruff"
    echo ""
fi

# Kiro CLI hooks configuration
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Kiro CLI Hook Configuration${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

local_kiro_config_dir="$HOME/.kiro/settings"
mkdir -p "$local_kiro_config_dir"

HOOKS_FILE="$local_kiro_config_dir/hooks.json"

# Clean existing hooks config for a fresh install
if [ -f "$HOOKS_FILE" ]; then
    log_info "Clearing existing hooks config: $HOOKS_FILE"
    rm -f "$HOOKS_FILE"
fi

log_info "Writing hooks configuration to $HOOKS_FILE"

cat > "$HOOKS_FILE" << EOF
{
  "hooks": {
    "postToolUse": [
      {
        "matcher": "fs_write|write",
        "command": "$HOOK_SCRIPT"
      }
    ],
    "stop": [
      {
        "command": "$TASK_HOOK_SCRIPT"
      }
    ]
  }
}
EOF

log_success "Hooks configuration written to $HOOKS_FILE"

# Project-level example
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Project-Level Hook Configuration${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
echo -e "${BLUE}For project-level configuration, create .kiro/hooks.json in your project:${NC}"
echo ""
cat << 'EOF'
{
  "hooks": {
    "postToolUse": [
      {
        "matcher": "fs_write|write",
        "command": "./scripts/run_tests.sh"
      }
    ]
  }
}
EOF

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    Setup Complete!                         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Hook script locations:"
echo "  postToolUse: $HOOK_SCRIPT"
echo "  stop:        $TASK_HOOK_SCRIPT"
echo ""
echo "Next steps:"
echo "  1. Install missing tools (if any)"
echo "  2. Test by making a code change (postToolUse hook)"
echo "  3. Test by stopping a session (stop hook)"
echo ""
echo "To run the hooks manually:"
echo "  postToolUse: echo '{\"hook_event_name\":\"postToolUse\",\"cwd\":\".\",\"tool_name\":\"fs_write\",\"tool_input\":{}}' | $HOOK_SCRIPT"
echo "  stop:        echo '{\"hook_event_name\":\"stop\",\"cwd\":\".\"}' | $TASK_HOOK_SCRIPT"
echo ""
