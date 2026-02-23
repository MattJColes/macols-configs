# Claude Code Agents, Skills & MCPs

This directory contains specialized AI agents, skills, hooks, and Model Context Protocol (MCP) server configurations for Claude Code.

## Quick Install

> **Note:** Each installer performs a clean deploy — it removes and replaces its target directory/config. Running `install_agents.sh` clears `~/.claude/agents/` and `~/.claude/skills/`, `install_skills.sh` clears `~/.claude/skills/`, and `install_hooks.sh` replaces the `hooks` key in `~/.claude/settings.json`.

```bash
# Install agents (markdown-based)
./install_agents.sh

# Install skills (slash-command-based)
./install_skills.sh

# Install only skills to current project
./install_skills.sh --skills-only --project

# Install hooks
./install_hooks.sh
```

## Directory Structure

```
ClaudeCode/
├── agents/              # 16 agent definitions (Markdown)
│   ├── architecture_expert.md
│   ├── code_reviewer.md
│   └── ...
├── skills/              # 16 skill definitions (SKILL.md)
│   ├── architecture-expert/
│   ├── code-reviewer/
│   └── ...
├── hooks/               # Testing & security automation
│   ├── post_code_hook.sh
│   ├── install_hooks.sh
│   └── README.md
├── claude.md            # System-level Claude instructions
├── mcp-config.json      # MCP server configuration
├── install_agents.sh    # Agent installer
├── install_skills.sh    # Skills installer
├── install_mcps.sh      # MCP server installer
└── README.md
```

## Agents vs Skills

- **Agents** (`.md` files): Full agent definitions with system prompts, installed to `~/.claude/agents/`
- **Skills** (`SKILL.md` files): Slash-command invocable workflows, installed to `~/.claude/skills/`

Both provide the same 16 specializations - choose the format that fits your workflow.

## 16 Specialized Agents/Skills

| Name | Description |
|------|-------------|
| `architecture-expert` | System design, AWS infrastructure, technical decisions |
| `cdk-expert-python` | AWS CDK infrastructure in Python |
| `cdk-expert-ts` | AWS CDK infrastructure in TypeScript |
| `code-reviewer` | Code quality, security, and best practices review |
| `data-scientist` | Data analysis, ML models, visualization |
| `devops-engineer` | CI/CD, Docker, GitHub Actions |
| `documentation-engineer` | README, API docs, architecture documentation |
| `frontend-engineer-ts` | React, TypeScript, Tailwind CSS |
| `frontend-engineer-dart` | Flutter, Dart, mobile/web apps |
| `linux-specialist` | Shell scripting, git, system administration |
| `product-manager` | Feature planning, roadmaps, requirements |
| `project-coordinator` | Memory Bank management, task coordination |
| `python-backend` | FastAPI, Lambda, Python services |
| `python-test-engineer` | pytest, integration testing |
| `test-coordinator` | Test strategy, coverage analysis |
| `typescript-test-engineer` | Jest, Playwright, React Testing Library |
| `ui-ux-designer` | Wireframes, design systems, accessibility |

## 8 MCP Servers

| MCP | Purpose |
|-----|---------|
| `filesystem` | File operations across your home directory |
| `sequential-thinking` | Complex problem-solving and planning |
| `puppeteer` | Browser automation and screenshots |
| `playwright` | Cross-browser testing automation |
| `memory` | Persistent knowledge graph across sessions |
| `aws-kb` | AWS Knowledge Base retrieval |
| `context7` | Real-time library documentation |
| `dynamodb` | DynamoDB operations |

## Configuration

MCP configuration: `~/.claude/config.json`
Agent storage: `~/.claude/agents/`
Skill storage: `~/.claude/skills/`
Knowledge graph: `~/.claude/memory`

## Usage

### Agents
```bash
claude chat
# Agents are used automatically based on task context
# Or explicitly: "Use the code-reviewer agent to review my changes"
```

### Skills
```bash
/frontend-engineer-ts Build a user profile component with React
/python-backend Create a FastAPI endpoint for user management
/code-reviewer Review the changes in src/services/
```

## Workflow Example

```bash
User: "Add user authentication with Cognito"

1. test-coordinator defines testing strategy
2. python-test-engineer writes tests first
3. python-backend-agent implements auth code
4. Tests auto-run, errors auto-fixed (max 3 attempts)
5. code-reviewer checks for security issues
6. Commit message suggested
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
