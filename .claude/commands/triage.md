# Triage

Backlog prioritization for GitHub issues and Jira tickets without a milestone / release target. Reports the QA queue size and proposes priority + ownership.

> **Authoritative reference:** `.agent/skills/backlog-triage/SKILL.md`. This command file is a thin runbook — load the skill and follow its full workflow. **If a snippet here drifts from the skill, the skill wins.**

> **Required tooling:** `gh`, `jq`, `awk`. **All `<UPPER_SNAKE>` placeholders come from `.agent/context/project-ids.md`.** If any value is still `<...>`, halt and ask the user to fill it in — do not improvise IDs.

## 0. Memory consult

Read these in full before starting backlog or QA triage:

- `.claude/memory/feedback_for_testing_flow.md` — merged work may need a testing lane, not immediate closure.
- `.claude/memory/feedback_qa_ticket_status.md` — create QA tickets in the default/to-do state.
- `.claude/memory/feedback_pr_setup.md` — labels, assignee, and project fields after PR/issue creation.
- `.claude/memory/feedback_pr_path_overlap_check.md` — avoid bundling leftovers already covered by another PR.
- `.claude/memory/feedback_grounding_in_project.md` — prioritize from observed project data, not generic heuristics.
- `.claude/memory/feedback_codex_quality.md` — audit agent-created placeholders and topical relevance.

If a new triage failure mode lands in `MEMORY.md`, add the most relevant file here.

## Scope

Find open GitHub issues and Jira tickets without a milestone / release target, propose priority and ownership, and report the `For testing` queue size.

## Skeleton

> Resolve project IDs from `.agent/context/project-ids.md` once at the top of the script, then reuse:

```bash
set -euo pipefail

PROJECT_IDS_FILE=.agent/context/project-ids.md
# In project-ids.md the lines look like:
#   | Project ID (`PVT_...`) | `<PROJECT_ID>` | `gh api graphql ...` |
#   | Status                 | `<STATUS_FIELD_ID>` | usually built-in     |
#   | For testing            | `<STATUS_FOR_TESTING_ID>` |
# When split by backtick, the matched value sits at field $4 for the
# Project ID row (because the row contains an inline `PVT_...` token before it),
# and at field $2 for plain | Field | `<VALUE>` | rows.
PROJECT_ID=$(awk -F'`' '/Project ID \(`PVT_\.\.\.`\)/ {print $4; exit}' "$PROJECT_IDS_FILE")
STATUS_FIELD_ID=$(awk -F'`' '/^\| Status /             {print $2; exit}' "$PROJECT_IDS_FILE")
FOR_TESTING_OPTION_ID=$(awk -F'`' '/^\| For testing \|/   {print $2; exit}' "$PROJECT_IDS_FILE")

# Halt early if any placeholder is still unresolved
for v in PROJECT_ID STATUS_FIELD_ID FOR_TESTING_OPTION_ID; do
  case "${!v}" in '' | \<*\>) echo "Unresolved $v in $PROJECT_IDS_FILE" >&2; exit 1 ;; esac
done

# 1. GitHub issues without a milestone
gh issue list \
  --repo <OWNER>/<REPO> \
  --state open \
  --limit 200 \
  --json number,title,labels,assignees,milestone,updatedAt,url \
  --jq '.[] | select(.milestone == null)'

# 2. QA queue size (items in the "For testing" status)
gh api graphql --paginate \
  -F projectId="$PROJECT_ID" \
  -f query='
query($projectId: ID!, $endCursor: String) {
  node(id: $projectId) {
    ... on ProjectV2 {
      items(first: 100, after: $endCursor) {
        nodes {
          fieldValues(first: 20) {
            nodes {
              ... on ProjectV2ItemFieldSingleSelectValue {
                field { ... on ProjectV2SingleSelectField { id } }
                optionId
              }
            }
          }
          content {
            ... on Issue       { number title }
            ... on PullRequest { number title }
          }
        }
        pageInfo { hasNextPage endCursor }
      }
    }
  }
}' --jq ".data.node.items.nodes[] | select(.fieldValues.nodes[]? | (.field.id == \"$STATUS_FIELD_ID\" and .optionId == \"$FOR_TESTING_OPTION_ID\"))"
```

For Jira, use Atlassian MCP with:

```text
project = <JIRA_PROJECT_KEY>
AND statusCategory != Done
AND fixVersion is EMPTY
ORDER BY priority DESC, updated DESC
```

## Output

```markdown
## Backlog triage

**GitHub issues without milestone:** N
**Jira tickets without fixVersion:** M / not checked
**QA queue (`For testing`):** Q

### Recommended changes
| Item | Priority | Milestone | Owner | Why |
|---|---|---|---|---|
```

Do not mutate GitHub or Jira unless the user explicitly confirms or passes `--apply`. **For the full owner-mapping heuristics, severity rubric, and how to interpret labels, follow `.agent/skills/backlog-triage/SKILL.md`.**
