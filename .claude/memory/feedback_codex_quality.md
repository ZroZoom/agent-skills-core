---
name: Codex exercise quality
description: Codex generates placeholder exercises — always audit output for topical relevance
type: feedback
---

Codex (OpenAI) inserted 84 generic placeholders instead of real topic-specific exercises (PR #1747 / issue #1741). Two patterns:
- "Calculate a + b" in lessons about symmetry, probability, solids
- Identical matching "Data/Goal/Check" copy-paste across 26 lessons

**Why:** Codex optimized for meeting the formal requirement (5-3-1 standard) without understanding lesson context.

**How to apply:**
- After every batch exercise generation by Codex → topical audit (not just structural)
- Look for patterns: `audit-param`, `audit-matching` in IDs, generic "a+b" in questions
- Script: `npx tsx scripts/audit-e8-pedagogy.ts` detects placeholders
