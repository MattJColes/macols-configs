#!/bin/bash
#
# Post-Task Hook for Claude Code
#
# This hook runs when a task is marked as completed to provide comprehensive validation:
# 1. Run ALL project tests (pytest, jest/mocha) without file filtering
# 2. Run comprehensive security scans (bandit for Python)
# 3. Check for package vulnerabilities (pip-audit, npm audit)
#
# EXIT CODES:
# - 0: All checks passed, allow task completion
# - 2: Critical issues found, BLOCK task completion (errors fed back to Claude)
#
# Claude Code passes JSON via stdin with task_id, task_subject, task_description.
# Hook output on stderr is fed back to Claude as feedback.
#
# Install this hook using: ./install_hooks.sh
#

set -euo pipefail

# Read hook input from stdin (required - Claude Code sends JSON)
HOOK_INPUT=$(cat)

# Parse task metadata from the hook input
TASK_SUBJECT=""

if command -v jq &> /dev/null; then
    TASK_SUBJECT=$(echo "$HOOK_INPUT" | jq -r '.task_subject // empty' 2>/dev/null || true)
fi

# Configuration - longer timeout for comprehensive testing
MAX_TEST_TIME="${MAX_TEST_TIME:-300}"  # 5 minutes default for full test suite

# Track issues found
declare -a CRITICAL_ISSUES=()
declare -a WARNINGS=()

add_warning() {
    WARNINGS+=("$1")
}

add_critical_issue() {
    CRITICAL_ISSUES+=("$1")
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
    if ! command -v pytest &> /dev/null; then
        add_warning "pytest not installed - skipping Python tests"
        return 0
    fi

    # Check if tests exist
    if [ ! -d "tests" ] && [ ! -d "test" ]; then
        if ! find . -maxdepth 3 -name "test_*.py" -o -name "*_test.py" 2>/dev/null | grep -q .; then
            add_warning "No Python test files found - skipping"
            return 0
        fi
    fi

    local test_output
    if test_output=$(timeout "$MAX_TEST_TIME" pytest -v --tb=short 2>&1); then
        add_warning "Python tests: PASSED"
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            add_critical_issue "Python tests: TIMED OUT after ${MAX_TEST_TIME}s"
        else
            add_critical_issue "Python tests: FAILED"
            # Include last few lines of output for context
            local tail_output
            tail_output=$(echo "$test_output" | tail -10)
            add_critical_issue "Test output:\n$tail_output"
        fi
        return 1
    fi
}

# Run Node.js tests (Jest or Mocha)
run_node_tests() {
    if [ ! -f "package.json" ]; then
        return 0
    fi

    if ! grep -q '"test"' package.json 2>/dev/null; then
        add_warning "No test script in package.json - skipping"
        return 0
    fi

    local test_output
    if test_output=$(timeout "$MAX_TEST_TIME" npm test 2>&1); then
        add_warning "Node.js tests: PASSED"
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            add_critical_issue "Node.js tests: TIMED OUT after ${MAX_TEST_TIME}s"
        else
            add_critical_issue "Node.js tests: FAILED"
            local tail_output
            tail_output=$(echo "$test_output" | tail -10)
            add_critical_issue "Test output:\n$tail_output"
        fi
        return 1
    fi
}

# Run CDK synth
run_cdk_tests() {
    if [ ! -f "cdk.json" ]; then
        return 0
    fi

    if [ -f "app.py" ]; then
        if cdk synth --quiet 2>&1; then
            add_warning "CDK synth: PASSED"
        else
            add_critical_issue "CDK synth: FAILED"
            return 1
        fi
    elif grep -q "typescript" package.json 2>/dev/null; then
        if npm run build 2>&1 && cdk synth --quiet 2>&1; then
            add_warning "CDK synth: PASSED"
        else
            add_critical_issue "CDK synth: FAILED"
            return 1
        fi
    fi
}

# Run bandit security scan
run_bandit_scan() {
    if ! command -v bandit &> /dev/null; then
        return 0
    fi

    local src_dirs=""
    for dir in src app lib lambda functions .; do
        if [ -d "$dir" ] && find "$dir" -maxdepth 3 -name "*.py" -type f 2>/dev/null | grep -q .; then
            src_dirs="$src_dirs $dir"
        fi
    done

    if [ -z "$src_dirs" ]; then
        return 0
    fi

    local bandit_output
    bandit_output=$(bandit -r $src_dirs -f txt -ll 2>&1) || true

    if echo "$bandit_output" | grep -qE "Severity: (High|Medium)"; then
        local high_count
        high_count=$(echo "$bandit_output" | grep -c "Severity: High" || echo "0")
        local medium_count
        medium_count=$(echo "$bandit_output" | grep -c "Severity: Medium" || echo "0")

        if [ "$high_count" -gt 0 ]; then
            add_critical_issue "Bandit: $high_count HIGH severity security issues found"
        fi
        if [ "$medium_count" -gt 0 ]; then
            add_warning "Bandit: $medium_count MEDIUM severity security issues found"
        fi
    else
        add_warning "Bandit security scan: PASSED"
    fi
}

# Run pip-audit
run_pip_audit() {
    if ! command -v pip-audit &> /dev/null; then
        return 0
    fi

    if [ ! -f "requirements.txt" ] && [ ! -f "pyproject.toml" ]; then
        return 0
    fi

    local audit_output
    if audit_output=$(pip-audit 2>&1); then
        add_warning "pip-audit: no vulnerabilities"
    else
        if echo "$audit_output" | grep -q "found"; then
            add_critical_issue "pip-audit: vulnerabilities found in Python dependencies"
        fi
    fi
}

# Run npm audit
run_npm_audit() {
    if [ ! -f "package.json" ] || [ ! -d "node_modules" ]; then
        return 0
    fi

    local audit_output
    if audit_output=$(npm audit --json 2>&1); then
        add_warning "npm audit: no vulnerabilities"
    else
        local high_count
        high_count=$(echo "$audit_output" | grep -o '"high":[0-9]*' | cut -d: -f2 || echo "0")
        local critical_count
        critical_count=$(echo "$audit_output" | grep -o '"critical":[0-9]*' | cut -d: -f2 || echo "0")

        if [ "${critical_count:-0}" -gt 0 ] || [ "${high_count:-0}" -gt 0 ]; then
            add_critical_issue "npm audit: critical/high vulnerabilities found in Node.js dependencies"
        fi
    fi
}

# Main execution
main() {
    local project_info
    project_info=$(detect_project_type)
    local has_python has_node has_cdk
    IFS=':' read -r has_python has_node has_cdk <<< "$project_info"

    local ran_something=false

    # Run ALL tests without file filtering (comprehensive validation)
    if [ "$has_python" = "true" ]; then
        run_python_tests || true
        run_bandit_scan || true
        run_pip_audit || true
        ran_something=true
    fi

    if [ "$has_node" = "true" ]; then
        run_node_tests || true
        run_npm_audit || true
        ran_something=true
    fi

    if [ "$has_cdk" = "true" ]; then
        run_cdk_tests || true
        ran_something=true
    fi

    # If nothing ran, allow task completion
    if [ "$ran_something" = false ]; then
        exit 0
    fi

    # If critical issues found, BLOCK task completion
    if [ ${#CRITICAL_ISSUES[@]} -gt 0 ]; then
        echo "Task '$TASK_SUBJECT' cannot be completed due to critical issues:" >&2
        for issue in "${CRITICAL_ISSUES[@]}"; do
            echo "  - $issue" >&2
        done
        echo "" >&2
        echo "Please fix these issues before completing the task." >&2
        exit 2  # Exit code 2 blocks task completion
    fi

    # All checks passed, allow task completion
    if [ ${#WARNINGS[@]} -gt 0 ]; then
        echo "Task '$TASK_SUBJECT' validation complete with notes:" >&2
        for warning in "${WARNINGS[@]}"; do
            echo "  - $warning" >&2
        done
    fi

    exit 0
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
