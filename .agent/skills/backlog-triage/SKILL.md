---
name: backlog-triage
description: "Backlog prioritization for GitHub issues and Jira tickets. Finds items without milestones, proposes owners and priority, and reports QA queue size. Trigger when: /triage backlog, prioritize backlog, issues without milestone, triage backlogu."
---

# Backlog Triage Skill

Prioritize open GitHub issues and Jira tickets without a milestone or release target.

## Contract

- Inputs: optional filters such as `--github-only`, `--jira-only`, `--limit N`, `--apply`.
- Output: a Polish triage report with proposed milestone, owner, and priority.
- Side effects: no mutations unless the user passes `--apply` or explicitly confirms.

## Workflow

### 1. GitHub issues without milestone

```bash
gh issue list \
  --repo <OWNER>/<REPO> \
  --state open \
  --limit 200 \
  --json number,title,labels,assignees,milestone,updatedAt,url \
  --jq '.[] | select(.milestone == null)'
```

### 2. QA queue size

Use the Project board status field from `.agent/context/project-ids.md`:

```bash
PROJECT_IDS_FILE=.agent/context/project-ids.md
PROJECT_ID=$(awk -F'`' '/Project ID:/ {print $2; exit}' "$PROJECT_IDS_FILE")
STATUS_FIELD_ID=$(awk -F'`' '/^## Status Field:/ {print $2; exit}' "$PROJECT_IDS_FILE")
FOR_TESTING_OPTION_ID=$(awk -F'`' '/\| For testing \|/ {print $2; exit}' "$PROJECT_IDS_FILE")

gh api graphql --paginate \
  -f projectId="$PROJECT_ID" \
  -f query='
query($projectId: ID!, $endCursor: String) {
  node(id: $projectId) {
    ... on ProjectV2 {
      items(first: 100, after: $endCursor) {
        nodes {
          fieldValues(first: 20) {
            nodes {
              ... on ProjectV2ItemFieldSingleSelectValue {
                field {
                  ... on ProjectV2SingleSelectField { id }
                }
                optionId
                name
              }
            }
          }
          content {
            ... on Issue { number title }
            ... on PullRequest { number title }
          }
        }
        pageInfo { hasNextPage endCursor }
      }
    }
  }
}' --jq ".data.node.items.nodes[] | select(.fieldValues.nodes[]? | (.field.id == \"$STATUS_FIELD_ID\" and .optionId == \"$FOR_TESTING_OPTION_ID\"))"
```

Report the count and list the oldest or most important items.

### 3. Jira tickets without release target

Use Atlassian MCP when available:

- cloudId: `04762561-2290-48a3-97b3-3700f99ca8ee`
- JQL:

```text
project = SPZA
AND statusCategory != Done
AND fixVersion is EMPTY
ORDER BY priority DESC, updated DESC
```

If Jira MCP is unavailable, mark Jira as `not checked` and keep the GitHub report useful.

### 4. Priority rubric

| Priority | Use when |
|---|---|
| P0 | Blocks demo, production, security, auth, payments, data loss, deploy. |
| P1 | Directly affects core UX, active milestone delivery, or a public path users will hit. |
| P2 | Tooling, internal workflow, polish, non-blocking quality improvements. |
| P3 | Nice-to-have, deferred infra checks, exploratory tasks. |

Owner hints:

| Area | Suggested owner |
|---|---|
| content, docs | content owner or relevant agent |
| code quality, TypeScript, routing | core dev |
| testing, QA queue | test manager / QA |
| Supabase, RLS, migrations | database owner |
| GitHub, CI, skills, release process | repo-ops/tooling owner |

### 5. Output

```markdown
## Backlog triage

**GitHub issues without milestone:** N
**Jira tickets without fixVersion:** M / not checked
**QA queue (`For testing`):** Q

### Recommended changes
| Item | Priority | Milestone | Owner | Why |
|---|---|---|---|---|
| #123 | P1 | M2: Matematyka E8 Ready | core dev | ... |

### Apply plan
- Add milestone ...
- Add labels ...
- Assign ...
```

If the user confirms applying changes, use `gh issue edit` for GitHub and Atlassian MCP for Jira. Apply one item at a time and report partial failures.

## Rules

- Do not downgrade P0/P1 without evidence.
- Do not assign issues to Copilot unless the issue is explicitly suitable for Copilot implementation.
- Do not close issues from this skill.
- Do not mutate Jira/GitHub in preview mode.
