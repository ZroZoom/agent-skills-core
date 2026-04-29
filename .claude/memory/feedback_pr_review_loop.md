---
name: Monitor PR comments after push
description: After pushing to a PR, poll for new review comments every 2 min and handle them before moving on
type: feedback
---

After every push to a PR, monitor for new review comments (Copilot, Gemini, humans) before moving on to the next task.

**Why:** Bot reviewers (Copilot, Gemini) take 1-3 min to analyze the diff. If I don't wait and check, unresolved comments accumulate and block merge. The coding agent has the best context to fix issues immediately.

**How to apply:** After pushing, wait ~2 min then check for unresolved review threads. Fix code issues, reply to non-actionable comments, resolve threads, push again. Repeat until 0 unresolved threads for 2 consecutive checks. Use background polling or /loop to avoid blocking the user.
