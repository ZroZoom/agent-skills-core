#!/usr/bin/env bash
# PostToolUse hook for Claude Code: runs a quick typecheck after Edit/Write.
# Project-aware — only runs when the project actually has TypeScript config.
#
# Reference: https://code.claude.com/docs/en/hooks
#
# Test:
#   echo '{}' | ./scripts/claude-hooks/typecheck-after-edit.sh
#   # In a TS repo: prints last 5 lines of `tsc --noEmit`.
#   # In a non-TS repo: silently exits 0.

set -euo pipefail

# Skip noisily in repos that don't use TypeScript.
if [ -f tsconfig.json ] || [ -f jsconfig.json ]; then
  npx --no-install tsc --noEmit --pretty 2>&1 | tail -5 || true
fi

exit 0
