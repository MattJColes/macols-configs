#!/bin/bash
#
# Shared Node.js PATH Helper
#
# Sources NVM/fnm if node is not already in PATH.
# Should be sourced (not executed) by scripts that need Node.js.
#
# Usage:
#   source "$(dirname "$0")/../shared/ensure_node.sh"
#
# After sourcing, `command -v node` will succeed if Node.js is installed
# via NVM, fnm, Homebrew, or system package manager.
#

# Guard against direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script must be sourced, not executed directly." >&2
    exit 1
fi

# Already available — nothing to do
if command -v node &> /dev/null; then
    return 0 2>/dev/null || true
fi

# Try NVM
if [ -z "${NVM_DIR:-}" ]; then
    export NVM_DIR="${HOME}/.nvm"
fi
if [ -s "$NVM_DIR/nvm.sh" ]; then
    # shellcheck source=/dev/null
    \. "$NVM_DIR/nvm.sh"
    if command -v node &> /dev/null; then
        return 0 2>/dev/null || true
    fi
fi

# Try fnm
if command -v fnm &> /dev/null; then
    eval "$(fnm env)"
    if command -v node &> /dev/null; then
        return 0 2>/dev/null || true
    fi
fi

# Try Homebrew node (macOS)
if [ -d "/opt/homebrew/opt/node/bin" ]; then
    export PATH="/opt/homebrew/opt/node/bin:$PATH"
    if command -v node &> /dev/null; then
        return 0 2>/dev/null || true
    fi
fi
if [ -d "/usr/local/opt/node/bin" ]; then
    export PATH="/usr/local/opt/node/bin:$PATH"
    if command -v node &> /dev/null; then
        return 0 2>/dev/null || true
    fi
fi

# Try Volta
if [ -d "${VOLTA_HOME:-$HOME/.volta}/bin" ]; then
    export PATH="${VOLTA_HOME:-$HOME/.volta}/bin:$PATH"
    if command -v node &> /dev/null; then
        return 0 2>/dev/null || true
    fi
fi
