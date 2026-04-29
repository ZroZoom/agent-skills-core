# Review Agent Work

Audit a PR produced by Claude/Codex/Copilot against the linked issue and repo rules.

Load `.agent/skills/review-agent/SKILL.md` and follow it.

## Arguments

- Optional PR number. If absent, resolve the PR for the current branch.

## Required flow

1. Fetch PR metadata, diff, checks, reviews, and unresolved threads.
2. Fetch linked issue acceptance criteria.
3. Inspect changed files for placeholders, scope creep, missing translations, policy violations, and permanent `as any`.
4. Compare implementation against acceptance criteria.
5. Return verdict: `approve`, `needs-fixes`, or `reject`.

## Output

Findings first, ordered by severity, with file references. If no issues are found, say so clearly and list residual risk/test gaps.
