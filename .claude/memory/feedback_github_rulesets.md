---
name: GitHub Rulesets vs Branch Protection
description: Use rulesets API (not legacy branch protection) to check branch rules
type: feedback
---

When checking branch protection: use the Rulesets API, NOT legacy Branch Protection.

- **Rulesets**: `gh api repos/OWNER/REPO/rulesets` — this is what's configured in this repo ("Ochrona main")
- **Legacy**: `gh api repos/OWNER/REPO/branches/BRANCH/protection` — returns 404 because it's not used

**Why:** The user corrected me — I was looking at the old API and declared no protection, which was incorrect. Rulesets (2023+) replaced branch protection rules.

**How to apply:** When checking branch protection — try rulesets first, then legacy as a fallback. Don't assume that a 404 on legacy means no protection.
