# OpenCode Configuration

OpenCode setup with MCP servers and LM Studio integration for local model inference.

## Overview

This folder provides configuration scripts for [OpenCode](https://github.com/opencode-ai/opencode), a terminal-based AI coding assistant. The setup mirrors the MCP configuration used by Claude Code and Kiro CLI, ensuring consistency across all three AI assistants.

## Quick Start

```bash
# 1. Install MCPs (same as Claude Code/Kiro)
./install_mcps.sh

# 2. Configure LM Studio with GLM4.7-Air
./configure_lmstudio.sh

# 3. Start OpenCode
opencode-glm  # Uses local GLM4.7-Air
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

## LM Studio + GLM4.7-Air Setup

### Prerequisites

1. **LM Studio** - Download from [lmstudio.ai](https://lmstudio.ai/)
2. **GLM4.7-Air Model** - THUDM/glm-4-9b-chat

### Model Installation

1. Open LM Studio
2. Search for `THUDM/glm-4-9b-chat`
3. Download a quantized version:
   - **Q4_K_M** - Balanced (recommended, ~5GB VRAM)
   - **Q5_K_M** - Higher quality (~6GB VRAM)
   - **Q8_0** - Best quality (~9GB VRAM)
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
# Start with GLM4.7-Air (local)
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

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LMSTUDIO_HOST` | `localhost` | LM Studio server host |
| `LMSTUDIO_PORT` | `1234` | LM Studio server port |
| `GLM_MODEL` | `glm-4-9b-chat` | Model identifier |
| `ANTHROPIC_API_KEY` | - | For Claude fallback |

## Comparison: Claude Code vs Kiro vs OpenCode

| Feature | Claude Code | Kiro CLI | OpenCode |
|---------|-------------|----------|----------|
| Config Location | `~/.claude/` | `~/.kiro/` | `~/.config/opencode/` |
| MCP Format | `config.json` | `settings/mcp.json` | `mcp.json` |
| Agent Format | Markdown | JSON | Built-in |
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

## Why GLM4.7-Air?

GLM-4-9B-Chat (GLM4.7-Air) offers:
- **131K context window** - Handle large codebases
- **Multilingual support** - Chinese and English
- **Efficient inference** - Runs on consumer GPUs
- **Strong coding ability** - Competitive with larger models
- **Open weights** - No API costs for local use

## Related Configurations

- [ClaudeAgents](../ClaudeAgents/) - Claude Code MCP and agent setup
- [KiroAgents](../KiroAgents/) - Kiro CLI MCP and agent setup
- [Terminal](../Terminal/) - Development environment setup
