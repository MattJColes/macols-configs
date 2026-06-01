# Kiro CLI Personas, Skills, Hooks & MCPs

Specialized AI agents with per-agent MCP configs and progressive skill loading
for Kiro CLI. Each persona is authored once as a **single source file** —
`personas/<name>/SKILL.md` — and `install.sh` generates the matching Kiro agent
JSON from it at install time.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Agent JSON (generated from the persona's SKILL.md)     │
│  ├── prompt (brief role summary)                        │
│  ├── mcpServers (only MCPs this agent needs)            │
│  ├── includeMcpJson: false (skip global MCPs)           │
│  └── resources                                          │
│      ├── file://.kiro/steering/**/*.md (always loaded)  │
│      └── skill://...SKILL.md (loaded on-demand)         │
└─────────────────────────────────────────────────────────┘
```

**Key design decisions:**
- One source of truth per persona — the skill body is shared by both the
  installed skill and the generated agent, so they never drift
- Agents declare only the MCPs they need (not all of them globally)
- Skill content loads progressively (metadata at startup, full content on-demand)
- `$HOME` in filesystem MCP args is expanded at install time

## Agents vs Skills — one source

Each persona lives in `personas/<name>/SKILL.md`. That skill is the **canonical
content**. A small block of frontmatter controls what gets installed:

```yaml
---
agent: true            # also generate a Kiro agent from this persona
model: opus            # cross-tool parity only — Kiro agent JSON has no model
                       # field, so the generator ignores it (default: sonnet)
name: architecture-expert
description: Pragmatic software architecture specialist ...
---
```

At install time:

- **Skill install** copies `SKILL.md` to `~/.kiro/skills/<name>/SKILL.md`,
  stripping the `agent` and `model` keys (only `name` + `description` remain).
  The body is unchanged.
- **Agent generation** (only when `agent: true`) writes
  `~/.kiro/agents/<name>.json` — thin config (`tools`, `allowedTools`, a brief
  `prompt`, per-agent `mcpServers`) plus a `skill://` resource that points at the
  installed skill for the detailed guidance. Personas without `agent: true` are
  skill-only.

The generator (an embedded Node block in `install.sh`) holds the
`MCP_SERVERS` definitions, the per-agent `AGENT_MCPS` map, and the brief
`BRIEF_PROMPTS`.

## Directory Structure

```
Kiro/
├── personas/            # One folder per persona — single source SKILL.md files
│   ├── architecture-expert/
│   │   └── SKILL.md     #   agent: true → also generates an agent
│   ├── code-reviewer/
│   │   └── SKILL.md
│   └── ...
├── hooks/               # Testing & security automation
│   ├── post_code_hook.sh
│   ├── post_task_hook.sh
│   └── README.md
├── steering.md          # System-level Kiro instructions
├── install.sh           # Unified installer (skills, generated agents, MCPs, hooks)
└── README.md
```

## Quick Install

```bash
# Install everything (agents, skills, MCP packages, hooks)
./install.sh

# Install a single component
./install.sh --agents-only
./install.sh --skills-only
./install.sh --mcps-only
./install.sh --hooks-only

# Install MCP packages + write the global fallback config
./install.sh --mcps-only --with-global-config

# Preview available personas (a +agent marker shows which also install an agent)
./install.sh --list
```

## Per-Agent MCP Mapping

Each agent only starts the MCP servers it needs. All agents get `filesystem` + `memory`.

| Agent | context7 | seq-thinking | puppeteer | playwright | dynamodb | aws-kb | dart |
|---|---|---|---|---|---|---|---|
| architecture-expert | Y | Y | - | - | - | Y | - |
| cdk-expert-ts | Y | - | - | - | - | Y | - |
| cdk-expert-python | Y | - | - | - | - | Y | - |
| code-reviewer | - | - | - | - | - | - | - |
| dart-app-developer | Y | - | - | - | - | - | Y |
| data-scientist | Y | - | - | - | Y | Y | - |
| devops-engineer | Y | - | - | Y | - | - | - |
| documentation-engineer | Y | - | - | - | - | - | - |
| frontend-engineer-ts | Y | - | - | - | - | - | - |
| linux-specialist | - | - | - | - | - | - | - |
| product-manager | - | - | - | - | - | - | - |
| project-coordinator | - | - | - | - | - | - | - |
| python-backend | Y | - | - | - | Y | Y | - |
| python-test-engineer | Y | - | - | - | Y | - | - |
| security-specialist | Y | Y | - | - | - | Y | - |
| test-coordinator | - | - | - | Y | - | - | - |
| typescript-test-engineer | Y | Y | Y | Y | - | - | - |
| ui-ux-designer | Y | - | Y | - | - | - | - |
| writing-blog-posts | - | - | - | - | - | - | - |
| writing-documents | - | - | - | - | - | - | - |
| writing-style | - | - | - | - | - | - | - |

## Specialized Personas

### Architecture & Design
- **architecture-expert** - AWS architecture, caching, scaling, design patterns
- **ui-ux-designer** - UI/UX design, WCAG accessibility, mobile-first

### Development
- **python-backend** - Python 3.12, FastAPI, DynamoDB, Cognito auth
- **frontend-engineer-ts** - TypeScript, React, Tailwind CSS
- **dart-app-developer** - Flutter/Dart, feature-first architecture, Riverpod
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

### Writing
- **writing-blog-posts** - Blog posts for coles.codes in Matt Coles' voice
- **writing-documents** - Memos, PRFAQs, COEs in the Amazon writing style
- **writing-style** - Matt Coles' personal writing style for messages and email

## Configuration Paths

| Path | Purpose |
|------|---------|
| `~/.kiro/agents/*.json` | Generated agent configs (with per-agent MCPs) |
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
```

## Generated Agent JSON Format

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

Testing and security automation hook scripts live in `hooks/`; install them via:

```bash
./install.sh --hooks-only
```

The hook automatically runs after code changes:
- **pytest** - Python tests
- **jest/mocha** - JavaScript/TypeScript tests
- **flutter test** - Flutter/Dart tests
- **dart analyze** - Dart static analysis
- **bandit** - Python security scanning
- **pip-audit / npm audit** - Package vulnerability checks

## Maintenance

- Update a persona: edit `personas/<name>/SKILL.md`, then re-run
  `./install.sh --skills-only` and/or `./install.sh --agents-only`
- Add or remove an agent: set or clear `agent: true` in the persona's
  frontmatter
- Update the per-agent MCP mapping or brief prompts: edit the `AGENT_MCPS` /
  `BRIEF_PROMPTS` maps in the generator block in `install.sh`
- Update hooks: edit files in `hooks/`, then re-run `./install.sh --hooks-only`
- Install MCP packages: `./install.sh --mcps-only`
```