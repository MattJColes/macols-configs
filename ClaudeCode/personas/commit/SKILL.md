---
name: commit
description: Run tests and linters, then create a conventional commit and push to the current branch.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
user-invocable: true
---

# Commit Skill

1. Run all tests (pytest for backend, dart test for frontend)
2. Run linters (ruff check, dart analyze)
3. If all pass, create a conventional commit with a descriptive message
4. Push to current branch
5. Report the commit hash and any warnings
