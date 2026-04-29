---
name: pr-merge-supervisor infinite loop bypass
description: Supervisor cycles forever when bots skip new HEAD review after update-branch — kill and use direct gh pr merge --auto
type: feedback
---

`tools/pr-merge-supervisor.ts` can fall into an infinite loop after `update-branch` creates a new merge HEAD: WAIT_REVIEWS times out (240s) → CHECK_THREADS ✅ → CHECK_CI ✅ → CHECK_MERGED (not merged) → CHECK_MERGE_STATE (CLEAN) → VERIFY_AUTO_MERGE prints "re-armed" but `autoMergeRequest` is null on GitHub → back to WAIT_REVIEWS. Each cycle burns ~5 min of GraphQL quota.

**Why:** Bot reviewers (Copilot/Gemini) usually don't re-post a fresh review on a merge commit, so WAIT_REVIEWS always times out. The "auto-merge re-arm" succeeds locally but doesn't stick on GitHub side, often because the PR was already in queue from an earlier arm. Confirmed in 2026-04-27 batch-merge session — both #2023 and #2007 stuck this way until killed.

**How to apply:**
- When supervisor reports >2 cycles of "WAIT_REVIEWS → ... → VERIFY_AUTO_MERGE → WAIT_REVIEWS" without progress, kill it (`TaskStop`) and run `gh pr merge <N> --squash --auto` directly.
- Verify queue position via `gh api graphql` `mergeQueue.entries`. Direct enqueue worked first try in this session for both stuck PRs.
- Distinct from `feedback_supervisor_timeout.md` (which is about the 240s reviewer wait window) — this is the multi-cycle progress-failure mode.
