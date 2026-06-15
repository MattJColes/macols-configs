#!/usr/bin/env bash
#
# Unified installer for the Pi coding agent (pi.dev / @earendil-works/pi-coding-agent)
# — skills, context (AGENTS.md), hooks, and pi itself.
#
# Pi's model differs from Claude Code / Codex / OpenCode in two ways:
#   • Skills follow the Agent Skills standard (SKILL.md), invoked as /skill:<name>.
#   • There is no built-in MCP and no settings.json hook array. Hooks are
#     TypeScript extensions; we install a small extension (pi-checks) that shells
#     out to the same shared check scripts the other tools use.
#
# By default installs everything (and pi if missing). Use the flags below to
# install a subset.
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

# Personas are the single shared source of truth (shared/personas), consumed by
# every tool's installer (ClaudeCode/Codex/OpenCode/Pi).
PERSONAS_DIR="$SHARED_DIR/personas"

# Install targets — pi global config dir (overridable via PI_CODING_AGENT_DIR).
PI_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
SKILLS_DIR="$PI_DIR/skills"
EXTENSIONS_DIR="$PI_DIR/extensions"
HOOKS_DIR="$PI_DIR/hooks"
AGENTS_FILE="$PI_DIR/AGENTS.md"
HOOK_SCRIPT="$SCRIPT_DIR/hooks/post_code_hook.sh"
TASK_HOOK_SCRIPT="$SCRIPT_DIR/hooks/post_task_hook.sh"
EXTENSION_SRC="$SCRIPT_DIR/hooks/pi-checks.ts"

# Pi packages (https://pi.dev/packages) installed via `pi install`. These bundle
# extensions/skills that give pi extra capabilities.
#   • pi-agent-web-access  — web search, page fetch, YouTube transcripts, GitHub browsing
#   • @mjasnikovs/pi-task  — multi-step task tracking and coordination
#   • context-mode         — context management / session continuity
#   • pi-subagents         — delegate work to specialised subagents (parallel/chain)
#   • pi-lens              — real-time code feedback (LSP, linters, formatters, types)
#   • @vigolium/piolium    — multi-phase repository security audit agent
#   • pi-simplify          — /simplify reviews changed code for clarity & consistency
#   • gentle-pi            — senior-architect harness (SDD/TDD, subagents, guardrails)
#   • pi-ask-user          — interactive ask_user tool (split-pane select, multi-select)
#   • pi-markdown-preview  — preview Markdown/LaTeX/code/diff output in terminal/browser
#   • pi-btw               — /btw side-question command without polluting the conversation
PI_PACKAGES="pi-agent-web-access
@mjasnikovs/pi-task
context-mode
pi-subagents
pi-lens
@vigolium/piolium
pi-simplify
gentle-pi
pi-ask-user
pi-markdown-preview
pi-btw"

# Each persona is a single source file: shared/personas/<name>/SKILL.md. For Pi
# we emit one Agent Skill per persona — the SAME body, with Agent-Skills
# frontmatter (name, description, optional allowed-tools). One source of truth,
# shared with the Claude Code / Codex / OpenCode installers.
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
for (const name of fs.readdirSync(pdir).sort()) {
  const src = path.join(pdir, name, "SKILL.md");
  if (!fs.existsSync(src)) continue;
  const { data, body } = parse(fs.readFileSync(src, "utf8"));
  const pname = data.name || name;
  let fm = "---\n";
  fm += "name: " + pname + "\n";
  if (data.description) fm += "description: " + data.description + "\n";
  if (data["allowed-tools"] && data["allowed-tools"].length) {
    fm += "allowed-tools:\n";
    for (const t of data["allowed-tools"]) fm += "  - " + t + "\n";
  }
  fm += "---\n";
  const dest = path.join(tdir, name);
  fs.mkdirSync(dest, { recursive: true });
  fs.writeFileSync(path.join(dest, "SKILL.md"), fm + body);
  console.log("  ✓ /skill:" + pname);
  count++;
}
console.log("__COUNT__" + count);
PERSONA_EOF

# generate_skills <personas_dir> <target_dir>
generate_skills() {
    if ! command -v node &> /dev/null; then
        printf "${RED}Node.js required to generate skills${NC}\n"
        return 1
    fi
    out=$(PERSONAS_DIR="$1" TARGET_DIR="$2" node -e "$PERSONA_GEN_JS")
    SKILL_COUNT=$(printf "%s" "$out" | sed -n 's/^__COUNT__//p')
    printf "%s\n" "$out" | grep -v '^__COUNT__'
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Installs Pi coding agent skills, context (AGENTS.md) and check hooks.
Skills are generated from shared/personas/<name>/SKILL.md.
With no options, pi is installed (if missing) and everything is configured.

Options:
    -h, --help        Show this help message
    --skills-only     Install only Agent Skills (/skill:<name>)
    --context-only    Install only the system-level AGENTS.md
    --hooks-only      Install only the pi-checks extension + hook scripts
    --packages-only   Install only the pi packages (pi install <pkg>)
    --mcps-only       (pi has no built-in MCP — prints guidance and exits)
    --no-pi           Skip installing/upgrading the pi binary
    --no-packages     Skip installing pi packages
    -p, --project     Install skills to ./.pi/skills and AGENTS.md to ./AGENTS.md
    --list            List available personas and exit
EOF
}

list_skills() {
    printf "${BLUE}Available Personas (installed as /skill:<name>):${NC}\n\n"
    for persona_dir in "$PERSONAS_DIR"/*; do
        [ -d "$persona_dir" ] || continue
        persona_name=$(basename "$persona_dir")
        [ -f "$persona_dir/SKILL.md" ] || continue
        description=$(grep -m1 "^description:" "$persona_dir/SKILL.md" | sed 's/^description: //')
        printf "  ${GREEN}/skill:%-22s${NC} %s\n" "$persona_name" "$description"
    done
    echo ""
}

install_pi() {
    if command -v pi &> /dev/null; then
        printf "${GREEN}✓ pi already installed: %s${NC}\n" "$(command -v pi)"
        return 0
    fi
    printf "${BLUE}Installing pi coding agent...${NC}\n"
    if command -v npm &> /dev/null; then
        npm install -g --ignore-scripts @earendil-works/pi-coding-agent \
            && printf "${GREEN}✓ pi installed via npm${NC}\n" && return 0
        printf "${YELLOW}npm install failed; falling back to pi.dev install script${NC}\n"
    fi
    if command -v curl &> /dev/null; then
        curl -fsSL https://pi.dev/install.sh | sh \
            && printf "${GREEN}✓ pi installed via pi.dev${NC}\n" && return 0
    fi
    printf "${RED}Could not install pi. Install Node.js/npm or curl, then re-run.${NC}\n"
    return 1
}

install_skills() {
    target_dir="$1"

    if [ ! -d "$PERSONAS_DIR" ]; then
        printf "${RED}Error: personas directory not found at %s${NC}\n" "$PERSONAS_DIR"
        return 1
    fi

    if [ -d "$target_dir" ]; then
        printf "${YELLOW}Clearing existing skills in: %s${NC}\n" "$target_dir"
        rm -rf "$target_dir"
    fi
    mkdir -p "$target_dir"

    printf "${BLUE}Installing skills to: %s${NC}\n" "$target_dir"
    generate_skills "$PERSONAS_DIR" "$target_dir" || return 1
    printf "${GREEN}✓ Installed %s skills${NC}\n" "$SKILL_COUNT"
}

install_context() {
    target_file="$1"

    if [ ! -f "$SCRIPT_DIR/AGENTS.md" ]; then
        printf "${RED}Error: AGENTS.md not found at %s${NC}\n" "$SCRIPT_DIR/AGENTS.md"
        return 1
    fi
    mkdir -p "$(dirname "$target_file")"
    cp "$SCRIPT_DIR/AGENTS.md" "$target_file"
    printf "${GREEN}✓ Wrote system context to %s${NC}\n" "$target_file"
}

install_packages() {
    if ! command -v pi &> /dev/null; then
        printf "${RED}pi not found — install pi first (drop --no-pi) before installing packages${NC}\n"
        return 1
    fi

    printf "${BLUE}Installing pi packages...${NC}\n"
    for pkg in $PI_PACKAGES; do
        printf "${BLUE}  → pi install %s${NC}\n" "$pkg"
        if pi install "$pkg"; then
            printf "${GREEN}  ✓ %s${NC}\n" "$pkg"
        else
            printf "${YELLOW}  ⚠ Failed to install %s (continuing)${NC}\n" "$pkg"
        fi
    done
}

install_mcps() {
    printf "${YELLOW}Pi has no built-in MCP support.${NC}\n"
    cat << EOF
Pi deliberately omits MCP — its philosophy is to expose capabilities as CLI
tools (with READMEs) and Agent Skills instead. To give pi an external
capability, install a CLI tool and document it, or add a skill under
$SKILLS_DIR. Nothing to register here.
EOF
}

install_hooks() {
    printf "${BLUE}Installing pi-checks extension and hook scripts...${NC}\n"

    for f in "$SHARED_DIR/post_code_checks.sh" "$SHARED_DIR/post_task_checks.sh" \
             "$HOOK_SCRIPT" "$TASK_HOOK_SCRIPT" "$EXTENSION_SRC"; do
        if [ ! -f "$f" ]; then
            printf "${RED}Required file not found: %s${NC}\n" "$f"
            return 1
        fi
    done

    chmod +x "$HOOK_SCRIPT" "$TASK_HOOK_SCRIPT"
    mkdir -p "$HOOKS_DIR" "$EXTENSIONS_DIR"

    cp "$HOOK_SCRIPT" "$HOOKS_DIR/post_code_hook.sh"
    cp "$TASK_HOOK_SCRIPT" "$HOOKS_DIR/post_task_hook.sh"
    chmod +x "$HOOKS_DIR/post_code_hook.sh" "$HOOKS_DIR/post_task_hook.sh"

    # Bake the absolute hooks dir into the extension so it can find the scripts
    # regardless of where pi runs from.
    sed "s#__PI_HOOKS_DIR__#$HOOKS_DIR#g" "$EXTENSION_SRC" > "$EXTENSIONS_DIR/pi-checks.ts"

    printf "${GREEN}✓ Extension installed to %s${NC}\n" "$EXTENSIONS_DIR/pi-checks.ts"
    printf "${GREEN}✓ Hook scripts installed to %s${NC}\n" "$HOOKS_DIR"
}

# Parse arguments
DO_SKILLS=true
DO_CONTEXT=true
DO_HOOKS=true
DO_PI=true
DO_PACKAGES=true
PROJECT_INSTALL=false
SUBSET=false

set_subset() {
    if [ "$SUBSET" = false ]; then
        DO_SKILLS=false; DO_CONTEXT=false; DO_HOOKS=false; DO_PI=false; DO_PACKAGES=false
        SUBSET=true
    fi
}

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --list) list_skills; exit 0 ;;
        --skills-only)  set_subset; DO_SKILLS=true ;;
        --context-only) set_subset; DO_CONTEXT=true ;;
        --hooks-only)   set_subset; DO_HOOKS=true ;;
        --packages-only) set_subset; DO_PACKAGES=true ;;
        --mcps-only)    install_mcps; exit 0 ;;
        --no-pi)        DO_PI=false ;;
        --no-packages)  DO_PACKAGES=false ;;
        -p|--project)   PROJECT_INSTALL=true ;;
        *) printf "${RED}Unknown option: %s${NC}\n" "$1"; usage; exit 1 ;;
    esac
    shift
done

printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "${CYAN}Pi Coding Agent Installer${NC}\n"
printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"

# Hooks (extensions) and the project skills dir are only honoured for a trusted
# project; the global install below is the common path.
if [ "$DO_PI" = true ] && [ "$PROJECT_INSTALL" = false ]; then install_pi; echo ""; fi
if [ "$DO_PACKAGES" = true ] && [ "$PROJECT_INSTALL" = false ]; then install_packages; echo ""; fi
if [ "$DO_SKILLS" = true ]; then
    if [ "$PROJECT_INSTALL" = true ]; then install_skills "./.pi/skills"; else install_skills "$SKILLS_DIR"; fi
    echo ""
fi
if [ "$DO_CONTEXT" = true ]; then
    if [ "$PROJECT_INSTALL" = true ]; then install_context "./AGENTS.md"; else install_context "$AGENTS_FILE"; fi
    echo ""
fi
if [ "$DO_HOOKS" = true ] && [ "$PROJECT_INSTALL" = false ]; then install_hooks; echo ""; fi

printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "${GREEN}Installation complete! 🎉${NC}\n"
printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"
echo "Next steps:"
echo "  • Run 'pi' to start the agent (or '/reload' inside pi to pick up the extension)"
echo "  • Skills are available as /skill:<name> (e.g. /skill:python-backend)"
echo "  • The pi-checks extension runs tests/lint/security advisories after edits and turns"
echo "  • pi-agent-web-access adds web search, page fetch, YouTube transcripts and GitHub browsing"
echo "  • Pi has no MCP — expose external capabilities as CLI tools + skills instead"
echo ""
