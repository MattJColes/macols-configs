# Claude Code Testing & Security Hooks

Post-code hooks for Claude Code that automatically run tests, security scans, and intelligent code review after coding tasks.

## Features

- **Automatic Test Running**: pytest, jest/mocha, CDK synthesis
- **Security Scanning**: bandit for Python, npm audit for Node.js, pip-audit for Python packages
- **Project Detection**: Automatically detects project type and runs relevant checks
- **Agent Code Review**: `type: "agent"` hook spawns a mini LLM agent to review changed files for bugs and security issues beyond what automated tools catch

## Hook Types

Two hooks fire on every `Edit|Write|NotebookEdit`:

| Type | What it does |
|------|-------------|
| `command` | Runs shell script: tests, bandit, pip-audit/npm audit |
| `agent` | Spawns a mini LLM agent to review the edited file for logic bugs and missed security issues |

> **Note:** `type: "agent"` hooks run a scoped LLM agent with tool access. They are separate from the main Claude session's subagents spawned via the Task tool.

## Installation

> **Note:** Running `install_hooks.sh` replaces the entire `hooks` key in `~/.claude/settings.json`. Any pre-existing hooks will be removed.

```bash
./install_hooks.sh
```

## Hook Configuration

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write|NotebookEdit",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/ClaudeCode/hooks/post_code_hook.sh"
          },
          {
            "type": "agent",
            "prompt": "A file was just edited. Check tool_input.file_path — if the file is not a source code file (e.g. it ends in .md, .json, .toml, .yaml, .yml, .txt, .cfg, .ini, .lock), respond with SKIPPED and stop. Otherwise, read the file and briefly review it for: (1) potential bugs or logic errors, (2) security issues that automated scans miss, (3) missing error handling for edge cases. Only flag real issues with specific line references. Be concise and skip style preferences.",
            "timeout": 60
          }
        ]
      }
    ]
  }
}
```

Or use Claude Code's `/hooks` command for interactive configuration.

## Manual Execution

```bash
./post_code_hook.sh
```

## Environment Variables

- `MAX_TEST_TIME` - Timeout for test runs in seconds (default: `120` for PostToolUse, `300` for Stop)
