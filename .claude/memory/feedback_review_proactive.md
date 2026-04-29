---
name: Proactive review checking
description: After every push to a PR, proactively check for new reviewer comments — don't wait for the user to ask
type: feedback
---

After every push to a PR, automatically check for new review threads (GraphQL `reviewThreads` with `isResolved=false`) — don't wait for the user to ask "any more comments?".

**Why:** On PR #1716, the user had to ask 3 times about new comments — each time there were more to fix.

**How to apply:** After every push: 1) wait ~2 min for new Copilot/Gemini review round, 2) check unresolved threads, 3) fix and resolve.
