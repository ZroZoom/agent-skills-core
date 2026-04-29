# Repo Operations

Repository management: creating issues/PRs, pre-merge review, labels/milestones.
The operation depends on the argument: `issue`, `pr`, `review`, `label`.
If no argument is provided — ask the user what they want to do.

> **Authoritative reference:** `.agent/skills/repo-ops/SKILL.md` covers the full Git/PR lifecycle, GitHub Project integration, and review-thread resolution. This command file is a thin runbook for the four most common operations and links into the skill for deeper procedures. **If a snippet here drifts from the skill, the skill wins.**

> **Required tooling:** `gh`, `git`, `jq`. **All `<UPPER_SNAKE>` placeholders come from `.agent/context/project-ids.md`.** If any value is still `<...>`, halt and ask the user to fill it in — do not improvise IDs.

> **Bash safety:** every snippet starts with `set -euo pipefail`. Untrusted strings (issue/PR titles, comment bodies, branch names) are delivered to `gh` via `--body-file` / `--title-file` or `-F field=@/tmp/file`, NEVER via shell interpolation. See `CLAUDE.md` → `Untrusted Input`.

---

## Operation: `issue` — Create Issue

1. Ask for the title (if not provided in arguments).
2. Ask for the type: `bug` / `enhancement` / `docs` / `refactor` / `content`.
3. Determine priority: P0 / P1 / P2.
4. Draft the body in this format:

   ```
   ## Problem
   [what is broken or missing]

   ## Expected behavior
   [how it should work]

   ## Steps to reproduce (for bugs)
   1. ...
   ```

5. Resolve the milestone (ask the user; capture by **number**, not title — titles can contain shell-special characters):

   ```bash
   set -euo pipefail
   gh api repos/<OWNER>/<REPO>/milestones --jq '.[] | {number,title}'
   # User picks a number, e.g. 7
   MILESTONE_NUMBER=7
   ```

6. **Write the title and body to files first**, then create the issue from those files. Never interpolate user-supplied strings directly into the shell:

   ```bash
   set -euo pipefail

   # Write the title and body to disk so quotes/backticks/newlines can't escape into the shell.
   printf '%s' "$ISSUE_TITLE" > /tmp/issue-title.txt
   cat > /tmp/issue-body.md <<'BODY'
   ## Problem
   <fill in>

   ## Expected behavior
   <fill in>
   BODY

   ISSUE_URL=$(gh issue create \
     --title "$(cat /tmp/issue-title.txt)" \
     --body-file /tmp/issue-body.md \
     --label "$LABEL" \
     --milestone "$MILESTONE_NUMBER" \
     --assignee "@me")

   ISSUE_NUMBER=$(echo "$ISSUE_URL" | sed -n 's#.*/\([0-9][0-9]*\)$#\1#p')
   echo "Created issue #$ISSUE_NUMBER"
   ```

   **Note:** `--assignee "@me"` = the current GitHub user (issue owner). Use `@copilot` ONLY when delegating implementation to Copilot SWE Agent. Don't confuse assignee (responsibility) with reviewer (review-only role).

   **Available labels:** `bug`, `enhancement`, `documentation`, `refactor`, `content`, `ui/ux`, `database`, `tests`, `i18n`, `accessibility`, `security` (customize for your project).

7. Add to GitHub Project and set fields. **For full GraphQL details, fetch field IDs, and option IDs, follow `.agent/skills/repo-ops/SKILL.md` → section 7.** Skeleton:

   ```bash
   set -euo pipefail
   ITEM_ID=$(gh api graphql \
     -f query='query($owner:String!,$repo:String!,$number:Int!) {
       repository(owner:$owner, name:$repo) {
         issue(number:$number) {
           projectItems(first:1) { nodes { id } }
         }
       }
     }' \
     -F owner='<OWNER>' -F repo='<REPO>' -F number="$ISSUE_NUMBER" \
     --jq '.data.repository.issue.projectItems.nodes[0].id')

   gh project item-edit --project-id <PROJECT_ID> --id "$ITEM_ID" \
     --field-id <PRIORITY_FIELD_ID> --single-select-option-id <PRIORITY_P1_ID>
   gh project item-edit --project-id <PROJECT_ID> --id "$ITEM_ID" \
     --field-id <SIZE_FIELD_ID>     --single-select-option-id <SIZE_M_ID>
   ```

8. Display the new issue URL.

> **Token scope:** GitHub Project edits require `read:project,project`. On "missing scopes", run `gh auth refresh -s read:project,project` and retry. Do NOT silently skip project assignment.

---

## Operation: `pr` — Create PR

1. Verify the current branch is `feature/*` / `fix/*` / `chore/*`:

   ```bash
   set -euo pipefail
   BRANCH=$(git branch --show-current)
   case "$BRANCH" in
     main|master) echo "Refusing to create PR from $BRANCH" >&2; exit 1 ;;
   esac
   git status --short
   ```

2. If there are uncommitted changes — stop and ask the user.

3. Push the branch if there is no remote:

   ```bash
   git push -u origin "$BRANCH"
   ```

4. Find related issues (search commit messages and branch name):

   ```bash
   git log main..HEAD --oneline
   ```

5. Resolve the milestone (capture by **number**):

   ```bash
   gh api repos/<OWNER>/<REPO>/milestones --jq '.[] | {number,title}'
   MILESTONE_NUMBER=7
   ```

6. **Write the title and body to files**, then create the PR via `--body-file`. Apply the same untrusted-input safety to the title (it can come from an issue title that contains backticks, `$()` etc.):

   ```bash
   set -euo pipefail

   # Title
   printf '%s' "$PR_TITLE" > /tmp/pr-title.txt

   # Body
   cat > /tmp/pr-body.md <<'BODY'
   ## Description
   [what was done and why]

   ## Changes
   - ...

   ## Tests
   - [ ] typecheck: `npm run typecheck`
   - [ ] lint: `npm run lint`
   - [ ] build: `npm run build`

   ## Related issues
   Closes #<ISSUE_NUMBER>
   BODY

   gh pr create \
     --title "$(cat /tmp/pr-title.txt)" \
     --body-file /tmp/pr-body.md \
     --label "ready-for-review" \
     --label "$DOMAIN_LABEL" \
     --milestone "$MILESTONE_NUMBER" \
     --assignee "@me"
   ```

   **Roles:**
   - `--assignee "@me"` = the PR author / owner (responsibility for landing it).
   - **Reviewers are governed by your `main` branch ruleset** (CODEOWNERS, required reviewers, automated bots like Copilot). Configure once, do not re-request reviewers manually each time.
   - `gh pr create` does not accept `--reviewer "@copilot"` — Copilot is triggered by your ruleset, not a CLI flag.
   - DO NOT set `@copilot` as the PR assignee — it confuses ownership with review duty.

7. Add to GitHub Project and set fields. **Full procedure: `.agent/skills/repo-ops/SKILL.md` → section 7.** Skeleton:

   ```bash
   set -euo pipefail
   PR_ID=$(gh pr view "$PR_NUMBER" --json id --jq '.id')

   ITEM_ID=$(gh api graphql \
     -f query='mutation($projectId:ID!,$contentId:ID!) {
       addProjectV2ItemById(input:{projectId:$projectId, contentId:$contentId}) {
         item { id }
       }
     }' \
     -F projectId='<PROJECT_ID>' -F contentId="$PR_ID" \
     --jq '.data.addProjectV2ItemById.item.id')

   gh project item-edit --project-id <PROJECT_ID> --id "$ITEM_ID" \
     --field-id <STATUS_FIELD_ID>   --single-select-option-id <STATUS_IN_REVIEW_ID>
   gh project item-edit --project-id <PROJECT_ID> --id "$ITEM_ID" \
     --field-id <PRIORITY_FIELD_ID> --single-select-option-id <PRIORITY_P1_ID>
   gh project item-edit --project-id <PROJECT_ID> --id "$ITEM_ID" \
     --field-id <SIZE_FIELD_ID>     --single-select-option-id <SIZE_M_ID>
   ```

8. Display the new PR URL.

---

## Operation: `review` — Review PR before merge

For the current branch or a given PR number. **For the full review-thread workflow (read-before-resolve, batch GraphQL mutations, `mergeStateStatus` interpretation), follow `.agent/skills/repo-ops/SKILL.md` → section 9.** Skeleton:

```bash
set -euo pipefail
PR="${PR:-$(gh pr view --json number --jq '.number')}"

gh pr view "$PR" --json number,title,state,reviewDecision,mergeable,mergeStateStatus,headRefName

gh api graphql \
  -f query='query($owner:String!,$repo:String!,$pr:Int!) {
    repository(owner:$owner, name:$repo) {
      pullRequest(number:$pr) {
        reviewThreads(first:100) {
          nodes { id isResolved path line comments(first:1) { nodes { body } } }
        }
      }
    }
  }' \
  -F owner='<OWNER>' -F repo='<REPO>' -F pr="$PR"

gh pr checks "$PR"
```

Then output the checklist:

```
## Review Checklist — PR #<N>

✅/❌ Unresolved conversations: X unresolved
✅/❌ CI: passed / failed / pending
✅/❌ Branch up to date: up-to-date / behind main
✅/❌ Mergeable: yes / no

### Unresolved threads:
- path/file.ts:42 — "comment..."
```

If everything is OK — suggest: "Ready to merge. Run `/merge`?"

---

## Operation: `label` — Manage labels and priority

For a given issue or PR number.

```bash
set -euo pipefail
gh issue view "$NUMBER" --json labels  # or: gh pr view "$NUMBER" --json labels

# Apply changes after asking the user
gh issue edit "$NUMBER" --add-label "$LABEL" --remove-label "$OLD_LABEL"
# or:
gh pr edit "$NUMBER" --add-label "$LABEL"
```

**Priorities (convention):**

| Label | When |
|---|---|
| `bug` + P0 | Blocks production |
| `enhancement` + P1 | Important for the next release |
| any + P2 | Nice-to-have |

**Testing labels:** `ready-for-review` → `testing` → `tested` / `needs-fixes`
