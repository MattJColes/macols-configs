## Structure

```
my-configs/
├── Terminal/           # Dev environment setup (Python, Node, AWS, Podman, AI tools)
├── ClaudeCode/         # Claude Code agents, skills, hooks & MCPs
├── Codex/              # Codex CLI prompts, AGENTS.md, hooks & MCPs
├── OpenCode/           # OpenCode skills, MCPs & LM Studio (GLM4.7-Air)
├── Pi/                 # Pi coding agent skills, AGENTS.md & check hooks
├── shared/             # Single source of truth: personas + check libraries
└── .github/            # Security scanning & dependabot
```

The specialist **personas** live once in `shared/personas/<name>/SKILL.md` and
every tool's installer generates its own format from that single source — so the
skills, agents, prompts and Pi skills never drift apart.

### 1. Set Up Terminal Environment

**macOS:**
```bash
cd Terminal
./install_macos.sh
```

**Ubuntu 26:**
```bash
cd Terminal
./install_ubuntu26.sh
```

**Optional - Enhanced Shell:**
```bash
./install_ohmyzsh_p10k.sh
```

**[Terminal Setup Details](Terminal/README.md)**

### 2. Configure AI Agents

Each tool has a single `install.sh` that installs agents, skills, MCP servers
and hooks. Run it with no arguments to install everything, or scope it with
`--agents-only`, `--skills-only`, `--mcps-only`, `--hooks-only` (and `--list`
to preview available skills, `-p`/`--project` for a per-project install).

**Claude Code:**
```bash
cd ClaudeCode
./install.sh                    # Agents, skills, MCPs and hooks
```

**Codex CLI:**
```bash
cd Codex
./install.sh                    # Prompts, AGENTS.md, MCPs and hooks
```

**OpenCode (with LM Studio + GLM4.7-Air):**
```bash
cd OpenCode
./install.sh                    # Agents, skills, MCPs and hooks
./configure_lmstudio.sh         # Set up local GLM4.7-Air model
```

**Pi:**
```bash
cd Pi
./install.sh                    # Installs pi (if missing), skills, AGENTS.md & hooks
```

**[ClaudeCode](ClaudeCode/README.md)** | **[Codex](Codex/README.md)** | **[OpenCode](OpenCode/README.md)** | **[Pi](Pi/README.md)**

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
- **Claude Code** - 21 specialized agents + skills with MCPs
- **Codex CLI** - 22 custom prompts (slash commands), AGENTS.md, MCPs & advisory hooks
- **OpenCode** - Terminal AI with skills, MCPs & LM Studio for local models (GLM4.7-Air)
- **Pi** - Minimal coding agent: personas as Agent Skills (`/skill:<name>`), AGENTS.md & advisory hooks (no MCP by design)

Each tool is authored from single-source personas in `shared/personas/<name>/SKILL.md`;
each installer generates that tool's agents/skills/prompts from the same body.

### 21 Specialized Agents
**Development:** python-backend, frontend-engineer-ts, dart-app-developer, cdk-expert-ts, cdk-expert-python, data-scientist
**Testing:** test-coordinator, python-test-engineer, typescript-test-engineer
**DevOps:** devops-engineer, linux-specialist, code-reviewer
**Architecture:** architecture-expert, ui-ux-designer
**Security:** security-specialist
**Management:** documentation-engineer, product-manager, project-coordinator
**Writing:** writing-blog-posts, writing-documents, writing-style

### Core MCP Servers
- **filesystem** - File operations
- **puppeteer** & **playwright** - Browser automation
- **context7** - Real-time, up-to-date library documentation
- **aws-kb** & **dynamodb** - AWS service interactions
- **github** & **gitlab** - Optional: repository operations (require access tokens)

---

- **Auto-testing** - Agents run tests after code changes and attempt fixes
- **Commit suggestions** - Professional commit messages auto-generated
- **Audit logging** - GDPR/SOC2 compliant user action tracking (Python)
- **Podman first** - Secure rootless containers throughout

---

## Documentation

Each directory has detailed documentation:

- **[Terminal/](Terminal/README.md)** - Installation scripts, tools, troubleshooting
- **[ClaudeCode/](ClaudeCode/README.md)** - Agents, skills, hooks, MCPs, workflows
- **[Codex/](Codex/README.md)** - Codex CLI prompts, AGENTS.md, hooks & MCPs
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
# 3. python-backend implements code
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
cat ~/.config/opencode/mcp.json   # Check OpenCode config
```

More help in each directory's README.
