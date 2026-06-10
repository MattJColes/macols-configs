# Claude Code Agents, Skills & MCPs

This directory contains specialized AI agents, skills, hooks, and Model Context Protocol (MCP) server configurations for Claude Code.

## Quick Install

Each persona is authored as a **single source file** — `personas/<name>/SKILL.md`.
The skill is the canonical content; when its frontmatter sets `agent: true`,
`install.sh` also **generates** a matching agent from the same body (so the two
never drift). A single `install.sh` installs skills, generated agents, MCP
servers and hooks. It performs a clean deploy — it removes and replaces its
target directory/config: agents clear `~/.claude/agents/` (and copy `CLAUDE.md`),
skills clear `~/.claude/skills/`, hooks replace the `hooks` key in
`~/.claude/settings.json`, and MCPs re-register each server in
`mcp-config.json` at user scope (removing any existing entry with the same
name first).

```bash
# Install everything (skills, agents, MCPs, hooks)
./install.sh

# Install a single component
./install.sh --agents-only
./install.sh --skills-only
./install.sh --mcps-only
./install.sh --hooks-only

# Install skills & agents into the current project (./.claude/)
./install.sh --skills-only --project

# Preview available personas (a +agent marker shows which also install an agent)
./install.sh --list
```

### Prerequisites

The installer is a Bash script. It needs **git**, **Node.js** (used to generate
agents and write the hooks config), and — only for `--mcps-only` — the
[`claude`](https://docs.claude.com/claude-code) CLI plus `jq` and `uv`
(auto-installed if missing).

### Install on Linux

```bash
# Debian/Ubuntu — install prerequisites
sudo apt-get update && sudo apt-get install -y git nodejs npm jq

git clone https://github.com/MattJColes/macols-configs.git
cd macols-configs/ClaudeCode
./install.sh
```

### Install on macOS

```bash
# Requires Homebrew (https://brew.sh)
brew install git node jq

git clone https://github.com/MattJColes/macols-configs.git
cd macols-configs/ClaudeCode
./install.sh
```

### Install on Windows

The installer is a Bash script, so run it under **WSL2** (recommended) or
**Git Bash**.

```bash
# In a WSL2 (Ubuntu) shell — same as Linux:
sudo apt-get update && sudo apt-get install -y git nodejs npm jq

git clone https://github.com/MattJColes/macols-configs.git
cd macols-configs/ClaudeCode
./install.sh
```

> Note: under WSL2 the configs install into the WSL home (`~/.claude/`), so run
> Claude Code from inside WSL. For native Windows + Git Bash, ensure `node` is
> on your `PATH`; agents and skills install to `%USERPROFILE%\.claude\`.

## Directory Structure

```
ClaudeCode/
├── personas/            # One folder per persona — 22 skills, 21 generate an agent
│   ├── architecture-expert/
│   │   └── SKILL.md     #   single source (agent: true → also generates an agent)
│   ├── code-reviewer/
│   │   └── SKILL.md
│   ├── commit/
│   │   └── SKILL.md     #   skill-only persona (no `agent:` key)
│   └── ...
├── hooks/               # Testing & security automation
│   ├── post_code_hook.sh
│   ├── post_task_hook.sh
│   ├── pre_deploy_hook.sh  # PreToolUse guard: confirm `cdk diff` before deploy/destroy
│   └── README.md
├── CLAUDE.md            # System-level Claude instructions
├── mcp-config.json      # MCP server configuration
├── install.sh           # Unified installer (skills, agents, MCPs, hooks)
└── README.md
```

## Agents vs Skills — one source

Each persona is authored once as `personas/<name>/SKILL.md`. That skill is the
**single source of truth**; there are no separate agent files to keep in sync.
A small block of frontmatter controls what gets installed:

```yaml
---
name: code-reviewer
description: Code review specialist for quality, security, and best practices.
allowed-tools:        # becomes the agent's `tools` when an agent is generated
  - Read
  - Edit
  - Bash
user-invocable: true
agent: true           # generate an agent from this same body
model: opus           # model for the generated agent (default: sonnet)
---
```

`install.sh` installs the skill to `~/.claude/skills/<name>/SKILL.md` (stripping
the `agent`/`model` keys), and — when `agent: true` — generates
`~/.claude/agents/<name>.md` from the **same body**, swapping in agent-style
frontmatter (`tools`, `model`). Drop `agent: true` for a skill-only persona
(e.g. `commit`, the `writing-*` helpers).

## Specialized Personas

The `+agent` column marks personas that also install an agent (`./install.sh --list`
shows this live).

| Name | +agent | Description |
|------|:------:|-------------|
| `architecture-expert` | ✓ | System design, AWS infrastructure, technical decisions |
| `cdk-expert-python` | ✓ | AWS CDK infrastructure in Python |
| `cdk-expert-ts` | ✓ | AWS CDK infrastructure in TypeScript |
| `code-reviewer` | ✓ | Code quality, security, and best practices review |
| `commit` |  | Run tests/linters, then create a conventional commit and push |
| `dart-app-developer` | ✓ | Flutter/Dart apps — architecture, widgets, Riverpod, tests |
| `data-scientist` | ✓ | Data analysis, ML models, visualization |
| `devops-engineer` | ✓ | CI/CD, Docker, GitHub Actions |
| `documentation-engineer` | ✓ | README, API docs, architecture documentation |
| `frontend-engineer-ts` | ✓ | React, TypeScript, Tailwind CSS |
| `linux-specialist` | ✓ | Shell scripting, git, system administration |
| `product-manager` | ✓ | Feature planning, roadmaps, requirements |
| `project-coordinator` | ✓ | Memory Bank management, task coordination |
| `python-backend` | ✓ | FastAPI, Lambda, Python services |
| `python-test-engineer` | ✓ | pytest, integration testing |
| `security-specialist` | ✓ | Threat modeling, OWASP, AWS security hardening |
| `test-coordinator` | ✓ | Test strategy, coverage analysis |
| `typescript-test-engineer` | ✓ | Jest, Playwright, React Testing Library |
| `ui-ux-designer` | ✓ | Wireframes, design systems, accessibility |
| `writing-blog-posts` | ✓ | Blog posts for coles.codes in Matt's voice |
| `writing-documents` | ✓ | Docs, memos, PRFAQs, COEs (Amazon writing style) |
| `writing-style` | ✓ | Matt's personal writing style for messages & email |

## MCP Servers

| MCP | Purpose |
|-----|---------|
| `filesystem` | File operations across your home directory |
| `puppeteer` | Browser automation and screenshots |
| `playwright` | Cross-browser testing automation |
| `memory` | Persistent knowledge graph across sessions |
| `aws-kb` | AWS Knowledge Base retrieval |
| `aws-iac` | CDK/CloudFormation validation — cfn-lint, cfn-guard, CDK-NAG, construct examples (`awslabs.aws-iac-mcp-server`) |
| `aws-documentation` | Live AWS service/construct documentation lookup (`awslabs.aws-documentation-mcp-server`) |
| `context7` | Real-time library documentation |
| `dart` | Dart/Flutter project context and tools |

## Configuration

MCP configuration: `~/.claude.json` (top-level `mcpServers` key, written by `./install.sh --mcps-only`)
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
3. python-backend implements auth code
4. Tests auto-run, errors auto-fixed (max 3 attempts)
5. code-reviewer checks for security issues
6. Commit message suggested
```

## Hooks

Testing and security automation hook scripts live in `hooks/`; install them via:

```bash
./install.sh --hooks-only
```

The hook automatically runs after code changes:
- **pytest** - Python tests
- **jest/mocha** - JavaScript/TypeScript tests
- **bandit** - Python security scanning
- **pip-audit / npm audit** - Package vulnerability checks

`install.sh --hooks-only` also writes hard, model-independent safety into
`~/.claude/settings.json` (these are enforced by the harness, not interpreted
from CLAUDE.md, which degrades as context grows):

- **PreToolUse deploy guard** (`pre_deploy_hook.sh`) — pauses `cdk deploy` /
  `cdk destroy` and asks you to confirm you reviewed `cdk diff` for resource
  replacements (a renamed Construct ID can force destruction).
- **`permissions.deny`** — blocks reads of `~/.aws/**` so AWS credentials never
  reach the model.
- **`env.CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1`** — scrubs secrets from subprocess
  environments.

Bypass ("yolo") permissions mode is left enabled — the installer removes any
`disableBypassPermissionsMode` lockdown from a previous strict install.
