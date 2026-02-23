# Kiro CLI Testing & Security Hooks

Post-code hooks for Kiro CLI that automatically run tests and security scans after coding tasks.

## Features

- **Automatic Test Running**: pytest, jest/mocha, CDK synthesis, flutter test
- **Security Scanning**: bandit for Python, npm audit for Node.js, pip-audit for Python packages
- **Project Detection**: Automatically detects project type and runs relevant checks

## Kiro Hook Events

Kiro CLI supports these hook events: `agentSpawn`, `userPromptSubmit`, `preToolUse`, `postToolUse`, `stop`.

> **Note:** Kiro hooks are command-based only (shell scripts). There is no `type: "agent"` equivalent — hooks cannot directly spawn LLM subagents. To run agents automatically, use Kiro's built-in subagent system in your custom agent configurations.

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

- `REPORT_FILE` - Custom path for the report (default: `/tmp/code_review_report.md`)
- `MAX_TEST_TIME` - Timeout for test runs in seconds (default: `300`)
