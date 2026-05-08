---
name: Fetch remote before pushing to an active PR branch
description: Automation may add merge/update commits to a PR branch, so fetch and reconcile before pushing local commits
type: feedback
---

Before pushing to a PR branch that is under review, merge-queue supervision, or update-branch automation, fetch the remote branch and check divergence. Automation can add commits that your local branch does not have.

**Why:** Tools that update a branch with the base branch can silently add a merge commit. Pushing from an older local branch then fails as non-fast-forward or risks overwriting peer/automation work if force is used.

**How to apply:**
- Before pushing: `git fetch origin <branch-name>`.
- Compare `git log origin/<branch-name>..HEAD` and `git log HEAD..origin/<branch-name>`.
- If the branch diverged, rebase or merge before pushing.
- In long review loops, repeat this check after supervisor/update-branch steps and before every push.
