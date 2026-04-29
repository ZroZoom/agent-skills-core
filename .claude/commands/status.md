# Status Check

Quick overview of the repository state. Run ALL commands in parallel and display a concise dashboard.

## Commands to run

```bash
# 1. Current branch and uncommitted changes
git branch --show-current
git status --short

# 2. Last 5 commits
git log --oneline -5

# 3. Active branches (sorted by date)
git branch -a --sort=-committerdate --format='%(refname:short) (%(committerdate:relative))' | head -10

# 4. Open PRs with CI status
gh pr list --state open --json number,title,headRefName,statusCheckRollup --template '{{range .}}#{{.number}} {{.title}} [{{.headRefName}}] {{range .statusCheckRollup}}{{.conclusion}} {{end}}{{"\n"}}{{end}}'

# 4a. Version-bump collision check (>1 open = race between auto-version-bump runs)
gh pr list --search 'chore: bump version in:title base:main' --state open --json number,title,headRefName --jq '[.[] | select(.headRefName | startswith("chore/bump-v"))] | if length > 1 then "⚠️ COLLISION: " + (length | tostring) + " open bump PRs — " + ([.[] | "#\(.number) \(.title)"] | join(", ")) else empty end'

# 5. Open issues (top 10)
gh issue list --state open --limit 10 --json number,title,labels --template '{{range .}}#{{.number}} {{.title}} {{range .labels}}[{{.name}}] {{end}}{{"\n"}}{{end}}'

# 6. Dependabot alerts (open)
gh api repos/{owner}/{repo}/dependabot/alerts --jq '[.[] | select(.state == "open")] | if length == 0 then "No open alerts" else sort_by(.security_advisory.severity) | group_by(.security_advisory.severity) | map("\(.[0].security_advisory.severity): \(length) (\([.[].security_vulnerability.package.name] | unique | join(", ")))") | join(", ") end'

# 7. CI status on main (last 5 workflow runs)
gh run list --branch main --limit 5 --json name,conclusion,status,startedAt --template '{{range .}}{{.name}}: {{if .conclusion}}{{.conclusion}}{{else}}{{.status}}{{end}} ({{.startedAt}}){{"\n"}}{{end}}'

# 8. Milestones — progress
gh api repos/{owner}/{repo}/milestones --jq '.[] | select(.state == "open") | "\(.title): \(.closed_issues)/\(.closed_issues + .open_issues) closed (due: \(.due_on[:10] // "no date"))"'

# 9. Repo memory drift — entries changed in last 7 days (cross-agent SSOT at .claude/memory/)
git log --since='7 days ago' --diff-filter=AM --name-only --pretty=format: -- '.claude/memory/*.md' | grep -v '^$' | sort -u
```

## 10. Jira — active tickets (project <JIRA_PROJECT_KEY>)

Use the Atlassian MCP tool `searchJiraIssuesUsingJql` with:
- cloudId: `<JIRA_CLOUD_ID>`
- jql: `project = <JIRA_PROJECT_KEY> AND status NOT IN (Done, Closed) ORDER BY updated DESC`
- limit: 10

Display in this format:
```
**Jira <JIRA_PROJECT_KEY> (X active):**
- <JIRA_KEY>-123 Title [status] (assignee)
```

## 11. Netlify — deploy status

Use the Netlify MCP tool `netlify-deploy-services-reader` to check the latest deploy status.
If the MCP tool is unavailable, use this command:
```bash
gh api repos/{owner}/{repo}/deployments --jq 'if length == 0 then "No deployments" else .[0] | .id as $id | "\(.environment): \(.description // "no description") (\(.created_at))" end'
```

## Response format

Display a concise dashboard in this format:

```
## Repository Status

**Branch:** feature/xyz (3 uncommitted files)
**Recent commits:** ...

**Open PRs (X):**
- #123 Title [CI: passed/failed/pending]

**Open issues (Y):**
- #456 Title [label]

**Jira <JIRA_PROJECT_KEY> (X active):**
- <JIRA_KEY>-123 Title [In Progress] (<assignee>)

**Milestones:**
- M1: Security & Compliance: 8/14 closed (due: 2026-05-15)
- M2: Matematyka E8 Ready: 10/12 closed (due: 2026-06-15)

**Dependabot:**
- high: 2 (minimatch, tar), moderate: 1 (ajv)
- (or) No open alerts

**CI on main:**
- Quality Checks: success (2h ago)
- CodeQL: in_progress

**Netlify:**
- Production: ready (https://xxx.netlify.app)

**Repo memory drift (last 7 days):**
- `.claude/memory/feedback_xyz.md` — added/updated 2 days ago
- (or) No changes — repo memory is current

If any entries are listed, briefly note the topics so the agent knows whether to read them before proceeding.

**Needs attention:**
- PR #123 has failed CI
- 3 uncommitted files
- <JIRA_KEY>-456 blocks release
- 2 high Dependabot alerts!
- CI on main FAILED
- ⚠️ COLLISION: 2 open bump PRs — #1941 chore: bump version to 3.28.0, #1942 chore: bump version to 3.27.2
```

Flag everything that requires immediate action.
