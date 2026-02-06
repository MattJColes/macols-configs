# Kiro CLI Agents, Hooks & MCPs

This directory contains specialized AI agents, hooks, steering configuration, and Model Context Protocol (MCP) server configurations for Kiro CLI.

## Directory Structure

```
Kiro/
├── agents/              # 16 agent definitions (JSON)
│   ├── architecture-expert.json
│   ├── code-reviewer.json
│   └── ...
├── hooks/               # Testing & security automation
│   ├── post_code_hook.sh
│   ├── install_hooks.sh
│   └── README.md
├── steering.md          # System-level Kiro instructions
├── install_agents.sh    # Agent installer
├── install_mcps.sh      # MCP server installer
└── README.md
```

## Quick Install

```bash
# Install agents
./install_agents.sh

# Install MCP servers
./install_mcps.sh

# Install hooks
cd hooks && ./install_hooks.sh
```

## 8 MCP Servers

| MCP | Purpose |
|-----|---------|
| `filesystem` | File operations for all agents |
| `sequential-thinking` | Complex problem-solving and planning |
| `puppeteer` | Browser automation and screenshots |
| `playwright` | Cross-browser testing automation |
| `memory` | Persistent knowledge graph across sessions |
| `aws-kb` | AWS Knowledge Base retrieval |
| `context7` | Real-time library documentation |
| `dynamodb` | DynamoDB operations |

## 16 Specialized Agents

### Architecture & Design
- **architecture-expert** - System architecture, AWS infrastructure, caching strategies
- **ui-ux-designer** - UI/UX design, WCAG accessibility, mobile-first

### Development
- **python-backend** - Python 3.12, FastAPI, DynamoDB, Cognito auth
- **frontend-engineer** - TypeScript, React, Tailwind CSS
- **aws-cdk-expert-ts** - AWS CDK TypeScript infrastructure
- **aws-cdk-expert-python** - AWS CDK Python infrastructure
- **data-scientist** - Pandas, ML, ETL pipelines
- **linux-specialist** - Bash scripting, system administration

### Testing
- **test-coordinator** - Test strategy and coverage orchestration
- **python-test-engineer** - pytest, integration testing
- **typescript-test-engineer** - Jest, Playwright, E2E testing

### DevOps & Review
- **devops-engineer** - CI/CD, security scanning, monitoring
- **code-reviewer** - Security, architecture, complexity review

### Documentation & Management
- **documentation-engineer** - README, ARCHITECTURE docs, Mermaid diagrams
- **product-manager** - Feature specs, requirements, validation
- **project-coordinator** - Project planning, task coordination

## Configuration

| Path | Purpose |
|------|---------|
| `~/.kiro/agents/` | Agent configurations |
| `~/.kiro/settings/mcp.json` | MCP server configuration |
| `~/.kiro/settings/hooks.json` | Hook configuration |
| `~/.kiro/memory` | Knowledge graph memory |

## Usage

```bash
# Start Kiro chat session
kiro chat

# List available agents
/agent list

# Use specific agent
/agent use code-reviewer

# Generate a new agent
/agent generate
```

## Workflow Example

```bash
User: "Add user authentication with Cognito"

1. test-coordinator defines testing strategy
2. python-test-engineer writes tests first
3. python-backend implements auth code
4. Tests auto-run, errors auto-fixed (max 3 attempts)
5. code-reviewer checks for security issues
6. Suggests commit: "feat: add Cognito JWT authentication"
```

## Hooks

Testing and security automation hooks are in `hooks/`:

```bash
cd hooks && ./install_hooks.sh
```

The hook automatically runs after code changes:
- **pytest** - Python tests
- **jest/mocha** - JavaScript/TypeScript tests
- **bandit** - Python security scanning
- **pip-audit / npm audit** - Package vulnerability checks

## Maintenance

- Update MCPs: Re-run `./install_mcps.sh`
- Update agents: Edit `.json` files in `agents/`
- Update hooks: Edit files in `hooks/`
- Reinstall agents: Re-run `./install_agents.sh`
