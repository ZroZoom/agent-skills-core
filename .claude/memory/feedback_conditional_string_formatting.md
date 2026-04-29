---
name: Enumerate cases for conditional string formatting
description: When fixing string formatting with conditional punctuation (colons, spaces), enumerate all input→output cases before coding
type: feedback
---
When building strings with conditional punctuation (e.g., label + value + colon), enumerate ALL input→output cases before writing logic.

**Why:** On PR #1892, a colon-dedup fix required 3 iterations because each attempt handled one case but broke another. The regex approach (`/[:\s]$/`) was fragile — it controlled the space but not the trailing colon.

**How to apply:** Write out a table first:
- `"Podzielność przez" + "2"` → `"Podzielność przez 2:"`
- `"Sytuacja ze świata:" + "17 cukierków"` → `"Sytuacja ze świata: 17 cukierków"`
Then use explicit `endsWith()` checks with separate branches — not regex.
