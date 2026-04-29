---
name: Proactive status pings during long async ops
description: When background ops run 5+ min, ping ~5 min interval — user shouldn't have to ask "status?" repeatedly
type: feedback
---

When a long-running async op (merge supervisor, queue waiting for E2E batch, big merge commit with hooks, branch rebase) takes >5 min, send a proactive 1-line update at roughly 5-min intervals — not silence until completion. Without periodic pings the user defaults to interrogating ("co teraz?", "i co?", "now?", "jaki status?"), which (a) wastes their attention switching back to the terminal, (b) fires GraphQL calls that compound rate-limit pressure, (c) loses trust that work is still progressing.

**Why:** Confirmed in 2026-04-27 session — multiple supervisors running in background, agent gave one initial status report then went silent waiting for `task-notification`. User pinged 4× in ~30 min asking for status. They explicitly noted "wszystkie review są już zrobione!" when agent was reporting that supervisor was still in WAIT_REVIEWS — meaning the proactive log was both stale AND insufficient.

**How to apply:**
- Long supervisor / queue wait → send 1-line update every ~5 min: "Still in queue position 1, AWAITING_CHECKS — E2E batch usually 5-10 min" (not silence).
- Big merge commit with slow hooks → tell user the expected duration up-front: "validate-content takes ~5 min on this size of merge".
- When you DO get a status notification, summarize the **delta** since last ping — not a re-statement of full state.
- Cap proactive cadence at ~5 min; finer = noise. If nothing changed and queue is healthy, "still in queue, no change" is fine.
- Distinct from `feedback_review_proactive.md` (which is about post-push thread checks) — this rule is about long-running ops where state doesn't change for minutes.
