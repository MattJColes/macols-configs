#!/bin/bash
#
# Post-Code Hook for Claude Code and Kiro CLI
#
# This hook runs automatically after coding tasks complete to:
# 1. Run project tests (pytest, jest, mocha)
# 2. Run security scans (bandit for Python)
# 3. Check for package vulnerabilities (pip-audit, npm audit)
# 4. Provide security findings summary
#
# Install this hook using: ./install_hooks.sh
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
REPORT_FILE="${REPORT_FILE:-/tmp/code_review_report.md}"
MAX_TEST_TIME="${MAX_TEST_TIME:-300}"  # 5 minutes default

# Track overall status
OVERALL_STATUS=0
declare -a ISSUES_FOUND=()

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ISSUES_FOUND+=("$1")
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ISSUES_FOUND+=("$1")
    OVERALL_STATUS=1
}

log_section() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Detect project type
detect_project_type() {
    local has_python=false
    local has_node=false
    local has_cdk=false

    if [ -f "pyproject.toml" ] || [ -f "requirements.txt" ] || [ -f "setup.py" ]; then
        has_python=true
    fi

    if [ -f "package.json" ]; then
        has_node=true
    fi

    if [ -f "cdk.json" ]; then
        has_cdk=true
    fi

    echo "${has_python}:${has_node}:${has_cdk}"
}

# Run Python tests
run_python_tests() {
    log_section "Python Tests (pytest)"

    if ! command -v pytest &> /dev/null; then
        log_warning "pytest not installed - skipping Python tests"
        return 0
    fi

    # Check if tests directory exists
    if [ ! -d "tests" ] && [ ! -d "test" ]; then
        # Try to find any test files
        if ! find . -name "test_*.py" -o -name "*_test.py" 2>/dev/null | grep -q .; then
            log_info "No Python test files found - skipping"
            return 0
        fi
    fi

    log_info "Running pytest..."
    if timeout "$MAX_TEST_TIME" pytest -v --tb=short 2>&1; then
        log_success "All Python tests passed"
    else
        log_error "Python tests failed"
        return 1
    fi
}

# Run Node.js tests (Jest or Mocha)
run_node_tests() {
    log_section "JavaScript/TypeScript Tests"

    if [ ! -f "package.json" ]; then
        log_info "No package.json found - skipping Node.js tests"
        return 0
    fi

    # Check for test script in package.json
    if ! grep -q '"test"' package.json; then
        log_info "No test script in package.json - skipping"
        return 0
    fi

    log_info "Running npm test..."
    if timeout "$MAX_TEST_TIME" npm test 2>&1; then
        log_success "All Node.js tests passed"
    else
        log_error "Node.js tests failed"
        return 1
    fi
}

# Run CDK tests and synth
run_cdk_tests() {
    log_section "CDK Infrastructure Tests"

    if [ ! -f "cdk.json" ]; then
        log_info "No cdk.json found - skipping CDK tests"
        return 0
    fi

    # Determine if Python or TypeScript CDK
    if [ -f "app.py" ]; then
        log_info "Running Python CDK synth..."
        if cdk synth --quiet 2>&1; then
            log_success "CDK synthesis successful"
        else
            log_error "CDK synthesis failed"
            return 1
        fi
    elif [ -f "bin" ] || grep -q "typescript" package.json 2>/dev/null; then
        log_info "Running TypeScript CDK synth..."
        if npm run build 2>&1 && cdk synth --quiet 2>&1; then
            log_success "CDK synthesis successful"
        else
            log_error "CDK synthesis failed"
            return 1
        fi
    fi
}

# Run Python security scan with bandit
run_bandit_scan() {
    log_section "Python Security Scan (Bandit)"

    if ! command -v bandit &> /dev/null; then
        log_warning "bandit not installed - install with: pip install bandit"
        return 0
    fi

    # Find Python source directories
    local src_dirs=""
    for dir in src app lib lambda functions .; do
        if [ -d "$dir" ] && find "$dir" -name "*.py" -type f 2>/dev/null | grep -q .; then
            src_dirs="$src_dirs $dir"
        fi
    done

    if [ -z "$src_dirs" ]; then
        log_info "No Python source files found - skipping"
        return 0
    fi

    log_info "Running bandit security scan..."
    local bandit_output
    bandit_output=$(bandit -r $src_dirs -f txt -ll 2>&1) || true

    # Check for high/critical issues
    if echo "$bandit_output" | grep -qE "Severity: (High|Medium)"; then
        log_warning "Security issues found in Python code:"
        echo "$bandit_output" | grep -E "(>>|Severity:|Confidence:|Location:|Issue:)" | head -50

        # Count issues
        local high_count
        high_count=$(echo "$bandit_output" | grep -c "Severity: High" || echo "0")
        local medium_count
        medium_count=$(echo "$bandit_output" | grep -c "Severity: Medium" || echo "0")

        if [ "$high_count" -gt 0 ]; then
            log_error "Found $high_count HIGH severity security issues"
        fi
        if [ "$medium_count" -gt 0 ]; then
            log_warning "Found $medium_count MEDIUM severity security issues"
        fi
    else
        log_success "No high/medium security issues found"
    fi
}

# Run Python package vulnerability check
run_pip_audit() {
    log_section "Python Package Vulnerabilities (pip-audit)"

    if ! command -v pip-audit &> /dev/null; then
        log_warning "pip-audit not installed - install with: pip install pip-audit"
        return 0
    fi

    if [ ! -f "requirements.txt" ] && [ ! -f "pyproject.toml" ]; then
        log_info "No requirements.txt or pyproject.toml found - skipping"
        return 0
    fi

    log_info "Checking Python packages for vulnerabilities..."
    local audit_output
    if audit_output=$(pip-audit 2>&1); then
        log_success "No known vulnerabilities in Python packages"
    else
        if echo "$audit_output" | grep -q "found"; then
            log_error "Vulnerabilities found in Python packages:"
            echo "$audit_output" | head -30
        else
            log_warning "pip-audit encountered an issue: $audit_output"
        fi
    fi
}

# Run npm audit for Node.js packages
run_npm_audit() {
    log_section "Node.js Package Vulnerabilities (npm audit)"

    if [ ! -f "package.json" ]; then
        log_info "No package.json found - skipping"
        return 0
    fi

    if [ ! -d "node_modules" ]; then
        log_info "node_modules not found - run npm install first"
        return 0
    fi

    log_info "Checking npm packages for vulnerabilities..."
    local audit_output
    if audit_output=$(npm audit --json 2>&1); then
        log_success "No known vulnerabilities in npm packages"
    else
        # Parse JSON output for summary
        local high_count
        high_count=$(echo "$audit_output" | grep -o '"high":[0-9]*' | cut -d: -f2 || echo "0")
        local critical_count
        critical_count=$(echo "$audit_output" | grep -o '"critical":[0-9]*' | cut -d: -f2 || echo "0")

        if [ "${critical_count:-0}" -gt 0 ] || [ "${high_count:-0}" -gt 0 ]; then
            log_error "Found critical/high vulnerabilities:"
            npm audit --omit=dev 2>&1 | head -40
        else
            log_warning "Some vulnerabilities found (run 'npm audit' for details)"
        fi
    fi
}

# Generate summary report
generate_report() {
    log_section "Summary Report"

    local report_content="# Code Review Report

Generated: $(date)
Project: $(pwd)

## Status: $([ $OVERALL_STATUS -eq 0 ] && echo 'PASSED' || echo 'ISSUES FOUND')

"

    if [ ${#ISSUES_FOUND[@]} -gt 0 ]; then
        report_content+="## Issues Found

"
        for issue in "${ISSUES_FOUND[@]}"; do
            report_content+="- $issue
"
        done
        report_content+="
"
    fi

    report_content+="## Checks Performed

- Python tests (pytest)
- Node.js tests (jest/mocha)
- CDK synthesis
- Python security scan (bandit)
- Python package vulnerabilities (pip-audit)
- Node.js package vulnerabilities (npm audit)

## Recommendations

1. Fix any failing tests before committing
2. Address HIGH severity security issues immediately
3. Update vulnerable packages when possible
4. Review MEDIUM severity issues for false positives
"

    echo "$report_content" > "$REPORT_FILE"

    if [ $OVERALL_STATUS -eq 0 ]; then
        log_success "All checks passed!"
    else
        echo ""
        log_error "Issues found - see summary above"
        echo ""
        echo -e "${YELLOW}Full report saved to: $REPORT_FILE${NC}"
    fi
}

# Main execution
main() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           Post-Code Hook: Testing & Security               ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local project_info
    project_info=$(detect_project_type)
    local has_python has_node has_cdk
    IFS=':' read -r has_python has_node has_cdk <<< "$project_info"

    log_info "Detected project type: Python=$has_python, Node=$has_node, CDK=$has_cdk"

    # Run tests
    if [ "$has_python" = "true" ]; then
        run_python_tests || true
        run_bandit_scan || true
        run_pip_audit || true
    fi

    if [ "$has_node" = "true" ]; then
        run_node_tests || true
        run_npm_audit || true
    fi

    if [ "$has_cdk" = "true" ]; then
        run_cdk_tests || true
    fi

    # Generate report
    generate_report

    exit $OVERALL_STATUS
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
