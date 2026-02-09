# OpenCode Configuration

OpenCode setup with skills, MCP servers, and LM Studio integration for local model inference.

## Overview

This folder provides configuration scripts for [OpenCode](https://github.com/opencode-ai/opencode), a terminal-based AI coding assistant. The setup includes skills (reusable agent behaviors) and MCP servers, mirroring the configuration used by Claude Code and Kiro CLI for consistency across all three AI assistants.

## Quick Start

```bash
# 1. Install agents (specialized assistants)
./install_agents.sh

# 2. Install skills (agent behaviors - includes agents)
./install_skills.sh

# 3. Install MCPs (tool integrations)
./install_mcps.sh

# 4. Configure LM Studio with GLM-4.7-Flash
./configure_lmstudio.sh

# 5. Start OpenCode
opencode-glm  # Uses local GLM-4.7-Flash
```

## Agents

Agents are specialized assistants that handle specific types of tasks. They are installed to `~/.config/opencode/agents/` and can be invoked as skills or via the Task tool.

```bash
# Install agents
./install_agents.sh
```

See [agents/README.md](agents/README.md) for detailed agent documentation.

## Skills

Skills provide reusable agent behaviors that OpenCode agents can load on-demand. They are installed to `~/.config/opencode/skills/` (global) or `.opencode/skills/` (project-level).

**Note:** Running `./install_skills.sh` will also install agents automatically.

| Skill | Description |
|-------|-------------|
| `architecture-expert` | System design, AWS infrastructure, and technical decisions |
| `cdk-expert-python` | AWS CDK with Python |
| `cdk-expert-ts` | AWS CDK with TypeScript |
| `code-reviewer` | Code quality, security, and best practices |
| `data-scientist` | Data analysis, ML models, and visualization |
| `devops-engineer` | CI/CD, Docker, and infrastructure automation |
| `documentation-engineer` | README, API docs, and user guides |
| `frontend-engineer` | React, TypeScript, and Tailwind CSS |
| `linux-specialist` | Shell scripting and system administration |
| `product-manager` | Feature planning, requirements, and roadmaps |
| `project-coordinator` | Task orchestration and Memory Bank management |
| `python-backend` | FastAPI, AWS Lambda, and Python services |
| `python-test-engineer` | pytest and test automation |
| `security-specialist` | Threat modeling, OWASP, and AWS security |
| `test-coordinator` | Test strategy, coverage, and coordination |
| `typescript-test-engineer` | Jest, Playwright, and React Testing Library |
| `ui-ux-designer` | Wireframes, design systems, and accessibility |

Install skills:

```bash
# Install globally
./install_skills.sh

# Install to current project
./install_skills.sh --project

# List available skills
./install_skills.sh --list
```

## MCP Servers

The following MCP servers are configured (identical to Claude Code and Kiro):

| Server | Description | Use Case |
|--------|-------------|----------|
| `filesystem` | File read/write operations | All file operations |
| `sequential-thinking` | Complex problem-solving | Architecture, planning |
| `puppeteer` | Browser automation | Screenshots, UI testing |
| `playwright` | Cross-browser testing | E2E testing |
| `memory` | Knowledge graph persistence | Cross-session context |
| `aws-kb` | AWS Knowledge Base retrieval | AWS documentation |
| `context7` | Real-time documentation | Up-to-date library docs |
| `dynamodb` | DynamoDB operations | Data modeling |

### Optional MCPs

- `github` - GitHub repository operations (requires PAT)
- `gitlab` - GitLab repository operations (requires PAT)

## LM Studio + GLM-4.7-Flash Setup

### Prerequisites

1. **LM Studio** - Download from [lmstudio.ai](https://lmstudio.ai/)
2. **GLM-4.7-Flash Model** - zai-org/glm-4.7-flash

### Model Installation

1. Open LM Studio
2. Search for `zai-org/glm-4.7-flash`
3. Download a quantized version:
   - **Q4_K_M** - Balanced (recommended, ~3GB VRAM)
   - **Q5_K_M** - Higher quality (~4GB VRAM)
   - **Q8_0** - Best quality (~5GB VRAM)
4. Load the model
5. Start the local server (port 1234)

### Configuration

Run the configuration script:

```bash
./configure_lmstudio.sh
```

This creates:
- `~/.config/opencode/config.json` - Main OpenCode configuration
- `~/.config/opencode/mcp.json` - MCP server configuration
- Shell aliases for easy switching

### Usage

```bash
# Start with GLM-4.7-Flash (local)
opencode-glm

# Start with Claude (requires ANTHROPIC_API_KEY)
opencode-claude

# Check LM Studio status
lmstudio-status
```

## Configuration Files

| File | Location | Purpose |
|------|----------|---------|
| `config.json` | `~/.config/opencode/` | Main OpenCode settings |
| `mcp.json` | `~/.config/opencode/` | MCP server definitions |
| `opencode.md` | `~/.config/opencode/` | System-level agent configuration |
| `agents/` | `~/.config/opencode/` | Agent definitions |
| `skills/` | `~/.config/opencode/` | Agent skill definitions |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LMSTUDIO_HOST` | `localhost` | LM Studio server host |
| `LMSTUDIO_PORT` | `1234` | LM Studio server port |
| `GLM_MODEL` | `glm-4.7-flash` | Model identifier |
| `ANTHROPIC_API_KEY` | - | For Claude fallback |

## Comparison: Claude Code vs Kiro vs OpenCode

| Feature | Claude Code | Kiro CLI | OpenCode |
|---------|-------------|----------|----------|
| Config Location | `~/.claude/` | `~/.kiro/` | `~/.config/opencode/` |
| MCP Format | `config.json` | `settings/mcp.json` | `mcp.json` |
| Agents Format | `.md` | `.md` | `.md` |
| Agents Location | `~/.claude/agents/` | `~/.kiro/agents/` | `~/.config/opencode/agents/` |
| Skills Format | `SKILL.md` | `SKILL.md` | `SKILL.md` |
| Skills Location | `~/.claude/skills/` | `~/.kiro/skills/` | `~/.config/opencode/skills/` |
| Default Model | Claude | Kiro | Configurable |
| Local Models | No | No | Yes (LM Studio) |

## Troubleshooting

### LM Studio Connection Issues

```bash
# Check if LM Studio is running
curl http://localhost:1234/v1/models

# Check available models
lmstudio-status
```

### MCP Not Loading

1. Verify MCP config exists: `cat ~/.config/opencode/mcp.json`
2. Check npm packages: `npm list -g | grep modelcontextprotocol`
3. Restart OpenCode

### Model Not Found

Ensure the model identifier matches exactly what LM Studio shows. Check with:

```bash
curl http://localhost:1234/v1/models | jq '.data[].id'
```

## Why GLM-4.7-Flash?

GLM-4.7-Flash offers:
- **131K context window** - Handle large codebases
- **Faster inference** - Optimized for speed and efficiency
- **Smaller model size** - 4.7B parameters, runs on less powerful hardware
- **Strong coding ability** - Specialized for code generation tasks
- **Multilingual support** - Chinese and English
- **Open weights** - No API costs for local use

## Related Configurations

- [ClaudeAgents](../ClaudeAgents/) - Claude Code MCP and agent setup
- [KiroAgents](../KiroAgents/) - Kiro CLI MCP and agent setup
- [Terminal](../Terminal/) - Development environment setup
