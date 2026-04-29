---
name: GraphQL reviewThreads pagination
description: Always use first:100 and check hasNextPage when querying PR review threads
type: feedback
---
GraphQL reviewThreads query must use `first:100` (not 50) and verify `hasNextPage`.

**Why:** PRs with 3 bot reviewers (Copilot, Gemini, Codex) easily hit 70-80+ threads. Using `first:50` silently misses threads, causing "0 unresolved" while GitHub blocks merge. User caught this during PR #1879 merge.

**How to apply:** Every `reviewThreads` GraphQL query should use `first:100` and check `pageInfo { hasNextPage }`. If hasNextPage is true, paginate.
