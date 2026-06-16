# Codex Hooks

Lifecycle hooks for Codex CLI. `../install.sh` writes these into
`~/.codex/hooks.json`, which Codex loads alongside `config.toml`.

| Hook | Event | What it does |
|------|-------|--------------|
| `post_code_hook.sh` | `PostToolUse` (file edits) | Fast, file-scoped lint / type-check for the changed file only (`ruff`+`mypy`, `eslint`, or `dart analyze`) |
| `post_task_hook.sh` | `Stop` (turn complete) | Full validation pass — tests, lint, `bandit`, `pip-audit`, `npm audit`, `cdk synth` |
| `pre_deploy_hook.sh` | `PreToolUse` (shell) | Warns before `cdk deploy` / `cdk destroy` to review `cdk diff` for resource replacement |

All three are **advisory**: they report findings (stdout is fed back to Codex
as context; stderr is shown to you) and exit `0`. They never hard-block a tool
call — hard enforcement on Codex comes from `approval_policy` and
`sandbox_mode` in `config.toml`, not from a hook decision schema that varies
between Codex versions.

The heavy lifting lives in the shared, tool-agnostic libraries under
`../../shared/` (`post_code_checks.sh`, `post_task_checks.sh`), the same ones
the Claude Code and OpenCode hooks use.

> **Matchers may need tuning.** `hooks.json` matches on Codex's internal tool
> names (e.g. the shell/exec tool, the patch/edit tool). These names can change
> between Codex releases; if a hook stops firing, run `codex` with hook
> debugging and adjust the `matcher` regexes in `~/.codex/hooks.json` (or in
> `install.sh`).
