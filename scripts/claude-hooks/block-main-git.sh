#!/usr/bin/env bash
# PreToolUse hook for Claude Code: refuses `git commit` / `git push` when the
# current branch is `main` or `master`. Backs the rule documented in
# CLAUDE.md → Git Rules.
#
# Claude Code passes the tool event as JSON on stdin. The Bash command being
# run is at `.tool_input.command`. Exit code 2 blocks the tool call and shows
# the stderr output to the user.
#
# Reference: https://code.claude.com/docs/en/hooks
#
# Test:
#   echo '{"tool_input":{"command":"git push origin main"}}' \
#     | ./scripts/claude-hooks/block-main-git.sh
#   # Should exit 2 with a BLOCKED message (assuming you're on main).

set -euo pipefail

# Read the event JSON from stdin. If no jq, fall back to a forgiving regex.
if command -v jq >/dev/null 2>&1; then
  CMD=$(jq -r '.tool_input.command // empty' < /dev/stdin)
else
  CMD=$(awk -F'"command"[[:space:]]*:[[:space:]]*"' 'NR==1{print $2}' < /dev/stdin | awk -F'"' '{print $1}')
fi

# Match `git commit` / `git push` as whole words at start of segment, so we
# don't accidentally block `gh pr commit-suggestion` or `git commit-tree` parsing.
if printf '%s' "$CMD" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+(commit|push)([[:space:]]|$)'; then
  BRANCH=$(git branch --show-current 2>/dev/null || echo "")
  if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
    echo "BLOCKED: cannot run \`git commit\` or \`git push\` on branch '$BRANCH'." >&2
    echo "Create a feature branch first: git checkout -b feature/<name>" >&2
    exit 2
  fi
fi

exit 0
