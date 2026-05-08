---
name: Re-audit whole function after bot-review fixes
description: After applying a valid bot review fix, re-read the entire affected function or module before pushing
type: feedback
---

After implementing a fix for a bot review comment, re-read the entire affected function or module end-to-end. Do not inspect only the changed hunk.

**Why:** Reactive fix-per-comment work can create semantic drift. A change that satisfies one comment may contradict another branch, invert an API meaning, or break a caller that was outside the diff hunk.

**How to apply:**
- For each valid bot comment, implement the fix, then read the whole affected unit top-to-bottom.
- Spot-check the API semantics the comment relied on; bots can be wrong.
- If multiple comments touch the same unit, integrate them together and push once per coherent set.
- Ask "does every branch still make sense together?" before pushing.
