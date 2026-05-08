---
name: Always git add explicit paths
description: Use explicit git add paths; never sweep with git add -A or git add . because runtime and IDE artifacts can leak into commits
type: feedback
---

Use explicit paths for every `git add`. Avoid `git add -A`, `git add .`, and `git add :/`. The few seconds saved by sweeping are not worth the cleanup risk.

**Why:** Sweeping can stage untracked runtime directories, IDE caches, generated hook files, or unrelated edits from another task. This pollutes commits and can trigger remote push or review failures.

**How to apply:**
- Run `git status --short`, then stage only the paths that belong to this change: `git add path/to/file1 path/to/file2`.
- For larger commits, build the explicit path list from modified tracked entries and inspect untracked entries separately.
- Never include `??` entries unless you have verified each one belongs in the commit.
- Globs are fine when they are narrow and reviewable, such as `git add tools/*.ts tools/__tests__/*.ts`.
