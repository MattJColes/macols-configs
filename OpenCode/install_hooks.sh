#!/bin/bash
#
# Install Post-Code Hooks for OpenCode
#
# This script sets up hooks that run automatically after coding tasks:
# - Tests (pytest, jest/mocha, flutter test)
# - Linters (ruff for Python, eslint for JS/TS, dart analyze for Dart)
# - Type checking (mypy for Python)
# - Security scans (bandit)
# - Package vulnerability checks (pip-audit, npm audit)
#
# OpenCode uses a plugin system for hooks. This installer:
# 1. Copies the hook shell script
# 2. Installs a plugin that triggers it via tool.execute.after
# 3. Injects the OPENCODE_HOOK_SCRIPT env var via a shell.env plugin
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
HOOK_PLUGIN="$SCRIPT_DIR/hooks/post_code_hook_plugin.mjs"

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
echo -e "${CYAN}║        Post-Code Hook Installer for OpenCode              ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ ! -f "$HOOK_SCRIPT" ]; then
    log_error "Hook script not found at $HOOK_SCRIPT"
    exit 1
fi

if [ ! -f "$HOOK_PLUGIN" ]; then
    log_error "Hook plugin not found at $HOOK_PLUGIN"
    exit 1
fi

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

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Install OpenCode Plugin
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}OpenCode Plugin Installation${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

OPENCODE_PLUGINS_DIR="$HOME/.config/opencode/plugins"
mkdir -p "$OPENCODE_PLUGINS_DIR"

# Clean existing hook plugin for a fresh install
if [ -f "$OPENCODE_PLUGINS_DIR/post_code_hook_plugin.mjs" ]; then
    log_info "Clearing existing hook plugin"
    rm -f "$OPENCODE_PLUGINS_DIR/post_code_hook_plugin.mjs"
fi

# Copy the plugin
cp "$HOOK_PLUGIN" "$OPENCODE_PLUGINS_DIR/post_code_hook_plugin.mjs"
log_success "Plugin installed to $OPENCODE_PLUGINS_DIR/post_code_hook_plugin.mjs"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Install shell.env plugin for hook script path
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Create an env plugin that sets OPENCODE_HOOK_SCRIPT so the hook plugin knows where the script is
ENV_PLUGIN="$OPENCODE_PLUGINS_DIR/post_code_hook_env.mjs"

if [ -f "$ENV_PLUGIN" ]; then
    rm -f "$ENV_PLUGIN"
fi

cat > "$ENV_PLUGIN" << EOF
/**
 * Injects OPENCODE_HOOK_SCRIPT into the shell environment
 * so the post_code_hook_plugin can find the hook script.
 *
 * Auto-generated by install_hooks.sh
 */
export const PostCodeHookEnv = async () => {
  return {
    "shell.env": async (input, output) => {
      output.env.OPENCODE_HOOK_SCRIPT = "$HOOK_SCRIPT";
    },
  };
};
EOF

log_success "Environment plugin installed to $ENV_PLUGIN"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Project-Level Example
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Project-Level Hook Configuration${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
echo -e "${BLUE}For project-level hooks, create .opencode/plugins/my_hook.mjs:${NC}"
echo ""
cat << 'EXAMPLE'
export const MyProjectHook = async ({ $ , directory }) => {
  return {
    "tool.execute.after": async (input) => {
      if (["write", "edit"].includes(input.tool?.toLowerCase())) {
        await $`bash ./scripts/run_tests.sh`.cwd(directory);
      }
    },
  };
};
EXAMPLE

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    Setup Complete!                         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Installed files:"
echo "  Plugin:  $OPENCODE_PLUGINS_DIR/post_code_hook_plugin.mjs"
echo "  Env:     $OPENCODE_PLUGINS_DIR/post_code_hook_env.mjs"
echo "  Script:  $HOOK_SCRIPT"
echo ""
echo "Next steps:"
echo "  1. Install missing tools (if any)"
echo "  2. Restart OpenCode to load plugins"
echo "  3. Make a code change - the hook will run automatically"
echo ""
echo "To run the hook manually:"
echo "  $HOOK_SCRIPT"
echo ""
