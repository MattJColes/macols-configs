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
#   run_post_code_checks — fast, file-scoped lint/type-check orchestrator
#
# Per-edit checks are intentionally lightweight: only the linter/type-checker
# for the changed file's language runs here. Tests, security audits and cdk
# synth run once at turn end via the Stop hook (post_task_checks.sh).
#
# Shared environment/discovery helpers (setup_timeout_cmd, find_venv_bin, …)
# live in checks_common.sh, sourced below.
#
# Results are collected in ISSUES_FOUND[] and MESSAGES[] arrays.
# Always returns 0 (non-blocking).
#

# Guard against direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script must be sourced, not executed directly." >&2
    exit 1
fi

# Shared helpers (also sources ensure_node.sh).
SHARED_DIR_SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=checks_common.sh
source "$SHARED_DIR_SELF/checks_common.sh"

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

# Run ruff linter — scoped to the changed file.
run_ruff_check() {
    local ruff_bin
    ruff_bin=$(find_venv_bin ruff)
    [ -z "$ruff_bin" ] && return 0

    local target="."
    if [ -n "$FILE_PATH" ] && [[ "$FILE_PATH" == *.py ]]; then
        target="$FILE_PATH"
    fi

    local ruff_output
    if ruff_output=$("$ruff_bin" check "$target" 2>&1); then
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

# Run mypy type checker — scoped to the changed file.
run_mypy_check() {
    local mypy_bin
    mypy_bin=$(find_venv_bin mypy)
    [ -z "$mypy_bin" ] && return 0

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
    local mypy_cmd="${TIMEOUT_CMD:+$TIMEOUT_CMD $MAX_TEST_TIME }$mypy_bin --no-error-summary $target"
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

# Run ESLint — scoped to the changed file. Prefers a project-local eslint binary
# over `npx` to avoid npx's per-invocation resolution overhead on every edit.
run_eslint_check() {
    local eslint_bin
    if [ -x "node_modules/.bin/eslint" ]; then
        eslint_bin="node_modules/.bin/eslint"
    elif command -v eslint &> /dev/null; then
        eslint_bin="eslint"
    elif command -v npx &> /dev/null; then
        eslint_bin="npx eslint"
    else
        return 0
    fi

    local target
    if [ -n "$FILE_PATH" ] && [[ "$FILE_PATH" == *.ts || "$FILE_PATH" == *.js || "$FILE_PATH" == *.tsx || "$FILE_PATH" == *.jsx ]]; then
        target="$FILE_PATH"
    else
        target="."
    fi

    local eslint_output
    local eslint_cmd="${TIMEOUT_CMD:+$TIMEOUT_CMD 60 }$eslint_bin --no-warn-on-unmatched-pattern \"$target\""
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
