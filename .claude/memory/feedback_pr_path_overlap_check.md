---
name: Check open PR path overlap before bundling leftovers
description: Before committing leftover or unrelated files to a branch, inspect open PR file lists for the same paths
type: feedback
---

Before bundling leftover or unrelated changes into a feature branch, inspect open PR file lists for the same paths. If a peer PR already touches the same files, prefer leaving those changes to that PR or asking the user.

**Why:** Duplicate "cleanup" commits in multiple PRs create noisy diffs, confusing review context, and avoidable merge conflicts. Shared memory/docs/config files are especially prone to this when several agents work in parallel.

**How to apply:**
- Run a cheap file-list scan before adding unrelated changes:
  `gh pr list --state open --limit 100 --json number,url,files`
- Look for exact paths and directory prefixes that overlap with your leftovers.
- If overlap exists, surface it immediately and propose the lower-conflict default.
- For cross-agent memory directories, assume parallel edits are common.
