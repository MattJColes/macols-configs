## 📂 Structure

```
my-configs/
├── Terminal/           # Dev environment setup (Python, Node, AWS, Podman, AI tools)
├── ClaudeAgents/       # Claude Code specialized agents & MCPs
├── QAgents/           # Amazon Q Developer agents & MCPs
└── iTerm2/            # iTerm2 configurations and themes
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

📖 **[Terminal Setup Details →](Terminal/README.md)**

### 2. Configure AI Agents

**Claude Code:**
```bash
cd ClaudeAgents
./install_mcps.sh
./install_agents.sh
```

**Amazon Q Developer:**
```bash
cd QAgents
./install_mcps.sh
```

📖 **[ClaudeAgents →](ClaudeAgents/README.md)** | **[QAgents →](QAgents/README.md)**

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
- **Claude Code** - 15 specialized agents with MCPs
- **Amazon Q Developer** - AWS-native AI assistant

### 15 Specialized Agents
**Development:** python-backend, frontend-engineer, cdk-expert, data-scientist
**Testing:** test-coordinator, python-test-engineer, typescript-test-engineer
**DevOps:** devops-engineer, linux-specialist, code-reviewer
**Architecture:** architecture-expert, ui-ux-designer
**Management:** documentation-engineer, product-manager, project-coordinator

### 7 MCP Servers
- **filesystem** - File operations
- **sequential-thinking** - Complex problem-solving
- **puppeteer** & **playwright** - Browser automation
- **memory** - Knowledge graph across sessions
- **aws** & **dynamodb** - AWS service interactions

---

✅ **Auto-testing** - Agents run tests after code changes and attempt fixes
✅ **Commit suggestions** - Professional commit messages auto-generated
✅ **Audit logging** - GDPR/SOC2 compliant user action tracking (Python)
✅ **Sequential thinking** - Break down complex problems systematically
✅ **Persistent memory** - Context retained across sessions
✅ **Podman first** - Secure rootless containers throughout

---

## 📚 Documentation

Each directory has detailed documentation:

- **[Terminal/](Terminal/README.md)** - Installation scripts, tools, troubleshooting
- **[ClaudeAgents/](ClaudeAgents/README.md)** - Agent descriptions, MCPs, workflows
- **[QAgents/](QAgents/README.md)** - Q Developer setup and configuration

---

## 🔧 Example Workflow

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

## 🛠️ Troubleshooting

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
cat ~/.claude/config.json  # Check Claude config
cat ~/.aws/amazonq/mcp-config.json  # Check Q config
```

More help in each directory's README.
