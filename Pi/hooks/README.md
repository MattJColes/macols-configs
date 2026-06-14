# Pi Check Hooks

Pi has no `settings.json` hook array — hooks are TypeScript extensions. The
`pi-checks` extension subscribes to two pi lifecycle events and shells out to
the shared check scripts, mirroring Claude Code's PostToolUse + Stop hooks.

| Pi event | Script | When | Equivalent |
|----------|--------|------|------------|
| `tool_result` (write/edit tools) | `post_code_hook.sh <file>` | after a file is written/edited | Claude Code PostToolUse |
| `agent_end` | `post_task_hook.sh` | when the agent finishes a turn | Claude Code Stop |

Both scripts source the shared libraries in `../../shared/` (`post_code_checks.sh`,
`post_task_checks.sh`) and run the relevant tests, lint, type-checks and
security scans for the detected project type (Python, Node, CDK, Flutter).

## Advisory + change-gated

Unlike a blocking Stop hook, these are **advisory**:

- `post_task_hook.sh` is **change-gated** — it calls the shared `code_changed`
  helper and skips the whole battery when the working tree has no changed code
  files (e.g. a Q&A or docs-only turn).
- When code did change, findings are printed and surfaced into the session via
  `pi.sendMessage`, but the agent is **never blocked**. Read the findings and
  fix real issues.

## Install

```bash
# from the Pi/ directory
./install.sh --hooks-only
```

This copies the scripts to `~/.pi/agent/hooks/`, writes the extension to
`~/.pi/agent/extensions/pi-checks.ts` (with the absolute hooks path baked in),
and pi auto-discovers it on next start (or `/reload`).
