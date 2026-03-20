#!/bin/bash
#
# Shared Post-Task Checks Library
#
# Sourced by tool-specific wrappers (ClaudeCode, Kiro, OpenCode).
# NOT directly executable — must be sourced.
#
# Expects caller to set:
#   MAX_TEST_TIME (optional, default 300) — timeout in seconds
#
# Provides:
#   setup_timeout_cmd    — sets TIMEOUT_CMD for macOS/Linux compatibility
#   detect_project_type  — echoes "has_python:has_node:has_cdk:has_flutter"
#   run_post_task_checks — orchestrator that runs all checks (no file filtering)
#
# Results are collected in CRITICAL_ISSUES[] and WARNINGS[] arrays.
# Caller decides how to report/block based on these arrays.
#

# Guard against direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script must be sourced, not executed directly." >&2
    exit 1
fi

# Defaults
MAX_TEST_TIME="${MAX_TEST_TIME:-300}"

# Track issues found
declare -a CRITICAL_ISSUES=()
declare -a WARNINGS=()

add_warning() {
    WARNINGS+=("$1")
}

add_critical_issue() {
    CRITICAL_ISSUES+=("$1")
}

# macOS compatibility: use gtimeout (brew install coreutils) or fall back
setup_timeout_cmd() {
    if command -v gtimeout &> /dev/null; then
        TIMEOUT_CMD="gtimeout"
    elif command -v timeout &> /dev/null; then
        TIMEOUT_CMD="timeout"
    else
        TIMEOUT_CMD=""
    fi
}

# Detect project type
detect_project_type() {
    local has_python=false
    local has_node=false
    local has_cdk=false
    local has_flutter=false

    if [ -f "pyproject.toml" ] || [ -f "requirements.txt" ] || [ -f "setup.py" ]; then
        has_python=true
    fi

    if [ -f "package.json" ]; then
        has_node=true
    fi

    if [ -f "cdk.json" ]; then
        has_cdk=true
    fi

    if [ -f "pubspec.yaml" ]; then
        has_flutter=true
    fi

    echo "${has_python}:${has_node}:${has_cdk}:${has_flutter}"
}

# Find the project's Python/pytest from a virtualenv if present
find_python_pytest() {
    for venv_dir in .venv venv env; do
        if [ -f "$venv_dir/bin/pytest" ]; then
            echo "$venv_dir/bin/pytest"
            return 0
        fi
    done
    if command -v pytest &> /dev/null; then
        echo "pytest"
        return 0
    fi
    echo ""
}

# Run Python tests
run_python_tests() {
    local pytest_bin
    pytest_bin=$(find_python_pytest)

    if [ -z "$pytest_bin" ]; then
        add_warning "pytest not installed - skipping Python tests"
        return 0
    fi

    if [ ! -d "tests" ] && [ ! -d "test" ]; then
        if ! find . -maxdepth 3 -name "test_*.py" -o -name "*_test.py" 2>/dev/null | grep -q .; then
            add_warning "No Python test files found - skipping"
            return 0
        fi
    fi

    local test_output
    local pytest_cmd="${TIMEOUT_CMD:+$TIMEOUT_CMD $MAX_TEST_TIME }$pytest_bin -v --tb=short"
    if test_output=$(eval "$pytest_cmd" 2>&1); then
        add_warning "Python tests: PASSED"
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            add_critical_issue "Python tests: TIMED OUT after ${MAX_TEST_TIME}s"
        else
            add_critical_issue "Python tests: FAILED"
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
    local npm_cmd="${TIMEOUT_CMD:+$TIMEOUT_CMD $MAX_TEST_TIME }npm test"
    if test_output=$(eval "$npm_cmd" 2>&1); then
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

# Run Flutter tests
run_flutter_tests() {
    if ! command -v flutter &> /dev/null; then
        add_warning "flutter not installed - skipping Flutter tests"
        return 0
    fi

    if [ ! -d "test" ]; then
        add_warning "No Flutter test/ directory found - skipping"
        return 0
    fi

    local test_output
    local flutter_cmd="${TIMEOUT_CMD:+$TIMEOUT_CMD $MAX_TEST_TIME }flutter test"
    if test_output=$(eval "$flutter_cmd" 2>&1); then
        add_warning "Flutter tests: PASSED"
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            add_critical_issue "Flutter tests: TIMED OUT after ${MAX_TEST_TIME}s"
        else
            add_critical_issue "Flutter tests: FAILED"
            local tail_output
            tail_output=$(echo "$test_output" | tail -10)
            add_critical_issue "Test output:\n$tail_output"
        fi
        return 1
    fi
}

# Run dart analyze
run_dart_analyze() {
    if ! command -v dart &> /dev/null; then
        add_warning "dart not installed - skipping Dart analysis"
        return 0
    fi

    local analyze_output
    if analyze_output=$(dart analyze . 2>&1); then
        add_warning "Dart analyze: PASSED"
    else
        local issue_count
        issue_count=$(echo "$analyze_output" | grep -cE "^\s*(info|warning|error) " || true)
        if [ "$issue_count" -gt 0 ]; then
            add_critical_issue "Dart analyze: $issue_count issues"
            local tail_output
            tail_output=$(echo "$analyze_output" | head -10)
            add_critical_issue "Dart analyze output:\n$tail_output"
        fi
    fi
}

# Run bandit security scan
run_bandit_scan() {
    if ! command -v bandit &> /dev/null; then
        return 0
    fi

    local -a src_dirs=()
    for dir in src app lib lambda functions; do
        if [ -d "$dir" ] && find "$dir" -maxdepth 3 -name "*.py" -type f 2>/dev/null | grep -q .; then
            src_dirs+=("$dir")
        fi
    done

    if [ ${#src_dirs[@]} -eq 0 ]; then
        if find . -maxdepth 3 -name "*.py" -type f 2>/dev/null | grep -q .; then
            src_dirs=(".")
        else
            return 0
        fi
    fi

    local bandit_output
    bandit_output=$(bandit -r "${src_dirs[@]}" -f txt -ll 2>&1) || true

    if echo "$bandit_output" | grep -qE "Severity: (High|Medium)"; then
        local high_count
        high_count=$(echo "$bandit_output" | grep -c "Severity: High" || true)
        local medium_count
        medium_count=$(echo "$bandit_output" | grep -c "Severity: Medium" || true)

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

# Run ruff linter
run_ruff_check() {
    if ! command -v ruff &> /dev/null; then
        return 0
    fi

    local ruff_output
    if ruff_output=$(ruff check . 2>&1); then
        add_warning "Ruff: PASSED"
    else
        local error_count
        error_count=$(echo "$ruff_output" | grep -cE "^.+:[0-9]+:[0-9]+:" || true)
        if [ "$error_count" -gt 0 ]; then
            add_critical_issue "Ruff: $error_count linting issues"
            local tail_output
            tail_output=$(echo "$ruff_output" | head -10)
            add_critical_issue "Ruff output:\n$tail_output"
        fi
    fi
}

# Run mypy type checker
run_mypy_check() {
    if ! command -v mypy &> /dev/null; then
        return 0
    fi

    local target=""
    for dir in src app lib lambda functions; do
        if [ -d "$dir" ] && find "$dir" -maxdepth 3 -name "*.py" -type f 2>/dev/null | grep -q .; then
            target="$target $dir"
        fi
    done
    if [ -z "$target" ]; then
        return 0
    fi

    local mypy_output
    local mypy_cmd="${TIMEOUT_CMD:+$TIMEOUT_CMD $MAX_TEST_TIME }mypy --no-error-summary $target"
    if mypy_output=$(eval "$mypy_cmd" 2>&1); then
        add_warning "Mypy: PASSED"
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            add_critical_issue "Mypy: TIMED OUT after ${MAX_TEST_TIME}s"
        else
            local error_count
            error_count=$(echo "$mypy_output" | grep -c ": error:" || true)
            if [ "$error_count" -gt 0 ]; then
                add_critical_issue "Mypy: $error_count type errors"
                local tail_output
                tail_output=$(echo "$mypy_output" | grep ": error:" | head -10)
                add_critical_issue "Mypy output:\n$tail_output"
            fi
        fi
    fi
}

# Run ESLint
run_eslint_check() {
    if ! command -v npx &> /dev/null; then
        return 0
    fi

    local eslint_output
    local eslint_cmd="${TIMEOUT_CMD:+$TIMEOUT_CMD 60 }npx eslint --no-warn-on-unmatched-pattern ."
    if eslint_output=$(eval "$eslint_cmd" 2>&1); then
        add_warning "ESLint: PASSED"
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            add_critical_issue "ESLint: TIMED OUT"
        else
            local error_count
            error_count=$(echo "$eslint_output" | grep -cE "^.+:[0-9]+:[0-9]+" || true)
            if [ "$error_count" -gt 0 ]; then
                add_critical_issue "ESLint: $error_count issues"
                local tail_output
                tail_output=$(echo "$eslint_output" | head -10)
                add_critical_issue "ESLint output:\n$tail_output"
            fi
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
        high_count=$(echo "$audit_output" | grep -o '"high":[0-9]*' | cut -d: -f2 || true)
        local critical_count
        critical_count=$(echo "$audit_output" | grep -o '"critical":[0-9]*' | cut -d: -f2 || true)

        if [ "${critical_count:-0}" -gt 0 ] || [ "${high_count:-0}" -gt 0 ]; then
            add_critical_issue "npm audit: critical/high vulnerabilities found in Node.js dependencies"
        fi
    fi
}

# Main orchestrator — runs ALL checks without file filtering
run_post_task_checks() {
    setup_timeout_cmd

    local project_info
    project_info=$(detect_project_type)
    local has_python has_node has_cdk has_flutter
    IFS=':' read -r has_python has_node has_cdk has_flutter <<< "$project_info" || true

    local ran_something=false

    if [ "$has_python" = "true" ]; then
        run_python_tests || true
        run_bandit_scan || true
        run_pip_audit || true
        run_ruff_check || true
        run_mypy_check || true
        ran_something=true
    fi

    if [ "$has_node" = "true" ]; then
        run_node_tests || true
        run_npm_audit || true
        run_eslint_check || true
        ran_something=true
    fi

    if [ "$has_cdk" = "true" ]; then
        run_cdk_tests || true
        ran_something=true
    fi

    if [ "$has_flutter" = "true" ]; then
        run_flutter_tests || true
        run_dart_analyze || true
        ran_something=true
    fi

    # Return 1 if nothing ran (caller can check)
    if [ "$ran_something" = false ]; then
        return 1
    fi

    return 0
}
