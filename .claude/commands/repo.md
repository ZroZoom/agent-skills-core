# Repo Operations

Repository management: creating issues/PRs, pre-merge review, labels/milestones.
The operation depends on the argument: `issue`, `pr`, `review`, `label`.
If no argument is provided — ask the user what they want to do.

---

## Operation: `issue` — Create Issue

1. Ask for the title (if not provided in arguments)
2. Ask for the type: `bug` / `enhancement` / `docs` / `refactor` / `content`
3. Determine priority: P0 Critical / P1 High / P2 Medium
4. Propose a description in this format:

```
## Problem
[what is broken or missing]

## Expected behavior
[how it should work]

## Steps to reproduce (for bugs)
1. ...
```

5. Ask user for **milestone** and capture the chosen title:
```bash
gh api repos/<OWNER>/<REPO>/milestones --jq '.[] | {number,title}'
MILESTONE="M2: Matematyka E8 Ready"  # ← replace with user's choice
```

6. Create the issue and capture the number:
```bash
ISSUE_URL=$(gh issue create \
  --title "..." \
  --body "..." \
  --label "LABEL" \
  --milestone "$MILESTONE" \
  --assignee "@me")
ISSUE_NUMBER=$(echo "$ISSUE_URL" | sed -n 's#.*/\([0-9][0-9]*\)$#\1#p')
echo "Created issue #$ISSUE_NUMBER"
```

**Note:** `--assignee "@me"` = the current GitHub user (issue owner). Use `@copilot` ONLY when delegating implementation to Copilot SWE Agent. Don't confuse assignee (responsibility) with reviewer (review-only role).

**Available labels:** `bug`, `enhancement`, `documentation`, `refactor`, `content`, `ui/ux`, `database`, `tests`, `i18n`, `accessibility`, `security` (customize for your project)

7. Add to GitHub Project and set fields:
```bash
# Get Item ID (use $ISSUE_NUMBER from step 6)
ITEM_ID=$(gh api graphql -f query='query { repository(owner: "<OWNER>", name: "<REPO>") { issue(number: '$ISSUE_NUMBER') { projectItems(first: 1) { nodes { id } } } } }' --jq '.data.repository.issue.projectItems.nodes[0].id')

# Set Priority and Size (IDs in .agent/context/project-ids.md)
gh project item-edit --project-id PVT_kwDODtV8184BKyTu --id $ITEM_ID --field-id PVTSSF_lADODtV8184BKyTuzg6jZAU --single-select-option-id PRIORITY_ID
gh project item-edit --project-id PVT_kwDODtV8184BKyTu --id $ITEM_ID --field-id PVTSSF_lADODtV8184BKyTuzg6jZAY --single-select-option-id SIZE_ID
```

8. Display the new issue URL.

> **Token scope note:** GitHub Project edits require `read:project,project` token scopes. If `gh project item-edit` fails with "missing scopes", run `gh auth refresh -s read:project,project` and ask the user to re-authenticate, then retry. Do NOT silently skip project assignment.

---

## Operation: `pr` — Create PR

1. Check the current branch — MUST be `feature/*` or `fix/*`:
```bash
git branch --show-current
git status --short
```

2. If there are uncommitted changes — stop and ask the user.

3. Push the branch if there is no remote:
```bash
git push -u origin $(git branch --show-current)
```

4. Find related issues (search commit messages and branch name):
```bash
git log main..HEAD --oneline
```

5. Ask user for **milestone** and capture the chosen title:
```bash
gh api repos/<OWNER>/<REPO>/milestones --jq '.[] | {number,title}'
MILESTONE="M2: Matematyka E8 Ready"  # ← replace with user's choice
```

6. Create the PR:
```bash
gh pr create \
  --title "..." \
  --body "$(cat <<'EOF'
## Description
[what was done and why]

## Changes
- ...

## Tests
- [ ] typecheck: `npm run typecheck`
- [ ] lint: `npm run lint`
- [ ] build: `npm run build`

## Related issues
Closes #ISSUE_NUMBER
EOF
)" \
  --label "ready-for-review" \
  --label "DOMAIN_LABEL" \
  --milestone "$MILESTONE" \
  --assignee "@me"
```

**Roles:**
- `--assignee "@me"` = the PR author / owner (responsibility for landing it).
- **Reviewers are governed by the `main` branch ruleset.** Current ruleset state:
  - `require_code_owner_review: false` and `required_reviewers: []` — CODEOWNERS may suggest owners in the GitHub UI, but reviewers are not automatically required/requested by branch protection.
  - `copilot_code_review.review_on_push: true` — Copilot reviews are triggered by pushes to the PR head ref, including draft PRs. A `ready-for-review` label change alone is not a Copilot trigger.
  - Do not pass `--reviewer "@copilot"` to `gh pr create` — gh CLI rejects it with "@copilot not found".
- **Manual reviewer context:** when a human review is needed, use `.github/CODEOWNERS` as the maintainer map (`@<MAINTAINER>`, `@<OWNER>/core-devs`, `@<OWNER>/content`); these are manual review hints, not branch-protection requirements.
- DO NOT set `@copilot` as the PR assignee — it confuses ownership with review duty.

7. (Optional) Edit labels post-create — skip if already passed at create:
```bash
gh pr edit PR_NUMBER --add-label "DOMAIN_LABEL"
```

8. Add to GitHub Project and set fields:
```bash
# Get content ID
PR_ID=$(gh pr view PR_NUMBER --json id --jq '.id')

# Add to project
ITEM_ID=$(gh api graphql -f query='mutation { addProjectV2ItemById(input: { projectId: "PVT_kwDODtV8184BKyTu", contentId: "'$PR_ID'" }) { item { id } } }' --jq '.data.addProjectV2ItemById.item.id')

# Set Status=In review, Priority, Size (IDs in .agent/context/project-ids.md)
gh project item-edit --project-id PVT_kwDODtV8184BKyTu --id $ITEM_ID --field-id PVTSSF_lADODtV8184BKyTuzg6jYRw --single-select-option-id df73e18b
gh project item-edit --project-id PVT_kwDODtV8184BKyTu --id $ITEM_ID --field-id PVTSSF_lADODtV8184BKyTuzg6jZAU --single-select-option-id PRIORITY_ID
gh project item-edit --project-id PVT_kwDODtV8184BKyTu --id $ITEM_ID --field-id PVTSSF_lADODtV8184BKyTuzg6jZAY --single-select-option-id SIZE_ID
```

> **Token scope note:** Project edits require `read:project,project` scopes. On "missing scopes" error, run `gh auth refresh -s read:project,project` and ask the user to re-authenticate, then retry — don't silently skip.

9. Display the new PR URL.

---

## Operation: `review` — Review PR before merge

For the current branch or a given PR number.

1. Get the PR state:
```bash
gh pr view --json number,title,state,reviewDecision,mergeable,mergeStateStatus,headRefName
```

2. Check for unresolved conversations:
```bash
gh api graphql -f query='query {
  repository(owner: "<OWNER>", name: "<REPO>") {
    pullRequest(number: PR_NUMBER) {
      reviewThreads(first: 100) {
        nodes { id isResolved path line comments(first: 1) { nodes { body } } }
      }
    }
  }
}'
```

List unresolved threads with comment content.

3. Check CI:
```bash
gh pr checks PR_NUMBER
```

4. Check if the branch is up to date:
```bash
gh pr view PR_NUMBER --json mergeStateStatus --jq '.mergeStateStatus'
```

5. Display the checklist:
```
## Review Checklist — PR #NUMBER

✅/❌ Unresolved conversations: X unresolved
✅/❌ CI: passed/failed/pending
✅/❌ Branch up to date: up-to-date / behind main
✅/❌ Mergeable: yes/no

### Unresolved threads:
- path/file.ts:42 — "comment..."
```

6. If everything is OK — suggest: "Ready to merge. Run `/merge`?"

---

## Operation: `label` — Manage labels and priority

For a given issue or PR number.

1. Display current labels:
```bash
gh issue view ISSUE_NUMBER --json labels
# or
gh pr view PR_NUMBER --json labels
```

2. Ask which labels to add/remove.

3. Apply changes:
```bash
gh issue edit ISSUE_NUMBER --add-label "LABEL" --remove-label "OLD_LABEL"
# or
gh pr edit PR_NUMBER --add-label "LABEL"
```

**Priorities (convention):**
| Label | When |
|---|---|
| `bug` + P0 | Blocks production |
| `enhancement` + P1 | Important for the next release |
| any + P2 | Nice-to-have |

**Testing labels:**
- `ready-for-review` → `testing` → `tested` / `needs-fixes`
