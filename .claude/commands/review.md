# Review a pull request

Project-level override of the built-in `/review`. Performs the standard code review **plus** assesses existing reviewer comments (Copilot, Gemini, humans) and surfaces conflicts.

Optimized for this repo's review patterns observed across open PRs (2026-04-27): median ~10 review threads per PR, max ~30, ~80% from bots. The 5-rounds-not-enough cases (PR #1976: 20 threads, #1986: 28) come from unfiltered bot suggestions piling up.

## 1. Resolve PR number

If no PR number in args:
```bash
gh pr list --state open --limit 10 --json number,title,headRefName,statusCheckRollup
```
Pick the PR or ask the user.

## 2. Fetch PR metadata + diff

```bash
gh pr view <num> --json number,title,state,mergeable,mergeStateStatus,headRefName,baseRefName,additions,deletions,files
gh pr diff <num>
```

## 3. Generate own code review

Sections (concise, but thorough):
- **Overview** — what the PR does
- **Code correctness** — hoisting, edge cases, error paths, type widening
- **Project conventions** — branch naming, commit style, mirrored patterns from CLAUDE.md
- **Performance** — only flag if measurable
- **Test coverage** — gaps, not nitpicks
- **Security** — input validation, secrets, file paths
- **Suggestions** — labeled (Polish, Optional, Worth flagging) with priority

## 4. Fetch existing review threads

```bash
gh api graphql -f query='
{
  repository(owner: "<OWNER>", name: "<REPO>") {
    pullRequest(number: <num>) {
      reviewThreads(first: 100) {
        totalCount
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          comments(first: 5) {
            nodes {
              author { login }
              body
              createdAt
              outdated
            }
          }
        }
      }
    }
  }
}' --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved | not)'
```

Plus top-level review summaries (overall verdicts):
```bash
gh pr view <num> --json reviews --jq '.reviews[] | select(.body != "") | {author: .author.login, state, body: .body[:300], submittedAt}'
```

## 5. Assess each unresolved thread

For each thread from step 4 where `isResolved == false` AND no comment has `outdated == true`:

| Field | Value |
|---|---|
| **Source** | bot vs human — bot patterns: `copilot-pull-request-reviewer`, `gemini-code-assist`, `Copilot`, `coderabbitai*` |
| **Location** | `path:line` |
| **Suggestion type** | actionable code suggestion (has GitHub `suggestion` block) vs prose advice |
| **Verdict** | one of: **AGREE** / **DISAGREE** / **PARTIAL** / **OUTDATED** / **DUPLICATE** |
| **Why** | one line — reference code, project convention, or memory rule |

Assessment heuristics for this repo (from `.claude/memory/`):

- **Bot scope-creep nag** (`feedback_copilot-scope-nag.md`, `feedback_codex_quality.md`): Copilot/Gemini often demand refactors of pre-existing code touched only incidentally. → DISAGREE if the suggestion expands scope; cite the rule.
- **Bot conflicts**: when Copilot and Gemini disagree (e.g., one says "extract helper", other says "defer pre-existing"), prefer the one aligned with CLAUDE.md "don't add abstractions beyond what the task requires" rule.
- **Verify reviewer API claims** (`feedback_verify-reviewer-api-claims.md`): bots invent GraphQL union/field names. If a suggestion edits API code, verify against official docs before agreeing.
- **AI-fabricated content** (`feedback_no-fabricated-domain-content.md`): if a bot suggests adding curriculum codes, legal refs, or scientific facts → DISAGREE without authoritative source.
- **Outdated suggestions**: if a comment was posted before recent commits to the same file, mark OUTDATED rather than re-evaluating its body verbatim.

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
1. <thread-id> [<priority>] — apply suggestion at <path:line> (Copilot)
2. ...
```

## 7. Output discipline

- **Never bulk-resolve** threads from this skill alone — assessment is advisory; the user/another command (`/merge`) handles resolution.
- **Length cap**: if >20 threads to assess, group similar ones (e.g., "5 Copilot threads about EOL handling — all flagged DISAGREE: same root cause, see thread #1") instead of repeating verdicts.
- For **AGREE** items: name the exact change to make next, not "consider X".
- For **DISAGREE** items: cite the rule (memory file, CLAUDE.md section) so the user can verify the decision.
- Surface PRR-level review verdicts (REQUEST_CHANGES, APPROVED) separately from line-level threads — they often have different intent.

## Notes for fresh repos

- Bot login names listed above are the ones seen in this repo. If a new bot appears (CodeRabbit, etc.), add its login pattern to the bot-detection list in step 5 and to memory.
- The GraphQL query in step 4 uses `first: 100` — sufficient for all PRs observed in this repo. If a PR exceeds 100 threads, paginate with `pageInfo.endCursor`.
