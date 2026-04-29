---
name: Pre-commit hooks timeout on big merges
description: validate-content + validate-exercises take 5+ min after merging 90+ files, exceeding default Bash background timeout — use foreground long timeout, never --no-verify
type: feedback
---

Pre-commit hooks (lint-staged + project validators) can take **5+ minutes** when committing a merge of 90+ files (e.g. merging main into a long-lived feature branch). The default Bash `run_in_background` timeout is 120000ms (2 min), which kills the commit silently — output looks like `(Bash completed with no output)` but the commit may or may not have landed.

**Why:** Validation runtime often scales with the number of project files (lint-staged amplifies on big merges, content/data validators iterate full corpora). When the agent panics and uses `--no-verify` to escape, real lint/type errors slip into PR-level CI and cost extra round-trip cycles.

**How to apply:**
- For commits after large merges, use foreground Bash with `timeout: 600000` (10 min). Use `git commit -F /tmp/msg.txt` so multi-line message can't fail to parse.
- **Never** use `--no-verify` to escape slow hooks — they catch real bugs and CLAUDE.md prohibits it.
- If unsure how big the merge is, `git diff --stat HEAD..ORIG_HEAD | tail -1` — anything >50 files = expect 3+ min hooks.
