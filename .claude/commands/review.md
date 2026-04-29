# Review a pull request

Project-level override of the built-in `/review`. Performs the standard code review **plus** assesses existing reviewer comments (Copilot, Gemini, CodeRabbit, humans) and surfaces conflicts.

> **Why this exists.** Across PRs with multiple automated reviewers, the unfiltered comment pile-up is a leading cause of "5-rounds-not-enough" merges. Around 80% of threads typically come from bots; the most useful work is separating actionable suggestions from scope-creep nags. Adjust the heuristics in step 5 to match your project's experience and store new patterns in `.claude/memory/`.

> **Required tooling:** `gh`, `jq`. **`<OWNER>` / `<REPO>` resolve from `.agent/context/project-ids.md`** — halt if still placeholders.

## 1. Resolve PR number

If no PR number in args:

```bash
set -euo pipefail
gh pr list --state open --limit 10 --json number,title,headRefName,statusCheckRollup
```

Pick the PR or ask the user.

## 2. Fetch PR metadata + diff

```bash
set -euo pipefail
PR="${1:?usage: /review <PR_NUMBER>}"
gh pr view "$PR" --json number,title,state,mergeable,mergeStateStatus,headRefName,baseRefName,additions,deletions,files
gh pr diff "$PR"
```

## 3. Generate own code review

Sections (concise, but thorough):

- **Overview** — what the PR does
- **Code correctness** — hoisting, edge cases, error paths, type widening
- **Project conventions** — branch naming, commit style, mirrored patterns from `CLAUDE.md`
- **Performance** — only flag if measurable
- **Test coverage** — gaps, not nitpicks
- **Security** — input validation, secrets, file paths
- **Suggestions** — labeled (Polish, Optional, Worth flagging) with priority

## 4. Fetch existing review threads

```bash
set -euo pipefail
gh api graphql \
  -F owner='<OWNER>' -F repo='<REPO>' -F pr="$PR" \
  -f query='query($owner:String!,$repo:String!,$pr:Int!) {
    repository(owner:$owner, name:$repo) {
      pullRequest(number:$pr) {
        reviewThreads(first: 100) {
          totalCount
          nodes {
            id isResolved isOutdated path line
            comments(first: 5) {
              nodes { author { login } body createdAt outdated }
            }
          }
        }
      }
    }
  }' \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved | not)'
```

Plus top-level review summaries (overall verdicts):

```bash
gh pr view "$PR" --json reviews --jq '.reviews[] | select(.body != "") | {author: .author.login, state, body: .body[:300], submittedAt}'
```

## 5. Assess each unresolved thread

For each thread from step 4 where `isResolved == false` AND no comment has `outdated == true`:

| Field | Value |
|---|---|
| **Source** | bot vs human — common bot logins: `copilot-pull-request-reviewer`, `Copilot`, `gemini-code-assist`, `coderabbitai*` |
| **Location** | `path:line` |
| **Suggestion type** | actionable code suggestion (has GitHub `suggestion` block) vs prose advice |
| **Verdict** | one of: **AGREE** / **DISAGREE** / **PARTIAL** / **OUTDATED** / **DUPLICATE** |
| **Why** | one line — reference code, project convention, or memory rule |

Default heuristics (each cites a real file in `.claude/memory/`):

- **Bot scope-creep** ([`feedback_codex_quality.md`](../memory/feedback_codex_quality.md), [`feedback_bot_review_triage.md`](../memory/feedback_bot_review_triage.md)) — Copilot/Gemini/CodeRabbit often demand refactors of pre-existing code touched only incidentally. → DISAGREE if the suggestion expands scope.
- **Bot conflicts** — when two bots disagree (e.g., one says "extract helper", another says "leave it"), prefer the one aligned with this project's `CLAUDE.md` rules. Cite the section.
- **Read before resolve** ([`feedback_pr_review_bots.md`](../memory/feedback_pr_review_bots.md)) — never bulk-resolve threads. Each verdict must reference the actual comment text.
- **Outdated suggestions** — if a comment was posted before recent commits to the same file, mark OUTDATED rather than re-evaluating its body verbatim.
- **Grounding** ([`feedback_grounding_in_project.md`](../memory/feedback_grounding_in_project.md)) — assess against THIS project's conventions, not generic best practices.

> **Add your own.** When a new pattern appears (a specific bot inventing API names, a recurring scope-creep theme, etc.), record it in `.claude/memory/feedback_<slug>.md` via `/self-analysis` and add a row above. The heuristics here should reflect actual rules in your repo's memory directory.

## 6. Surface decisions

After assessing:

```
## Existing reviews — assessment

**Bots: <N> threads (Copilot: <M>, Gemini: <K>, ...)**
- ✅ AGREE (<count>) — concrete fixes worth applying
- ❌ DISAGREE (<count>) — scope-creep / pre-existing / wrong API claim
- 🟡 PARTIAL (<count>) — apply parts, reject parts
- ⏭️ OUTDATED (<count>) — already addressed by recent commits

**Humans: <N> threads**
- ... (assess each individually, NEVER bulk-DISAGREE human reviews)

**Conflicts:**
- Bot A says X, Bot B says Y → recommend Z because <reason>
- My own review §<section> contradicts <author>:<line> → recommend Z

**Actionable items (in priority order):**
1. <thread-id> [<priority>] — apply suggestion at <path:line> (<reviewer>)
2. ...
```

## 7. Output discipline

- **Never bulk-resolve** threads from this skill alone — assessment is advisory; the user (or `/merge`) handles resolution.
- **Length cap** — if >20 threads to assess, group similar ones (e.g., "5 Copilot threads about EOL handling — all flagged DISAGREE: same root cause, see thread #1") instead of repeating verdicts.
- For **AGREE** items, name the exact change to make next, not "consider X".
- For **DISAGREE** items, cite the rule (memory file, `CLAUDE.md` section) so the user can verify the decision.
- Surface PR-level review verdicts (`REQUEST_CHANGES`, `APPROVED`) separately from line-level threads — they often have different intent.

## Notes

- Bot login names above are the ones commonly seen. If a new bot appears, add its login pattern to step 5 and to a new memory file.
- The GraphQL query uses `first: 100` — paginate with `pageInfo.endCursor` if a PR exceeds that.
