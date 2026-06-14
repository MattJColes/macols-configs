#!/usr/bin/env bash
#
# Unified installer for Claude Code — agents, skills, MCPs and hooks.
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
CLAUDE_DIR="$HOME/.claude"
AGENTS_DIR="$CLAUDE_DIR/agents"
SKILLS_DIR="$CLAUDE_DIR/skills"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
# Personas are the single shared source of truth, consumed by every tool's
# installer (ClaudeCode/Codex/OpenCode/Pi) from shared/personas.
PERSONAS_DIR="$SHARED_DIR/personas"
MCP_CONFIG_FILE="$SCRIPT_DIR/mcp-config.json"
HOOK_SCRIPT="$SCRIPT_DIR/hooks/post_code_hook.sh"
TASK_HOOK_SCRIPT="$SCRIPT_DIR/hooks/post_task_hook.sh"
PRE_DEPLOY_HOOK_SCRIPT="$SCRIPT_DIR/hooks/pre_deploy_hook.sh"

# Each persona is a single source file: personas/<name>/SKILL.md. The skill is
# the canonical content. When its frontmatter sets `agent: true`, install.sh
# also generates an agent from the SAME body, swapping the frontmatter
# (allowed-tools -> tools, adding `model:`). This keeps one source of truth and
# stops the skill and agent definitions from drifting apart.
read -r -d '' PERSONA_GEN_JS <<'PERSONA_EOF' || true
const fs = require("fs"), path = require("path");
const mode = process.env.MODE, pdir = process.env.PERSONAS_DIR, tdir = process.env.TARGET_DIR;
const DEFAULT_TOOLS = ["Read", "Write", "Edit", "Bash", "Grep", "Glob"];

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

function emit(obj) {
  let o = "---\n";
  for (const [k, v] of Object.entries(obj)) {
    if (v === undefined || v === null) continue;
    if (Array.isArray(v)) { o += k + ":\n"; for (const i of v) o += "  - " + i + "\n"; }
    else o += k + ": " + v + "\n";
  }
  return o + "---\n";
}

let count = 0;
for (const name of fs.readdirSync(pdir).sort()) {
  const src = path.join(pdir, name, "SKILL.md");
  if (!fs.existsSync(src)) continue;
  const { data, body } = parse(fs.readFileSync(src, "utf8"));
  const pname = data.name || name;
  if (mode === "skill") {
    const fm = { name: pname, description: data.description };
    if (data["allowed-tools"]) fm["allowed-tools"] = data["allowed-tools"];
    if (data["user-invocable"] !== undefined) fm["user-invocable"] = data["user-invocable"];
    const dest = path.join(tdir, name);
    fs.mkdirSync(dest, { recursive: true });
    fs.writeFileSync(path.join(dest, "SKILL.md"), emit(fm) + body);
    console.log("  ✓ " + pname);
    count++;
  } else if (mode === "agent") {
    if (data.agent !== true) continue;
    const tools = (data["allowed-tools"] && data["allowed-tools"].length) ? data["allowed-tools"] : DEFAULT_TOOLS;
    const fm = { name: pname, description: data.description, tools: tools.join(", "), model: data.model || "sonnet" };
    fs.mkdirSync(tdir, { recursive: true });
    fs.writeFileSync(path.join(tdir, pname + ".md"), emit(fm) + body);
    console.log("  ✓ " + pname);
    count++;
  }
}
console.log("__COUNT__" + count);
PERSONA_EOF

# generate_personas <skill|agent> <personas_dir> <target_dir>
# Prints a per-item checklist; sets PERSONA_COUNT to the number generated.
generate_personas() {
    if ! command -v node &> /dev/null; then
        printf "${RED}Node.js required to generate personas${NC}\n"
        return 1
    fi
    out=$(MODE="$1" PERSONAS_DIR="$2" TARGET_DIR="$3" node -e "$PERSONA_GEN_JS")
    PERSONA_COUNT=$(printf "%s" "$out" | sed -n 's/^__COUNT__//p')
    printf "%s\n" "$out" | grep -v '^__COUNT__'
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Installs Claude Code agents, skills, MCP servers and hooks.
Agents and skills are authored together under personas/<name>/
(SKILL.md, optional AGENT.md) and installed to their respective targets.
With no options, all four are installed.

Options:
    -h, --help        Show this help message
    --agents-only     Install only agents (and system CLAUDE.md)
    --skills-only     Install only skills
    --mcps-only       Install only MCP servers
    --hooks-only      Install only post-code/post-task hooks
    -p, --project     Install agents & skills to the current project
                      (./.claude/agents and ./.claude/skills)
    --list            List available personas and exit
EOF
}

list_skills() {
    printf "${BLUE}Available Personas:${NC}\n\n"
    for persona_dir in "$PERSONAS_DIR"/*; do
        [ -d "$persona_dir" ] || continue
        persona_name=$(basename "$persona_dir")
        [ -f "$persona_dir/SKILL.md" ] || continue
        description=$(grep -m1 "^description:" "$persona_dir/SKILL.md" | sed 's/^description: //')
        if grep -q "^agent:[[:space:]]*true" "$persona_dir/SKILL.md"; then marker="${CYAN}+agent${NC}"; else marker="      "; fi
        printf "  ${GREEN}%-25s${NC} %b  %s\n" "$persona_name" "$marker" "$description"
    done
    echo ""
}

install_agents() {
    target_dir="$1"

    if [ ! -d "$PERSONAS_DIR" ]; then
        printf "${RED}Error: personas directory not found at %s${NC}\n" "$PERSONAS_DIR"
        return 1
    fi

    if [ -d "$target_dir" ]; then
        printf "${YELLOW}Clearing existing agents in: %s${NC}\n" "$target_dir"
        rm -rf "$target_dir"
    fi
    mkdir -p "$target_dir"

    printf "${BLUE}Installing agents to: %s${NC}\n" "$target_dir"
    generate_personas agent "$PERSONAS_DIR" "$target_dir" || return 1
    printf "${GREEN}✓ Installed %s agents${NC}\n" "$PERSONA_COUNT"

    # System-level Claude configuration (user scope only)
    if [ "$target_dir" = "$AGENTS_DIR" ] && [ -f "$SCRIPT_DIR/CLAUDE.md" ]; then
        cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
        printf "${GREEN}✓ Copied system CLAUDE.md to %s${NC}\n" "$CLAUDE_DIR/CLAUDE.md"
    fi
}

install_skills() {
    target_dir="$1"

    if [ -d "$target_dir" ]; then
        printf "${YELLOW}Clearing existing skills in: %s${NC}\n" "$target_dir"
        rm -rf "$target_dir"
    fi
    mkdir -p "$target_dir"

    printf "${BLUE}Installing skills to: %s${NC}\n" "$target_dir"
    generate_personas skill "$PERSONAS_DIR" "$target_dir" || return 1
    printf "${GREEN}✓ Installed %s skills${NC}\n" "$PERSONA_COUNT"
}

install_mcps() {
    printf "${BLUE}Registering MCP servers from mcp-config.json...${NC}\n"

    if ! command -v claude &> /dev/null; then
        printf "${RED}claude CLI not found. Install Claude Code first: https://docs.claude.com/claude-code${NC}\n"
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
        server_json=$(jq --arg name "$name" --arg home "$HOME" \
            '.mcpServers[$name] | walk(if type == "string" then gsub("\\$HOME"; $home) else . end)' \
            "$MCP_CONFIG_FILE")
        # Remove any existing server with this name (any scope) so install is idempotent.
        claude mcp remove "$name" >/dev/null 2>&1 || true
        if claude mcp add-json -s user "$name" "$server_json" >/dev/null; then
            printf "  ${GREEN}✓ registered${NC}\n"
        else
            printf "  ${RED}✗ failed to register${NC}\n"
        fi
    done
    printf "${GREEN}✓ MCP servers registered (run 'claude mcp list' to inspect)${NC}\n"
}

install_hooks() {
    printf "${BLUE}Installing post-code/post-task hooks...${NC}\n"

    for f in "$SHARED_DIR/post_code_checks.sh" "$SHARED_DIR/post_task_checks.sh" \
             "$HOOK_SCRIPT" "$TASK_HOOK_SCRIPT" "$PRE_DEPLOY_HOOK_SCRIPT"; do
        if [ ! -f "$f" ]; then
            printf "${RED}Required file not found: %s${NC}\n" "$f"
            return 1
        fi
    done

    chmod +x "$HOOK_SCRIPT" "$TASK_HOOK_SCRIPT" "$PRE_DEPLOY_HOOK_SCRIPT"
    mkdir -p "$CLAUDE_DIR"

    if ! command -v node &> /dev/null; then
        printf "${RED}Node.js required to write hooks configuration${NC}\n"
        return 1
    fi

    SETTINGS_FILE="$SETTINGS_FILE" \
    HOOK_SCRIPT="$HOOK_SCRIPT" \
    TASK_HOOK_SCRIPT="$TASK_HOOK_SCRIPT" \
    PRE_DEPLOY_HOOK_SCRIPT="$PRE_DEPLOY_HOOK_SCRIPT" \
    node -e '
const fs = require("fs");
const env = process.env;
let existing = {};
if (fs.existsSync(env.SETTINGS_FILE)) {
    try { existing = JSON.parse(fs.readFileSync(env.SETTINGS_FILE, "utf8")); } catch(e) {}
}
existing.hooks = {
    PreToolUse: [
        { matcher: "Bash",
          hooks: [{ type: "command", command: env.PRE_DEPLOY_HOOK_SCRIPT }] }
    ],
    PostToolUse: [
        { matcher: "Edit|Write|NotebookEdit",
          hooks: [{ type: "command", command: env.HOOK_SCRIPT }] }
    ],
    Stop: [
        { hooks: [{ type: "command", command: env.TASK_HOOK_SCRIPT }] }
    ]
};

// Hard safety the model cannot talk itself out of: deny reads of AWS
// credentials and scrub secrets from subprocess env. Bypass ("yolo")
// permissions mode is intentionally left available.
existing.permissions = existing.permissions || {};
const deny = new Set(existing.permissions.deny || []);
deny.add("Read(~/.aws/**)");
deny.add("Read(./.aws/**)");
existing.permissions.deny = [...deny];

existing.env = existing.env || {};
existing.env.CLAUDE_CODE_SUBPROCESS_ENV_SCRUB = "1";

// Re-enable bypass mode if a previous strict install disabled it.
delete existing.disableBypassPermissionsMode;

fs.writeFileSync(env.SETTINGS_FILE, JSON.stringify(existing, null, 2) + "\n");
'
    printf "${GREEN}✓ Hooks, permissions and safety settings written to %s${NC}\n" "$SETTINGS_FILE"
}

# Parse arguments
DO_AGENTS=true
DO_SKILLS=true
DO_MCPS=true
DO_HOOKS=true
PROJECT_INSTALL=false
SUBSET=false

set_subset() {
    if [ "$SUBSET" = false ]; then
        DO_AGENTS=false; DO_SKILLS=false; DO_MCPS=false; DO_HOOKS=false
        SUBSET=true
    fi
}

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --list) list_skills; exit 0 ;;
        --agents-only) set_subset; DO_AGENTS=true ;;
        --skills-only) set_subset; DO_SKILLS=true ;;
        --mcps-only)   set_subset; DO_MCPS=true ;;
        --hooks-only)  set_subset; DO_HOOKS=true ;;
        -p|--project)  PROJECT_INSTALL=true ;;
        *) printf "${RED}Unknown option: %s${NC}\n" "$1"; usage; exit 1 ;;
    esac
    shift
done

printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "${CYAN}Claude Code Installer${NC}\n"
printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"

if [ "$DO_AGENTS" = true ]; then
    if [ "$PROJECT_INSTALL" = true ]; then install_agents "./.claude/agents"; else install_agents "$AGENTS_DIR"; fi
    echo ""
fi
if [ "$DO_SKILLS" = true ]; then
    if [ "$PROJECT_INSTALL" = true ]; then install_skills "./.claude/skills"; else install_skills "$SKILLS_DIR"; fi
    echo ""
fi
if [ "$DO_MCPS" = true ]; then install_mcps; echo ""; fi
if [ "$DO_HOOKS" = true ]; then install_hooks; echo ""; fi

printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "${GREEN}Installation complete! 🎉${NC}\n"
printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"
echo "Next steps:"
echo "  • Restart Claude Code to load the new configuration"
echo "  • Agents are invoked automatically or via 'Use the <agent> agent ...'"
echo "  • Skills are available as slash commands (e.g. /python-backend)"
[ "$DO_MCPS" = true ] && echo "  • Configure AWS credentials (~/.aws/credentials) for aws-kb/dynamodb MCPs"
echo ""
