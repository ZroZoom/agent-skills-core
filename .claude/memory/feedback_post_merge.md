---
name: Post-merge checklist
description: After merging a PR, execute full post-merge process — close tickets, verify deploy, run tests
type: feedback
---

After merging a PR, don't stop at `git checkout main && git pull`. Full checklist:

1. **Close linked issues/tickets** — check if PR had linked issues (GitHub, Jira, Linear), update status
2. **Verify deploy** — confirm hosting deploy succeeded (Netlify/Vercel/etc.), open production
3. **Smoke test on production** — run test plan from PR description on live site
4. **Clean up local branches** — delete merged branches
5. **Notify if needed** — if someone was waiting for the change

**Why:** Without an explicit checklist, ticket verification and post-deploy tests get skipped and the user has to remind.

**How to apply:** After every merge, ask about linked tickets and propose smoke test per PR test plan.
