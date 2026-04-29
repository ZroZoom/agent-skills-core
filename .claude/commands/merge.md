# Merge PR

Merge a PR via the manual checklist (default) or via an automated merge supervisor (optional, project-specific).

> **Authoritative reference for the manual loop:** `.agent/skills/repo-ops/SKILL.md` → section 9 (review threads) and `CLAUDE.md` → `PR Management`. **If a snippet here drifts from those, they win.**

> **Required tooling:** `gh`, `git`, `jq`. Set `set -euo pipefail` at the top of any multi-step block.

## 1. Identify the PR

```bash
set -euo pipefail
PR="${1:-$(gh pr view --json number --jq '.number')}"
gh pr view "$PR" --json number,title,state,headRefName,mergeStateStatus,reviewDecision
```

## 2. Run the merge loop

> **Default (works without project-specific tooling):** the manual loop in step 2a.
>
> **Optional (if your project has it):** a merge supervisor script (e.g. `tools/pr-merge-supervisor.ts`) automates `wait_reviews → resolve_threads → check_ci → update_branch → re-arm auto-merge → verify_merged`. Use step 2b instead, then jump to step 3.

### 2a. Manual loop

```bash
set -euo pipefail
PR="${PR:?set PR}"

# 1. Fetch unresolved review threads (read them — never bulk-resolve without reading)
gh api graphql \
  -f query='query($owner:String!,$repo:String!,$pr:Int!) {
    repository(owner:$owner,name:$repo) {
      pullRequest(number:$pr) {
        reviewThreads(first:100) {
          nodes { id isResolved path line comments(first:5) { nodes { body author { login } } } }
        }
      }
    }
  }' \
  -F owner='<OWNER>' -F repo='<REPO>' -F pr="$PR"

# 2. Fix code or reply with rationale ("won't fix — [reason]"). Push if code changed.

# 3. Resolve each thread you've actually addressed (batch in one mutation when you can):
gh api graphql -f query='
  mutation {
    t1: resolveReviewThread(input:{threadId: "<THREAD_ID_1>"}) { thread { isResolved } }
    t2: resolveReviewThread(input:{threadId: "<THREAD_ID_2>"}) { thread { isResolved } }
  }'

# 4. CI green check
gh pr checks "$PR"

# 5. Update branch if behind main
gh pr view "$PR" --json mergeStateStatus --jq '.mergeStateStatus'
# If "BEHIND": update via UI / API, then re-check CI

# 6. Merge (squash + auto; merge queue compatible)
gh pr merge "$PR" --squash --auto
```

**CRITICAL:** after a push that fixes review comments, you must re-loop — a new push triggers new bot reviews (new threads), `update-branch` can silently drop auto-merge, and CI restarts. Keep looping until: 0 unresolved threads + CI green + `mergeStateStatus=CLEAN` + actually merged.

### 2b. Optional: project-specific supervisor

If your project ships a merge supervisor (a script that automates the loop above and exits with a status code), invoke it. Example shape:

```bash
npx tsx tools/pr-merge-supervisor.ts "$PR"
```

Recommended exit-code contract for any supervisor implementation:

| Code | Meaning | What to do |
|---:|---|---|
| 0 | MERGED | proceed to step 3 |
| 1 | BLOCKED_MANUAL | follow the printed checklist (read threads → fix → push → re-run) |
| 2 | TIMEOUT | CI is slow / stuck — `gh pr checks` then re-run |
| 3 | ERROR | unexpected — fix and re-run |

> A supervisor is just an orchestrator over the manual loop. If your project doesn't have one, step 2a is sufficient.

## 3. Post-merge cleanup

Only after the merge actually landed (verify with `gh pr view "$PR" --json state,mergedAt`):

```bash
set -euo pipefail
git checkout main && git pull
git branch -d "$BRANCH_NAME" 2>/dev/null || true

# Close linked issues automatically? Check what the PR closed
gh pr view "$PR" --json closingIssuesReferences --jq '.closingIssuesReferences[].number'
```

Run the post-merge checklist from `CLAUDE.md` → `Post-Merge Checklist`.

## 4. Summary

Display: PR number, title, merge status, closed issues.

## Rules

- **NEVER use `--admin`** — it bypasses branch protection.
- **NEVER skip the loop** — "auto-merge set" is NOT the end. You must verify `state == "MERGED"`.
- **NEVER close downstream tickets** (Jira / Linear) without verifying QA on production first.
