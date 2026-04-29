---
name: Use /merge slash command for PR merging
description: Always use /merge (or follow .claude/commands/merge.md) when merging PRs — it has the full checklist
type: feedback
---

When merging a PR, use the `/merge` slash command which executes `.claude/commands/merge.md`. It includes the complete checklist: unresolved threads, CI checks, branch update, merge with --auto, cleanup, and issue closing.

**Why:** User created a dedicated merge supervisor flow. Using it ensures no steps are skipped (thread resolution, branch update, post-merge cleanup).

**How to apply:** When asked to merge a PR or when a PR is ready, invoke `/merge` or follow the steps in `.claude/commands/merge.md` rather than ad-hoc merge commands.
