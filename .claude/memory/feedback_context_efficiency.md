---
name: Be efficient with context window
description: Trim bash output, use offset/limit on reads, pipe through tail/head to save context tokens
type: feedback
---

Minimize context usage to avoid premature autocompact:

- Pipe long bash output through `| tail -N` or `| head -N` (especially build logs, git push output)
- Use `offset/limit` when reading files instead of reading entire files
- Don't re-read files already in context

**Why:** Git push triggers pre-push hooks with full build output (~741KB). These eat 28%+ of context window needlessly.

**How to apply:** After `git push`, use `2>&1 | tail -5` to capture just success/failure. For `git log`, limit with `-N`. For file reads, use narrow `offset/limit` ranges.
