# Testing & Security Automation Hooks

Post-code hooks for Claude Code and Kiro CLI that automatically run tests and security scans after coding tasks.

## Features

- **Automatic Test Running**
  - pytest for Python projects
  - jest/mocha for JavaScript/TypeScript projects
  - CDK synthesis for infrastructure projects

- **Security Scanning**
  - bandit for Python security issues
  - npm audit for Node.js vulnerabilities
  - pip-audit for Python package vulnerabilities

- **Project Detection**
  - Automatically detects project type (Python, Node.js, CDK)
  - Only runs relevant checks for each project

## Installation

```bash
./install_hooks.sh
```

This will:
1. Check for required tools (pytest, bandit, pip-audit, npm)
2. Provide configuration examples for Claude Code and Kiro CLI
3. Optionally create a project-level test script

## Required Tools

### Python Projects
```bash
pip install pytest bandit pip-audit
```

### Node.js Projects
```bash
npm install  # npm audit is built-in
```

### CDK Projects
```bash
npm install -g aws-cdk
```

## Hook Configuration

### Claude Code

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
            "command": "/path/to/Hooks/post_code_hook.sh"
          }
        ]
      }
    ]
  }
}
```

### Kiro CLI

Add to `~/.kiro/settings/hooks.json`:

```json
{
  "hooks": {
    "postTask": [
      {
        "name": "test-and-security-scan",
        "description": "Run tests and security scans after code changes",
        "command": "/path/to/Hooks/post_code_hook.sh",
        "enabled": true,
        "triggers": ["fs_write", "execute_bash"]
      }
    ]
  }
}
```

## Manual Execution

Run the hook manually in any project:

```bash
./post_code_hook.sh
```

## Output

The hook provides colored output:
- `[PASS]` - Check passed
- `[WARN]` - Warning (non-critical issue)
- `[FAIL]` - Check failed (critical issue)
- `[INFO]` - Informational message

A report is saved to `/tmp/code_review_report.md` after each run.

## Environment Variables

- `REPORT_FILE` - Custom path for the report (default: `/tmp/code_review_report.md`)
- `MAX_TEST_TIME` - Timeout for test runs in seconds (default: `300`)

## Files

- `post_code_hook.sh` - Main hook script
- `install_hooks.sh` - Installation helper
- `README.md` - This documentation
