---
name: Batch-merge cascades conflicts to other open PRs
description: Merging 5+ PRs in one session forces all other open feature branches to need rebase, especially in shared/generated files — plan before mass-merging
type: feedback
---

After merging 5+ PRs in one session, every OTHER open feature branch tends to develop conflicts in:
- generated files committed to the repo (e.g. `src/generated/*.json`, build artifacts)
- shared config (e.g. `package.json`, type definitions, design-system files)
- frequently-touched shared components

**Why:** Even structurally tiny changes to generated/shared files cause `dirty`/`behind` status across all open PRs. If five different feature branches each need a rebase + force-push + CI re-run, that's 5× CI burn and a context-switch tax for every author whose branch you forced into rebase.

**How to apply:**
- Before mass-merging, list other-author open PRs that touch shared files. Check via `gh pr list --json files`.
- If overlap exists, **interleave your merges with the other author's** so cascading rebases happen one branch at a time, not five at once.
- For pure generated-file conflicts on someone else's PR: take `main`'s version and let their next push regenerate. For shared code: review and resolve. For domain content owned by another author: escalate, never resolve unilaterally.
