---
name: Documentation is reviewed like code
description: SESSION_LEARNINGS and SKILL.md go through full bot review — shell commands must be technically correct
type: feedback
---

Internal documentation (SESSION_LEARNINGS.md, SKILL.md) is reviewed by bots the same way as code. Shell commands must be technically correct.

**Why:** A one-line grep in SESSION_LEARNINGS.md generated 4 review comments across 3 iterations: false positives (`level:` matching in body text), logic bug (`grep -v ':1$'` excludes 11/21), missing globstar in bash, `{subject}` treated as literal. 3 out of 4 were justified.

**How to apply:** When adding commands to documentation — verify: anchoring (`^`), filter correctness, portability (find vs globstar), numeric edge cases. Treat it like code review, not a note.
