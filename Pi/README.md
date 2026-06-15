# Pi Coding Agent

Configuration for the [Pi coding agent](https://pi.dev)
(`@earendil-works/pi-coding-agent`): specialist personas as Agent Skills,
a system-level `AGENTS.md`, and advisory test/lint/security check hooks — all
generated from the same shared sources as the Claude Code, Codex and OpenCode
setups.

## Install

```bash
cd Pi
./install.sh                    # installs pi (if missing), packages, skills, AGENTS.md, hooks
```

Scope it with flags:

```bash
./install.sh --skills-only      # just the /skill:<name> Agent Skills
./install.sh --context-only     # just the system AGENTS.md
./install.sh --hooks-only       # just the pi-checks extension + scripts
./install.sh --packages-only    # just the pi packages (pi install <pkg>)
./install.sh --no-pi            # configure everything but don't touch the pi binary
./install.sh --no-packages      # skip installing pi packages
./install.sh -p                 # per-project: ./.pi/skills + ./AGENTS.md
./install.sh --list             # preview available personas
```

## What gets installed

| Resource | Location | Notes |
|----------|----------|-------|
| Skills   | `~/.pi/agent/skills/<name>/SKILL.md` | Agent Skills standard, invoked as `/skill:<name>` |
| Context  | `~/.pi/agent/AGENTS.md` | System-level instructions |
| Hooks    | `~/.pi/agent/extensions/pi-checks.ts` + `~/.pi/agent/hooks/*.sh` | Advisory checks |
| Packages | installed via `pi install` | [`pi-agent-web-access`](https://pi.dev/packages/pi-agent-web-access): web search, page fetch, YouTube transcripts, GitHub repo browsing |

(`~/.pi/agent` is overridable via `PI_CODING_AGENT_DIR`.)

## How it differs from the other tools

Pi is deliberately minimal:

- **Skills, not agents.** Personas install as Agent Skills (`/skill:<name>`)
  rather than separate agent definitions. The `AGENTS.md` context plus the
  skills cover the same ground.
- **No MCP.** Pi has no built-in Model Context Protocol support — by design it
  prefers CLI tools (with READMEs) and skills. `./install.sh --mcps-only` just
  prints this guidance. Expose external capabilities as a documented CLI tool or
  a skill instead.
- **Hooks are extensions.** Pi has no `settings.json` hook array. Instead a tiny
  TypeScript extension (`pi-checks`) subscribes to pi's `tool_result` and
  `agent_end` events and shells out to the shared check scripts — mirroring
  Claude Code's PostToolUse + Stop hooks, but **advisory** (it reports, never
  blocks).

See [hooks/README.md](hooks/README.md) for the check behaviour.
