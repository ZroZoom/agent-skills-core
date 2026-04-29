---
name: Triaging bot review comments
description: How to assess Gemini/Copilot suggestions — not all are worth fixing
type: feedback
---

Bot reviewers (Gemini, Copilot) generate many comments per PR. Triage before fixing:

**Fix:** Real bugs (type mismatches, data shape mismatches), missing safety guards, false positives in validators.

**Won't-fix with rationale:** Hardcoded Polish strings in content-level rendering (this is an educational platform — lesson content labels are not UI chrome). Pre-existing issues not introduced by the PR.

**How to apply:**
- Evaluate each comment against: "Does this affect the PR's changed code, or is it pre-existing?"
- Reply with "Out of scope — pre-existing" for issues in untouched code
- Reply with "Won't fix — [rationale]" with domain-specific reasoning
- Always reply before resolving, even for won't-fix items
