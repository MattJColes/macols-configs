#!/bin/bash

# Re-exec under bash if invoked with sh/dash (bashisms ahead)
if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi

set -e

echo "=== Ubuntu 26 Development Environment Setup ==="
echo ""

# Set non-interactive mode for apt
export DEBIAN_FRONTEND=noninteractive

# Update package list
echo "Updating package list..."
sudo apt-get update -y

# Install curl
echo "Installing curl..."
sudo apt-get install -y curl wget

# Install htop
echo "Installing htop..."
sudo apt-get install -y htop

# Install curl
echo "Installing unzip..."
sudo apt-get install -y unzip

# Install git early (needed by the oh-my-zsh/p10k installer)
echo "Installing git..."
sudo apt-get install -y git

# Install zsh + Oh My Zsh + Powerlevel10k first so ~/.zshrc exists
# before the NVM/brew/herdr blocks below append to it
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Running install_ohmyzsh_p10k.sh..."
bash "$SCRIPT_DIR/install_ohmyzsh_p10k.sh"

# Install Python 3.14
# Works on both Ubuntu 24.04 (needs the deadsnakes PPA) and 26.04 (ships 3.14
# in the default repos, so the PPA is skipped).
#
# IMPORTANT: we deliberately do NOT point /usr/bin/python3 at 3.14. Ubuntu's
# apt tooling (command-not-found / cnf-update-db) imports the python3-apt C
# bindings (apt_pkg), which only exist for the distro's stock python3. Re-aiming
# /usr/bin/python3 at 3.14 breaks every later apt run with:
#   ModuleNotFoundError: No module named 'apt_pkg'
# Instead we register `python` (which doesn't exist by default) -> 3.14, leaving
# the system python3 untouched.
echo "Installing Python 3.14..."
if apt-cache show python3.14 >/dev/null 2>&1; then
    # Already available in the distro repos (Ubuntu 26.04+)
    echo "python3.14 available in default repos; skipping deadsnakes PPA."
else
    # Ubuntu 24.04 etc. — pull from the deadsnakes PPA
    echo "Adding deadsnakes PPA for python3.14..."
    sudo apt-get install -y software-properties-common
    sudo add-apt-repository -y ppa:deadsnakes/ppa
    sudo apt-get update -y
fi
sudo apt-get install -y python3.14 python3.14-venv python3.14-dev python3-pip
# Provide a `python` command pointing at 3.14 without touching system python3.
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3.14 1

# Install uv
echo "Installing uv..."
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install AWS CLI
echo "Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
cd /tmp
unzip -q awscliv2.zip
sudo ./aws/install --update
rm -rf awscliv2.zip aws

# Install GitHub CLI
# https://github.com/cli/cli/blob/trunk/docs/install_linux.md#debian
echo "Installing GitHub CLI..."
(type -p wget >/dev/null || (sudo apt-get update && sudo apt-get install wget -y)) \
	&& sudo mkdir -p -m 755 /etc/apt/keyrings \
	&& out=$(mktemp) && wget -nv -O"$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
	&& cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&& sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&& sudo mkdir -p -m 755 /etc/apt/sources.list.d \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&& sudo apt-get update \
	&& sudo apt-get install gh -y

# Install Podman
echo "Installing Podman..."
sudo apt-get install -y podman

# Install Docker (official repo)
echo "Installing Docker..."
sudo apt-get install -y ca-certificates
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add current user to docker group (takes effect after re-login)
echo "Adding $USER to docker group..."
sudo usermod -aG docker "$USER"

# Install QEMU + binfmt for multi-arch Docker builds (linux/arm64, etc.)
echo "Installing QEMU and binfmt support..."
sudo apt-get install -y qemu-user-static binfmt-support

# Install NVM (fetch latest release tag)
echo "Installing NVM..."
NVM_LATEST=$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep -oP '"tag_name": "\K[^"]+')
NVM_LATEST="${NVM_LATEST:-v0.40.1}"
echo "Using NVM ${NVM_LATEST}"
curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_LATEST}/install.sh" | bash
export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Ensure NVM is loaded in .zshrc if zsh is installed
if [ -f "$HOME/.zshrc" ] && ! grep -q 'NVM_DIR' "$HOME/.zshrc" 2>/dev/null; then
    cat >> "$HOME/.zshrc" << 'NVMEOF'

# NVM (Node Version Manager)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
NVMEOF
    echo "Added NVM configuration to ~/.zshrc"
fi

# Install latest Node.js via NVM
echo "Installing latest Node.js via NVM..."
nvm install node
nvm use node
nvm alias default node

# Install TypeScript globally (latest)
echo "Installing TypeScript..."
npm install -g typescript@latest

# Install AWS CDK (latest)
echo "Installing AWS CDK..."
npm install -g aws-cdk@latest

# Install LazyVim dependencies (lazygit comes from brew in the sub-script — not in Ubuntu apt)
echo "Installing LazyVim dependencies..."
sudo apt-get install -y git ripgrep fd-find

# Install Neovim (latest stable)
echo "Installing Neovim..."
NVIM_VERSION=$(curl -s https://api.github.com/repos/neovim/neovim/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
curl -Lo /tmp/nvim-linux-x86_64.tar.gz "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-x86_64.tar.gz"
sudo rm -rf /opt/nvim-linux-x86_64
sudo tar -C /opt -xzf /tmp/nvim-linux-x86_64.tar.gz
rm /tmp/nvim-linux-x86_64.tar.gz

# Add nvim to PATH if not already there
if ! grep -q '/opt/nvim-linux-x86_64/bin' ~/.bashrc; then
    # shellcheck disable=SC2016
    echo 'export PATH="$PATH:/opt/nvim-linux-x86_64/bin"' >> ~/.bashrc
fi

# Install Claude Code (latest)
echo "Installing Claude Code..."
npm install -g @anthropic-ai/claude-code@latest

# Install Codex CLI (latest)
# The Homebrew package (https://formulae.brew.sh/cask/codex) is a macOS-only
# cask — Homebrew on Linux can't install casks — so install via npm here.
echo "Installing Codex CLI..."
npm install -g @openai/codex@latest

# Install Ollama
echo "Installing Ollama..."
curl -fsSL https://ollama.com/install.sh | sh

# Configure tmux (enable mouse scroll wheel + PgUp in SSH sessions)
echo "Configuring tmux..."
if [ ! -f "$HOME/.tmux.conf" ] || ! grep -q '^set -g mouse on' "$HOME/.tmux.conf" 2>/dev/null; then
    cat >> "$HOME/.tmux.conf" << 'TMUXEOF'

# Enable mouse: scroll wheel scrolls the pane's scrollback
set -g mouse on

# Page Up jumps straight into copy mode and scrolls up
bind -n Pageup copy-mode -u
TMUXEOF
    echo "Added tmux mouse configuration to ~/.tmux.conf"
fi

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

# Install Homebrew + herdr + yazi + lazygit + neovim tooling (sub-script)
echo "Running install_brew_herdr_yazi_lazygit_nvim.sh..."
bash "$SCRIPT_DIR/install_brew_herdr_yazi_lazygit_nvim.sh"

# Launch herdr automatically on SSH login (idempotent)
echo "Configuring herdr auto-launch on SSH login..."
if [ -f "$HOME/.zshrc" ] && ! grep -q 'Launch herdr on SSH login' "$HOME/.zshrc" 2>/dev/null; then
    cat >> "$HOME/.zshrc" << 'HERDREOF'

# --- Launch herdr on SSH login ---
if [[ -n "$SSH_CONNECTION" && -z "$HERDR_ENV" ]]; then
  herdr
fi
HERDREOF
    echo "Added herdr auto-launch to ~/.zshrc"
fi

echo ""
echo "=== Configuration ==="
echo ""

# Git configuration
read -rp "Enter your Git username: " git_username
read -rp "Enter your Git email: " git_email

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

# Ollama model configuration
echo ""
echo "=== Ollama Model Setup ==="
read -p "Pull an Ollama model now? [y/N]: " -r REPLY
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Popular models:"
    echo "  - qwen3:30b     (30B - powerful, recommended)"
    echo "  - qwen2.5-coder (7B - coding focused)"
    echo "  - deepseek-r1   (7B - reasoning focused)"
    echo "  - llama3.2      (3B - fast, lightweight)"
    echo "  - llama3.1      (8B - balanced)"
    echo ""
    read -rp "Enter model name [qwen3:30b]: " ollama_model
    ollama_model=${ollama_model:-qwen3:30b}

    echo "Pulling $ollama_model..."
    ollama pull "$ollama_model"
    echo "Model $ollama_model installed successfully!"
fi

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Next steps:"
echo "1. Log out and back in (or run 'newgrp docker') for docker group membership to take effect"
echo "2. Restart your terminal or run: source ~/.bashrc"
echo "3. Run 'nvim' to complete LazyVim setup"
echo "4. Start Ollama service if not already running: ollama serve"
echo "5. Pull additional models: ollama pull <model-name>"
echo "6. Verify installations:"
echo "   - python3 --version"
echo "   - node --version"
echo "   - aws --version"
echo "   - claude --version"
echo "   - codex --version"
echo "   - ollama --version"
