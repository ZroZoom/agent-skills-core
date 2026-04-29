---
name: No poll loops
description: Don't poll CI status in a loop — use gh pr checks --watch in background and wait for notification
type: feedback
---

Never do manual loops like `gh pr checks | grep pending` every few seconds. Use `gh pr checks --watch` as a background task and wait for the notification.

**Why:** On PR #1716, looped ~15 times checking E2E tests pending — user had to interrupt.

**How to apply:** For long CI runs: `run_in_background: true` with `gh pr checks --watch`, don't poll manually.
