---
name: GraphQL rate limit budgeting
description: Conserve GitHub GraphQL rate limit during multi-cycle review sessions to avoid dead time
type: feedback
---
Budget GraphQL calls across review-fix-push cycles. Each supervisor run + thread query + resolution costs ~20-30 points. After 2+ cycles in one session, rate limit risk is high.

**Why:** PR #1899 session hit rate limit 0 after 3 fix-push cycles (resolve threads individually + supervisor runs + repeated queries). Caused 25 min dead time; user had to merge manually.

**How to apply:**
- Always batch thread resolutions into a single mutation (see `feedback_pr_review_bots.md`)
- Combine thread ID query + resolution into 2 calls total (1 query, 1 batched mutation)
- After 2+ review cycles, check `rateLimit { remaining }` before running supervisor
- If remaining < 100, warn user and suggest: manual merge via UI, or wait for reset
- **Cap parallel `pr-merge-supervisor` processes at 2.** Each polls GraphQL ~3-4 calls/min for the duration of its run. 4+ in parallel for 30 min exhausts the 5000/hr quota on its own (confirmed 2026-04-27: 4 parallel supervisors + thread resolves + status checks → rate limit hit in ~30 min, blocked subsequent `gh pr merge --auto` and comment posts).
- Once a supervisor reports `isInMergeQueue: true` with `AWAITING_CHECKS`, **kill it** and trust the queue. Cycles in queue-wait are wasted polls; the queue handles the merge regardless.
- During degraded GraphQL state, fall back to REST (`gh api repos/.../pulls/N --jq ...`) for status checks — REST has a separate quota. Only retry GraphQL-only operations (auto-merge enable, thread resolve, `dequeuePullRequest`) after `gh api rate_limit --jq .resources.graphql` shows >100 remaining.
