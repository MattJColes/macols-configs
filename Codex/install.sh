#!/usr/bin/env bash
#
# Unified installer for Codex CLI — prompts, system instructions, MCPs and hooks.
#
# Codex's analog of Claude Code's agents/skills is custom prompts (slash
# commands) under ~/.codex/prompts. This installer generates one prompt per
# persona, writes the system-level AGENTS.md, registers MCP servers via the
# `codex mcp` CLI, and wires lifecycle hooks into ~/.codex/hooks.json.
#
# By default installs everything. Use the flags below to install a subset.
#
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SHARED_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/shared"

# Ensure Node.js is in PATH (sources NVM/fnm if needed)
# shellcheck source=../shared/ensure_node.sh
if [ -f "$SHARED_DIR/ensure_node.sh" ]; then
    # shellcheck disable=SC1091
    source "$SHARED_DIR/ensure_node.sh"
fi

# Install targets
CODEX_DIR="$HOME/.codex"
PROMPTS_DIR="$CODEX_DIR/prompts"
AGENTS_FILE="$CODEX_DIR/AGENTS.md"
HOOKS_JSON="$CODEX_DIR/hooks.json"
# Personas are the single shared source of truth (shared/personas), consumed by
# every tool's installer (ClaudeCode/Codex/OpenCode/Pi).
PERSONAS_DIR="$SHARED_DIR/personas"
MCP_CONFIG_FILE="$SCRIPT_DIR/mcp-config.json"
HOOK_SCRIPT="$SCRIPT_DIR/hooks/post_code_hook.sh"
TASK_HOOK_SCRIPT="$SCRIPT_DIR/hooks/post_task_hook.sh"
PRE_DEPLOY_HOOK_SCRIPT="$SCRIPT_DIR/hooks/pre_deploy_hook.sh"

# Each persona is a single source file: personas/<name>/SKILL.md. For Codex we
# emit one custom prompt per persona — the SAME body, with Codex prompt
# frontmatter (description + argument-hint) swapped in for the skill frontmatter.
# One source of truth, shared with the Claude Code / OpenCode installers.
read -r -d '' PERSONA_GEN_JS <<'PERSONA_EOF' || true
const fs = require("fs"), path = require("path");
const pdir = process.env.PERSONAS_DIR, tdir = process.env.TARGET_DIR;

function parse(text) {
  const m = text.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);
  if (!m) return { data: {}, body: text };
  const data = {}; let cur = null;
  for (const line of m[1].split(/\r?\n/)) {
    const li = line.match(/^\s*-\s+(.*)$/);
    if (li && cur) { (data[cur] = data[cur] || []).push(li[1].trim()); continue; }
    const kv = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (kv) {
      const k = kv[1], v = kv[2];
      if (v === "") { data[k] = []; cur = k; }
      else { data[k] = v === "true" ? true : v === "false" ? false : v; cur = null; }
    }
  }
  return { data, body: m[2] };
}

let count = 0;
fs.mkdirSync(tdir, { recursive: true });
for (const name of fs.readdirSync(pdir).sort()) {
  const src = path.join(pdir, name, "SKILL.md");
  if (!fs.existsSync(src)) continue;
  const { data, body } = parse(fs.readFileSync(src, "utf8"));
  let fm = "---\n";
  if (data.description) fm += "description: " + data.description + "\n";
  fm += "argument-hint: \"[task or context]\"\n";
  fm += "---\n";
  // The persona body trails any extra args the user passes when invoking /<name>.
  fs.writeFileSync(path.join(tdir, name + ".md"), fm + body);
  console.log("  ✓ /" + name);
  count++;
}
console.log("__COUNT__" + count);
PERSONA_EOF

# generate_prompts <personas_dir> <target_dir>
# Prints a per-item checklist; sets PROMPT_COUNT to the number generated.
generate_prompts() {
    if ! command -v node &> /dev/null; then
        printf "${RED}Node.js required to generate prompts${NC}\n"
        return 1
    fi
    out=$(PERSONAS_DIR="$1" TARGET_DIR="$2" node -e "$PERSONA_GEN_JS")
    PROMPT_COUNT=$(printf "%s" "$out" | sed -n 's/^__COUNT__//p')
    printf "%s\n" "$out" | grep -v '^__COUNT__'
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Installs Codex CLI custom prompts, system instructions (AGENTS.md), MCP
servers and lifecycle hooks. Prompts are generated from personas/<name>/SKILL.md.
With no options, all four are installed.

Options:
    -h, --help          Show this help message
    --prompts-only      Install only custom prompts (slash commands)
    --instructions-only Install only the system-level AGENTS.md
    --mcps-only         Install only MCP servers
    --hooks-only        Install only lifecycle hooks
    -p, --project       Install prompts to ./.codex/prompts and AGENTS.md to ./AGENTS.md
    --list              List available personas and exit
EOF
}

list_personas() {
    printf "${BLUE}Available Personas (installed as /<name> prompts):${NC}\n\n"
    for persona_dir in "$PERSONAS_DIR"/*; do
        [ -d "$persona_dir" ] || continue
        persona_name=$(basename "$persona_dir")
        [ -f "$persona_dir/SKILL.md" ] || continue
        description=$(grep -m1 "^description:" "$persona_dir/SKILL.md" | sed 's/^description: //')
        printf "  ${GREEN}/%-24s${NC} %s\n" "$persona_name" "$description"
    done
    echo ""
}

install_prompts() {
    target_dir="$1"

    if [ ! -d "$PERSONAS_DIR" ]; then
        printf "${RED}Error: personas directory not found at %s${NC}\n" "$PERSONAS_DIR"
        return 1
    fi

    if [ -d "$target_dir" ]; then
        printf "${YELLOW}Clearing existing prompts in: %s${NC}\n" "$target_dir"
        rm -rf "$target_dir"
    fi
    mkdir -p "$target_dir"

    printf "${BLUE}Installing prompts to: %s${NC}\n" "$target_dir"
    generate_prompts "$PERSONAS_DIR" "$target_dir" || return 1
    printf "${GREEN}✓ Installed %s prompts${NC}\n" "$PROMPT_COUNT"
}

install_instructions() {
    target_file="$1"

    if [ ! -f "$SCRIPT_DIR/AGENTS.md" ]; then
        printf "${RED}Error: AGENTS.md not found at %s${NC}\n" "$SCRIPT_DIR/AGENTS.md"
        return 1
    fi
    mkdir -p "$(dirname "$target_file")"
    cp "$SCRIPT_DIR/AGENTS.md" "$target_file"
    printf "${GREEN}✓ Wrote system instructions to %s${NC}\n" "$target_file"
}

install_mcps() {
    printf "${BLUE}Registering MCP servers from mcp-config.json...${NC}\n"

    if ! command -v codex &> /dev/null; then
        printf "${RED}codex CLI not found. Install Codex first: brew install --cask codex (macOS) or npm i -g @openai/codex${NC}\n"
        return 1
    fi
    if ! command -v jq &> /dev/null; then
        printf "${YELLOW}jq not found. Installing...${NC}\n"
        if [[ "$OSTYPE" == "darwin"* ]] && command -v brew &> /dev/null; then
            brew install jq
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sudo apt-get install -y jq
        else
            printf "${RED}Please install jq manually: https://stedolan.github.io/jq/${NC}\n"
            return 1
        fi
    fi
    if ! command -v uv &> /dev/null; then
        printf "${YELLOW}uv not found. Installing (needed for uvx-based MCPs)...${NC}\n"
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    fi
    if [ ! -f "$MCP_CONFIG_FILE" ]; then
        printf "${RED}MCP config file not found: %s${NC}\n" "$MCP_CONFIG_FILE"
        return 1
    fi

    for name in $(jq -r '.mcpServers | keys[]' "$MCP_CONFIG_FILE"); do
        printf "${BLUE}→ %s${NC}\n" "$name"

        # Build env flags (--env KEY=VALUE), expanding $HOME.
        env_flags=()
        while IFS= read -r kv; do
            [ -z "$kv" ] && continue
            env_flags+=(--env "$kv")
        done < <(jq -r --arg home "$HOME" \
            '.mcpServers[$name].env // {} | to_entries[] | "\(.key)=\(.value | gsub("\\$HOME"; $home))"' \
            --arg name "$name" "$MCP_CONFIG_FILE")

        command_bin=$(jq -r --arg name "$name" '.mcpServers[$name].command' "$MCP_CONFIG_FILE")

        args=()
        while IFS= read -r a; do
            args+=("$a")
        done < <(jq -r --arg home "$HOME" --arg name "$name" \
            '.mcpServers[$name].args // [] | .[] | gsub("\\$HOME"; $home)' \
            "$MCP_CONFIG_FILE")

        # Remove any existing server with this name so install is idempotent.
        codex mcp remove "$name" >/dev/null 2>&1 || true
        if codex mcp add "$name" "${env_flags[@]}" -- "$command_bin" "${args[@]}" >/dev/null 2>&1; then
            printf "  ${GREEN}✓ registered${NC}\n"
        else
            printf "  ${RED}✗ failed to register${NC}\n"
        fi
    done
    printf "${GREEN}✓ MCP servers registered (run 'codex mcp list' to inspect)${NC}\n"
}

install_hooks() {
    printf "${BLUE}Installing lifecycle hooks...${NC}\n"

    for f in "$SHARED_DIR/post_code_checks.sh" "$SHARED_DIR/post_task_checks.sh" \
             "$HOOK_SCRIPT" "$TASK_HOOK_SCRIPT" "$PRE_DEPLOY_HOOK_SCRIPT"; do
        if [ ! -f "$f" ]; then
            printf "${RED}Required file not found: %s${NC}\n" "$f"
            return 1
        fi
    done

    chmod +x "$HOOK_SCRIPT" "$TASK_HOOK_SCRIPT" "$PRE_DEPLOY_HOOK_SCRIPT"
    mkdir -p "$CODEX_DIR"

    if ! command -v node &> /dev/null; then
        printf "${RED}Node.js required to write hooks configuration${NC}\n"
        return 1
    fi

    # Codex loads ~/.codex/hooks.json. Matchers use Claude-Code-compatible tool
    # names (Bash, Edit, Write); adjust them in hooks.json if a future Codex
    # release renames its internal tools.
    HOOKS_JSON="$HOOKS_JSON" \
    HOOK_SCRIPT="$HOOK_SCRIPT" \
    TASK_HOOK_SCRIPT="$TASK_HOOK_SCRIPT" \
    PRE_DEPLOY_HOOK_SCRIPT="$PRE_DEPLOY_HOOK_SCRIPT" \
    node -e '
const fs = require("fs");
const env = process.env;
const config = {
    PreToolUse: [
        { matcher: "Bash",
          hooks: [{ type: "command", command: env.PRE_DEPLOY_HOOK_SCRIPT, timeout: 30 }] }
    ],
    PostToolUse: [
        { matcher: "Edit|Write|NotebookEdit",
          hooks: [{ type: "command", command: env.HOOK_SCRIPT, timeout: 120 }] }
    ],
    Stop: [
        { hooks: [{ type: "command", command: env.TASK_HOOK_SCRIPT, timeout: 300 }] }
    ]
};
fs.writeFileSync(env.HOOKS_JSON, JSON.stringify(config, null, 2) + "\n");
'
    printf "${GREEN}✓ Hooks written to %s${NC}\n" "$HOOKS_JSON"
}

# Parse arguments
DO_PROMPTS=true
DO_INSTRUCTIONS=true
DO_MCPS=true
DO_HOOKS=true
PROJECT_INSTALL=false
SUBSET=false

set_subset() {
    if [ "$SUBSET" = false ]; then
        DO_PROMPTS=false; DO_INSTRUCTIONS=false; DO_MCPS=false; DO_HOOKS=false
        SUBSET=true
    fi
}

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --list) list_personas; exit 0 ;;
        --prompts-only)      set_subset; DO_PROMPTS=true ;;
        --instructions-only) set_subset; DO_INSTRUCTIONS=true ;;
        --mcps-only)         set_subset; DO_MCPS=true ;;
        --hooks-only)        set_subset; DO_HOOKS=true ;;
        -p|--project)        PROJECT_INSTALL=true ;;
        *) printf "${RED}Unknown option: %s${NC}\n" "$1"; usage; exit 1 ;;
    esac
    shift
done

printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "${CYAN}Codex CLI Installer${NC}\n"
printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"

if [ "$DO_PROMPTS" = true ]; then
    if [ "$PROJECT_INSTALL" = true ]; then install_prompts "./.codex/prompts"; else install_prompts "$PROMPTS_DIR"; fi
    echo ""
fi
if [ "$DO_INSTRUCTIONS" = true ]; then
    if [ "$PROJECT_INSTALL" = true ]; then install_instructions "./AGENTS.md"; else install_instructions "$AGENTS_FILE"; fi
    echo ""
fi
if [ "$DO_MCPS" = true ]; then install_mcps; echo ""; fi
if [ "$DO_HOOKS" = true ]; then install_hooks; echo ""; fi

printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "${GREEN}Installation complete! 🎉${NC}\n"
printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"
echo "Next steps:"
echo "  • Restart Codex to load the new configuration"
echo "  • Prompts are available as slash commands (e.g. /python-backend, /code-reviewer)"
echo "  • Run 'codex mcp list' to inspect registered MCP servers"
[ "$DO_MCPS" = true ] && echo "  • Configure AWS credentials (~/.aws/credentials) for the aws-* MCPs"
echo ""
