---
name: PR setup procedure
description: After creating a PR, always add labels, assignee, and GitHub Project fields — don't stop at gh pr create
type: feedback
---

After creating a PR (`gh pr create`) ALWAYS execute the full procedure:

1. **Labels + assignee**: `gh pr edit NUMBER --add-label "ready-for-review" --add-label "DOMAIN_LABEL" --add-assignee "@me"`
2. **Add to GitHub Project**: GraphQL `addProjectV2ItemById` (contentId from `gh pr view --json id`)
3. **Set project fields**: Status → "In review", Priority (P0-P2), Size (XS-XL)

**Why:** The user expects the PR to be fully configured — just `gh pr create` is not enough. The `/repo pr` skill describes this flow, but it's easy to skip steps 2-3.

**How to apply:** Every time after `gh pr create` — continue with steps 2-3. Field IDs are in `.agent/context/project-ids.md`.
