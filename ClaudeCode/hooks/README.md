# Claude Code Testing & Security Hooks

Hooks for Claude Code that lint the file you just edited and run the full
test/security battery once a turn ends.

## Features

- **Fast per-edit feedback**: lint + type-check the single file that changed
- **Full validation at turn end**: pytest, jest/mocha, CDK synth, security scans
- **Security Scanning**: bandit for Python, npm audit for Node.js, pip-audit for Python packages
- **Project Detection**: Automatically detects project type and runs relevant checks

## Hook Types

One hook fires on every `Edit|Write|NotebookEdit`:

| Type | What it does |
|------|-------------|
| `command` | Fast, **file-scoped** lint / type-check for the changed file only — `ruff`+`mypy` (Python), `eslint` (JS/TS), or `dart analyze` (Dart). No tests or security audits run per-edit; those run once at turn end (Stop hook below) so editing N files doesn't re-run the whole suite N times. |

A second hook fires on `PreToolUse` for `Bash`:

| Hook | What it does |
|------|-------------|
| `pre_deploy_hook.sh` | Detects `cdk deploy` / `cdk destroy` and returns `permissionDecision: "ask"`, pausing to confirm you reviewed `cdk diff` for resource replacements. A renamed Construct ID changes its logical ID and forces delete-then-create — data loss on stateful resources. `cdk diff` / `cdk synth` pass through untouched. |

A third hook fires on `Stop` (turn end):

| Hook | What it does |
|------|-------------|
| `post_task_hook.sh` | **Advisory + change-gated.** This is the one place the full battery runs (tests, lint, type-check, security scans) — once a turn ends, and only when the git working tree has changed code files (skips Q&A/docs-only turns via the shared `code_changed` gate). It **reports** findings to stderr rather than blocking the stop. The PostToolUse hook above only lints the changed file; the heavy suite is deliberately concentrated here so it runs once per turn instead of after every edit. To restore blocking, emit `{"decision":"block","reason":...}` on stdout from this script. |

`install.sh --hooks-only` additionally writes hard safety to
`~/.claude/settings.json` that the model cannot override: `permissions.deny` on
`Read(~/.aws/**)` and `env.CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1`. Bypass ("yolo")
permissions mode is left enabled.

## Installation

> **Note:** Running `./install.sh --hooks-only` replaces the entire `hooks` key in `~/.claude/settings.json`. Any pre-existing hooks will be removed.

```bash
# from the ClaudeCode/ directory
./install.sh --hooks-only
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

- `MAX_TEST_TIME` - Timeout for test runs in seconds (default: `120` for PostToolUse, `300` for Stop)
