---
name: Never use git stash
description: User explicitly forbids git stash — use WIP commits or ask instead
type: feedback
---

Never use `git stash`. User forgets about stashes and they get lost.

**Why:** CLAUDE.md also says this — "NEVER use git stash — ask user: Keep (WIP commit) or discard?"

**How to apply:** When switching branches with uncommitted changes, either commit them first (WIP commit) or ask the user whether to keep or discard.
