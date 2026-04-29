---
name: Scan for new tools at session start
description: Check git log for new scripts/tools added since last session — don't get surprised by pr-merge-supervisor
type: feedback
---

At the start of a session, scan recent commits for new tools, scripts, or slash commands that were added by other sessions/agents.

**Why:** Session didn't know about `tools/pr-merge-supervisor.ts` (added in PR #1787) and used ad-hoc merge commands instead. User had to point out the new tool.

**How to apply:** Early in session: `git log --oneline -20 -- tools/ .claude/commands/ scripts/` to spot new tooling.
