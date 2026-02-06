# Terminal Development Environment Setup

Automated scripts to set up a complete development environment for macOS and Ubuntu 24.04 with AI coding assistants and modern tooling.

## 📦 What Gets Installed

### Core Development Tools

#### **Python Ecosystem**
- Python 3.12 (latest stable)
- `uv` - Fast Python package manager (Astral)
- `pip` - Python package installer

#### **Node.js Ecosystem**
- Node.js 22 (LTS)
- TypeScript (global)
- AWS CDK (global)

#### **AWS Tools**
- AWS CLI v2
- AWS CDK for infrastructure as code

#### **Container Tools**
- **Podman** - Rootless, daemonless container engine (Docker alternative)
  - More secure (runs without root)
  - No daemon required
  - Docker-compatible

#### **System Utilities**
- `htop` - Interactive process viewer
- `curl`, `wget` - Download utilities
- `git` - Version control
- `ripgrep` - Fast grep alternative
- `fd` - Fast find alternative

### AI Coding Assistants

#### **Claude Code**
- Official Anthropic CLI for Claude
- Specialized agents for different development tasks
- MCP (Model Context Protocol) server support

#### **Kiro CLI**
- AWS-native AI coding assistant by AWS
- Deep AWS service integration
- Code generation and debugging
- Steering file and agent-based workflows

### Editor Setup

#### **LazyVim (Neovim Distribution)**
- Modern Neovim configuration
- LSP support out of the box
- Pre-configured with sensible defaults
- Plugin management with lazy.nvim

## 🚀 Installation Scripts

### macOS Installation

```bash
./install_macos.sh
```

**What it does:**
1. Installs/updates Homebrew
2. Installs all core development tools
3. Installs Node.js 22 and Python 3.12
4. Installs Podman for containers
5. Installs Claude Code and Kiro CLI
6. Sets up LazyVim (backs up existing config)

**Requirements:**
- macOS 10.15 (Catalina) or later
- Internet connection

**Post-install:**
```bash
# Start new terminal session
# Complete LazyVim setup
nvim

# Configure AWS
aws configure

# Initialize Podman (if using containers)
podman machine init
podman machine start
```

---

### Ubuntu 24.04 Installation

```bash
./install_ubuntu24.sh
```

**What it does:**
1. Updates apt repositories
2. Installs Python 3.12, Node.js 22, AWS CLI
3. Installs Podman for containers
4. Installs Neovim (latest stable)
5. Installs Claude Code and Kiro CLI
6. Sets up LazyVim with backups

**Requirements:**
- Ubuntu 24.04 LTS
- sudo privileges
- Internet connection

**Post-install:**
```bash
# Reload shell configuration
source ~/.bashrc

# Complete LazyVim setup
nvim

# Configure AWS
aws configure

# Verify installations
python3 --version
node --version
aws --version
claude --version
kiro --version  # or 'q --version' for backwards compatibility
```

---

### Oh My Zsh + Powerlevel10k

```bash
./install_ohmyzsh_p10k.sh
```

**What it does:**
1. Installs zsh (if not present)
2. Installs Oh My Zsh framework
3. Installs Powerlevel10k theme
4. Installs useful plugins:
   - `zsh-autosuggestions` - Command suggestions
   - `zsh-syntax-highlighting` - Syntax highlighting
5. Sets zsh as default shell

**Features:**
- Beautiful, informative prompt
- Git status integration
- Command execution time
- Python virtualenv detection
- Fast and responsive

**Post-install:**
```bash
# Log out and log back in for zsh to take effect
# Or start new terminal session

# Configure Powerlevel10k
p10k configure
```

---

### iTerm2 Color Scheme (macOS only)

```bash
./install_iterm_colors.sh
```

**What it does:**
1. Installs Monokai Pro color scheme for iTerm2
2. Configures iTerm2 preferences

**Monokai Pro Features:**
- Professional dark theme
- Carefully selected colors for readability
- Syntax highlighting optimized for code
- Easy on the eyes for long sessions

**Manual import (if script doesn't work):**
1. Open iTerm2 → Preferences → Profiles → Colors
2. Click "Color Presets" → Import
3. Select `monokai_pro.itermcolors`
4. Select "Monokai Pro" from presets

## 🛠️ Installed Tools Overview

### Development

| Tool | Purpose | Version |
|------|---------|---------|
| Python | Backend development | 3.12 |
| Node.js | Frontend/full-stack | 22 LTS |
| TypeScript | Type-safe JavaScript | Latest |
| AWS CDK | Infrastructure as code | Latest |
| uv | Python package manager | Latest |

### Containers

| Tool | Purpose | Why Podman? |
|------|---------|-------------|
| Podman | Container runtime | Rootless, secure, Docker-compatible |

**Podman Benefits:**
- ✅ Runs without root (more secure)
- ✅ No daemon required (simpler)
- ✅ Docker-compatible (same commands)
- ✅ OCI standard compliance

### AI Assistants

| Tool | Best For |
|------|----------|
| Claude Code | General development, specialized agents |
| Kiro CLI | AWS services, cloud architecture, AI coding assistant |

### Editor

| Tool | Description |
|------|-------------|
| LazyVim | Modern Neovim distro with LSP, treesitter, fuzzy finding |

## 📁 File Descriptions

### Installation Scripts

- **`install_macos.sh`** - Complete macOS development environment
- **`install_ubuntu24.sh`** - Complete Ubuntu 24.04 development environment
- **`install_ohmyzsh_p10k.sh`** - Oh My Zsh + Powerlevel10k theme
- **`install_iterm_colors.sh`** - iTerm2 Monokai Pro color scheme

### Configuration Files

- **`monokai_pro.itermcolors`** - Monokai Pro theme for iTerm2

## 🔧 Configuration Locations

After installation, configuration files are located at:

```
~/.bashrc                    # Bash configuration (Ubuntu)
~/.zshrc                     # Zsh configuration (if installed)
~/.config/nvim/              # Neovim/LazyVim configuration
~/.aws/                      # AWS CLI configuration
~/.claude/                   # Claude Code configuration
~/.local/bin/                # Local binaries (Kiro CLI, etc.)
```

## 🚦 Getting Started

### 1. Run Installation
```bash
# macOS
./install_macos.sh

# Ubuntu 24.04
./install_ubuntu24.sh

# Optional: Install Oh My Zsh + Powerlevel10k
./install_ohmyzsh_p10k.sh

# macOS only: Install iTerm2 colors
./install_iterm_colors.sh
```

### 2. Configure AWS
```bash
aws configure
```
Enter your:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., `us-east-1`)
- Default output format (e.g., `json`)

### 3. Set Up Claude Code Agents
```bash
cd ../ClaudeAgents
./install_mcps.sh
./install_agents.sh
```

### 4. Set Up Kiro CLI Agents
```bash
cd ../KiroAgents
./install_agents.sh  # Installs agents and optionally MCPs
```

**Note**: Kiro CLI stores configuration in `~/.kiro/`. Install agents and MCPs from the `../Kiro/` directory.

### 5. Initialize Podman (if using containers)
```bash
# macOS
podman machine init
podman machine start

# Ubuntu - already ready to use
podman run hello-world
```

### 6. Start Coding!
```bash
# Open LazyVim
nvim

# Use Claude Code
claude

# Use Kiro CLI
kiro chat
```

## 🔄 Updating Tools

### Update Homebrew packages (macOS)
```bash
brew update && brew upgrade
```

### Update apt packages (Ubuntu)
```bash
sudo apt update && sudo apt upgrade
```

### Update npm global packages
```bash
npm update -g
```

### Update Claude Code
```bash
# macOS
brew upgrade anthropics/claude/claude

# Ubuntu
sudo apt update && sudo apt upgrade claude
```

### Update Kiro CLI
```bash
# macOS
brew upgrade kiro-cli

# Ubuntu - download latest from kiro.dev
# Or re-run installation script
```

## 🐛 Troubleshooting

### Podman not working on macOS
```bash
podman machine rm
podman machine init
podman machine start
```

### LazyVim not loading
```bash
# Remove and reinstall
rm -rf ~/.config/nvim ~/.local/share/nvim ~/.cache/nvim
git clone https://github.com/LazyVim/starter ~/.config/nvim
nvim
```

### Oh My Zsh not default shell
```bash
chsh -s $(which zsh)
# Log out and log back in
```

### PATH not updated
```bash
# Reload shell config
source ~/.bashrc  # or source ~/.zshrc
```

## 📚 Additional Resources

- [Claude Code Docs](https://docs.claude.com/en/docs/claude-code)
- [Kiro CLI Docs](https://kiro.dev/docs/cli/)
- [LazyVim Docs](https://www.lazyvim.org/)
- [Podman Docs](https://podman.io/)
- [Powerlevel10k](https://github.com/romkatv/powerlevel10k)

## 🔗 Related Directories

- **`../ClaudeCode/`** - Claude Code agents, skills, hooks and MCPs
- **`../Kiro/`** - Kiro CLI agents, hooks, steering and MCPs

## ⚡ Quick Reference

### Common Commands

```bash
# Python
python3 --version
uv pip install <package>

# Node.js
node --version
npm install -g <package>

# Podman
podman run hello-world
podman-compose up
podman ps

# AWS
aws s3 ls
aws dynamodb list-tables

# Claude Code
claude chat
claude code

# Kiro CLI
kiro chat
/agent list      # list available agents
/agent use <agent-name>

# LazyVim
nvim                    # Start editor
:Lazy                  # Plugin manager
:Mason                 # LSP installer
:checkhealth          # Health check
```

## 🎨 Customization

All scripts back up existing configurations before making changes. You can customize:

1. **LazyVim**: Edit `~/.config/nvim/lua/config/`
2. **Oh My Zsh**: Edit `~/.zshrc`
3. **Bash**: Edit `~/.bashrc`
4. **AWS CLI**: Edit `~/.aws/config`

## 📝 Notes

- All scripts are idempotent (safe to re-run)
- Existing configurations are backed up with timestamps
- Scripts require internet connection
- Some installations may require sudo password
- Podman is preferred over Docker for security and simplicity
