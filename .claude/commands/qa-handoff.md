# QA Handoff — Handoff to Tester

Prepare a QA ticket in Jira and hand off to the tester. Argument: issue or PR number.

## 1. Gather information

```bash
gh issue view {NUMBER} --json title,body,labels
gh pr view {NUMBER} --json title,body,url 2>/dev/null
```

## 2. Find the preview URL

Format: `https://{DEPLOY_ID}--<NETLIFY_SITE>.netlify.app`

```bash
gh pr list --state open --json number,headRefName,url
```

## 3. Create a QA ticket in Jira

Use the Atlassian MCP (`createJiraIssue`):

- **Project**: <JIRA_PROJECT_KEY>
- **Type**: Task
- **Assignee**: <assignee> (Jira account ID)
- **Body** (template):

```
## PR
[link to PR]

## What changed
[brief description of changes]

## Test scenarios

### T1: [Scenario name]
**Preconditions:** [initial state]
**Steps:**
1. ...
2. ...
**Expected result:** ...

### T2: ...

## Acceptance criteria
- [ ] [Criterion 1]
- [ ] [Criterion 2]
```

## 4. After receiving the report

- Test PASS → close the issue
- Test FAIL → create a new issue describing the problems
