#!/bin/bash
#
# Shared Post-Task Checks Library
#
# Sourced by tool-specific wrappers (ClaudeCode, OpenCode).
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

# Ensure Node.js is in PATH (sources NVM/fnm if needed)
SHARED_DIR_SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ensure_node.sh
if [ -f "$SHARED_DIR_SELF/ensure_node.sh" ]; then
    source "$SHARED_DIR_SELF/ensure_node.sh"
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

# Gate: has any code been changed in the working tree?
#
# Returns 0 (run the checks) when the git working tree contains added/modified/
# untracked files with a code extension, OR when we can't tell (no git, not a
# repo) — we never silently suppress checks. Returns 1 (skip) when the tree is
# clean of code changes, e.g. a Q&A or docs-only turn. This keeps the full
# test/lint/typecheck battery from running on every turn that didn't touch code.
code_changed() {
    command -v git &> /dev/null || return 0
    git rev-parse --is-inside-work-tree &> /dev/null || return 0

    local changed
    changed=$(git status --porcelain 2>/dev/null | sed 's/^...//;s/.* -> //')
    [ -z "$changed" ] && return 1

    if echo "$changed" | grep -qiE '\.(py|ts|tsx|js|jsx|mjs|cjs|dart|go|rs|java|rb|kt|swift|c|cc|cpp|h|hpp|cs|php|scala|sql)$'; then
        return 0
    fi
    return 1
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
    # Also detect monorepo sub-projects with their own pyproject.toml
    if [ "$has_python" = "false" ]; then
        if find . -maxdepth 3 -name "pyproject.toml" -not -path "*/.venv/*" -not -path "*/node_modules/*" 2>/dev/null | grep -q .; then
            has_python=true
        fi
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

# Find a tool binary from a virtualenv, walking up to repo root.
# Usage: find_venv_bin <tool_name>  e.g. find_venv_bin pytest
find_venv_bin() {
    local tool="$1"
    # Check cwd first
    for venv_dir in .venv venv env; do
        if [ -f "$venv_dir/bin/$tool" ]; then
            echo "$(pwd)/$venv_dir/bin/$tool"
            return 0
        fi
    done
    # Walk up to repo root looking for a shared venv
    local search_dir="$PWD"
    while [ "$search_dir" != "/" ]; do
        for venv_dir in .venv venv env; do
            if [ -f "$search_dir/$venv_dir/bin/$tool" ]; then
                echo "$search_dir/$venv_dir/bin/$tool"
                return 0
            fi
        done
        search_dir="$(dirname "$search_dir")"
    done
    # Fall back to PATH
    if command -v "$tool" &> /dev/null; then
        echo "$tool"
        return 0
    fi
    echo ""
}

# Convenience alias for backward compat
find_python_pytest() {
    find_venv_bin pytest
}

# Discover Python sub-projects. Returns directories containing pyproject.toml
# that also have a test/ or tests/ directory (i.e. testable sub-projects).
# Falls back to "." if no sub-projects found but root has test files.
find_python_projects() {
    local -a projects=()

    # Find sub-projects by pyproject.toml that have test directories
    while IFS= read -r toml; do
        local dir
        dir="$(dirname "$toml")"
        # Skip root-level pyproject.toml (handled as fallback)
        [ "$dir" = "." ] && continue
        if [ -d "$dir/test" ] || [ -d "$dir/tests" ]; then
            projects+=("$dir")
        fi
    done < <(find . -maxdepth 4 -name "pyproject.toml" -not -path "*/.venv/*" -not -path "*/node_modules/*" 2>/dev/null | sort)

    # If no sub-projects found, fall back to root
    if [ ${#projects[@]} -eq 0 ]; then
        projects=(".")
    fi

    echo "${projects[@]}"
}

# Run Python tests — monorepo-aware: runs pytest from each sub-project directory
run_python_tests() {
    local root_dir="$PWD"

    local -a projects
    read -ra projects <<< "$(find_python_projects)"

    local any_failed=false

    for project_dir in "${projects[@]}"; do
        local label="$project_dir"
        [ "$project_dir" = "." ] && label="root"

        cd "$root_dir/$project_dir" || continue

        # Resolve pytest per project so sub-project .venvs (with their own
        # deps) win over a global tool install
        local pytest_bin
        pytest_bin=$(find_python_pytest)
        if [ -z "$pytest_bin" ]; then
            add_warning "pytest not installed - skipping Python tests ($label)"
            cd "$root_dir" || return
            continue
        fi

        # Check test directory exists
        if [ ! -d "tests" ] && [ ! -d "test" ]; then
            if ! find . -maxdepth 3 -name "test_*.py" -o -name "*_test.py" 2>/dev/null | grep -q .; then
                cd "$root_dir" || return
                continue
            fi
        fi

        local test_output
        local pytest_cmd="${TIMEOUT_CMD:+$TIMEOUT_CMD $MAX_TEST_TIME }$pytest_bin -v --tb=short"
        if test_output=$(eval "$pytest_cmd" 2>&1); then
            add_warning "Python tests ($label): PASSED"
        else
            local exit_code=$?
            if [ $exit_code -eq 124 ]; then
                add_critical_issue "Python tests ($label): TIMED OUT after ${MAX_TEST_TIME}s"
            else
                add_critical_issue "Python tests ($label): FAILED"
                local tail_output
                tail_output=$(echo "$test_output" | tail -10)
                add_critical_issue "Test output:\n$tail_output"
            fi
            any_failed=true
        fi

        cd "$root_dir" || return
    done

    if [ "$any_failed" = true ]; then
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
    local bandit_bin
    bandit_bin=$(find_venv_bin bandit)
    if [ -z "$bandit_bin" ]; then
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

    # Skip virtualenvs and vendored deps — bandit's built-in exclude covers
    # .git/.tox/__pycache__ but NOT .venv/venv/node_modules, so third-party
    # library source under e.g. src/<pkg>/.venv would otherwise produce
    # un-fixable findings (you can't #nosec code you don't own).
    local bandit_exclude='*/.venv/*,*/venv/*,*/node_modules/*,*/.git/*,*/.tox/*,*/__pycache__/*,*/build/*,*/dist/*'

    local bandit_output
    bandit_output=$("$bandit_bin" -r "${src_dirs[@]}" --exclude "$bandit_exclude" -f txt -ll 2>&1) || true

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

# Run ruff linter — monorepo-aware
run_ruff_check() {
    local ruff_bin
    ruff_bin=$(find_venv_bin ruff)
    if [ -z "$ruff_bin" ]; then
        return 0
    fi

    local root_dir="$PWD"
    local -a projects
    read -ra projects <<< "$(find_python_projects)"

    for project_dir in "${projects[@]}"; do
        local label="$project_dir"
        [ "$project_dir" = "." ] && label="root"

        cd "$root_dir/$project_dir" || continue

        local ruff_output
        if ruff_output=$("$ruff_bin" check . 2>&1); then
            add_warning "Ruff ($label): PASSED"
        else
            local error_count
            error_count=$(echo "$ruff_output" | grep -cE "^.+:[0-9]+:[0-9]+:" || true)
            if [ "$error_count" -gt 0 ]; then
                add_critical_issue "Ruff ($label): $error_count linting issues"
                local tail_output
                tail_output=$(echo "$ruff_output" | head -10)
                add_critical_issue "Ruff output:\n$tail_output"
            fi
        fi

        cd "$root_dir" || return
    done
}

# Run mypy type checker — monorepo-aware, uses each sub-project's config
run_mypy_check() {
    local mypy_bin
    mypy_bin=$(find_venv_bin mypy)
    if [ -z "$mypy_bin" ]; then
        return 0
    fi

    local root_dir="$PWD"
    local -a projects
    read -ra projects <<< "$(find_python_projects)"

    for project_dir in "${projects[@]}"; do
        local label="$project_dir"
        [ "$project_dir" = "." ] && label="root"

        cd "$root_dir/$project_dir" || continue

        # Find target directories for mypy
        local target=""
        if [ -f "pyproject.toml" ] && grep -q '\[tool\.mypy\]' pyproject.toml 2>/dev/null; then
            # Use targets from bandit config or scan for source dirs
            for dir in app src lib lambda functions stacks config custom_constructs; do
                if [ -d "$dir" ] && find "$dir" -maxdepth 3 -name "*.py" -type f 2>/dev/null | grep -q .; then
                    target="$target $dir"
                fi
            done
        fi

        if [ -z "$target" ]; then
            cd "$root_dir" || return
            continue
        fi

        local mypy_output
        local mypy_cmd="${TIMEOUT_CMD:+$TIMEOUT_CMD $MAX_TEST_TIME }$mypy_bin --no-error-summary $target"
        if mypy_output=$(eval "$mypy_cmd" 2>&1); then
            add_warning "Mypy ($label): PASSED"
        else
            local exit_code=$?
            if [ $exit_code -eq 124 ]; then
                add_critical_issue "Mypy ($label): TIMED OUT after ${MAX_TEST_TIME}s"
            else
                local error_count
                error_count=$(echo "$mypy_output" | grep -c ": error:" || true)
                if [ "$error_count" -gt 0 ]; then
                    add_critical_issue "Mypy ($label): $error_count type errors"
                    local tail_output
                    tail_output=$(echo "$mypy_output" | grep ": error:" | head -10)
                    add_critical_issue "Mypy output:\n$tail_output"
                fi
            fi
        fi

        cd "$root_dir" || return
    done
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
