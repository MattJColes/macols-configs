# Kiro CLI Testing & Security Hooks

Post-code hooks for Kiro CLI that automatically run tests and security scans after coding tasks.

## Features

- **Automatic Test Running**: pytest, jest/mocha, CDK synthesis
- **Security Scanning**: bandit for Python, npm audit for Node.js, pip-audit for Python packages
- **Project Detection**: Automatically detects project type and runs relevant checks

## Installation

```bash
./install_hooks.sh
```

## Hook Configuration

Add to `~/.kiro/settings/hooks.json`:

```json
{
  "hooks": {
    "postTask": [
      {
        "name": "test-and-security-scan",
        "description": "Run tests and security scans after code changes",
        "command": "/path/to/Kiro/hooks/post_code_hook.sh",
        "enabled": true,
        "triggers": ["fs_write", "execute_bash"]
      }
    ]
  }
}
```

## Manual Execution

```bash
./post_code_hook.sh
```

## Environment Variables

- `REPORT_FILE` - Custom path for the report (default: `/tmp/code_review_report.md`)
- `MAX_TEST_TIME` - Timeout for test runs in seconds (default: `300`)
