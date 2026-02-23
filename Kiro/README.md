# Kiro CLI Agents, Skills, Hooks & MCPs

Specialized AI agents with per-agent MCP configs and progressive skill loading for Kiro CLI.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Agent JSON                                             │
│  ├── prompt (brief role summary)                        │
│  ├── mcpServers (only MCPs this agent needs)            │
│  ├── includeMcpJson: false (skip global MCPs)           │
│  └── resources                                          │
│      ├── file://.kiro/steering/**/*.md (always loaded)  │
│      └── skill://...SKILL.md (loaded on-demand)         │
└─────────────────────────────────────────────────────────┘
```

**Key design decisions:**
- Agents declare only the MCPs they need (not all 8 globally)
- Skill content loads progressively (metadata at startup, full content on-demand)
- `$HOME` in filesystem MCP args is expanded at install time

## Directory Structure

```
Kiro/
├── agents/              # 18 agent definitions (JSON) with per-agent MCPs
│   ├── architecture-expert.json
│   ├── code-reviewer.json
│   └── ...
├── skills/              # 18 SKILL.md files (progressive loading)
│   ├── architecture-expert/SKILL.md
│   ├── code-reviewer/SKILL.md
│   └── ...
├── hooks/               # Testing & security automation
│   ├── post_code_hook.sh
│   ├── install_hooks.sh
│   └── README.md
├── steering.md          # System-level Kiro instructions
├── install_agents.sh    # Agent + skill installer
├── install_mcps.sh      # MCP package installer
├── generate_skills_and_agents.py  # Generator script (dev tool)
└── README.md
```

## Quick Install

```bash
# Install agents + skills (also offers MCP package install)
./install_agents.sh

# Install MCP npm packages only (no global config written)
./install_mcps.sh

# Install MCP packages + write global fallback config
./install_mcps.sh --with-global-config

# Install hooks
cd hooks && ./install_hooks.sh
```

## Per-Agent MCP Mapping

Each agent only starts the MCP servers it needs. All agents get `filesystem` + `memory`.

| Agent | context7 | seq-thinking | puppeteer | playwright | dynamodb | aws-kb |
|---|---|---|---|---|---|---|
| architecture-expert | Y | Y | - | - | - | Y |
| cdk-expert-ts | Y | - | - | - | - | Y |
| cdk-expert-python | Y | - | - | - | - | Y |
| code-reviewer | - | - | - | - | - | - |
| data-scientist | Y | - | - | - | Y | Y |
| devops-engineer | Y | - | - | Y | - | - |
| documentation-engineer | Y | - | - | - | - | - |
| frontend-engineer-ts | Y | - | - | - | - | - |
| frontend-engineer-dart | Y | - | - | - | - | - |
| linux-specialist | - | - | - | - | - | - |
| product-manager | - | - | - | - | - | - |
| project-coordinator | - | - | - | - | - | - |
| python-backend | Y | - | - | - | Y | Y |
| python-test-engineer | Y | - | - | - | Y | - |
| security-specialist | Y | Y | - | - | - | Y |
| test-coordinator | - | - | - | Y | - | - |
| typescript-test-engineer | Y | Y | Y | Y | - | - |
| ui-ux-designer | Y | - | Y | - | - | - |

## 18 Specialized Agents

### Architecture & Design
- **architecture-expert** - AWS architecture, caching, scaling, design patterns
- **ui-ux-designer** - UI/UX design, WCAG accessibility, mobile-first

### Development
- **python-backend** - Python 3.12, FastAPI, DynamoDB, Cognito auth
- **frontend-engineer-ts** - TypeScript, React, Tailwind CSS
- **frontend-engineer-dart** - Flutter, Dart, mobile/web apps
- **cdk-expert-ts** - AWS CDK TypeScript infrastructure
- **cdk-expert-python** - AWS CDK Python infrastructure
- **data-scientist** - Pandas, ML, ETL pipelines, data lakes
- **linux-specialist** - Shell scripting, system administration

### Testing
- **test-coordinator** - Test strategy and coverage orchestration
- **python-test-engineer** - pytest, integration testing
- **typescript-test-engineer** - Jest, Playwright, E2E testing

### DevOps & Security
- **devops-engineer** - CI/CD, security scanning, monitoring
- **code-reviewer** - Security, architecture, complexity review
- **security-specialist** - Threat modeling, OWASP, AWS hardening

### Documentation & Management
- **documentation-engineer** - README, ARCHITECTURE docs, Mermaid diagrams
- **product-manager** - Feature specs, requirements, validation
- **project-coordinator** - Project planning, task coordination

## Configuration Paths

| Path | Purpose |
|------|---------|
| `~/.kiro/agents/*.json` | Agent configs (with per-agent MCPs) |
| `~/.kiro/skills/*/SKILL.md` | Skill files (progressive loading) |
| `~/.kiro/settings/mcp.json` | Global MCP config (optional fallback) |
| `~/.kiro/settings/hooks.json` | Hook configuration |
| `~/.kiro/memory` | Knowledge graph memory |

## Usage

```bash
# Start Kiro chat session
kiro chat

# List available agents
/agent list

# Use specific agent (only its MCPs start)
/agent use code-reviewer

# Generate a new agent
/agent generate
```

## Agent JSON Format

```json
{
    "name": "python-backend",
    "description": "Senior Python 3.12 backend specialist...",
    "tools": ["fs_read", "fs_write", "execute_bash"],
    "allowedTools": ["fs_read"],
    "prompt": "Brief role summary. Follow skill resource for details.",
    "includeMcpJson": false,
    "mcpServers": {
        "filesystem": { "command": "npx", "args": ["..."] },
        "memory": { "command": "npx", "args": ["..."] },
        "dynamodb": { "command": "uvx", "args": ["..."], "env": { "..." } }
    },
    "resources": [
        "file://.kiro/steering/**/*.md",
        "skill://.kiro/skills/python-backend/SKILL.md"
    ]
}
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

## Development

To regenerate skills from agent prompts (or update after editing):

```bash
python3 generate_skills_and_agents.py
```

This extracts `prompt` from each agent JSON into `skills/*/SKILL.md` and updates agent JSONs with per-agent MCP configs.

## Maintenance

- Update agents: Edit JSON files in `agents/`, then re-run `./install_agents.sh`
- Update skills: Edit SKILL.md files in `skills/`, then re-run `./install_agents.sh`
- Update MCP mapping: Edit `generate_skills_and_agents.py` AGENT_MCPS dict, then re-run
- Update hooks: Edit files in `hooks/`
- Install MCP packages: `./install_mcps.sh`
