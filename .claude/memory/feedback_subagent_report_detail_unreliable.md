---
name: Subagent self-reports can hallucinate detail
description: Implementer subagents may describe fabricated fixture names or file details even when commits and test counts are real
type: feedback
---

When an implementer subagent reports completion, verify the narrative details against actual commits, files, and tests. Numeric claims such as "commit exists" or "N tests passed" are often more reliable than prose claims about exactly what was tested.

**Why:** Subagents can accurately finish a bounded code task while embellishing the summary with fixture names, file shapes, or extra cases that do not exist. Trusting the prose can hide coverage gaps.

**How to apply:**
- After a subagent reports done, run `git show --stat <sha>` and sample the changed tests/files.
- Grep test names or assertions instead of trusting "I added cases for X, Y, Z".
- For non-trivial delegated work, pair implementer output with a reviewer pass that reads the actual diff.
- If the report mentions unexpected scope, verify whether that scope really changed.
