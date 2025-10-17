#!/bin/bash

set -e

echo "=== Ubuntu 24 Development Environment Setup ==="
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

# Install Python 3.12 and pip
echo "Installing Python 3.12..."
sudo apt-get install -y python3.12 python3.12-venv python3-pip
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1

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

# Install Podman
echo "Installing Podman..."
sudo apt-get install -y podman

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

# Install LazyVim dependencies
echo "Installing LazyVim dependencies..."
sudo apt-get install -y git ripgrep fd-find lazygit

# Install Neovim (latest stable)
echo "Installing Neovim..."
NVIM_VERSION=$(curl -s https://api.github.com/repos/neovim/neovim/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
curl -Lo /tmp/nvim-linux-x86_64.tar.gz "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-x86_64.tar.gz"
sudo rm -rf /opt/nvim-linux-x86_64
sudo tar -C /opt -xzf /tmp/nvim-linux-x86_64.tar.gz
rm /tmp/nvim-linux-x86_64.tar.gz

# Add nvim to PATH if not already there
if ! grep -q '/opt/nvim-linux-x86_64/bin' ~/.bashrc; then
    echo 'export PATH="$PATH:/opt/nvim-linux-x86_64/bin"' >> ~/.bashrc
fi

# Install Q Developer CLI
echo "Installing Q Developer CLI..."
curl -L "https://desktop-release.q.us-east-1.amazonaws.com/latest/amazon-q.deb" -o "/tmp/amazon-q.deb"
sudo dpkg -i /tmp/amazon-q.deb || sudo apt-get install -f -y
rm /tmp/amazon-q.deb

# Install Claude Code
echo "Installing Claude Code..."
npm install -g @anthropic-ai/claude-code

# Install Ollama
echo "Installing Ollama..."
curl -fsSL https://ollama.com/install.sh | sh

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
    read -p "Enter model name [qwen3:30b]: " ollama_model
    ollama_model=${ollama_model:-qwen3:30b}

    echo "Pulling $ollama_model..."
    ollama pull "$ollama_model"
    echo "Model $ollama_model installed successfully!"
fi

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Next steps:"
echo "1. Restart your terminal or run: source ~/.bashrc"
echo "2. Run 'nvim' to complete LazyVim setup"
echo "3. Start Ollama service if not already running: ollama serve"
echo "4. Pull additional models: ollama pull <model-name>"
echo "5. Verify installations:"
echo "   - python3 --version"
echo "   - node --version"
echo "   - aws --version"
echo "   - claude --version"
echo "   - q --version"
echo "   - ollama --version"
