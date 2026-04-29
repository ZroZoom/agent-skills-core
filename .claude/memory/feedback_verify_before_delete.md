---
name: Verify before destructive git operations
description: Before deleting branches, check each one individually — don't batch delete with warnings
type: feedback
---

Before deleting local branches, verify each one individually. If `git branch -d` gives warnings ("not fully merged", "not yet merged to HEAD"), STOP and investigate before proceeding.

**Why:** User got scared when I batch-deleted 4 branches and 3 had warnings. Even though all were safe (squash merge), I should have explained the warnings BEFORE deleting, not after.

**How to apply:**
1. Check PR status for each branch first
2. If `git branch -d` warns about unmerged — explain why (squash merge) and ask before using `-D`
3. Never batch force-delete without user confirmation
