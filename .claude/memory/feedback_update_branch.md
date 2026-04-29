---
name: Always check update-branch before merge
description: Before merging a PR, proactively check if branch is behind main and update it
type: feedback
---

Always check if the PR branch is behind main and update it BEFORE attempting merge. Do this proactively after CI passes — don't wait for the user to ask.

**Why:** User expects this as part of standard PR flow. Skipping it delays merge.

**How to apply:** After CI passes and threads are resolved, BEFORE proposing merge: `gh pr view N --json mergeStateStatus` → if `BEHIND` → `update-branch` API → wait for new CI.
