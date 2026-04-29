---
name: Merge supervisor reviewer timing
description: Supervisor WAIT_REVIEWS=240s — but "ready for review" triggers new Copilot cycle that may arrive after timeout
type: feedback
---
The `WAIT_REVIEWS` timeout in `tools/pr-merge-supervisor.ts` is 240s (increased from 120s in PR #1803, merged 2026-04-08). Copilot reviews typically take 2-4 minutes.

**Key pattern:** When the supervisor converts a draft PR to "ready for review", this triggers a *new* Copilot review cycle. Copilot may submit threads after the 240s timeout. The supervisor's CHECK_THREADS after CI catches late reviews, but during the CI wait you should also manually check for new unresolved threads — don't assume the resolved count is final.

**Why:** On PR #1792 merge (2026-04-08), 2 new Copilot threads appeared after the reviewer timeout because marking "ready" triggered a new review. User noticed before the agent did.

**How to apply:** While supervisor waits for CI, periodically check for new unresolved threads. The supervisor does this automatically after CI passes (CHECK_THREADS), but manual checks during the CI wait prevent surprises.

**Duplicate threads:** Copilot reviews the full diff against base, not just the latest commit. Already-fixed issues get re-flagged on each "ready for review" cycle. When this happens, reply with the commit SHA that fixed it, then resolve. Don't re-implement the fix.
