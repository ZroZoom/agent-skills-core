---
name: Verify PR state with a fresh query before claiming
description: Before saying a PR has no unresolved threads or is ready to merge, fresh-query review threads and merge state
type: feedback
---

Before claiming a state assertion about a PR, such as "0 unresolved threads" or "ready to merge", do a fresh query after any recent resolve/push/update mutation.

Check:

- `reviewThreads(first: 100)` with `pageInfo { hasNextPage endCursor }`; paginate when `hasNextPage` is true, then count `isResolved == false` directly.
- `mergeStateStatus` or the host's equivalent merge-blocking field.
- Recent bot reviews, which can arrive between your previous read and your claim.

**Why:** GitHub review state is eventually consistent and automated reviewers can post new threads after you resolve an earlier batch. A stale "clean" claim wastes time and erodes trust.

**How to apply:**
- Treat your own mutation as "likely succeeded", not as proof that the visible state is clean.
- For user-visible merge/readiness claims, dump the fresh API result to a temp file and query it with `jq`.
- If the user reports contradictory UI, trust the screen and re-query immediately with `first: 100` plus `pageInfo`.
