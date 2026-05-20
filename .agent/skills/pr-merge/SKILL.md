---
name: pr-merge
description: "PR merge supervisor workflow. Use to merge a GitHub PR safely — resolve review threads correctly, check CI, run an optional repo supervisor, and do post-merge cleanup. Trigger when: /merge, merge PR, complete a PR, finalize a PR."
---

# PR Merge Skill

Merge a PR cleanly. Do not call a merge done until the post-merge checks pass.

## Contract

- Input: PR number, or current branch's PR.
- Output: merge status, closed issues, and cleanup status.
- Side effects: may resolve review threads, commit fixes, push, and enqueue
  auto-merge.

## Mandatory Memory Consult

Read these before starting (skip silently if a file does not exist):

- `.claude/memory/feedback_hooks_timeout_big_merges.md`
- `.claude/memory/feedback_batch_merge_cascade.md`
- `.claude/memory/feedback_fetch_before_push.md`
- `.claude/memory/feedback_for_testing_flow.md`
- `.claude/memory/feedback_post_merge.md`
- `.claude/memory/feedback_pr_review_loop.md`
- `.claude/memory/feedback_use_merge_command.md`
- `.claude/memory/feedback_update_branch.md`

If `MEMORY.md` has newer merge, Git workflow, automation, or post-merge
entries, read those too.

## Workflow

### 1. Identify PR

Use the provided number, or find the current branch PR:

```bash
gh pr view --json number,title,state,headRefName
```

### 2. Run Supervisor (if the project provides one)

If `tools/pr-merge-supervisor.ts` (or any equivalent merge supervisor)
exists in the repo, use it. The supervisor automates the full loop:
update-branch → mark ready → wait for review bots → check threads → check
CI → verify merged. When manual action is needed, it converts the PR to
draft, prints a checklist, and exits non-zero. Fix issues, then re-run.

```bash
npx tsx tools/pr-merge-supervisor.ts <PR_NUMBER>
```

Exit handling:

| Code | Meaning | Action |
|---|---|---|
| 0 | merged | proceed to cleanup |
| 1 | blocked manual | follow printed checklist, fix, then re-run supervisor |
| 2 | timeout | inspect `gh pr checks`, then re-run supervisor |
| 3 | error | read error, fix root cause, then re-run supervisor |

**Never say "done" until the supervisor exits with code 0** (or you have
completed the manual workflow below and verified merge).

### 3. Manual Workflow (if no supervisor or after supervisor block)

1. **Resolve ALL review conversations** — including bot reviews (Copilot,
   Gemini, etc.). Use the GraphQL `resolveReviewThread` mutation — replying
   is NOT enough:

   ```bash
   gh api graphql -f query='mutation { resolveReviewThread(input: {threadId: "THREAD_ID"}) { thread { isResolved } } }'
   ```

2. **Verify CI is green** — `gh pr checks` must show all passing.
3. **Update branch** if behind main — use the GitHub API `update-branch`
   endpoint or rebase locally.
4. **Merge**: `gh pr merge --squash --auto` (works with merge queues;
   `--admin` is forbidden — it bypasses protection).

If CI failed transiently (network timeout, API 500):
`gh run rerun <run-id> --failed` re-runs only failed jobs.

### 4. Post-merge Cleanup

Only after merge confirmed:

```bash
git checkout main
git pull
git branch -d <BRANCH_NAME> 2>/dev/null
gh pr view <PR_NUMBER> --json closingIssuesReferences \
  --jq '.closingIssuesReferences[].number'
```

Then close any linked non-GitHub tickets (Jira/Linear) per the project's
post-merge rules (see `.agent/skills/repo-ops/SKILL.md`).

## Rules

- **Never use `--admin`** — it bypasses branch protection.
- **Never skip the supervisor re-run after fixes** — its state machine
  expects to observe the post-fix outcome.
- **Do not treat "auto-merge set" as merged** — wait for the merge to
  actually complete.
- **Resolve review threads only after reading them** — don't mechanically
  bulk-resolve. Bot threads block merge just like human reviews.
- **E2E and smoke checks** may run only in the merge queue (not on every
  PR push) if the repo uses queued batches. Adjust expectations
  accordingly when reading `gh pr checks`.
