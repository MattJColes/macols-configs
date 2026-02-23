#!/bin/bash
#
# Post-Code Hook for OpenCode
#
# This hook runs automatically after file write/edit tool calls to:
# 1. Run project tests (pytest, jest, mocha, flutter test)
# 2. Run linters (ruff for Python, eslint for JS/TS, dart analyze for Dart)
# 3. Run type checking (mypy for Python)
# 4. Run security scans (bandit for Python)
# 5. Check for package vulnerabilities (pip-audit, npm audit)
#
# Called by the OpenCode plugin (post_code_hook_plugin.mjs).
# Stdin may or may not contain data depending on the caller.
#
# Install this hook using: ./install_hooks.sh
#

set -euo pipefail

# Drain stdin safely (some callers pipe data, some don't)
HOOK_INPUT=""
if [ ! -t 0 ]; then
    HOOK_INPUT=$(timeout 1 cat 2>/dev/null || true)
fi

# Try to parse file path from stdin if JSON was provided
FILE_PATH=""
if [ -n "$HOOK_INPUT" ] && command -v jq &> /dev/null; then
    FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
fi

# Skip non-source files to avoid unnecessary test runs
if [ -n "$FILE_PATH" ]; then
    case "$FILE_PATH" in
        *.py|*.ts|*.js|*.jsx|*.tsx|*.mjs|*.cjs|*.dart)
            # Testable source file - continue
            ;;
        *)
            # Not a source file (markdown, json, config, etc.) - skip
            exit 0
            ;;
    esac
fi

# Configuration
REPORT_FILE="${REPORT_FILE:-/tmp/code_review_report.md}"
MAX_TEST_TIME="${MAX_TEST_TIME:-120}"  # 2 minutes default

# Track issues found
declare -a ISSUES_FOUND=()
declare -a MESSAGES=()

add_message() {
    MESSAGES+=("$1")
}

add_issue() {
    ISSUES_FOUND+=("$1")
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

# Run Python tests
run_python_tests() {
    if ! command -v pytest &> /dev/null; then
        add_message "pytest not installed - skipping Python tests"
        return 0
    fi

    # Check if tests exist
    if [ ! -d "tests" ] && [ ! -d "test" ]; then
        if ! find . -maxdepth 3 -name "test_*.py" -o -name "*_test.py" 2>/dev/null | grep -q .; then
            add_message "No Python test files found - skipping"
            return 0
        fi
    fi

    local test_output
    if test_output=$(timeout "$MAX_TEST_TIME" pytest -v --tb=short 2>&1); then
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
    if test_output=$(timeout "$MAX_TEST_TIME" npm test 2>&1); then
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
    if test_output=$(timeout "$MAX_TEST_TIME" flutter test 2>&1); then
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
        issue_count=$(echo "$analyze_output" | grep -cE "^\s*(info|warning|error) " || echo "0")
        if [ "$issue_count" -gt 0 ]; then
            add_issue "Dart analyze: $issue_count issues"
            local tail_output
            tail_output=$(echo "$analyze_output" | head -10)
            add_message "$tail_output"
        fi
    fi
}

# Run bandit security scan
run_bandit_scan() {
    if ! command -v bandit &> /dev/null; then
        return 0
    fi

    local -a src_dirs=()
    for dir in src app lib lambda functions .; do
        if [ -d "$dir" ] && find "$dir" -maxdepth 3 -name "*.py" -type f 2>/dev/null | grep -q .; then
            src_dirs+=("$dir")
        fi
    done

    if [ ${#src_dirs[@]} -eq 0 ]; then
        return 0
    fi

    local bandit_output
    bandit_output=$(bandit -r "${src_dirs[@]}" -f txt -ll 2>&1) || true

    if echo "$bandit_output" | grep -qE "Severity: (High|Medium)"; then
        local high_count
        high_count=$(echo "$bandit_output" | grep -c "Severity: High" || echo "0")
        local medium_count
        medium_count=$(echo "$bandit_output" | grep -c "Severity: Medium" || echo "0")

        if [ "$high_count" -gt 0 ]; then
            add_issue "Bandit: $high_count HIGH severity issues"
        fi
        if [ "$medium_count" -gt 0 ]; then
            add_message "Bandit: $medium_count MEDIUM severity issues"
        fi
    else
        add_message "Bandit security scan: PASSED"
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
        error_count=$(echo "$ruff_output" | grep -cE "^.+:[0-9]+:[0-9]+:" || echo "0")
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

    local -a target=()
    if [ -n "$FILE_PATH" ] && [[ "$FILE_PATH" == *.py ]]; then
        target=("$FILE_PATH")
    else
        # Find src dirs with Python files
        for dir in src app lib lambda functions; do
            if [ -d "$dir" ] && find "$dir" -maxdepth 3 -name "*.py" -type f 2>/dev/null | grep -q .; then
                target+=("$dir")
            fi
        done
        if [ ${#target[@]} -eq 0 ]; then
            return 0
        fi
    fi

    local mypy_output
    if mypy_output=$(timeout "$MAX_TEST_TIME" mypy --no-error-summary "${target[@]}" 2>&1); then
        add_message "Mypy: PASSED"
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            add_issue "Mypy: TIMED OUT after ${MAX_TEST_TIME}s"
        else
            local error_count
            error_count=$(echo "$mypy_output" | grep -c ": error:" || echo "0")
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
    if eslint_output=$(timeout 60 npx eslint --no-warn-on-unmatched-pattern "$target" 2>&1); then
        add_message "ESLint: PASSED"
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            add_issue "ESLint: TIMED OUT"
        else
            local error_count
            error_count=$(echo "$eslint_output" | grep -cE "^.+:[0-9]+:[0-9]+" || echo "0")
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
        local high_count
        high_count=$(echo "$audit_output" | grep -o '"high":[0-9]*' | cut -d: -f2 || echo "0")
        local critical_count
        critical_count=$(echo "$audit_output" | grep -o '"critical":[0-9]*' | cut -d: -f2 || echo "0")

        if [ "${critical_count:-0}" -gt 0 ] || [ "${high_count:-0}" -gt 0 ]; then
            add_issue "npm audit: critical/high vulnerabilities found"
        fi
    fi
}

# Main execution
main() {
    local project_info
    project_info=$(detect_project_type)
    local has_python has_node has_cdk has_flutter
    IFS=':' read -r has_python has_node has_cdk has_flutter <<< "$project_info"

    local ran_something=false

    # Run tests based on file type and project type
    if [ "$has_python" = "true" ]; then
        if [ -z "$FILE_PATH" ] || [[ "$FILE_PATH" == *.py ]]; then
            run_python_tests || true
            run_bandit_scan || true
            run_pip_audit || true
            run_ruff_check || true
            run_mypy_check || true
            ran_something=true
        fi
    fi

    if [ "$has_node" = "true" ]; then
        if [ -z "$FILE_PATH" ] || [[ "$FILE_PATH" == *.ts ]] || [[ "$FILE_PATH" == *.js ]] || [[ "$FILE_PATH" == *.tsx ]] || [[ "$FILE_PATH" == *.jsx ]]; then
            run_node_tests || true
            run_npm_audit || true
            run_eslint_check || true
            ran_something=true
        fi
    fi

    if [ "$has_cdk" = "true" ]; then
        run_cdk_tests || true
        ran_something=true
    fi

    if [ "$has_flutter" = "true" ]; then
        if [ -z "$FILE_PATH" ] || [[ "$FILE_PATH" == *.dart ]]; then
            run_flutter_tests || true
            run_dart_analyze || true
            ran_something=true
        fi
    fi

    # If nothing ran, exit silently
    if [ "$ran_something" = false ]; then
        exit 0
    fi

    # Output results as plain text (caller reads stdout)
    if [ ${#ISSUES_FOUND[@]} -gt 0 ]; then
        echo "Hook: Post-code checks found issues:"
        for issue in "${ISSUES_FOUND[@]}"; do
            echo "  - $issue"
        done
    fi

    for msg in "${MESSAGES[@]}"; do
        echo "$msg"
    done

    # Always exit 0 so the hook doesn't block the agent
    exit 0
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
