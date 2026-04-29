# Merge PR

Merge a PR using the automated supervisor. Run EVERY step:

## 1. Identify PR

```bash
# If user gave a PR number, use it. Otherwise find PR from current branch:
gh pr view --json number,title,state,headRefName
```

## 2. Run Merge Supervisor

The supervisor is a state machine that handles the full loop:
push → wait for reviews → resolve threads → check CI → update branch → re-arm auto-merge → verify merged.

```bash
npx tsx tools/pr-merge-supervisor.ts PR_NUMBER
```

### Exit codes:
- **0 = MERGED** → proceed to step 3 (cleanup)
- **1 = BLOCKED_MANUAL** → supervisor printed a checklist. Follow it:
  1. Read each unresolved thread
  2. Fix code or reply with rationale ("won't fix — [reason]")
  3. Resolve threads via GraphQL: `gh api graphql -f query='mutation { resolveReviewThread(input: {threadId: "THREAD_ID"}) { thread { isResolved } } }'`
  4. If code changed: `git add + commit + push`
  5. If only CI failed transiently (GitHub API 500, network): `gh run rerun <run-id> --failed` — no push needed
  6. **Re-run supervisor**: `npx tsx tools/pr-merge-supervisor.ts PR_NUMBER`
  7. **Repeat until exit code 0**
- **2 = TIMEOUT** → CI is slow or stuck. Check `gh pr checks`. Re-run supervisor.
- **3 = ERROR** → unexpected failure. Read error, fix, re-run.

### CRITICAL: Do NOT skip the re-run loop.
After fixing threads and pushing, you MUST re-run the supervisor because:
- New push triggers new Copilot/Gemini reviews (new threads!)
- update-branch silently drops auto-merge
- CI restarts after every push

## 3. Post-merge cleanup

Only after supervisor exits with code 0:

```bash
git checkout main && git pull
git branch -d BRANCH_NAME 2>/dev/null

# Close linked issues
gh pr view PR_NUMBER --json closingIssuesReferences --jq '.closingIssuesReferences[].number'
```

## 4. Summary

Display: PR number, title, merge status, closed issues.

## Rules

- **NEVER use `--admin`** — it bypasses branch protection
- **NEVER skip the supervisor loop** — "auto-merge set" is NOT the end
- **NEVER close Jira tickets** without verifying QA on production first
