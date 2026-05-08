---
name: Never use git stash
description: User explicitly forbids git stash — use WIP commits or ask instead
type: feedback
---

Never use `git stash`. User forgets about stashes and they get lost.

**Why:** CLAUDE.md also says this — "NEVER use git stash — ask user: Keep (WIP commit) or discard?"

**How to apply:** When switching branches with uncommitted changes, either commit them first (WIP commit) or ask the user whether to keep or discard.

**Common replacements:**
- Need to compare with main? Use `git show origin/main:<path>` or `git diff origin/main -- <path>`.
- Need to test if a failure is pre-existing? Compare the file against main or inspect `git log <path>`.
- Need a clean tree for checkout? Make a visible WIP commit or ask whether to discard.
- Need to hide untracked build/runtime files? Remove only the verified artifact paths; do not stash the whole tree.
