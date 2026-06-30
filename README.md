# macols-configs

One source of truth for four agentic coding CLIs — **Claude Code**, **Codex**,
**OpenCode** and **Pi** — plus the terminal/dev-environment setup. Personas,
steering, MCP servers and check hooks are authored once under `shared/` and each
tool's installer renders them into that tool's native format, so nothing drifts.

## Structure

```
macols-configs/
├── install.sh              # orchestrator: env (optional) + all four tools
├── install_claudecode.sh   # self-contained per-tool installers
├── install_codex.sh        #   (ensure brew + CLI, then install configs)
├── install_opencode.sh
├── install_pi.sh
├── lib/
│   └── common.sh           # shared install functions used by all installers
├── shared/                 # ── single sources of truth ──
│   ├── personas/<name>/SKILL.md   # specialist personas (agents/skills/prompts)
│   ├── steering/base.md + tools/  # system steering, tokenised per tool
│   ├── mcp-config.json            # MCP server definitions
│   ├── hooks/                     # post-code / post-task / pre-deploy + plugins
│   ├── checks_common.sh          # shared check helpers (discovery, gate, timeout)
│   ├── post_code_checks.sh        # per-edit lint/type-check battery
│   ├── post_task_checks.sh        # turn-end battery (runs checks in parallel)
│   └── ensure_node.sh
├── Terminal/               # macOS / Ubuntu dev-environment setup
├── tests/verify_install.sh # post-install location + introspection checks
└── .github/workflows/      # installer tests, security scanning, dependabot
```

There are no per-tool directories: every difference between the tools lives in a
small per-tool file under `shared/` (e.g. `shared/steering/tools/codex.json`) and
in the matching `install_<tool>.sh`.

## Install

Each `install_<tool>.sh` is self-contained — it ensures Homebrew (macOS) and the
CLI binary, then installs that tool's agents/skills/prompts, steering, MCPs and
hooks. Run one, several, or all:

```bash
./install.sh                  # all four tools (binaries + configs)
./install.sh claudecode pi    # just Claude Code and Pi
./install.sh --env            # run the Terminal dev-environment setup first
./install_codex.sh            # one tool directly
```

Useful flags (per installer; run `--help` for the full list):

- `--agents-only` / `--skills-only` / `--prompts-only` / `--mcps-only` / `--hooks-only`
- `--no-cli` — skip the Homebrew/CLI bootstrap, install configs only
- `-p`, `--project` — install into the current project instead of user scope
- `--list` — preview the available personas

### Dev environment

```bash
./install.sh --env            # picks the right Terminal script for your OS
# or directly:
cd Terminal && ./install_macos.sh        # macOS
cd Terminal && ./install_ubuntu26.sh     # Ubuntu 26 / WSL2
```

See **[Terminal/README.md](Terminal/README.md)** for the full toolchain
(Python 3.x + uv, Node 22 + TypeScript/CDK, Podman, AWS CLI, LazyVim, etc.).

### Running with `--dangerously-skip-permissions`

Claude Code refuses bypass-permissions mode under root/sudo (the flag silently
drops back to the default mode), which bites in containers and install scripts
that run as root. The Claude Code installer drops a launcher at
`~/.claude/bin/claude-launch` that handles this the documented way:

```bash
~/.claude/bin/claude-launch            # or: alias cc=~/.claude/bin/claude-launch
```

- **Non-root** → runs `claude --dangerously-skip-permissions` directly.
- **Root** → drops to a non-root user (`$CLAUDE_USER`, else `$SUDO_USER`, else the
  owner of `$HOME`) and runs Claude as them. For this to work Claude must be
  installed for that user (or system-wide), not just for root.

If you genuinely intend to run as root inside a sandbox, the documented escape
hatch is `IS_SANDBOX=1 claude --dangerously-skip-permissions` — but a non-root
user is preferred.

## What gets installed, and where

| Tool | Personas as | Steering | MCP | Hooks |
|------|-------------|----------|-----|-------|
| Claude Code | agents `~/.claude/agents/`, skills `~/.claude/skills/` | `~/.claude/CLAUDE.md` | `claude mcp add-json` → `~/.claude.json` | `~/.claude/settings.json` |
| Codex | prompts `~/.codex/prompts/` | `~/.codex/AGENTS.md` | `codex mcp add` → `~/.codex/config.toml` | `~/.codex/hooks.json` |
| OpenCode | agents `~/.config/opencode/agents/`, skills `…/skills/` | `~/.config/opencode/AGENTS.md` | `mcp` key in `~/.config/opencode/opencode.json` | plugin in `…/plugins/` |
| Pi | Agent Skills `~/.pi/agent/skills/` (`/skill:<name>`) | `~/.pi/agent/AGENTS.md` | none by design | `pi-checks` extension |

**Pi is deliberately different:** it has no MCP — external capabilities come from
CLI tools, Agent Skills and pluggable packages (`pi install <pkg>`, e.g.
`pi-agent-web-access`, `pi-subagents`, `pi-ask-user`).

## Personas

Each persona is one file: `shared/personas/<name>/SKILL.md`. Its frontmatter
(`agent: true`, `model:`, `allowed-tools:`) drives how each installer renders it.
Add or edit a persona once and every tool picks it up on the next install.

**Development:** python-backend, frontend-engineer-ts, dart-app-developer,
cdk-expert-ts, cdk-expert-python, data-scientist ·
**Testing:** test-coordinator, python-test-engineer, typescript-test-engineer ·
**DevOps/Reliability:** devops-engineer, sre-reliability, linux-specialist, code-reviewer ·
**Architecture/Design:** architecture-expert, ui-ux-designer ·
**Security:** security-specialist ·
**Management:** documentation-engineer, product-manager, project-coordinator, engineering-manager ·
**Writing:** writing-blog-posts, writing-documents, writing-style

## MCP servers

Defined once in `shared/mcp-config.json` and registered into each tool's native
config: **filesystem**, **puppeteer**, **playwright**, **context7**, **dart**.
(Pi excluded by design.)

## Hooks

Thin wrappers in `shared/hooks/` source the shared check libraries and run
advisory (never blocking) checks:

- **post-code** (per edit) — fast, file-scoped lint/type-check
- **post-task** (turn end) — full test/security battery, only when code changed
- **pre-deploy** (Claude/Codex) — confirms `cdk diff` before `cdk deploy`/`destroy`

## Testing

`tests/verify_install.sh <tool>` asserts each tool's files landed in the expected
locations and that the CLI reports a configured state (non-auth introspection).
The **Test installers** GitHub Actions workflow runs `shellcheck` and, on Ubuntu,
installs each tool and runs the verifier across a `claudecode/codex/opencode/pi`
matrix.

```bash
./tests/verify_install.sh claudecode
```

## Post-installation

```bash
aws configure                                   # AWS credentials for aws-* MCPs
podman machine init && podman machine start     # containers (macOS)
claude --version && codex --version             # sanity check
```

## Troubleshooting

```bash
# MCPs not loading
claude mcp list                                 # Claude
codex mcp list                                  # Codex
jq .mcp ~/.config/opencode/opencode.json        # OpenCode (mcp key, not mcp.json)

# PATH not updated
source ~/.zshrc   # or ~/.bashrc
```
