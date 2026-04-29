# Project Board Analysis

Analyze the GitHub Project board and display a summary dashboard.

## API Strategy

- **Project board data**: `gh api graphql --paginate` (NOT `gh project item-list` — broken with "unknown owner type")
- **Milestones, PRs, issues**: REST API via `gh api repos/...` (no GraphQL cost)
- **Rate limit**: Check GraphQL budget first. If exhausted, skip board data and show REST-only dashboard.

## Commands

### 0. Check GraphQL rate limit (always run first)

```bash
gh api rate_limit --jq '.resources.graphql'
```

If `remaining` < 10: skip steps 1 and 5 (both require GraphQL), show REST-only dashboard with note "Board data unavailable (rate limit)".

### 1. Project board items (GraphQL, auto-paginates ~6 pages for 600 items)

```bash
gh api graphql --paginate -f query='
query($endCursor: String) {
  organization(login: "<OWNER>") {
    projectV2(number: 2) {
      items(first: 100, after: $endCursor) {
        nodes {
          fieldValueByName(name: "Status") {
            ... on ProjectV2ItemFieldSingleSelectValue { name }
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
}' --jq '.data.organization.projectV2.items.nodes[] | "\(.fieldValueByName.name // "none")\t\(.content.number // "")\t\(.content.title // "")"'
```

Output: TSV `status\tnumber\ttitle`. Extract:
- **Status counts**: pipe to `cut -f1 | sort | uniq -c | sort -rn`
- **For testing items**: `grep "^For testing"`
- **In progress items**: `grep "^In progress"`
- **All project numbers**: `cut -f2 | sort -n` (for cross-reference in step 5)

### 2. Milestones (REST — 1 call)

```bash
gh api "repos/<OWNER>/<REPO>/milestones?per_page=100" --jq '.[] | select(.state == "open") | "\(.title)\t\(.closed_issues)\t\(.closed_issues + .open_issues)\t\(.due_on[:10] // "none")"'
```

### 3. Open PRs (REST — 1 call)

```bash
gh api "repos/<OWNER>/<REPO>/pulls?state=open&per_page=100" --jq '.[] | "#\(.number) \(.title[:60]) [\(if .draft then "draft" else "ready" end)]"'
```

### 4. Open issues (REST — 1 call)

```bash
gh api "repos/<OWNER>/<REPO>/issues?state=open&per_page=100" --jq '.[] | select(.pull_request == null) | "#\(.number) \(.title[:50]) [M: \(.milestone.title // "NONE")]"'
```

### 5. Cross-reference and auto-add missing items

Compare issue/PR numbers from steps 3-4 against project item numbers from step 1.
Report items NOT in the project and issues without a milestone.

**Auto-add**: Any open PR or issue NOT in the project board must be added automatically (no user prompt needed).

1. Get the project node ID from step 1 query (add `id` field to the projectV2 selection), or fetch it:
   ```bash
   gh api graphql -f query='{ organization(login: "<OWNER>") { projectV2(number: 2) { id } } }' --jq '.data.organization.projectV2.id'
   ```
2. Get node IDs for missing items (issues API works for both issues and PRs):
   ```bash
   gh api repos/<OWNER>/<REPO>/issues/NUM --jq '.node_id'
   ```
3. Add each missing item:
   ```bash
   gh api graphql -f query='mutation { addProjectV2ItemById(input: {projectId: "PROJECT_ID", contentId: "NODE_ID"}) { item { id } } }'
   ```
4. Report how many items were added in the dashboard under **Auto-fixed**.

## Format

```
## GitHub Project: Szkoła Przyszłości AI — Development

**Board:**
| Status | Count |
|---|---:|
| Done | 485 |
| For testing | 98 |
| In progress | 1 |
| Backlog | 16 |

**Milestones:**
| Milestone | Progress | Due | Status |
|---|---|---|---|
| M1: Security & Compliance | 12/13 (92%) | 2026-05-15 | 🟢 1 left, 37d |
| M2: Matematyka E8 Ready | 14/16 (88%) | 2026-06-15 | 🟢 on track |
| <M3: Sample milestone> | 0/10 (0%) | 2026-07-15 | 🔴 not started, 98d |

**Open PRs:**
- #1796 refactor(ci): simplify self-analysis... [ready]
- #1792 fix(feedback): broken comment submit... [ready]

**In progress:**
- #1234 Some feature

**Needs attention:**
- X items "For testing" awaiting QA
- Y issues without milestone

**Auto-fixed:**
- Added Z items to project board: #1234, #5678
```

Calculate days remaining for each milestone. Flag:
- 🔴 overdue OR 0% with <100 days
- 🟡 <50% with <60 days
- 🟢 on track
- ⚪ >120 days remaining
