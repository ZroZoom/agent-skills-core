---
name: review-agent
description: "AI-agent PR auditor. Reviews Claude/Codex PRs against the linked issue, acceptance criteria, placeholder risk, tests, and project rules. Trigger when: /review-agent, review agent work, audit AI PR, sprawdź pracę agenta."
---

# Review Agent Skill

Audit a PR produced by Claude, Codex, Copilot, or another AI agent.

## Contract

- Input: PR number or current branch PR.
- Output: verdict `approve`, `needs-fixes`, or `reject` with evidence.
- Side effects: none by default. Do not approve, request changes, comment, or resolve threads unless explicitly asked.

## Workflow

### 1. Fetch PR context

```bash
PR=1234
gh pr view "$PR" \
  --repo <OWNER>/<REPO> \
  --json number,title,body,state,isDraft,author,headRefName,baseRefName,additions,deletions,files,commits,reviews,statusCheckRollup,url

gh pr diff "$PR" --repo <OWNER>/<REPO>
```

Fetch unresolved review threads separately if thread state matters:

```bash
gh api graphql -F pr="$PR" -f query='
query($pr: Int!) {
  repository(owner: "<OWNER>", name: "<REPO>") {
    pullRequest(number: $pr) {
      reviewThreads(first: 100) {
        nodes {
          id isResolved isOutdated path line
          comments(first: 5) { nodes { author { login } body createdAt outdated } }
        }
      }
    }
  }
}'
```

### 2. Find linked acceptance criteria

Read PR body for `Closes #...`, `Fixes #...`, or issue references. Fetch each linked issue:

```bash
gh issue view ISSUE_NUMBER \
  --repo <OWNER>/<REPO> \
  --json number,title,body,labels,milestone,state,url
```

If no issue is linked, mark this as a review risk.

### 3. Inspect the changed files locally

Check out or fetch the branch if needed, then inspect only changed files:

```bash
gh pr checkout "$PR"
CHANGED_FILES_FILE=$(mktemp)
gh pr view "$PR" --json files --jq '.files[].path' > "$CHANGED_FILES_FILE"
cat "$CHANGED_FILES_FILE"
```

Search for AI-quality risks in changed files:

```bash
while IFS= read -r file; do
  [ -f "$file" ] && rg -n "TODO|FIXME|placeholder|lorem|dummy|mock|example\\.com|coming soon|wkrótce|as any|eslint-disable" "$file"
done < "$CHANGED_FILES_FILE"
```

Also check for:

- generated files committed without the generator being run
- edits to `public/locales/*`
- missing translations in `src/locales/{pl,en,uk}`
- permanent `as any` Supabase fixes
- AI Act violations: AI grading, profiling, adaptive learning, behavior monitoring
- broad refactors unrelated to the issue

### 4. Evaluate tests and checks

Use PR check data first:

```bash
gh pr checks "$PR" --repo <OWNER>/<REPO>
```

If local verification is needed, run the narrowest meaningful command:

- docs-only: no local test required, but say so
- TypeScript behavior: `npm run typecheck`
- lint-sensitive changes: `npm run lint`
- content changes: `npm run validate:content`
- route/UI changes: targeted Playwright spec or manual path list
- release-risk changes: `npm run build`

### 5. Verdict rubric

| Verdict | Use when |
|---|---|
| `approve` | Acceptance criteria are met, checks are green, no meaningful placeholders or policy risks. |
| `needs-fixes` | The intent is right but there are missing tests, incomplete AC, risky placeholders, or small correctness bugs. |
| `reject` | The PR solves the wrong problem, violates policy, breaks architecture, fabricates content, or is too incomplete to patch safely. |

## Output Format

```markdown
## Review Agent Verdict

**PR:** #1234 Title
**Verdict:** approve / needs-fixes / reject
**Linked issues:** #...

### Findings
| Severity | File | Issue |
|---|---|---|
| high | `path:line` | ... |

### Acceptance criteria
- [x] ...
- [ ] ...

### Placeholder and scope scan
- ...

### Tests
- CI: ...
- Local: ...

### Required fixes
1. ...
```

If there are no findings, say that clearly and name the remaining residual risk.

## Rules

- Findings first. Avoid praise-heavy summaries.
- Use file and line references for concrete bugs.
- Do not bulk-resolve review threads.
- Do not rubber-stamp agent work only because CI passed.
- Cite `AGENTS.md` or relevant `.agent/skills/*` when rejecting scope creep or policy violations.
