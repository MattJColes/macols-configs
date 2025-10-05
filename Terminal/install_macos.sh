#!/bin/bash

set -e

echo "=== macOS Development Environment Setup ==="
echo ""

# Install Homebrew
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "Homebrew already installed"
fi

# Update Homebrew
echo "Updating Homebrew..."
brew update

# Install Python 3.12
echo "Installing Python 3.12..."
brew install python@3.12

# Install htop
echo "Installing htop..."
brew install htop

# Install AWS CLI
echo "Installing AWS CLI..."
brew install awscli

# Install Podman
echo "Installing Podman..."
brew install podman

# Install NVM
echo "Installing NVM..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install Node.js 22 via NVM
echo "Installing Node.js 22 via NVM..."
nvm install 22
nvm use 22
nvm alias default 22

# Install TypeScript globally
echo "Installing TypeScript..."
npm install -g typescript

# Install AWS CDK
echo "Installing AWS CDK..."
npm install -g aws-cdk

# Install uv
echo "Installing uv..."
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install Q Developer CLI
echo "Installing Q Developer CLI..."
brew install --cask amazon-q

# Install Claude Code
echo "Installing Claude Code..."
brew install anthropics/claude/claude

# Install LazyVim dependencies
echo "Installing LazyVim dependencies..."
brew install neovim ripgrep fd

# Backup existing nvim config if it exists
if [ -d "$HOME/.config/nvim" ]; then
    echo "Backing up existing nvim config..."
    mv "$HOME/.config/nvim" "$HOME/.config/nvim.backup.$(date +%Y%m%d_%H%M%S)"
fi

if [ -d "$HOME/.local/share/nvim" ]; then
    mv "$HOME/.local/share/nvim" "$HOME/.local/share/nvim.backup.$(date +%Y%m%d_%H%M%S)"
fi

if [ -d "$HOME/.local/state/nvim" ]; then
    mv "$HOME/.local/state/nvim" "$HOME/.local/state/nvim.backup.$(date +%Y%m%d_%H%M%S)"
fi

if [ -d "$HOME/.cache/nvim" ]; then
    mv "$HOME/.cache/nvim" "$HOME/.cache/nvim.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Install LazyVim
echo "Installing LazyVim..."
git clone https://github.com/LazyVim/starter "$HOME/.config/nvim"
rm -rf "$HOME/.config/nvim/.git"

echo ""
echo "=== Configuration ==="
echo ""

# Git configuration
read -p "Enter your Git username: " git_username
read -p "Enter your Git email: " git_email

if [ -n "$git_username" ]; then
    git config --global user.name "$git_username"
    echo "Git username set to: $git_username"
fi

if [ -n "$git_email" ]; then
    git config --global user.email "$git_email"
    echo "Git email set to: $git_email"
fi

# AWS configuration
echo ""
echo "Configuring AWS CLI..."
aws configure

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Next steps:"
echo "1. Start a new terminal session to load updated PATH"
echo "2. Run 'nvim' to complete LazyVim setup"
echo "3. Initialize Podman: podman machine init && podman machine start"
