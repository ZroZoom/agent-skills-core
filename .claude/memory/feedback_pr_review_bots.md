---
name: PR review bot thread resolution
description: How to properly resolve Gemini/Copilot automated review comments on PRs
type: feedback
---
When reviewing PRs, Gemini and Copilot bots leave review comments. Replying to comments is NOT enough to unblock merge — threads must be explicitly resolved via GraphQL.

**Why:** Unresolved conversations block merge (branch protection). Bot threads block just like human reviews.

**How to apply:**
- Reply to each comment with fix status or rationale (won't-fix)
- Get thread IDs: `gh api graphql -f query='query { repository(...) { pullRequest(number: N) { reviewThreads(first:100) { nodes { id isResolved } } } } }'`
- **ALWAYS batch-resolve in a single mutation** (never one-by-one — burns rate limit):
  ```graphql
  mutation {
    t1: resolveReviewThread(input: {threadId: "ID1"}) { thread { isResolved } }
    t2: resolveReviewThread(input: {threadId: "ID2"}) { thread { isResolved } }
  }
  ```
