---
name: Verify bot suggestions before incorporating
description: When bots suggest factual claims or behavior changes, verify against source code or primary docs first
type: feedback
---

When a review bot suggests adding a factual claim to documentation or code comments, verify the claim against the actual implementation first. Bot suggestions about code behavior are hypotheses, not facts.

**Why:** A bot can confidently propose a flag, API behavior, or implementation detail that is plausible but false. Copying that claim into docs/code creates a second bug and usually triggers another review round.

**How to apply:**
- When a bot says "also mention X" or "add Y", read the source file or official docs before agreeing.
- Especially verify option flags, API parameters, config defaults, generated-file behavior, and framework semantics.
- When fixing many bot comments in one batch, verify each factual claim independently. Volume should not reduce rigor.
