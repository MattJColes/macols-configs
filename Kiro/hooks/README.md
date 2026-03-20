# Kiro Testing & Security Hooks

Post-code hooks for Kiro that automatically run tests and security scans after coding tasks.

## Features

- **Automatic Test Running**: pytest, jest/mocha, CDK synthesis, flutter test
- **Security Scanning**: bandit for Python, npm audit for Node.js, pip-audit for Python packages
- **Project Detection**: Automatically detects project type and runs relevant checks

## CLI Hook Events

Kiro CLI supports these hook events: `agentSpawn`, `userPromptSubmit`, `preToolUse`, `postToolUse`, `stop`.

> **Note:** CLI hooks are command-based only (shell scripts). There is no `type: "agent"` equivalent — hooks cannot directly spawn LLM subagents.

## IDE Hooks

Kiro IDE supports hooks via the Command Palette (`Cmd+Shift+P` → "Kiro: Open Hooks Configuration"). IDE hooks support both **command** and **agent** ("Ask Kiro") types.

Available IDE hook events:

| Event | Description |
|-------|-------------|
| Pre Prompt Submit | Before user message is sent |
| Post Prompt Submit | After user message is sent |
| Pre Tool Execution | Before a tool runs |
| Post Tool Execution | After a tool runs (≈ CLI `postToolUse`) |
| Pre Task Execution | Before an agent task starts |
| Post Task Execution | After an agent task completes (≈ CLI `stop`) |
| Pre Subtask Execution | Before a subtask starts |
| Post Subtask Execution | After a subtask completes |
| Pre MCP Tool Execution | Before an MCP tool runs |
| Post MCP Tool Execution | After an MCP tool runs |

> **Note:** Agent-type hooks ("Ask Kiro") are IDE-only. CLI only supports command hooks.

## Installation

```bash
./install_hooks.sh
```

## Hook Configuration

Add to `~/.kiro/settings/hooks.json`:

```json
{
  "hooks": {
    "postToolUse": [
      {
        "matcher": "fs_write|write",
        "command": "/path/to/Kiro/hooks/post_code_hook.sh"
      }
    ],
    "stop": [
      {
        "command": "/path/to/Kiro/hooks/post_task_hook.sh"
      }
    ]
  }
}
```

## Manual Execution

```bash
echo '{"hook_event_name":"postToolUse","cwd":".","tool_name":"fs_write","tool_input":{}}' | ./post_code_hook.sh
```

## Environment Variables

- `MAX_TEST_TIME` - Timeout for test runs in seconds (default: `120` for post-code, `300` for post-task)
