#!/usr/bin/env bash
#
# Unified installer for OpenCode — agents, skills, MCPs and hooks.
#
# By default installs everything. Use the flags below to install a subset.
# (LM Studio / GLM4.7-Air setup remains in ./configure_lmstudio.sh.)
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

# Each persona is a single source file: personas/<name>/SKILL.md. The skill is
# the canonical content. When its frontmatter sets `agent: true`, install.sh
# also generates an OpenCode agent from the SAME body, swapping in OpenCode
# agent frontmatter (description, provider model, and a tools bool-map). This
# keeps one source of truth and stops the skill and agent from drifting apart.
read -r -d '' PERSONA_GEN_JS <<'PERSONA_EOF' || true
const fs = require("fs"), path = require("path");
const mode = process.env.MODE, pdir = process.env.PERSONAS_DIR, tdir = process.env.TARGET_DIR;
// Map the tool-agnostic model name to OpenCode's provider string.
const MODEL_MAP = { opus: "anthropic/claude-opus-4-6", sonnet: "anthropic/claude-sonnet-4-5" };
// OpenCode skills don't carry an allowed-tools list, so default all six to true.
const AGENT_TOOLS = ["read", "write", "edit", "bash", "grep", "glob"];

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
for (const name of fs.readdirSync(pdir).sort()) {
  const src = path.join(pdir, name, "SKILL.md");
  if (!fs.existsSync(src)) continue;
  const { data, body } = parse(fs.readFileSync(src, "utf8"));
  const pname = data.name || name;
  if (mode === "skill") {
    // Install the skill, stripping the `agent`/`model` keys (keep name, description, compatibility).
    let fm = "---\n";
    if (data.name) fm += "name: " + data.name + "\n";
    if (data.description) fm += "description: " + data.description + "\n";
    if (data.compatibility) fm += "compatibility: " + data.compatibility + "\n";
    fm += "---\n";
    const dest = path.join(tdir, name);
    fs.mkdirSync(dest, { recursive: true });
    fs.writeFileSync(path.join(dest, "SKILL.md"), fm + body);
    console.log("  ✓ " + name);
    count++;
  } else if (mode === "agent") {
    if (data.agent !== true) continue;
    const model = MODEL_MAP[data.model] || MODEL_MAP.sonnet;
    let fm = "---\n";
    fm += "description: " + (data.description || "") + "\n";
    fm += "model: " + model + "\n";
    fm += "tools:\n";
    for (const t of AGENT_TOOLS) fm += "  " + t + ": true\n";
    fm += "---\n";
    fs.mkdirSync(tdir, { recursive: true });
    // OpenCode agent filenames are hyphenated persona names with no `name:` field.
    fs.writeFileSync(path.join(tdir, name + ".md"), fm + body);
    console.log("  ✓ " + name);
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

# Install targets
CONFIG_DIR="$HOME/.config/opencode"
AGENTS_DIR="$CONFIG_DIR/agents"
SKILLS_DIR="$CONFIG_DIR/skills"
PLUGINS_DIR="$CONFIG_DIR/plugins"
MCP_CONFIG="$CONFIG_DIR/mcp.json"
HOOK_SCRIPT="$SCRIPT_DIR/hooks/post_code_hook.sh"
TASK_HOOK_SCRIPT="$SCRIPT_DIR/hooks/post_task_hook.sh"
HOOK_PLUGIN="$SCRIPT_DIR/hooks/post_code_hook_plugin.mjs"

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Installs OpenCode agents, skills, MCP servers and hooks.
Each persona is a single source file under personas/<name>/SKILL.md; agents are
generated from the same body when the frontmatter sets `agent: true`.
With no options, all four are installed.

Options:
    -h, --help        Show this help message
    --agents-only     Install only agents (and system opencode.md)
    --skills-only     Install only skills
    --mcps-only       Install only MCP servers
    --hooks-only      Install only the post-code hook plugin
    -p, --project     Install agents & skills to the current project
                      (./.opencode/agents and ./.opencode/skills)
    --list            List available personas and exit
EOF
}

list_skills() {
    printf "${BLUE}Available Personas:${NC}\n\n"
    for persona_dir in "$SCRIPT_DIR/personas"/*; do
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

    if [ ! -d "$SCRIPT_DIR/personas" ]; then
        printf "${RED}Error: personas directory not found at %s${NC}\n" "$SCRIPT_DIR/personas"
        return 1
    fi

    if [ -d "$target_dir" ]; then
        printf "${YELLOW}Clearing existing agents in: %s${NC}\n" "$target_dir"
        rm -rf "$target_dir"
    fi
    mkdir -p "$target_dir"

    printf "${BLUE}Installing agents to: %s${NC}\n" "$target_dir"
    generate_personas agent "$SCRIPT_DIR/personas" "$target_dir" || return 1
    printf "${GREEN}✓ Installed %s agents${NC}\n" "$PERSONA_COUNT"

    # System-level OpenCode configuration (user scope only)
    if [ "$target_dir" = "$AGENTS_DIR" ]; then
        mkdir -p "$CONFIG_DIR"
        cat > "$CONFIG_DIR/opencode.md" << 'EOF'
# System-Level OpenCode

You are a system-level OpenCode assistant focused on minimal, robust software development.

## Core Principles

### Code Development
- **Minimal Changes**: Make the smallest possible changes to introduce features without affecting unrelated components
- **Type Safety**: Use types when available to catch errors at compile time and improve code clarity
- **Simple Testing**: Write straightforward tests that validate input/output behavior without complex mocking
- **Clear Documentation**: Provide docstrings for public functions, explain non-obvious decisions, and document API usage

### Testing Strategy
- Focus on integration-style tests that verify actual behavior
- Test public interfaces rather than internal implementation details
- Prefer real dependencies over mocks when feasible
- Validate both happy path and edge cases
- Ensure tests are readable and maintainable

### Code Style
- Use descriptive names for functions, variables, and types
- Keep functions small and focused on a single responsibility
- Avoid unnecessary complexity and over-engineering
- Comment only when code intent isn't obvious from the implementation itself

## Development Approach

1. **Understand Requirements**: Clarify what needs to be accomplished and why
2. **Identify Minimal Changes**: Determine the smallest set of modifications needed
3. **Write Types First**: Define interfaces and types to guide implementation
4. **Implement Simply**: Write straightforward code without premature optimization
5. **Test Behavior**: Verify the implementation works as expected with simple tests
6. **Document Decisions**: Explain choices that aren't immediately obvious

## Quality Standards

- Code should be immediately understandable to other developers
- Tests should provide confidence that the code works correctly
- Changes should be reversible and non-disruptive
- Documentation should be sufficient for someone to use and maintain the code
EOF
        printf "${GREEN}✓ Wrote system config: %s${NC}\n" "$CONFIG_DIR/opencode.md"
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
    generate_personas skill "$SCRIPT_DIR/personas" "$target_dir" || return 1
    printf "${GREEN}✓ Installed %s skills${NC}\n" "$PERSONA_COUNT"
}

install_mcps() {
    printf "${BLUE}Installing MCP servers...${NC}\n"

    if ! command -v node &> /dev/null; then
        printf "${YELLOW}Node.js not found. Installing...${NC}\n"
        if [[ "$OSTYPE" == "linux-gnu"* ]] || grep -qi microsoft /proc/version 2>/dev/null; then
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
            sudo apt-get install -y nodejs
        elif [[ "$OSTYPE" == "darwin"* ]] && command -v brew &> /dev/null; then
            brew install node
        else
            printf "${RED}Please install Node.js manually: https://nodejs.org/${NC}\n"
            return 1
        fi
    fi
    printf "${GREEN}✓ Node.js: %s${NC}\n" "$(node --version)"

    if ! command -v npm &> /dev/null; then
        printf "${RED}npm not found. Please install npm.${NC}\n"
        return 1
    fi

    if ! command -v uv &> /dev/null; then
        printf "${YELLOW}uv not found. Installing...${NC}\n"
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    fi
    command -v uv &> /dev/null && printf "${GREEN}✓ uv: %s${NC}\n" "$(uv --version)"

    mkdir -p "$HOME/.mcp/servers"
    for pkg in \
        @modelcontextprotocol/server-filesystem \
        @modelcontextprotocol/server-sequential-thinking \
        @modelcontextprotocol/server-puppeteer \
        @playwright/mcp \
        @modelcontextprotocol/server-memory \
        @modelcontextprotocol/server-aws-kb-retrieval \
        @upstash/context7-mcp; do
        printf "${BLUE}→ %s${NC}\n" "$pkg"
        npm install -g "$pkg" >/dev/null 2>&1 && printf "  ${GREEN}✓${NC}\n" || printf "  ${YELLOW}⚠ (may already be installed)${NC}\n"
    done
    printf "  ${GREEN}✓${NC} dynamodb / mempalace (Python via uvx, on-demand)\n"
    if command -v dart &> /dev/null; then
        printf "  ${GREEN}✓${NC} dart (built into Dart SDK)\n"
    else
        printf "  ${YELLOW}⚠${NC} dart (install Dart 3.9+ for the Flutter/Dart MCP)\n"
    fi

    mkdir -p "$CONFIG_DIR"
    [ -f "$MCP_CONFIG" ] && rm -f "$MCP_CONFIG"
    cat > "$MCP_CONFIG" << EOF
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "$HOME"]
    },
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
    },
    "puppeteer": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-puppeteer"]
    },
    "playwright": {
      "command": "npx",
      "args": ["-y", "@playwright/mcp"]
    },
    "memory": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"]
    },
    "aws-kb": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-aws-kb-retrieval"],
      "env": { "AWS_PROFILE": "default" }
    },
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"]
    },
    "dynamodb": {
      "command": "uvx",
      "args": ["awslabs.dynamodb-mcp-server@latest"],
      "env": {
        "AWS_REGION": "ap-southeast-2",
        "AWS_PROFILE": "default",
        "DDB-MCP-READONLY": "false"
      }
    },
    "dart": {
      "command": "dart",
      "args": ["mcp-server"]
    },
    "mempalace": {
      "command": "uvx",
      "args": ["--from", "mempalace", "mempalace-mcp"]
    }
  }
}
EOF
    printf "${GREEN}✓ MCP configuration written: %s${NC}\n" "$MCP_CONFIG"
}

install_hooks() {
    printf "${BLUE}Installing post-code hook plugin...${NC}\n"

    for f in "$SHARED_DIR/post_code_checks.sh" "$SHARED_DIR/post_task_checks.sh" \
             "$HOOK_SCRIPT" "$TASK_HOOK_SCRIPT" "$HOOK_PLUGIN"; do
        if [ ! -f "$f" ]; then
            printf "${RED}Required file not found: %s${NC}\n" "$f"
            return 1
        fi
    done

    chmod +x "$HOOK_SCRIPT" "$TASK_HOOK_SCRIPT"
    mkdir -p "$PLUGINS_DIR"

    # Clean current + stale plugins for a fresh install
    rm -f "$PLUGINS_DIR/post_code_hook_plugin.mjs" "$PLUGINS_DIR/post_code_hook_env.mjs"

    sed \
        -e "s|__HOOK_SCRIPT_PATH__|${HOOK_SCRIPT}|g" \
        -e "s|__TASK_HOOK_SCRIPT_PATH__|${TASK_HOOK_SCRIPT}|g" \
        "$HOOK_PLUGIN" > "$PLUGINS_DIR/post_code_hook_plugin.mjs"
    printf "${GREEN}✓ Plugin installed to %s${NC}\n" "$PLUGINS_DIR/post_code_hook_plugin.mjs"
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
printf "${CYAN}OpenCode Installer${NC}\n"
printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"

if [ "$DO_AGENTS" = true ]; then
    if [ "$PROJECT_INSTALL" = true ]; then install_agents "./.opencode/agents"; else install_agents "$AGENTS_DIR"; fi
    echo ""
fi
if [ "$DO_SKILLS" = true ]; then
    if [ "$PROJECT_INSTALL" = true ]; then install_skills "./.opencode/skills"; else install_skills "$SKILLS_DIR"; fi
    echo ""
fi
if [ "$DO_MCPS" = true ]; then install_mcps; echo ""; fi
if [ "$DO_HOOKS" = true ]; then install_hooks; echo ""; fi

printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "${GREEN}Installation complete! 🎉${NC}\n"
printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"
echo "Next steps:"
echo "  • Restart OpenCode to load agents, skills, MCPs and hooks"
echo "  • Skills load on-demand via the skill tool; agents via the Task tool"
[ "$DO_MCPS" = true ] && echo "  • Ensure AWS credentials are configured (~/.aws/credentials)"
echo "  • Run ./configure_lmstudio.sh to set up local GLM4.7-Air via LM Studio"
echo ""
