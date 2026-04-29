# Session Self-Analysis

Perform a self-analysis of the current session and record findings. Run at the end of a session or when the user has flagged issues.

## 1. Review Signals

Analyze interactions in the current session:
- Did the user have to clarify their question?
- Did the user ask for a format change?
- Were there requests for factual corrections?
- Did the user repeat the same instructions?
- Did review bots (Copilot, Gemini) catch code issues?

If no friction was detected — say so briefly and end.

## 2. Categorization

For each issue found, assign a category:
- **Format**: Wrong structure, length, style
- **Substance**: Factual error, failure to use existing patterns
- **Tone**: Too formal/casual
- **Logic**: Flawed reasoning, missed instructions

## 3. 5 Whys Analysis

For the most important issue, ask "why?" until you reach the root cause. 3-5 steps is enough.

## 4. Formulate Rules

Format: `[Trigger/Context] -> [Expected behavior]`

Examples of good rules:
- ✅ `[Writing RLS policy] -> Check is_admin() helper; use DROP IF EXISTS`
- ✅ `[Integrating existing function] -> Read its implementation first`
- ❌ `Be more careful` (too vague)

## 5. Record Findings

**Primary target: memory files** (`~/.claude/projects/.../memory/feedback_*.md`).
Memory is loaded into context automatically on every session start — it has the highest impact.

For each new rule, choose the right destination:

| Type | Destination | When |
|------|-------------|------|
| **Process/workflow feedback** | `memory/feedback_*.md` (SSOT) | Agent behavior, PR workflow, review patterns, user preferences |
| **Technical gotcha** | `.agent/SESSION_LEARNINGS.md` | Code-level patterns (React, SVG, npm, LaTeX) that are too specific for memory |
| **Domain skill rule** | `.agent/skills/*/SKILL.md` | SQL, ESLint, UI, tests, content rules tied to a specific skill |

### Deduplication check (REQUIRED)

Before saving any rule:
- **Check memory files** — `ls` the memory directory and grep for keywords
- **Check SESSION_LEARNINGS.md** — grep for the concept
- **Check relevant SKILL.md** — if domain-specific

If a memory file already covers the concept → update it (add detail, link to new incident). Do NOT create a duplicate in SESSION_LEARNINGS.

### Memory file format

```markdown
---
name: Short rule name
description: One-line description (used for relevance matching)
type: feedback
---

Rule statement.

**Why:** Incident that caused this rule.

**How to apply:** When/where this guidance kicks in.
```

After creating the file, add a one-line pointer to `MEMORY.md` in the same memory directory.

**Important:**
- Use bullet points (`-`), not numbered lists
- Do not add rules that already exist in any of the three targets
- Rules must be specific and verifiable
- Add context explaining "why" so future agents can assess edge cases

## 6. Sync to repo memory

User memory (`~/.claude/projects/.../memory/`) is per-machine and invisible to other agents (Codex, Copilot, peer Claudes on other machines). The repo has a parallel tracked memory at `.claude/memory/` — that's the cross-agent SSOT.

**For each rule saved to user memory in step 5, decide:**

| Rule kind | Sync to `.claude/memory/`? |
|---|---|
| Project workflow / convention (PR flow, validation, content rules) | ✅ yes |
| Technical gotcha specific to this codebase | ✅ yes |
| User-personal preference (terse Polish, autonomous mode, dispatch style) | ❌ keep in user memory only |
| Already exists in repo memory under different name | update existing — don't duplicate |

**Sync procedure:**
- `ls .claude/memory/` — see existing files (note: repo uses `snake_case`, user memory uses `kebab-case` — match repo convention when copying)
- For each project-relevant rule: copy/adapt content from user memory → `.claude/memory/<name>.md`
- Update `.claude/memory/MEMORY.md` index — one-line pointer in the appropriate section
- Cross-check `.agent/SESSION_LEARNINGS.md` — if a one-liner there already covers the rule, the repo-memory entry is the deeper-dive version

## 7. Commit to an open PR

The sync from step 6 must NOT create a new PR. Attach the commit to an existing open PR.

**Branch resolution:**
- If currently on a feature branch, check whether it has an open PR:
  ```bash
  gh pr view --json number,state 2>/dev/null
  ```
  Suppress stderr — `gh pr view` exits non-zero with a noisy "no pull requests found" message when the branch has no PR. Treat empty output as "no PR for current branch" and fall through to the next rule.
- If output shows `"state":"OPEN"` → commit on this branch.
- Otherwise (on `main`, or current branch has no open PR) → check `gh pr list --author @me --state open --limit 5`
  - Exactly one match → check out that branch, commit, push
  - Multiple → ask the user which PR
  - Zero open PRs → DEFER. Save the diff somewhere safe (e.g., note in next session's first turn) — do NOT create a new PR just for memory sync

**Commit message format:**
```
docs(memory): sync session learnings to repo memory

- <brief list of new/updated rules>
```

Push to the PR branch. Do NOT use `--no-verify`. The PR-merge supervisor handles the rest.
