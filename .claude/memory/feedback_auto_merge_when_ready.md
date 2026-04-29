---
name: Auto-merge when CI green + 0 unresolved
description: Don't ask "mergować?" — run /merge immediately when PR is ready
type: feedback
---

When CI is green and there are 0 unresolved review threads, run `/merge` immediately. Don't ask the user for permission — the dispatch pattern implies full autonomous cycle.

**Why:** User had to prompt "i co?" and "co?" multiple times when the PR was clearly ready. Asking "mergować?" adds unnecessary friction.

**How to apply:** CI green + 0 unresolved → `/merge` (or `npx tsx tools/pr-merge-supervisor.ts`). Only ask if there's ambiguity (e.g. failing tests, open questions).
