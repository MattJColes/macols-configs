#!/usr/bin/env bash
#
# Self-contained installer for the Pi coding agent (@earendil-works/pi-coding-agent).
#
# Ensures the `pi` CLI, then installs Agent Skills, the system AGENTS.md, the
# pi-checks extension and Pi's pluggable packages — all from the single sources
# of truth under shared/.
#
# Pi differs from the other CLIs: skills are invoked as /skill:<name>, hooks are
# TypeScript extensions (not a settings hook array), and there is NO MCP — Pi
# exposes external capabilities through CLI tools, Agent Skills and packages.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

PI_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
SKILLS_DIR="$PI_DIR/skills"
EXTENSIONS_DIR="$PI_DIR/extensions"
AGENTS_FILE="$PI_DIR/AGENTS.md"

# Pi packages (https://pi.dev/packages), installed via `pi install <source>`.
# These are all published on npm, so they need the explicit `npm:` source
# prefix — a bare name (e.g. `pi install pi-btw`) is treated by pi as a local
# filesystem PATH and fails with "Path does not exist".
#   • pi-agent-web-access  — web search, page fetch, YouTube transcripts, GitHub browsing
#   • @mjasnikovs/pi-task  — multi-step task tracking and coordination
#   • context-mode         — context management / session continuity
#   • pi-subagents         — delegate work to specialised subagents (parallel/chain)
#   • pi-ask-user          — interactive ask_user tool (split-pane select, multi-select)
#   • pi-markdown-preview  — preview Markdown/LaTeX/code/diff output in terminal/browser
#   • pi-btw               — /btw side-question command without polluting the conversation
PI_PACKAGES="npm:pi-agent-web-access
npm:@mjasnikovs/pi-task
npm:context-mode
npm:pi-subagents
npm:pi-ask-user
npm:pi-markdown-preview
npm:pi-btw"

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Installs (and, unless told otherwise, the pi CLI itself) Agent Skills, the
system AGENTS.md, the pi-checks extension and Pi packages from shared/.

Options:
    -h, --help        Show this help message
    --skills-only     Install only Agent Skills (/skill:<name>)
    --context-only    Install only the system AGENTS.md
    --hooks-only      Install only the pi-checks extension
    --packages-only   Install only the pi packages
    --mcps-only       (pi has no MCP — prints guidance and exits)
    --no-pi           Skip installing/upgrading the pi binary
    --no-packages     Skip installing pi packages
    -p, --project     Install skills to ./.pi/skills and AGENTS.md to ./AGENTS.md (implies --no-pi)
    --list            List available personas and exit
EOF
}

install_skills() {
    local target="$1"
    [ -d "$PERSONAS_DIR" ] || { printf "${RED}personas dir not found: %s${NC}\n" "$PERSONAS_DIR"; return 1; }
    [ -d "$target" ] && { printf "${YELLOW}Clearing existing skills in: %s${NC}\n" "$target"; rm -rf "$target"; }
    mkdir -p "$target"
    printf "${BLUE}Installing skills to: %s${NC}\n" "$target"
    generate_personas pi skill "$target" || return 1
    printf "${GREEN}✓ Installed %s skills${NC}\n" "$PERSONA_COUNT"
}

install_packages() {
    command -v pi &> /dev/null || { printf "${RED}pi not found — install pi first (drop --no-pi)${NC}\n"; return 1; }
    printf "${BLUE}Installing pi packages...${NC}\n"
    local pkg
    for pkg in $PI_PACKAGES; do
        printf "${BLUE}  → pi install %s${NC}\n" "$pkg"
        if pi install "$pkg"; then printf "${GREEN}  ✓ %s${NC}\n" "$pkg"; else printf "${YELLOW}  ⚠ Failed to install %s (continuing)${NC}\n" "$pkg"; fi
    done
}

print_mcp_guidance() {
    printf "${YELLOW}Pi has no built-in MCP support.${NC}\n"
    cat << EOF
Pi deliberately omits MCP — it exposes capabilities as CLI tools (with READMEs)
and Agent Skills instead. To give pi an external capability, install a CLI tool
and document it, add a skill under $SKILLS_DIR, or install a package via
'pi install <pkg>'. Nothing to register here.
EOF
}

DO_SKILLS=true; DO_CONTEXT=true; DO_HOOKS=true; DO_PI=true; DO_PACKAGES=true
PROJECT_INSTALL=false; SUBSET=false
set_subset() { if [ "$SUBSET" = false ]; then DO_SKILLS=false; DO_CONTEXT=false; DO_HOOKS=false; DO_PI=false; DO_PACKAGES=false; SUBSET=true; fi; }

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --list) list_personas pi; exit 0 ;;
        --skills-only)   set_subset; DO_SKILLS=true ;;
        --context-only)  set_subset; DO_CONTEXT=true ;;
        --hooks-only)    set_subset; DO_HOOKS=true ;;
        --packages-only) set_subset; DO_PACKAGES=true ;;
        --mcps-only)     print_mcp_guidance; exit 0 ;;
        --no-pi)         DO_PI=false ;;
        --no-packages)   DO_PACKAGES=false ;;
        -p|--project)    PROJECT_INSTALL=true; DO_PI=false ;;
        *) printf "${RED}Unknown option: %s${NC}\n" "$1"; usage; exit 1 ;;
    esac
    shift
done

banner "Pi Coding Agent Installer"

if [ "$DO_PI" = true ] && [ "$PROJECT_INSTALL" = false ]; then ensure_cli pi; echo ""; fi
if [ "$DO_PACKAGES" = true ] && [ "$PROJECT_INSTALL" = false ]; then install_packages; echo ""; fi
if [ "$DO_SKILLS" = true ]; then
    if [ "$PROJECT_INSTALL" = true ]; then install_skills "./.pi/skills"; else install_skills "$SKILLS_DIR"; fi; echo ""
fi
if [ "$DO_CONTEXT" = true ]; then
    if [ "$PROJECT_INSTALL" = true ]; then assemble_steering pi "./AGENTS.md"; else assemble_steering pi "$AGENTS_FILE"; fi; echo ""
fi
if [ "$DO_HOOKS" = true ] && [ "$PROJECT_INSTALL" = false ]; then install_pi_extension "$EXTENSIONS_DIR"; echo ""; fi

done_banner
echo "Next steps:"
echo "  • Run 'pi' to start the agent (or '/reload' inside pi to pick up the extension)"
echo "  • Skills are available as /skill:<name> (e.g. /skill:python-backend)"
echo "  • The pi-checks extension runs tests/lint/security advisories after edits and turns"
echo "  • Pi has no MCP — expose external capabilities as CLI tools + skills + packages"
echo ""
