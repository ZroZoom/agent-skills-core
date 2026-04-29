---
name: Pre-push hook blocks branch deletion
description: git push --delete triggers pre-push build hook — use GitHub API for bulk branch cleanup
type: feedback
---

`git push origin --delete <branch>` triggers the pre-push hook (full build) for EACH deletion — unusable for bulk cleanup.

**Why:** Pre-push hook runs `npm run build` on every push, including delete operations. 67 branches × 5min build = impossible.

**How to apply:** For bulk remote branch deletion, use `gh api repos/OWNER/REPO/git/refs/heads/BRANCH -X DELETE`. If branches are already gone on remote (e.g., auto-delete after PR merge), just run `git fetch --prune` to clean stale local tracking refs.
