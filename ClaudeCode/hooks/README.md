# Claude Code Testing & Security Hooks

Post-code hooks for Claude Code that automatically run tests and security scans after coding tasks.

## Features

- **Automatic Test Running**: pytest, jest/mocha, CDK synthesis
- **Security Scanning**: bandit for Python, npm audit for Node.js, pip-audit for Python packages
- **Project Detection**: Automatically detects project type and runs relevant checks

## Installation

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

- `REPORT_FILE` - Custom path for the report (default: `/tmp/code_review_report.md`)
- `MAX_TEST_TIME` - Timeout for test runs in seconds (default: `300`)
