#!/bin/bash
#
# Shared Post-Code Checks Library
#
# Sourced by tool-specific wrappers (ClaudeCode, OpenCode).
# NOT directly executable — must be sourced.
#
# Expects caller to set:
#   FILE_PATH   (optional) — file that was modified, used to filter checks
#   MAX_TEST_TIME (optional, default 120) — timeout in seconds
#
# Provides:
#   setup_timeout_cmd   — sets TIMEOUT_CMD for macOS/Linux compatibility
#   detect_project_type — echoes "has_python:has_node:has_cdk:has_flutter"
#   run_post_code_checks — fast, file-scoped lint/type-check orchestrator
#
# Per-edit checks are intentionally lightweight: only the linter/type-checker
# for the changed file's language runs here. Tests, security audits and cdk
# synth run once at turn end via the Stop hook (post_task_checks.sh).
#
# Results are collected in ISSUES_FOUND[] and MESSAGES[] arrays.
# Always returns 0 (non-blocking).
#

# Guard against direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script must be sourced, not executed directly." >&2
    exit 1
fi

# Ensure Node.js is in PATH (sources NVM/fnm if needed)
SHARED_DIR_SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ensure_node.sh
if [ -f "$SHARED_DIR_SELF/ensure_node.sh" ]; then
    source "$SHARED_DIR_SELF/ensure_node.sh"
fi

# Defaults
MAX_TEST_TIME="${MAX_TEST_TIME:-120}"
FILE_PATH="${FILE_PATH:-}"

# Track issues found
declare -a ISSUES_FOUND=()
declare -a MESSAGES=()

add_message() {
    MESSAGES+=("$1")
}

add_issue() {
    ISSUES_FOUND+=("$1")
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
        add_message "pytest not installed - skipping Python tests"
        return 0
    fi

    if [ ! -d "tests" ] && [ ! -d "test" ]; then
        if ! find . -maxdepth 3 -name "test_*.py" -o -name "*_test.py" 2>/dev/null | grep -q .; then
            add_message "No Python test files found - skipping"
            return 0
        fi
    fi

    local test_output
    local pytest_cmd="${TIMEOUT_CMD:+$TIMEOUT_CMD $MAX_TEST_TIME }$pytest_bin -v --tb=short"
    if test_output=$(eval "$pytest_cmd" 2>&1); then
        add_message "Python tests: PASSED"
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            add_issue "Python tests: TIMED OUT after ${MAX_TEST_TIME}s"
        else
            add_issue "Python tests: FAILED"
            local tail_output
            tail_output=$(echo "$test_output" | tail -20)
            add_message "$tail_output"
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
        add_message "No test script in package.json - skipping"
        return 0
    fi

    local test_output
    local npm_cmd="${TIMEOUT_CMD:+$TIMEOUT_CMD $MAX_TEST_TIME }npm test"
    if test_output=$(eval "$npm_cmd" 2>&1); then
        add_message "Node.js tests: PASSED"
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            add_issue "Node.js tests: TIMED OUT after ${MAX_TEST_TIME}s"
        else
            add_issue "Node.js tests: FAILED"
            local tail_output
            tail_output=$(echo "$test_output" | tail -20)
            add_message "$tail_output"
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
            add_message "CDK synth: PASSED"
        else
            add_issue "CDK synth: FAILED"
            return 1
        fi
    elif grep -q "typescript" package.json 2>/dev/null; then
        if npm run build 2>&1 && cdk synth --quiet 2>&1; then
            add_message "CDK synth: PASSED"
        else
            add_issue "CDK synth: FAILED"
            return 1
        fi
    fi
}

# Run Flutter tests
run_flutter_tests() {
    if ! command -v flutter &> /dev/null; then
        add_message "flutter not installed - skipping Flutter tests"
        return 0
    fi

    if [ ! -d "test" ]; then
        add_message "No Flutter test/ directory found - skipping"
        return 0
    fi

    local test_output
    local flutter_cmd="${TIMEOUT_CMD:+$TIMEOUT_CMD $MAX_TEST_TIME }flutter test"
    if test_output=$(eval "$flutter_cmd" 2>&1); then
        add_message "Flutter tests: PASSED"
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            add_issue "Flutter tests: TIMED OUT after ${MAX_TEST_TIME}s"
        else
            add_issue "Flutter tests: FAILED"
            local tail_output
            tail_output=$(echo "$test_output" | tail -20)
            add_message "$tail_output"
        fi
        return 1
    fi
}

# Run dart analyze
run_dart_analyze() {
    if ! command -v dart &> /dev/null; then
        add_message "dart not installed - skipping Dart analysis"
        return 0
    fi

    local analyze_output
    if analyze_output=$(dart analyze . 2>&1); then
        add_message "Dart analyze: PASSED"
    else
        local issue_count
        issue_count=$(echo "$analyze_output" | grep -cE "^\s*(info|warning|error) " || true)
        if [ "$issue_count" -gt 0 ]; then
            add_issue "Dart analyze: $issue_count issues"
            local tail_output
            tail_output=$(echo "$analyze_output" | head -10)
            add_message "$tail_output"
        fi
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
        add_message "pip-audit: no vulnerabilities"
    else
        if echo "$audit_output" | grep -q "found"; then
            add_issue "pip-audit: vulnerabilities found"
        fi
    fi
}

# Run ruff linter
run_ruff_check() {
    if ! command -v ruff &> /dev/null; then
        return 0
    fi

    local target="."
    if [ -n "$FILE_PATH" ] && [[ "$FILE_PATH" == *.py ]]; then
        target="$FILE_PATH"
    fi

    local ruff_output
    if ruff_output=$(ruff check "$target" 2>&1); then
        add_message "Ruff: PASSED"
    else
        local error_count
        error_count=$(echo "$ruff_output" | grep -cE "^.+:[0-9]+:[0-9]+:" || true)
        error_count="${error_count:-0}"
        if [ "$error_count" -gt 0 ]; then
            add_issue "Ruff: $error_count linting issues"
            local tail_output
            tail_output=$(echo "$ruff_output" | head -10)
            add_message "$tail_output"
        fi
    fi
}

# Run mypy type checker
run_mypy_check() {
    if ! command -v mypy &> /dev/null; then
        return 0
    fi

    local target
    if [ -n "$FILE_PATH" ] && [[ "$FILE_PATH" == *.py ]]; then
        target="$FILE_PATH"
    else
        target=""
        for dir in src app lib lambda functions; do
            if [ -d "$dir" ] && find "$dir" -maxdepth 3 -name "*.py" -type f 2>/dev/null | grep -q .; then
                target="$target $dir"
            fi
        done
        if [ -z "$target" ]; then
            return 0
        fi
    fi

    local mypy_output
    local mypy_cmd="${TIMEOUT_CMD:+$TIMEOUT_CMD $MAX_TEST_TIME }mypy --no-error-summary $target"
    if mypy_output=$(eval "$mypy_cmd" 2>&1); then
        add_message "Mypy: PASSED"
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            add_issue "Mypy: TIMED OUT after ${MAX_TEST_TIME}s"
        else
            local error_count
            error_count=$(echo "$mypy_output" | grep -c ": error:" || true)
            error_count="${error_count:-0}"
            if [ "$error_count" -gt 0 ]; then
                add_issue "Mypy: $error_count type errors"
                local tail_output
                tail_output=$(echo "$mypy_output" | grep ": error:" | head -10)
                add_message "$tail_output"
            fi
        fi
    fi
}

# Run ESLint
run_eslint_check() {
    if ! command -v npx &> /dev/null; then
        return 0
    fi

    local target
    if [ -n "$FILE_PATH" ] && [[ "$FILE_PATH" == *.ts || "$FILE_PATH" == *.js || "$FILE_PATH" == *.tsx || "$FILE_PATH" == *.jsx ]]; then
        target="$FILE_PATH"
    else
        target="."
    fi

    local eslint_output
    local eslint_cmd="${TIMEOUT_CMD:+$TIMEOUT_CMD 60 }npx eslint --no-warn-on-unmatched-pattern \"$target\""
    if eslint_output=$(eval "$eslint_cmd" 2>&1); then
        add_message "ESLint: PASSED"
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            add_issue "ESLint: TIMED OUT"
        else
            local error_count
            error_count=$(echo "$eslint_output" | grep -cE "^.+:[0-9]+:[0-9]+" || true)
            if [ "$error_count" -gt 0 ]; then
                add_issue "ESLint: $error_count issues"
                local tail_output
                tail_output=$(echo "$eslint_output" | head -10)
                add_message "$tail_output"
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
        add_message "npm audit: no vulnerabilities"
    else
        local high_count critical_count
        if command -v jq &> /dev/null; then
            # Read the authoritative summary counts; tolerate malformed JSON.
            high_count=$(echo "$audit_output" | jq -r '.metadata.vulnerabilities.high // 0' 2>/dev/null || echo 0)
            critical_count=$(echo "$audit_output" | jq -r '.metadata.vulnerabilities.critical // 0' 2>/dev/null || echo 0)
        else
            # Fallback: scan the metadata summary object only, not per-advisory.
            local summary
            summary=$(echo "$audit_output" | grep -o '"vulnerabilities":{[^}]*}' | tail -1 || true)
            high_count=$(echo "$summary" | grep -o '"high":[0-9]*' | cut -d: -f2 || true)
            critical_count=$(echo "$summary" | grep -o '"critical":[0-9]*' | cut -d: -f2 || true)
        fi

        if [ "${critical_count:-0}" -gt 0 ] || [ "${high_count:-0}" -gt 0 ]; then
            add_issue "npm audit: critical/high vulnerabilities found"
        fi
    fi
}

# Main orchestrator — fast, file-scoped lint/type-check only.
#
# The per-edit hook stays lightweight: for the single file that changed it runs
# only the linter / type-checker for that language. The heavy battery (tests,
# security audits, cdk synth) deliberately does NOT run here — it runs once at
# turn end via the Stop hook (post_task_checks.sh), instead of after every edit.
run_post_code_checks() {
    setup_timeout_cmd

    # Nothing to scope to / not a source file we lint — skip.
    case "$FILE_PATH" in
        *.py)
            run_ruff_check || true
            run_mypy_check || true
            ;;
        *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs)
            run_eslint_check || true
            ;;
        *.dart)
            run_dart_analyze || true
            ;;
        *)
            return 0
            ;;
    esac

    # Output results
    if [ ${#ISSUES_FOUND[@]} -gt 0 ]; then
        echo "Hook: Post-code checks found issues:"
        for issue in "${ISSUES_FOUND[@]}"; do
            echo "  - $issue"
        done
    fi

    for msg in "${MESSAGES[@]}"; do
        echo "$msg"
    done

    return 0
}
