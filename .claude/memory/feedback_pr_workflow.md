---
name: PR workflow - one at a time
description: Create and merge PRs sequentially, not in parallel, to avoid CI overload
type: feedback
---

Create and merge PRs one at a time — never open multiple PRs in parallel.

**Why:** Opening multiple PRs simultaneously causes CI to restart on each push, slowing down the entire pipeline.

**How to apply:** For multiple changes: create PR → wait for CI → merge → then start the next PR.
