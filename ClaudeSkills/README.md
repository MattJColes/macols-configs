# Claude Code Skills & MCP Configuration

This directory contains specialized Claude Code skills converted from agents, plus MCP (Model Context Protocol) server configuration.

## Quick Install

```bash
# Install everything (skills + MCPs)
./install.sh

# Install only skills
./install.sh --skills-only

# Install to current project
./install.sh --skills-only --project

# List available skills
./install.sh --list
```

## Available Skills (16)

| Skill | Description |
|-------|-------------|
| `/architecture-expert` | System design, AWS infrastructure, technical decisions |
| `/cdk-expert-python` | AWS CDK infrastructure in Python |
| `/cdk-expert-ts` | AWS CDK infrastructure in TypeScript |
| `/code-reviewer` | Code quality, security, and best practices review |
| `/data-scientist` | Data analysis, ML models, visualization |
| `/devops-engineer` | CI/CD, Docker, GitHub Actions |
| `/documentation-engineer` | README, API docs, architecture documentation |
| `/frontend-engineer` | React, TypeScript, Tailwind CSS |
| `/linux-specialist` | Shell scripting, git, system administration |
| `/product-manager` | Feature planning, roadmaps, requirements |
| `/project-coordinator` | Memory Bank management, task coordination |
| `/python-backend` | FastAPI, Lambda, Python services |
| `/python-test-engineer` | pytest, integration testing |
| `/test-coordinator` | Test strategy, coverage analysis |
| `/typescript-test-engineer` | Jest, Playwright, React Testing Library |
| `/ui-ux-designer` | Wireframes, design systems, accessibility |

## MCP Servers

The following MCP servers are configured:

| MCP | Purpose |
|-----|---------|
| `filesystem` | File operations across your home directory |
| `sequential-thinking` | Complex problem-solving and planning |
| `puppeteer` | Browser automation and screenshots |
| `playwright` | Cross-browser testing automation |
| `memory` | Persistent knowledge graph across sessions |
| `aws-kb` | AWS Knowledge Base retrieval |
| `context7` | Real-time library documentation (65% fewer tokens!) |
| `dynamodb` | DynamoDB operations |

### Optional MCPs

These can be added to your `~/.claude/settings.json`:

```json
{
  "github": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-github"],
    "env": {
      "GITHUB_PERSONAL_ACCESS_TOKEN": "your-token"
    }
  },
  "gitlab": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-gitlab"],
    "env": {
      "GITLAB_PERSONAL_ACCESS_TOKEN": "your-token",
      "GITLAB_API_URL": "https://gitlab.com"
    }
  }
}
```

## Directory Structure

```
ClaudeSkills/
├── install.sh           # Unified installer
├── mcp-config.json      # MCP server configuration
├── README.md            # This file
└── skills/
    ├── architecture-expert/
    │   └── SKILL.md
    ├── cdk-expert-python/
    │   └── SKILL.md
    ├── frontend-engineer/
    │   └── SKILL.md
    └── ... (16 skills total)
```

## Usage

### Invoking Skills

Once installed, invoke skills in Claude Code using slash commands:

```
/frontend-engineer Build a user profile component with React
/python-backend Create a FastAPI endpoint for user management
/code-reviewer Review the changes in src/services/
```

### Skills vs MCPs

- **Skills**: Procedural knowledge and workflows (how to do things)
- **MCPs**: External tools and data access (what Claude can use)

They work together:
- `/python-backend` skill knows how to write Python APIs
- `dynamodb` MCP provides DynamoDB access for that API

## Customization

### Add Custom Skills

Create a directory in `~/.claude/skills/your-skill/` with a `SKILL.md` file:

```markdown
---
name: your-skill
description: What this skill does
user-invocable: true
---

Instructions for Claude when using this skill...
```

### Modify MCP Config

Edit `~/.claude/settings.json` to add or modify MCP servers.

## Requirements

- Node.js 18+ (for MCP servers)
- Claude Code CLI
- (Optional) uv for Python MCPs
- (Optional) AWS credentials for aws-kb and dynamodb MCPs
