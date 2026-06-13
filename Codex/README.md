# Codex CLI Prompts, Instructions, MCPs & Hooks

This directory adapts the Claude Code configuration for [OpenAI Codex
CLI](https://developers.openai.com/codex). It shares the same persona sources
and the same shared check libraries, but installs them into Codex's own
layout (`~/.codex/`).

## How it maps to Claude Code

| Claude Code | Codex CLI | Location |
|-------------|-----------|----------|
| Skills / agents | Custom prompts (slash commands) | `~/.codex/prompts/<name>.md` |
| `CLAUDE.md` | `AGENTS.md` | `~/.codex/AGENTS.md` |
| `mcp-config.json` → `claude mcp add` | `codex mcp add` | `~/.codex/config.toml` |
| `settings.json` hooks | `hooks.json` | `~/.codex/hooks.json` |

Codex has no separate "agent" file format like Claude Code's subagents, so every
persona is installed as a **custom prompt** (slash command) instead. The body is
identical — only the frontmatter is swapped.

## Quick Install

Each persona is authored as a **single source file** — `personas/<name>/SKILL.md` —
the same sources used by the Claude Code and OpenCode installers. `install.sh`
generates one Codex prompt per persona, writes the system `AGENTS.md`, registers
MCP servers via the `codex mcp` CLI, and wires lifecycle hooks into
`~/.codex/hooks.json`. It performs a clean deploy of prompts and hooks.

```bash
# Install everything (prompts, AGENTS.md, MCPs, hooks)
./install.sh

# Install a single component
./install.sh --prompts-only
./install.sh --instructions-only
./install.sh --mcps-only
./install.sh --hooks-only

# Install prompts & AGENTS.md into the current project
./install.sh --prompts-only --project

# Preview available personas
./install.sh --list
```

### Prerequisites

The installer is a Bash script. It needs **Node.js** (to generate prompts and
write `hooks.json`) and — only for `--mcps-only` — the
[`codex`](https://developers.openai.com/codex) CLI plus `jq` and `uv`
(auto-installed if missing).

### Install Codex CLI

```bash
# macOS (Homebrew cask)
brew install --cask codex

# Linux / anywhere with Node
npm install -g @openai/codex@latest
```

> Homebrew **casks are macOS-only**, so on Linux install Codex via npm (the
> `Terminal/install_ubuntu26.sh` script does this for you).

## Directory Structure

```
Codex/
├── personas/            # One folder per persona — 22 prompts (shared sources)
│   ├── architecture-expert/
│   │   └── SKILL.md
│   └── ...
├── hooks/               # Advisory testing & security hooks
│   ├── post_code_hook.sh   #   PostToolUse — tests/lint/security on edits
│   ├── post_task_hook.sh   #   Stop — full validation pass
│   ├── pre_deploy_hook.sh  #   PreToolUse — cdk deploy/destroy reminder
│   └── README.md
├── AGENTS.md            # System-level Codex instructions (→ ~/.codex/AGENTS.md)
├── mcp-config.json      # MCP server configuration (shared shape)
├── install.sh          # Unified installer (prompts, AGENTS.md, MCPs, hooks)
└── README.md
```

## Personas (installed as `/<name>` prompts)

| Prompt | Description |
|--------|-------------|
| `/architecture-expert` | System design, AWS infrastructure, technical decisions |
| `/cdk-expert-python` | AWS CDK infrastructure in Python |
| `/cdk-expert-ts` | AWS CDK infrastructure in TypeScript |
| `/code-reviewer` | Code quality, security, and best practices review |
| `/commit` | Run tests/linters, then create a conventional commit and push |
| `/dart-app-developer` | Flutter/Dart apps — architecture, widgets, Riverpod, tests |
| `/data-scientist` | Data analysis, ML models, visualization |
| `/devops-engineer` | CI/CD, Docker, GitHub Actions |
| `/documentation-engineer` | README, API docs, architecture documentation |
| `/frontend-engineer-ts` | React, TypeScript, Tailwind CSS |
| `/linux-specialist` | Shell scripting, git, system administration |
| `/product-manager` | Feature planning, roadmaps, requirements |
| `/project-coordinator` | Memory Bank management, task coordination |
| `/python-backend` | FastAPI, Lambda, Python services |
| `/python-test-engineer` | pytest, integration testing |
| `/security-specialist` | Threat modeling, OWASP, AWS security hardening |
| `/test-coordinator` | Test strategy, coverage analysis |
| `/typescript-test-engineer` | Jest, Playwright, React Testing Library |
| `/ui-ux-designer` | Wireframes, design systems, accessibility |
| `/writing-blog-posts` | Blog posts for coles.codes in Matt's voice |
| `/writing-documents` | Docs, memos, PRFAQs, COEs (Amazon writing style) |
| `/writing-style` | Matt's personal writing style for messages & email |

## MCP Servers

Registered with `codex mcp add` (inspect with `codex mcp list`):

| MCP | Purpose |
|-----|---------|
| `filesystem` | File operations across your home directory |
| `puppeteer` | Browser automation and screenshots |
| `playwright` | Cross-browser testing automation |
| `aws-kb` | AWS Knowledge Base retrieval |
| `aws-iac` | CDK/CloudFormation validation — cfn-lint, cfn-guard, CDK-NAG |
| `aws-documentation` | Live AWS service/construct documentation lookup |
| `context7` | Real-time library documentation |
| `dart` | Dart/Flutter project context and tools |

## Usage

### Prompts

```bash
codex
# then, in the session:
/python-backend Create a FastAPI endpoint for user management
/code-reviewer Review the changes in src/services/
/commit
```

### Hooks

Three advisory lifecycle hooks are wired into `~/.codex/hooks.json`:

- **PostToolUse** (`post_code_hook.sh`) — after file edits, runs the project's
  tests, linters and security scans (pytest, jest, ruff, mypy, eslint, bandit,
  pip-audit, npm audit, cdk synth).
- **Stop** (`post_task_hook.sh`) — a full validation pass when a turn finishes,
  reporting any critical failures back to Codex.
- **PreToolUse** (`pre_deploy_hook.sh`) — a loud reminder to review `cdk diff`
  before `cdk deploy` / `cdk destroy`.

The hooks are **advisory** — they report findings and exit cleanly rather than
hard-blocking. Hard enforcement on Codex comes from `approval_policy` and
`sandbox_mode` in `~/.codex/config.toml`. The hook matchers use
Claude-Code-compatible tool names (`Bash`, `Edit`, `Write`); if a future Codex
release renames its internal tools, adjust the `matcher` fields in
`~/.codex/hooks.json` (or in `install.sh`). See [hooks/README.md](hooks/README.md).
