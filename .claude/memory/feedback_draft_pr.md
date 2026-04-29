---
name: Add changes to existing draft PR
description: When a draft PR exists for the current work, add commits there instead of creating a new PR
type: feedback
---

If there's an existing draft/open PR for the current work, add new commits to that branch instead of creating a separate PR.

**Why:** User prefers fewer, consolidated PRs. Creating a separate PR for a related change wastes CI runs and adds merge overhead.

**How to apply:** Before creating a new branch/PR, check if there's already an open PR for the current feature branch. If yes, commit there.
