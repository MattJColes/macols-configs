#!/usr/bin/env bash
#
# Unified installer for Kiro CLI — agents, skills, MCPs and hooks.
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
KIRO_DIR="$HOME/.kiro"
AGENTS_DIR="$KIRO_DIR/agents"
SKILLS_DIR="$KIRO_DIR/skills"
SETTINGS_DIR="$KIRO_DIR/settings"
HOOKS_FILE="$SETTINGS_DIR/hooks.json"
HOOK_SCRIPT="$SCRIPT_DIR/hooks/post_code_hook.sh"
TASK_HOOK_SCRIPT="$SCRIPT_DIR/hooks/post_task_hook.sh"

# Each persona is a single source file: personas/<name>/SKILL.md. The skill is
# the canonical content. When its frontmatter sets `agent: true`, install.sh
# also generates a Kiro agent JSON from the SAME source — thin config (tools,
# per-agent MCPs, a brief prompt) plus a `skill://` resource pointing at the
# skill for the real content. This keeps one source of truth so the skill and
# agent definitions never drift. The Kiro agent JSON has no model field, so the
# generator ignores `model` (it is kept in frontmatter for cross-tool parity).
read -r -d '' PERSONA_GEN_JS <<'PERSONA_EOF' || true
const fs = require("fs"), path = require("path");
const mode = process.env.MODE, pdir = process.env.PERSONAS_DIR, tdir = process.env.TARGET_DIR;
const HOME = process.env.HOME_DIR || "";

// MCP server definitions ($HOME left literal; expanded below for agent JSON).
const MCP_SERVERS = {
  filesystem: { command: "npx", args: ["-y", "@modelcontextprotocol/server-filesystem", "$HOME"] },
  memory: { command: "npx", args: ["-y", "@modelcontextprotocol/server-memory"] },
  context7: { command: "npx", args: ["-y", "@upstash/context7-mcp@latest"] },
  "sequential-thinking": { command: "npx", args: ["-y", "@modelcontextprotocol/server-sequential-thinking"] },
  puppeteer: { command: "npx", args: ["-y", "@modelcontextprotocol/server-puppeteer"] },
  playwright: { command: "npx", args: ["-y", "@playwright/mcp"] },
  dynamodb: { command: "uvx", args: ["awslabs.dynamodb-mcp-server@latest"], env: { AWS_REGION: "ap-southeast-2", AWS_PROFILE: "default", "DDB-MCP-READONLY": "false" } },
  "aws-kb": { command: "npx", args: ["-y", "@modelcontextprotocol/server-aws-kb-retrieval"], env: { AWS_PROFILE: "default" } },
  dart: { command: "dart", args: ["mcp-server"] },
};

// Per-agent MCPs beyond the common filesystem + memory.
const AGENT_MCPS = {
  "architecture-expert": ["context7", "sequential-thinking", "aws-kb"],
  "cdk-expert-ts": ["context7", "aws-kb"],
  "cdk-expert-python": ["context7", "aws-kb"],
  "code-reviewer": [],
  "data-scientist": ["context7", "dynamodb", "aws-kb"],
  "dart-app-developer": ["context7", "dart"],
  "devops-engineer": ["context7", "playwright"],
  "documentation-engineer": ["context7"],
  "frontend-engineer-ts": ["context7"],
  "linux-specialist": [],
  "product-manager": [],
  "project-coordinator": [],
  "python-backend": ["context7", "dynamodb", "aws-kb"],
  "python-test-engineer": ["context7", "dynamodb"],
  "security-specialist": ["context7", "sequential-thinking", "aws-kb"],
  "test-coordinator": ["playwright"],
  "typescript-test-engineer": ["context7", "sequential-thinking", "puppeteer", "playwright"],
  "ui-ux-designer": ["context7", "puppeteer"],
  "writing-blog-posts": [],
  "writing-documents": [],
  "writing-style": [],
};

// Brief role summaries for the agent's prompt field; the skill resource carries
// the detailed guidance.
const BRIEF_PROMPTS = {
  "architecture-expert": "You are a pragmatic AWS solutions architect. Follow the detailed guidelines in your skill resource for security, scalability, cost-effectiveness, and caching strategies.",
  "cdk-expert-ts": "You are an AWS CDK expert specializing in TypeScript infrastructure as code. Follow the detailed guidelines in your skill resource.",
  "cdk-expert-python": "You are an AWS CDK expert specializing in Python infrastructure as code. Follow the detailed guidelines in your skill resource.",
  "code-reviewer": "You are a senior engineer reviewing for security, architecture, and unnecessary complexity. Follow the detailed guidelines in your skill resource.",
  "data-scientist": "You are a data scientist and data engineer with deep expertise in AWS data services, big data processing, and machine learning. Follow the detailed guidelines in your skill resource.",
  "dart-app-developer": "You are a Flutter/Dart app developer focused on feature-first architecture, immutable models, Riverpod state, and good Dart practices. Follow the detailed guidelines in your skill resource.",
  "devops-engineer": "You are a DevOps engineer specializing in secure CI/CD pipelines, load testing, and monitoring. Follow the detailed guidelines in your skill resource.",
  "documentation-engineer": "You are a documentation engineer focused on clear, concise, up-to-date documentation. Follow the detailed guidelines in your skill resource.",
  "frontend-engineer-ts": "You are a frontend engineer focused on simple, clean React with TypeScript. Follow the detailed guidelines in your skill resource.",
  "linux-specialist": "You are a Linux SME with deep command line, git, and containerization expertise. Follow the detailed guidelines in your skill resource.",
  "product-manager": "You are a product manager focused on spec-driven development and feature preservation. Follow the detailed guidelines in your skill resource.",
  "project-coordinator": "You are a project coordinator responsible for maintaining project context and orchestrating agent collaboration. Follow the detailed guidelines in your skill resource.",
  "python-backend": "You are a Senior Python 3.12 backend engineer focused on clean, typed, functional code with database expertise. Follow the detailed guidelines in your skill resource.",
  "python-test-engineer": "You are a Python test engineer writing pragmatic pytest tests and enforcing code standards. Follow the detailed guidelines in your skill resource.",
  "security-specialist": "You are a senior application security engineer specializing in secure development, threat modeling, and cloud security hardening. Follow the detailed guidelines in your skill resource.",
  "test-coordinator": "You are a test coordinator enforcing test-driven development and quality standards. Follow the detailed guidelines in your skill resource.",
  "typescript-test-engineer": "You are a TypeScript test engineer for pragmatic testing and code quality. Follow the detailed guidelines in your skill resource.",
  "ui-ux-designer": "You are a UI/UX designer focused on intuitive, beautiful, accessible interfaces. Follow the detailed guidelines in your skill resource.",
  "writing-blog-posts": "You write blog posts for Matt Coles in his voice for coles.codes. Follow the detailed guidelines in your skill resource.",
  "writing-documents": "You write documents, memos, PRFAQs and COEs in the Amazon writing style. Follow the detailed guidelines in your skill resource.",
  "writing-style": "You apply Matt Coles' personal writing style to messages and email. Follow the detailed guidelines in your skill resource.",
};

function parse(text) {
  const m = text.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);
  if (!m) return { data: {}, body: text };
  const data = {};
  for (const line of m[1].split(/\r?\n/)) {
    const kv = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (kv) {
      const k = kv[1], v = kv[2];
      data[k] = v === "true" ? true : v === "false" ? false : v;
    }
  }
  return { data, body: m[2] };
}

function emit(obj) {
  let o = "---\n";
  for (const [k, v] of Object.entries(obj)) {
    if (v === undefined || v === null) continue;
    o += k + ": " + v + "\n";
  }
  return o + "---\n";
}

function expandHome(value) {
  if (typeof value === "string") return value.replace(/\$HOME/g, HOME);
  if (Array.isArray(value)) return value.map(expandHome);
  if (value && typeof value === "object") {
    const out = {};
    for (const [k, v] of Object.entries(value)) out[k] = expandHome(v);
    return out;
  }
  return value;
}

function buildMcpServers(name) {
  const servers = {};
  servers.filesystem = MCP_SERVERS.filesystem;
  servers.memory = MCP_SERVERS.memory;
  for (const m of AGENT_MCPS[name] || []) servers[m] = MCP_SERVERS[m];
  return expandHome(servers);
}

let count = 0;
for (const name of fs.readdirSync(pdir).sort()) {
  const src = path.join(pdir, name, "SKILL.md");
  if (!fs.existsSync(src)) continue;
  const { data, body } = parse(fs.readFileSync(src, "utf8"));
  const pname = data.name || name;
  if (mode === "skill") {
    const fm = { name: pname, description: data.description };
    const dest = path.join(tdir, name);
    fs.mkdirSync(dest, { recursive: true });
    fs.writeFileSync(path.join(dest, "SKILL.md"), emit(fm) + body);
    console.log("  ✓ " + pname);
    count++;
  } else if (mode === "agent") {
    if (data.agent !== true) continue;
    const agent = {
      name: pname,
      description: data.description,
      tools: ["fs_read", "fs_write", "execute_bash"],
      allowedTools: ["fs_read"],
      prompt: BRIEF_PROMPTS[pname] || (body.trim().slice(0, 200)),
      includeMcpJson: false,
      mcpServers: buildMcpServers(pname),
      resources: [
        "file://.kiro/steering/**/*.md",
        "skill://.kiro/skills/" + pname + "/SKILL.md",
      ],
    };
    fs.mkdirSync(tdir, { recursive: true });
    fs.writeFileSync(path.join(tdir, pname + ".json"), JSON.stringify(agent, null, 4) + "\n");
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
    out=$(MODE="$1" PERSONAS_DIR="$2" TARGET_DIR="$3" HOME_DIR="$HOME" node -e "$PERSONA_GEN_JS")
    PERSONA_COUNT=$(printf "%s" "$out" | sed -n 's/^__COUNT__//p')
    printf "%s\n" "$out" | grep -v '^__COUNT__'
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Installs Kiro CLI agents, skills, MCP packages and hooks.
With no options, all four are installed.

Options:
    -h, --help            Show this help message
    --agents-only         Install only agents
    --skills-only         Install only skills
    --mcps-only           Install only MCP server packages
    --hooks-only          Install only post-code/post-task hooks
    --with-global-config  When installing MCPs, also write ~/.kiro/settings/mcp.json
                          (fallback for the kiro_default agent; custom agents use
                          their own per-agent mcpServers config)
    --list                List available skills and exit
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
    if [ ! -d "$SCRIPT_DIR/personas" ]; then
        printf "${RED}Error: personas directory not found at %s${NC}\n" "$SCRIPT_DIR/personas"
        return 1
    fi

    if [ -d "$AGENTS_DIR" ]; then
        printf "${YELLOW}Clearing existing agents in: %s${NC}\n" "$AGENTS_DIR"
        rm -rf "$AGENTS_DIR"
    fi
    mkdir -p "$AGENTS_DIR"

    printf "${BLUE}Installing agents to: %s${NC}\n" "$AGENTS_DIR"
    generate_personas agent "$SCRIPT_DIR/personas" "$AGENTS_DIR" || return 1
    if [ "$PERSONA_COUNT" -eq 0 ]; then
        printf "${RED}Error: no agent-enabled personas found in %s${NC}\n" "$SCRIPT_DIR/personas"
        return 1
    fi
    printf "${GREEN}✓ Installed %s agents${NC}\n" "$PERSONA_COUNT"
}

install_skills() {
    if [ ! -d "$SCRIPT_DIR/personas" ]; then
        printf "${YELLOW}No personas directory found, skipping.${NC}\n"
        return 0
    fi

    if [ -d "$SKILLS_DIR" ]; then
        printf "${YELLOW}Clearing existing skills in: %s${NC}\n" "$SKILLS_DIR"
        rm -rf "$SKILLS_DIR"
    fi
    mkdir -p "$SKILLS_DIR"

    printf "${BLUE}Installing skills to: %s${NC}\n" "$SKILLS_DIR"
    generate_personas skill "$SCRIPT_DIR/personas" "$SKILLS_DIR" || return 1
    printf "${GREEN}✓ Installed %s skills${NC}\n" "$PERSONA_COUNT"
}

install_mcps() {
    printf "${BLUE}Installing MCP server packages...${NC}\n"
    printf "${BLUE}Agents use per-agent MCP configs; this installs the npm/Python packages they launch via npx/uvx.${NC}\n"

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
    printf "${GREEN}✓ MCP server packages installed${NC}\n"

    if [ "$WRITE_GLOBAL_CONFIG" = true ]; then
        mkdir -p "$SETTINGS_DIR"
        KIRO_MCP_CONFIG="$SETTINGS_DIR/mcp.json"
        [ -f "$KIRO_MCP_CONFIG" ] && rm -f "$KIRO_MCP_CONFIG"
        printf "${YELLOW}Writing global MCP fallback config: %s${NC}\n" "$KIRO_MCP_CONFIG"
        cat > "$KIRO_MCP_CONFIG" << EOF
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "$HOME"]
    },
    "memory": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"]
    },
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"]
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
        printf "${GREEN}✓ Global MCP config written${NC}\n"
    fi
}

install_hooks() {
    printf "${BLUE}Installing post-code/post-task hooks...${NC}\n"

    for f in "$SHARED_DIR/post_code_checks.sh" "$SHARED_DIR/post_task_checks.sh" \
             "$HOOK_SCRIPT" "$TASK_HOOK_SCRIPT"; do
        if [ ! -f "$f" ]; then
            printf "${RED}Required file not found: %s${NC}\n" "$f"
            return 1
        fi
    done

    chmod +x "$HOOK_SCRIPT" "$TASK_HOOK_SCRIPT"
    mkdir -p "$SETTINGS_DIR"
    [ -f "$HOOKS_FILE" ] && rm -f "$HOOKS_FILE"

    cat > "$HOOKS_FILE" << EOF
{
  "hooks": {
    "postToolUse": [
      {
        "matcher": "fs_write|write",
        "command": "$HOOK_SCRIPT"
      }
    ],
    "stop": [
      {
        "command": "$TASK_HOOK_SCRIPT"
      }
    ]
  }
}
EOF
    printf "${GREEN}✓ Hooks configuration written to %s${NC}\n" "$HOOKS_FILE"
    printf "${YELLOW}Note:${NC} IDE hooks are configured via the Command Palette (Kiro: Open Hooks Configuration).\n"
}

# Parse arguments
DO_AGENTS=true
DO_SKILLS=true
DO_MCPS=true
DO_HOOKS=true
WRITE_GLOBAL_CONFIG=false
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
        --with-global-config) WRITE_GLOBAL_CONFIG=true ;;
        *) printf "${RED}Unknown option: %s${NC}\n" "$1"; usage; exit 1 ;;
    esac
    shift
done

printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "${CYAN}Kiro CLI Installer${NC}\n"
printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"

if [ "$DO_AGENTS" = true ]; then install_agents; echo ""; fi
if [ "$DO_SKILLS" = true ]; then install_skills; echo ""; fi
if [ "$DO_MCPS" = true ]; then install_mcps; echo ""; fi
if [ "$DO_HOOKS" = true ]; then install_hooks; echo ""; fi

printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "${GREEN}Installation complete! 🎉${NC}\n"
printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"
echo "Next steps:"
echo "  • Restart Kiro CLI to pick up agents, skills and packages"
echo "  • '/agent list' to see agents, '/agent use <name>' to switch"
[ "$DO_MCPS" = true ] && echo "  • Ensure AWS credentials are configured (~/.aws/credentials)"
echo ""
