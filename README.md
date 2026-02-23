## Structure

```
my-configs/
├── Terminal/           # Dev environment setup (Python, Node, AWS, Podman, AI tools)
├── ClaudeCode/         # Claude Code agents, skills, hooks & MCPs
├── Kiro/               # Kiro CLI agents, hooks, steering & MCPs
├── OpenCode/           # OpenCode skills, MCPs & LM Studio (GLM4.7-Air)
└── .github/            # Security scanning & dependabot
```

### 1. Set Up Terminal Environment

**macOS:**
```bash
cd Terminal
./install_macos.sh
```

**Ubuntu 24.04:**
```bash
cd Terminal
./install_ubuntu24.sh
```

**Optional - Enhanced Shell:**
```bash
./install_ohmyzsh_p10k.sh
```

**[Terminal Setup Details](Terminal/README.md)**

### 2. Configure AI Agents

**Claude Code:**
```bash
cd ClaudeCode
./install_agents.sh             # Installs agents and skills
./install_hooks.sh              # Optional: test & security hooks
```

**Kiro CLI:**
```bash
cd Kiro
./install_agents.sh             # Installs agents and skills
./install_mcps.sh               # Optional
./install_hooks.sh              # Optional: test & security hooks
```

**OpenCode (with LM Studio + GLM4.7-Air):**
```bash
cd OpenCode
./install_skills.sh             # Install 17 agent skills
./install_mcps.sh               # Same MCPs as Claude/Kiro
./install_hooks.sh              # Optional: test & security hooks
./configure_lmstudio.sh         # Set up local GLM4.7-Air model
```

**[ClaudeCode](ClaudeCode/README.md)** | **[Kiro](Kiro/README.md)** | **[OpenCode](OpenCode/README.md)**

### 3. Post-Installation

```bash
# Configure AWS
aws configure

# Initialize Podman (macOS only)
podman machine init && podman machine start

# Verify
python3 --version && node --version && claude --version
```

---

### Development Tools
- **Python 3.12** with uv package manager
- **Node.js 22** with TypeScript and AWS CDK
- **Podman** - Rootless containers (Docker-compatible)
- **AWS CLI** - Cloud service management
- **LazyVim** - Modern Neovim with LSP

### AI Coding Assistants
- **Claude Code** - 17 specialized agents + skills with MCPs
- **Kiro CLI** - AWS-native AI assistant with 17 agents
- **OpenCode** - Terminal AI with 17 skills, MCPs & LM Studio for local models (GLM4.7-Air)

### 18 Specialized Agents
**Development:** python-backend, frontend-engineer-ts, frontend-engineer-dart, cdk-expert-ts, cdk-expert-python, data-scientist
**Testing:** test-coordinator, python-test-engineer, typescript-test-engineer
**DevOps:** devops-engineer, linux-specialist, code-reviewer
**Architecture:** architecture-expert, ui-ux-designer
**Security:** security-specialist
**Management:** documentation-engineer, product-manager, project-coordinator

### 8 Core MCP Servers
- **filesystem** - File operations
- **sequential-thinking** - Complex problem-solving
- **puppeteer** & **playwright** - Browser automation
- **memory** - Knowledge graph across sessions
- **context7** - Real-time, up-to-date library documentation
- **aws-kb** & **dynamodb** - AWS service interactions
- **github** & **gitlab** - Optional: repository operations (require access tokens)

---

- **Auto-testing** - Agents run tests after code changes and attempt fixes
- **Commit suggestions** - Professional commit messages auto-generated
- **Audit logging** - GDPR/SOC2 compliant user action tracking (Python)
- **Sequential thinking** - Break down complex problems systematically
- **Persistent memory** - Context retained across sessions
- **Podman first** - Secure rootless containers throughout

---

## Documentation

Each directory has detailed documentation:

- **[Terminal/](Terminal/README.md)** - Installation scripts, tools, troubleshooting
- **[ClaudeCode/](ClaudeCode/README.md)** - Agents, skills, hooks, MCPs, workflows
- **[Kiro/](Kiro/README.md)** - Kiro CLI agents, hooks, steering, MCPs
- **[OpenCode/](OpenCode/README.md)** - OpenCode with LM Studio & GLM4.7-Air

---

## Example Workflow

```bash
# Start Claude Code
claude chat

# Example: Build a feature with test-first development
You: "Add user authentication with Cognito"

# What happens:
# 1. test-coordinator plans testing strategy
# 2. python-test-engineer writes tests (fail initially)
# 3. python-backend-agent implements code
# 4. Tests auto-run, errors auto-fixed (max 3 attempts)
# 5. code-reviewer checks security
# 6. Commit message suggested
# 7. Audit logging included automatically
```

---

## Troubleshooting

**Podman not working (macOS):**
```bash
podman machine rm && podman machine init && podman machine start
```

**PATH not updated:**
```bash
source ~/.bashrc  # or source ~/.zshrc
```

**MCPs not loading:**
```bash
cat ~/.claude/config.json         # Check Claude config
cat ~/.kiro/settings/mcp.json     # Check Kiro config
cat ~/.config/opencode/mcp.json   # Check OpenCode config
```

More help in each directory's README.
