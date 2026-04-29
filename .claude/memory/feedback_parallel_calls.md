---
name: Parallel calls isolation
description: Don't group risky API calls (e.g. GraphQL with limited scope) with safer ones (REST) in the same parallel block — one failure cancels the rest
type: feedback
---

Don't mix calls with different failure risk in a single parallel tool calls block.

**Why:** When one call in a parallel group fails, the framework cancels the rest — even those that would have succeeded. E.g., GraphQL with missing `read:project` scope canceled 3 REST calls (milestones, PRs, issues).

**How to apply:** First run the risky/uncertain call separately. Only after success (or error handling) run the rest in parallel. Applies especially to: GraphQL vs REST, calls requiring special tokens/scopes, external APIs vs local commands.
